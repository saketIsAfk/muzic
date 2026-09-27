from fastapi import APIRouter, HTTPException
import cloudinary
import cloudinary.api

router = APIRouter()

BASE_FOLDER = "Uploaded"

@router.get("/health")
def health_check():
    return {"status": "success", "message": "Muzic Backend is Live"}

@router.get("/library")
def get_library():
    albums_result = cloudinary.api.subfolders(BASE_FOLDER)
    albums = albums_result["folders"]

    library = []

    for album in albums:
        album_name = album["name"]
        album_path = album["path"]
        
        songs_result = cloudinary.api.subfolders(album_path)
        songs_folders = songs_result["folders"]

        songs = []
        
        for folder in songs_folders:
            song_name = folder["name"]
            song_folder_path = folder["path"]

            audio_result = cloudinary.api.resources_by_asset_folder(
                f"{song_folder_path}/Song",
                resource_type="video",
                max_results=1
            )

            duration = None
            audio_public_id = None
            if audio_result["resources"]:
                audio = audio_result["resources"][0]
                audio_public_id = audio.get("public_id")

                full_audio = cloudinary.api.resource(
                    audio_public_id,
                    resource_type="video",
                )

                duration = full_audio.get("duration")

            profile_result = cloudinary.api.resources_by_asset_folder(
                f"{song_folder_path}/Profile",
                resource_type="image",
                max_results=1
            )

            cover_url = None
            if profile_result["resources"]:
                cover_url = profile_result["resources"][0]["secure_url"]

            songs.append({
                "song_name": song_name,
                "duration": duration,
                "audio_public_id": audio_public_id,
                "cover_url": cover_url
            })
        
        library.append({
            "album_name": album_name,
            "songs": songs
        })

    return {"library": library}


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