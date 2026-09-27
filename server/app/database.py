import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

if DATABASE_URL is None:
    raise RuntimeError("DATABASE_URL environment variable is not set.")

# engine doesn't mean the connection itself, it means it knows how to connect
engine = create_engine(
    DATABASE_URL,
    )

# session - works with help of transaction which is Groups changes into one atomic unit, if one fails, everything gets rolled back.

#  MODEL - A model is simply a Python class that describes a database table. Song - Python Class - Database Table

# COLUMN - Each property of class becomes a Column in a table.

# PRIMARY KEY - Every row needs a unique identity. It's like a National ID number for the row.

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False, # Don't send partial changes to the database unless I ask.
    autocommit=False, # Don't auto-save after every little change.
)