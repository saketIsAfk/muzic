import os
import cloudinary
import cloudinary.api
from dotenv import load_dotenv

from app.database import SessionLocal

load_dotenv()

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

BASE_FOLDER = "Uploaded"


def main():
    albums_result = cloudinary.api.subfolders(BASE_FOLDER)

    for album in albums_result["folders"]:
        album_name = album["name"]
        album_path = album["path"]

        print(f"\nALBUM: {album_name}")
        print(f"PATH:  {album_path}")

        songs_result = cloudinary.api.subfolders(album_path)

        for folder in songs_result["folders"]:
            song_name = folder["name"]
            song_folder_path = folder["path"]

            print(f"  SONG: {song_name}")
            print(f"  PATH: {song_folder_path}")


if __name__ == "__main__":
    main()