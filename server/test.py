import base64
import requests

url = "http://127.0.0.1:8000/predict/slice"
files = {"image": open(r"D:\Programming\Uni\Image Processing\Project\liver_tumor_segmentation\server\volume-0.nii", "rb")}

res = requests.post(url, files=files)
data = res.json()

# decode and save
for name in ["image", "mask"]:
    with open(f"{name}.png", "wb") as f:
        f.write(base64.b64decode(data[name]))
