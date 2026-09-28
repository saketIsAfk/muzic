from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
import cloudinary
import cloudinary.api

from app.database import get_db
from app.models import Album

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "success", "message": "Muzic Backend is Live"}

@router.get("/library")
def get_library(db: Session = Depends(get_db)):
    albums = (
        db.query(Album)
        .options(joinedload(Album.songs))  # one JOIN query, not one query per album
        .all()
    )

    return {
        "library": [
            {
                "album_name": album.title,
                "songs": [
                    {
                        "song_name": song.title,
                        "duration": song.duration,
                        "audio_public_id": song.audio_public_id,
                        "cover_url": song.cover_url,
                    }
                    for song in album.songs
                ],
            }
            for album in albums
        ]
    }


@router.get("/stream/{public_id:path}")
def stream_song(public_id: str):
    """Returns the playable MP3 URL for the given audio resource."""
    try:
        resource = cloudinary.api.resource(
            public_id,
            resource_type="video",
        )

        return {
            "stream_url": resource.get("secure_url", ""),
        }
    except cloudinary.exceptions.NotFound:
        raise HTTPException(status_code=404, detail=f"Resource '{public_id}' not found")