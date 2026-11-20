import json

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

import cloudinary.utils

from app.database import get_db
from scripts.ingest_cloudinary import BASE_FOLDER, get_or_create_album, ingest_song

router = APIRouter()


@router.post("/webhooks/cloudinary")
async def cloudinary_upload_webhook(request: Request, db: Session = Depends(get_db)):
    # Cloudinary signs every notification with the account's api_secret (already
    # configured in main.py). Verifying it stops anyone who finds this URL from
    # POSTing fake "upload" events to inject garbage rows into the DB — there's
    # no Firebase token on this route, so the signature is the only gate.
    raw_body = (await request.body()).decode("utf-8")
    timestamp = request.headers.get("X-Cld-Timestamp")
    signature = request.headers.get("X-Cld-Signature")

    if not timestamp or not signature:
        raise HTTPException(status_code=400, detail="Missing Cloudinary signature headers")

    is_valid = cloudinary.utils.verify_notification_signature(
        raw_body, int(timestamp), signature
    )
    if not is_valid:
        raise HTTPException(status_code=401, detail="Invalid Cloudinary signature")

    payload = json.loads(raw_body)

    if payload.get("notification_type") != "upload":
        return {"status": "ignored", "reason": "not an upload event"}

    public_id = payload.get("public_id", "")
    parts = public_id.split("/")

    # Expected shape: Uploaded/<Album>/<Song>/Song|Profile/<filename>
    if len(parts) < 4 or parts[0] != BASE_FOLDER:
        return {"status": "ignored", "reason": "not under managed folder structure"}

    album_name, song_name = parts[1], parts[2]
    song_folder_path = "/".join(parts[:3])

    album = get_or_create_album(db, album_name)
    status = ingest_song(db, album, song_name, song_folder_path)
    db.commit()

    return {"status": status, "album": album_name, "song": song_name}
