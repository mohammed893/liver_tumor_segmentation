import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.transforms as transforms
import base64
import io
import nibabel as nib
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import os
import sys
import uvicorn
import tempfile

IMAGE_SIZE = (224, 224)
MODEL_PATH = r"D:\Programming\Uni\Image Processing\Project\liver_tumor_segmentation\server\model\unet_best_epoch28_dice0.9688.pth"

def load_nifti_bytes(data: bytes, original_filename: str):
    """
    Load NIfTI data from bytes buffer.
    Nibabel requires a physical file path, so we use a temporary file.
    """

    suffix = ".nii.gz" if original_filename.lower().endswith(".nii.gz") else ".nii"

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name

    try:
        img = nib.load(tmp_path)
        data_arr = np.asanyarray(img.dataobj)
        if data_arr.ndim == 4:
            data_arr = data_arr.squeeze()
        return data_arr
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

def normalize_volume(volume: np.ndarray) -> np.ndarray:
    volume = np.clip(volume, -1000, 400)
    volume = (volume - volume.min()) / (volume.max() - volume.min() + 1e-8)
    return volume.astype(np.float32)

# --- 2) U-Net Model Definition ---
class DoubleConv(nn.Module):
    def __init__(self, in_ch, out_ch):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm2d(out_ch),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_ch, out_ch, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm2d(out_ch),
            nn.ReLU(inplace=True),
        )
    def forward(self, x): return self.net(x)

class Down(nn.Module):
    def __init__(self, in_ch, out_ch):
        super().__init__()
        self.pool_conv = nn.Sequential(nn.MaxPool2d(2), DoubleConv(in_ch, out_ch))
    def forward(self, x): return self.pool_conv(x)

