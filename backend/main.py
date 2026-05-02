import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from api.routes import router as api_router
from api.websocket import router as ws_router
from api.auth import router as auth_router
from api.users import router as users_router
from api.sessions_lifecycle import router as sessions_router
from api.dashboard import router as dashboard_router
from api.statistics import router as statistics_router
from config import settings

if not logging.getLogger().handlers:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )

logger = logging.getLogger("sentio.api")
_pwd_ctx = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def _seed_default_user() -> None:
    from database import SessionLocal
    from models.db_models import User

    email = settings.default_test_user_email
    password = settings.default_test_user_password
    if not email or not password:
        return

    db = SessionLocal()
    try:
        if db.query(User).filter(User.email == email).first():
            return

        user = User(
            email=email,
            name="Test User",
            provider="email",
            hashed_password=_pwd_ctx.hash(password),
            last_login=datetime.utcnow(),
        )
        db.add(user)
        db.commit()
        logger.info("Seeded default test user: %s", email)
    finally:
        db.close()


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Create DB tables on startup (idempotent)."""
    from database import create_tables, migrate_database
    create_tables()
    migrate_database()
    logger.info("Database tables ready")
    if settings.debug and settings.seed_default_user:
        _seed_default_user()
    yield


app = FastAPI(title=settings.app_name, debug=settings.debug, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allowed_origins,
    allow_origin_regex=settings.cors_allowed_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_api_requests(request: Request, call_next):
    if not request.url.path.startswith("/api"):
        return await call_next(request)

    start_time = time.perf_counter()
    client_host = request.client.host if request.client else "unknown"
    query_string = f"?{request.url.query}" if request.url.query else ""

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.exception(
            "%s %s%s -> unhandled error %.2fms [%s]",
            request.method,
            request.url.path,
            query_string,
            duration_ms,
            client_host,
        )
        raise

    duration_ms = (time.perf_counter() - start_time) * 1000
    logger.info(
        "%s %s%s -> %s %.2fms [%s]",
        request.method,
        request.url.path,
        query_string,
        response.status_code,
        duration_ms,
        client_host,
    )
    return response

# -----------------------------
# Include routers
# -----------------------------
app.include_router(api_router,        prefix="/api")
app.include_router(auth_router,       prefix="/api/auth",  tags=["auth"])
app.include_router(users_router,      prefix="/api/users", tags=["users"])
app.include_router(sessions_router,   prefix="/api",       tags=["sessions"])
app.include_router(dashboard_router,  prefix="/api",       tags=["dashboard"])
app.include_router(statistics_router, prefix="/api",       tags=["statistics"])
app.include_router(ws_router)

# -----------------------------
# Root endpoint
# -----------------------------
@app.get("/")
def root():
    return {"message": "Sentio EEG Backend is running."}


# Run with either:
#   python main.py
#   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )