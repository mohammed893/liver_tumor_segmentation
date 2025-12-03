from fastapi import FastAPI, UploadFile, File
from PIL import Image
import numpy as np
import torch
import torchvision.transforms as transforms
import base64
import io
import nibabel as nib
from fastapi.responses import JSONResponse

model_path = r"D:\Programming\Uni\Image Processing\Project\liver_tumor_segmentation\server\model\unet_best_epoch28_dice0.9688.pth"
model = torch.load(model_path, map_location=torch.device('cpu'))
# model.eval()

app = FastAPI(title="Image Segmentation API")

def image_to_base64(img: Image.Image):
    """Convert PIL Image to base64 string."""
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode()

def array_to_base64(mask_array: np.ndarray):
    """Convert 2D numpy mask to base64 PNG."""
    if mask_array.ndim == 2:
        img = Image.fromarray(mask_array.astype(np.uint8))
    else:
        img = Image.fromarray(mask_array)
    return image_to_base64(img)


def run_model(image_array: np.ndarray):
    h, w = image_array.shape[:2]
    mask = np.zeros((h, w), dtype=np.float32)
    
    cy, cx = h // 2, w // 2
    r = min(h, w) // 4

    y, x = np.ogrid[:h, :w]
    mask[(x-cx) ** 2 + (y-cx) ** 2 <= r ** 2] = 1

    return mask

@app.post("/predict/slice")
async def predict_slice(image: UploadFile = File(...)):
    
    filename = image.filename.lower()

    if filename.endswith((".png", ".jpg", ".jpeg")):
        image_bytes = await image.read()
        pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_array = np.array(pil_image)

        mask = run_model(image_array)

        overlay_image = image_array.copy()
        overlay_image[mask == 1] = [255, 0, 0]

        mask_64 = array_to_base64(mask * 255)
        overlay_64 = array_to_base64(overlay_image)

        return JSONResponse(content={
            "mask": mask_64,
            "overlay": overlay_64,
        })


    elif filename.endswith((".nii", ".nii.gz")):
        data = await image.read()

        if filename.endswith(".nii.gz"):
            temp_path = "temp_input.nii.gz"
        else:
            temp_path = "temp_input.nii"

        with open(temp_path, "wb") as f:
            f.write(data)
            
        nifti = nib.load(temp_path)
        vol = nifti.get_fdata()

        mid = vol[:, :, vol.shape[2] // 2]

        mn, mx = np.min(mid), np.max(mid)
        if mx - mn < 1e-6:
            mid_norm = np.zeros_like(mid)
        else:
            mid_norm = (mid - mn) / (mx - mn)

        mid_uint8 = (mid_norm * 255).astype(np.uint8)

        mask = run_model(mid_uint8)

        mask_64 = array_to_base64(mask * 255)
        image_64 = array_to_base64(mid_uint8)

        return JSONResponse({
            "image": image_64,
            "mask": mask_64
        })


    else:
        return JSONResponse(content={
            "error": "Invalid file type"
        }, status_code=400)