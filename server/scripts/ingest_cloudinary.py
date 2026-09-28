import os
import cloudinary
import cloudinary.api
from dotenv import load_dotenv

from app.database import SessionLocal
from app.models import Album, Song

load_dotenv()

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

BASE_FOLDER = "Uploaded"


def get_or_create_album(session, name):
    album = session.query(Album).filter_by(title=name).first()
    if album is None:
        album = Album(title=name)
        session.add(album)
        session.flush()  # sends INSERT now so album.id is assigned, without committing the transaction
    return album


def main():
    session = SessionLocal()
    try:
        albums_result = cloudinary.api.subfolders(BASE_FOLDER)

        for album_folder in albums_result["folders"]:
            album_name = album_folder["name"]
            album_path = album_folder["path"]

            print(f"\nALBUM: {album_name}")
            album = get_or_create_album(session, album_name)

            songs_result = cloudinary.api.subfolders(album_path)

            for song_folder in songs_result["folders"]:
                song_name = song_folder["name"]
                song_folder_path = song_folder["path"]

                audio_result = cloudinary.api.resources_by_asset_folder(
                    f"{song_folder_path}/Song",
                    resource_type="video",
                    max_results=1,
                )
                if not audio_result["resources"]:
                    print(f"  SKIP {song_name}: no audio file")
                    continue

                audio_public_id = audio_result["resources"][0]["public_id"]

                existing = session.query(Song).filter_by(
                    audio_public_id=audio_public_id
                ).first()
                if existing:
                    print(f"  SKIP {song_name}: already in DB")
                    continue

                full_audio = cloudinary.api.resource(
                    audio_public_id, resource_type="video"
                )
                duration = full_audio.get("duration")

                profile_result = cloudinary.api.resources_by_asset_folder(
                    f"{song_folder_path}/Profile",
                    resource_type="image",
                    max_results=1,
                )
                if not profile_result["resources"]:
                    print(f"  SKIP {song_name}: no cover image")
                    continue
                cover_url = profile_result["resources"][0]["secure_url"]

                song = Song(
                    title=song_name,
                    duration=duration,
                    audio_public_id=audio_public_id,
                    cover_url=cover_url,
                    album_id=album.id,
                )
                session.add(song)
                print(f"  ADDED {song_name}")

        session.commit()
        print("\nDone.")
    finally:
        session.close()


if __name__ == "__main__":
    main()
