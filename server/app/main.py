from fastapi import FastAPI
import cloudinary
import firebase_admin
from firebase_admin import credentials
from dotenv import load_dotenv
import json
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
#
# Two ways to supply it, same as DATABASE_URL vs a local .env file:
# - FIREBASE_SERVICE_ACCOUNT_JSON: the key's full JSON contents, as one env
#   var string. Used in production (Railway) — a secret should be an env var,
#   never a file shipped with the build.
# - FIREBASE_SERVICE_ACCOUNT_PATH: a path to the key file on disk. Used for
#   local dev, where keeping it as a gitignored file is simpler than pasting
#   JSON into .env.
_firebase_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
if _firebase_json:
    _firebase_credential = credentials.Certificate(json.loads(_firebase_json))
else:
    _firebase_credential = credentials.Certificate(os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))

firebase_admin.initialize_app(_firebase_credential)

app.include_router(stream_router)
app.include_router(auth_router)