from fastapi import FastAPI
import cloudinary
import firebase_admin
from firebase_admin import credentials
from dotenv import load_dotenv
import os
from app.core.views.stream.stream import router as stream_router
from app.core.views.auth.auth import router as auth_router

load_dotenv()

app = FastAPI()

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True,
)

# Firebase Admin SDK: lets the backend verify ID tokens issued by Firebase Auth
# on the client, using the service account key (never committed to git).
firebase_admin.initialize_app(
    credentials.Certificate(os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))
)

app.include_router(stream_router)
app.include_router(auth_router)