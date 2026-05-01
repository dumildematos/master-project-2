"""
database.py
-----------
SQLAlchemy engine + session factory for Sentio.

Default store: SQLite (sentio.db next to main.py).
Swap DATABASE_URL in .env to postgresql+psycopg2://... for production.
"""
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from config import settings

# SQLite needs check_same_thread=False for FastAPI's thread-pool workers.
# Ignored silently by other drivers.
_connect_args = (
    {"check_same_thread": False}
    if settings.database_url.startswith("sqlite")
    else {}
)

engine = create_engine(settings.database_url, connect_args=_connect_args)

# Enable WAL mode for SQLite — better concurrent read/write performance
if settings.database_url.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _set_wal(dbapi_conn, _):
        dbapi_conn.execute("PRAGMA journal_mode=WAL")
        dbapi_conn.execute("PRAGMA foreign_keys=ON")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency — yields a DB session and closes it on exit."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables() -> None:
    """Create all tables that don't yet exist (safe to call multiple times)."""
    from models import db_models  # noqa: F401 — side-effect: registers models
    Base.metadata.create_all(bind=engine)
