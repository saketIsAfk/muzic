# app/models.py

from sqlalchemy import (
    Column,
    Integer,
    String,
    ForeignKey,
    DateTime,
    func,
)
from sqlalchemy.orm import DeclarativeBase, relationship

# Base.metadata - is a dictionary-like object that holds all the table information ex(tablename, column names, column types).

class Base(DeclarativeBase): # Think of Base as the registry where SQLAlchemy keeps track of all your models. Creates the base class for every model.
    pass

class Song(Base):
    __tablename__ = "songs" #singular class, plural table - convention
    id = Column(Integer, primary_key=True)
    title = Column(String, nullable=False)
    duration = Column(Integer)
    audio_public_id = Column(String, nullable=False, unique=True)
    cover_url = Column(String, nullable=False)
    album_id = Column(Integer, ForeignKey("albums.id"))
    artist_id = Column(Integer, ForeignKey("artists.id"))
    artist = relationship("Artist", back_populates="songs")
    album = relationship("Album", back_populates="songs")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

class Artist(Base):
    __tablename__ = "artists"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    songs = relationship("Song", back_populates="artist")
    albums = relationship("Album", back_populates="artist")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

class Album(Base):
    __tablename__ = "albums"
    id = Column(Integer, primary_key=True)
    title = Column(String, nullable=False)
    cover_url = Column(String)
    release_year = Column(Integer)
    artist_id = Column(Integer, ForeignKey("artists.id"))
    artist = relationship("Artist", back_populates="albums")
    songs = relationship("Song", back_populates="album")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    # The Firebase UID is the link back to the identity provider — unique and
    # indexed because every verified request looks a user up by this value.
    firebase_uid = Column(String, nullable=False, unique=True)
    email = Column(String, nullable=False)
    display_name = Column(String)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

# Base.metadata.create_all(bind=engine) - Base.metadata - Take every registered model - Generate SQL - Execute against this Engine
# If create_all() is this easy, Why do people use Alembic? : simply it means create_all() will create the tables if they don't exist. It will not update the tables if they already exist. It will not create the tables if they already exist. It will not update the tables if they don't exist.