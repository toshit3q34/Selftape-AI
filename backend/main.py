from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from process_pdf import extract_script
import shutil
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or your Flutter web/mobile origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/upload-pdf/")
async def upload_pdf(file: UploadFile = File(...)):
    file_location = f"scripts/{file.filename}"
    with open(file_location, "wb") as f:
        shutil.copyfileobj(file.file, f)
    
    script_text = extract_script(file_location)
    os.remove(file_location)  # Optional: cleanup
    
    return {"text": script_text}
