"""
Quick-start table creation (no Alembic migration history).

Usage:
    python create_tables.py

Prefer Alembic (`alembic revision --autogenerate -m "init"` then
`alembic upgrade head`) once you need real migration history — this
script is just the fastest path to a working schema for local dev.
"""
import asyncio
import sys

# On Windows, asyncio's default ProactorEventLoop can throw a harmless but
# alarming-looking "Fatal error on SSL transport" / "Event loop is closed"
# traceback when an SSL connection (like asyncpg's TLS session to Neon)
# finishes tearing down after the loop has already closed. Switching to the
# selector event loop policy avoids it. This has no effect on other
# platforms.
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from app.core.db import Base, engine
import app.models  # noqa: F401  -- registers all model metadata


async def main():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    print("Tables created successfully.")


if __name__ == "__main__":
    asyncio.run(main())
