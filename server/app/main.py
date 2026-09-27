from fastapi import FastAPI
import cloudinary
from dotenv import load_dotenv
import os
from app.core.views.stream.stream import router as stream_router

load_dotenv()

app = FastAPI()

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True,
)

app.include_router(stream_router)