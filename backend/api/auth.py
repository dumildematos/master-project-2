"""
api/auth.py
-----------
Authentication endpoints:

  POST /api/auth/register        — email + password sign-up
  POST /api/auth/login           — email + password sign-in
  POST /api/auth/google          — Google ID-token exchange
  POST /api/auth/refresh         — extend a still-valid JWT
  POST /api/auth/logout          — client-side token invalidation hint
  GET  /api/auth/me              — return the calling user's profile

JWT is issued as a Bearer token (HS256).
Google tokens are verified against the three registered client IDs.
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from config import settings
from database import get_db
from models.db_models import User

logger = logging.getLogger("sentio.auth")
router = APIRouter()

_security  = HTTPBearer(auto_error=False)
_pwd_ctx   = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# All Google client IDs that are allowed as token audiences
_GOOGLE_AUDIENCES = {
    settings.google_web_client_id,
    settings.google_android_client_id,
    settings.google_ios_client_id,
} - {""}   # remove empty strings (unset IDs)


# =============================================================================
# Pydantic request / response schemas
# =============================================================================

class RegisterIn(BaseModel):
    email:    EmailStr
    password: str
    name:     Optional[str] = None


class LoginIn(BaseModel):
    email:    EmailStr
    password: str


class GoogleIn(BaseModel):
    id_token: str


class UserOut(BaseModel):
    id:         str
    email:      str
    name:       Optional[str]
    avatar_url: Optional[str]
    provider:   str
    created_at: datetime

    model_config = {"from_attributes": True}


class AuthOut(BaseModel):
    access_token: str
    token_type:   str = "bearer"
    user:         UserOut


# =============================================================================
# JWT helpers
# =============================================================================

def _now_utc() -> datetime:
    return datetime.now(tz=timezone.utc)


def create_access_token(user_id: str) -> str:
    expire = _now_utc() + timedelta(minutes=settings.jwt_expire_minutes)
    return jwt.encode(
        {"sub": user_id, "exp": expire},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def _decode_token(token: str) -> Optional[str]:
    """Return user_id string or None on any failure."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
        return payload.get("sub")
    except JWTError:
        return None


# =============================================================================
# Reusable dependency — injects the authenticated User into route handlers
# =============================================================================

async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_security),
    db: Session = Depends(get_db),
) -> User:
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = _decode_token(credentials.credentials)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = (
        db.query(User)
        .filter(User.id == user_id, User.is_active == True)  # noqa: E712
        .first()
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deactivated",
        )
    return user


# =============================================================================
# Endpoints
# =============================================================================

@router.post("/register", response_model=AuthOut, status_code=201)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    """Create a new email/password account."""
    if len(payload.password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")

    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(400, "Email already registered")

    user = User(
        email           = payload.email,
        name            = payload.name or payload.email.split("@")[0],
        provider        = "email",
        hashed_password = _pwd_ctx.hash(payload.password),
        last_login      = _now_utc(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    logger.info("New user registered  id=%s email=%s", user.id, user.email)
    return AuthOut(
        access_token=create_access_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/login", response_model=AuthOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    """Authenticate with email + password."""
    user = db.query(User).filter(User.email == payload.email).first()

    if (
        not user
        or not user.hashed_password
        or not _pwd_ctx.verify(payload.password, user.hashed_password)
    ):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account deactivated")

    user.last_login = _now_utc()
    db.commit()

    logger.info("User logged in  id=%s email=%s", user.id, user.email)
    return AuthOut(
        access_token=create_access_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/google", response_model=AuthOut)
def google_auth(payload: GoogleIn, db: Session = Depends(get_db)):
    """
    Verify a Google ID token (from google_sign_in on mobile) and return a JWT.

    The mobile app passes the `idToken` from GoogleSignInAuthentication.
    The backend verifies the token signature with Google's public keys and
    checks that the audience is one of the registered client IDs.
    """
    # ── Verify with Google ────────────────────────────────────────────────────
    try:
        from google.oauth2 import id_token as google_id_token
        from google.auth.transport import requests as google_requests

        # verify_oauth2_token raises ValueError on any problem
        info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            audience=None,   # we check audience manually below
        )
    except Exception as exc:
        logger.warning("Google token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {exc}")

    # ── Audience check ────────────────────────────────────────────────────────
    audience = info.get("aud")
    if _GOOGLE_AUDIENCES and audience not in _GOOGLE_AUDIENCES:
        raise HTTPException(
            status_code=401,
            detail=f"Token audience '{audience}' is not an authorised client ID",
        )

    google_sub  = info["sub"]
    email       = info.get("email", "")
    name        = info.get("name")
    avatar_url  = info.get("picture")

    if not email:
        raise HTTPException(400, "Google account has no email address")

    # ── Find or create user ───────────────────────────────────────────────────
    # 1. Exact match by provider + provider_id
    user = (
        db.query(User)
        .filter(User.provider == "google", User.provider_id == google_sub)
        .first()
    )

    if user is None:
        # 2. Existing account with same email (different provider) → link it
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.provider    = "google"
            user.provider_id = google_sub
            if avatar_url:
                user.avatar_url = avatar_url
        else:
            # 3. Brand-new user
            user = User(
                email       = email,
                name        = name,
                avatar_url  = avatar_url,
                provider    = "google",
                provider_id = google_sub,
            )
            db.add(user)

    # Always refresh mutable fields on every sign-in
    if name:       user.name       = name
    if avatar_url: user.avatar_url = avatar_url
    user.last_login = _now_utc()

    db.commit()
    db.refresh(user)

    logger.info(
        "Google sign-in  id=%s email=%s sub=%s",
        user.id, user.email, google_sub,
    )
    return AuthOut(
        access_token=create_access_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=AuthOut)
def refresh_token(
    current_user: User = Depends(get_current_user),
):
    """Issue a fresh token for a still-valid session."""
    return AuthOut(
        access_token=create_access_token(current_user.id),
        user=UserOut.model_validate(current_user),
    )


@router.post("/logout", status_code=204)
def logout():
    """
    Client-side logout — the client should discard the token.
    (Stateless JWTs cannot be invalidated server-side without a denylist;
    add Redis-backed token revocation here when needed.)
    """
    return None


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    """Return the profile of the authenticated caller."""
    return UserOut.model_validate(current_user)