class Up(nn.Module):
    def __init__(self, in_ch, out_ch, bilinear=True):
        super().__init__()
        if bilinear:
            self.up = nn.Upsample(scale_factor=2, mode='bilinear', align_corners=True)
            self.conv = DoubleConv(in_ch, out_ch)
        else:
            self.up = nn.ConvTranspose2d(in_ch//2, in_ch//2, kernel_size=2, stride=2)
            self.conv = DoubleConv(in_ch, out_ch)

    def forward(self, x1, x2):
        x1 = self.up(x1)
        # pad if needed
        diffY = x2.size()[2] - x1.size()[2]
        diffX = x2.size()[3] - x1.size()[3]
        x1 = F.pad(x1, [diffX // 2, diffX - diffX // 2,
                        diffY // 2, diffY - diffY // 2])
        x = torch.cat([x2, x1], dim=1)
        return self.conv(x)

class UNet(nn.Module):
    def __init__(self, n_channels=1, n_classes=1, base_c=32, bilinear=True):
        super().__init__()
        self.inc = DoubleConv(n_channels, base_c)
        self.down1 = Down(base_c, base_c*2)
        self.down2 = Down(base_c*2, base_c*4)
        self.down3 = Down(base_c*4, base_c*8)
        self.down4 = Down(base_c*8, base_c*8)
        self.up1 = Up(base_c*16, base_c*4, bilinear)
        self.up2 = Up(base_c*8, base_c*2, bilinear)
        self.up3 = Up(base_c*4, base_c, bilinear)
        self.up4 = Up(base_c*2, base_c, bilinear)
        self.outc = nn.Conv2d(base_c, n_classes, kernel_size=1)

    def forward(self, x):
        x1 = self.inc(x)       
        x2 = self.down1(x1)   
        x3 = self.down2(x2)
        x4 = self.down3(x3)
        x5 = self.down4(x4)
        x = self.up1(x5, x4)
        x = self.up2(x, x3)
        x = self.up3(x, x2)
        x = self.up4(x, x1)
        logits = self.outc(x)
        return logits


# --- 3) Model Loading ---

try:
    model = UNet(n_channels=1, n_classes=1, base_c=32) 
    checkpoint = torch.load(MODEL_PATH, map_location=torch.device('cpu'))
    model.load_state_dict(checkpoint['model_state'])
    model.eval()
    print(f"Model loaded successfully from {MODEL_PATH}")
except FileNotFoundError:
    sys.stderr.write(f"WARNING: Model checkpoint not found at {MODEL_PATH}. API will not function.\n")
    model = None
except Exception as e:
    sys.stderr.write(f"ERROR: Could not load model. Check UNet definition or checkpoint structure. Details: {e}\n")
    model = None


# --- 4) API Utility Functions ---

def image_to_base64(img: Image.Image) -> str:
    """Convert PIL Image to base64 string."""
    buffer = io.BytesIO()

    if img.mode == 'L' or img.mode == 'F':
        img.save(buffer, format="PNG")
    else:
        img.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode()

def array_to_base64(arr: np.ndarray, is_mask=False) -> str:
    """Convert 2D numpy array (image or mask) to base64 PNG."""
    if is_mask:
        # For masks (0 or 1), scale to 0/255 for better visual output
        img = Image.fromarray((arr * 255).astype(np.uint8), mode='L')
    else:
        # For normalized image arrays (0-255 uint8)
        if arr.dtype == np.float32 and arr.max() <= 1.01:
             arr = (arr * 255).astype(np.uint8)
        img = Image.fromarray(arr, mode='L')
        
    return image_to_base64(img)


def run_model(slice_array: np.ndarray, original_shape: tuple) -> np.ndarray:
    """
    Runs segmentation on a single, normalized 2D slice.
    :param slice_array: 2D numpy array (float32, [0, 1])
    :param original_shape: (H, W) of the input slice for mask resizing.
    :return: 2D numpy array of the mask (float32, 0 or 1) resized to original_shape.
    """
    if model is None:
        raise RuntimeError("Model is not loaded.")

    img_pil = Image.fromarray(slice_array)
    img_resized = img_pil.resize(IMAGE_SIZE, Image.BILINEAR)
    img_np_resized = np.array(img_resized)

    input_tensor = torch.from_numpy(img_np_resized).unsqueeze(0).unsqueeze(0).float()
    
    model.eval()
    with torch.no_grad():
        output = model(input_tensor) 
        
        mask_probs = torch.sigmoid(output) 
        mask_preds = (mask_probs > 0.5).float() 

    mask_np_resized = mask_preds.squeeze().cpu().numpy() 

    mask_np_original_size = np.array(Image.fromarray(mask_np_resized).resize(
        (original_shape[1], original_shape[0]), Image.NEAREST
    ))

    return mask_np_original_size


app = FastAPI(title="Image Segmentation API")

@app.post("/predict/slice")
async def predict_slice(image: UploadFile = File(...)):
    if model is None:
        raise HTTPException(status_code=503, detail="Model service is currently unavailable.")
        
    filename = image.filename.lower()
    data = await image.read()

    if filename.endswith((".png", ".jpg", ".jpeg")):
        try:
            pil_image = Image.open(io.BytesIO(data)).convert("L") 
            original_shape = pil_image.size[::-1] 
            
            image_array_uint8 = np.array(pil_image)
            image_array_norm = image_array_uint8.astype(np.float32) / 255.0
            
            mask = run_model(image_array_norm, original_shape)

            overlay_image = np.stack([image_array_uint8] * 3, axis=-1) 
            
            mask_indices = mask == 1
            overlay_image[mask_indices] = [255, 0, 0] 

            # Convert outputs to base64
            mask_64 = array_to_base64(mask, is_mask=True)
            overlay_64 = image_to_base64(Image.fromarray(overlay_image.astype(np.uint8)))

            return JSONResponse(content={
                "original_image": array_to_base64(image_array_uint8),
                "mask": mask_64,
                "overlay": overlay_64,
            })
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error processing 2D image: {e}")

    elif filename.endswith((".nii", ".nii.gz")):
        try:
            vol = load_nifti_bytes(data, filename)
            vol_norm = normalize_volume(vol) 

            z_dim = vol_norm.shape[2]
            middle_slice_index = z_dim // 2
            mid_slice_norm = vol_norm[:, :, middle_slice_index] 
            original_shape = mid_slice_norm.shape 

            mask = run_model(mid_slice_norm, original_shape)
            
            mid_uint8 = (mid_slice_norm * 255).astype(np.uint8)

            overlay_image = np.stack([mid_uint8] * 3, axis=-1) 
            mask_indices = mask == 1
            overlay_image[mask_indices] = [255, 0, 0] 

            mask_64 = array_to_base64(mask, is_mask=True)
            image_64 = array_to_base64(mid_uint8)
            overlay_64 = image_to_base64(Image.fromarray(overlay_image.astype(np.uint8)))

            return JSONResponse({
                "image": image_64,
                "mask": mask_64,
                "overlay": overlay_64
            })
            
        except Exception as e:
            print(f"Error processing NIfTI file: {e}") 
            raise HTTPException(status_code=500, detail=f"Error processing NIfTI file: {e}")



    else:
        raise HTTPException(status_code=400, detail="Invalid file type. Only PNG, JPG, NII, or NII.GZ are supported.")

if __name__ == "__main__":

    uvicorn.run(app, host="0.0.0.0", port=8000)