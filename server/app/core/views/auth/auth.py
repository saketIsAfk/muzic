from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User

router = APIRouter(prefix="/auth", tags=["auth"])

# HTTPBearer reads the "Authorization: Bearer <token>" header for us and
# rejects the request before our code runs if that header is missing or
# malformed. It also makes FastAPI show a lock icon on protected routes in
# the /docs UI.
bearer_scheme = HTTPBearer()


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)):
    """FastAPI dependency: verifies the Firebase ID token in the Authorization
    header and returns the decoded token (a dict with "uid", "email", etc.).

    This is the "never trust the client" boundary: the signature check below
    is done against Google's public keys, not anything the client sent us
    directly, so a forged or expired token is rejected here before any
    endpoint using this dependency ever runs.
    """
    try:
        return firebase_auth.verify_id_token(credentials.credentials)
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid Firebase ID token")
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Firebase ID token has expired")
    except Exception:
        raise HTTPException(status_code=401, detail="Could not verify Firebase ID token")


def get_or_create_db_user(
    token: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    """FastAPI dependency chained on top of get_current_user: resolves the
    verified Firebase identity to an actual row in our own users table —
    get-or-create, same pattern as the Cloudinary ingest script's albums.

    This is provider-agnostic on purpose: the token looks identical whether
    the client signed in with Google or email/password, so this code never
    needs to know or care which one was used.
    """
    firebase_uid = token["uid"]
    user = db.query(User).filter_by(firebase_uid=firebase_uid).first()
    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            email=token.get("email", ""),
            display_name=token.get("name"),
        )
        db.add(user)
        db.commit()
        db.refresh(user)  # loads the id Postgres just assigned
    return user


@router.get("/me")
def read_current_user(user: User = Depends(get_or_create_db_user)):
    """Protected route proving the full chain: verified token -> real users
    row. `id` is our own primary key, not Firebase's — this is what future
    tables (favorites, playlists) will foreign-key against.
    """
    return {
        "id": user.id,
        "firebase_uid": user.firebase_uid,
        "email": user.email,
        "display_name": user.display_name,
    }
