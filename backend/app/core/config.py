"""
Central application settings, loaded from environment variables.

In production (Render), set these as environment variables in the
service dashboard. Locally, copy .env.example to .env and fill it in.
"""
from functools import lru_cache
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Query params some Postgres hosts (Neon included) add for libpq/psycopg2
# clients that asyncpg's connect() does not accept as keyword arguments.
# Passing these through raises `TypeError: connect() got an unexpected
# keyword argument '...'` at connection time.
_ASYNCPG_UNSUPPORTED_PARAMS = {"channel_binding", "options", "target_session_attrs", "gssencmode"}


def _normalize_database_url(raw_url: str) -> str:
    """
    Makes the async engine tolerant of however the connection string was
    pasted in. Neon (and most Postgres hosts) hand out a URL shaped for a
    *sync* libpq-based client, e.g.
    `postgresql://user:pass@host/db?sslmode=require&channel_binding=require`.
    This project uses the async `asyncpg` driver, which:
      - needs the scheme `postgresql+asyncpg://`, not `postgresql://`
      - calls the TLS param `ssl`, not `sslmode`
      - has no `channel_binding` (or a few other libpq-only) parameters
    Auto-correct all of the above instead of failing with a cryptic
    `ModuleNotFoundError: No module named 'psycopg2'` or
    `TypeError: connect() got an unexpected keyword argument 'channel_binding'`.
    """
    parts = urlsplit(raw_url.strip())

    scheme = parts.scheme
    if scheme in ("postgres", "postgresql", "postgresql+psycopg2", "postgresql+psycopg"):
        scheme = "postgresql+asyncpg"

    ssl_seen = False
    normalized_pairs: list[tuple[str, str]] = []
    for key, value in parse_qsl(parts.query, keep_blank_values=True):
        key_lower = key.lower()
        if key_lower == "sslmode":
            normalized_pairs.append(("ssl", "require"))
            ssl_seen = True
        elif key_lower == "ssl":
            normalized_pairs.append((key, value))
            ssl_seen = True
        elif key_lower in _ASYNCPG_UNSUPPORTED_PARAMS:
            continue  # drop: asyncpg's connect() doesn't accept these
        else:
            normalized_pairs.append((key, value))

    if not ssl_seen and "neon.tech" in parts.netloc:
        normalized_pairs.append(("ssl", "require"))

    new_query = urlencode(normalized_pairs)
    return urlunsplit((scheme, parts.netloc, parts.path, new_query, parts.fragment))


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- App ---
    APP_NAME: str = "Local Food Delivery API"
    ENVIRONMENT: str = "development"  # development | staging | production
    API_V1_PREFIX: str = "/api/v1"

    # --- Security ---
    JWT_SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # --- Database (Neon/Supabase/Render Postgres) ---
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/fooddelivery"

    @field_validator("DATABASE_URL")
    @classmethod
    def _fix_database_url(cls, v: str) -> str:
        return _normalize_database_url(v)



    # --- Email (Resend) ---
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "no-reply@yourdomain.com"
    OTP_EXPIRE_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 5
    OTP_RESEND_COOLDOWN_SECONDS: int = 60

    # --- Image storage (Cloudinary) ---
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # --- Push notifications (Firebase) ---
    FCM_SERVICE_ACCOUNT_JSON: str = ""  # path or raw JSON, loaded by services/push.py

    # --- Maps ---
    GOOGLE_MAPS_API_KEY: str = ""

    # --- CORS ---
    CORS_ORIGINS: list[str] = ["*"]  # tighten in production


@lru_cache
def get_settings() -> Settings:
    return Settings()
