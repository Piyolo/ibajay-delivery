"""Process-local sliding-window rate limiting for credential endpoints.

Why this exists (and why it is in-memory): the API runs as a single Render
free-tier instance, so a plain dict is enough and no third-party package is
added. Consequences / limitations:

* **Process-local** — limits are per-instance and are cleared whenever the
  service restarts or redeploys (it fails open, never closed). If the
  service is ever scaled to multiple instances, each instance enforces its
  own window; move this store to Redis (see services/realtime.py note)
  before scaling out.
* **Client IP** is taken from the right-most `X-Forwarded-For` entry, which
  Render's proxy appends (right-most = the address Render saw), falling
  back to the socket address for direct/local calls (e.g. tests). A client
  that reaches the app without the proxy can spoof that header.
* All bookkeeping happens synchronously inside one event loop with no
  `await` between prune and record, so no locking is needed.

Counting policy:

* ``POST /auth/login`` counts **failed** attempts only: the window is
  checked before credentials are verified, a hit is recorded only when the
  credentials are wrong, and a successful login clears the key. A burst of
  successful logins therefore never locks anyone out.
* ``POST /auth/register/start`` and ``POST /auth/forgot-password/start``
  count **every request**, because those endpoints always answer 200 (even
  for unknown emails) and the cost being capped is the OTP email itself.

The store is module-level (``limiter``); tests call ``limiter.reset()`` to
start from a clean slate.
"""
import time
from collections import deque

from fastapi import HTTPException, Request, status

DEFAULT_WINDOW_SECONDS = 60
DEFAULT_TOO_MANY_DETAIL = "Too many requests. Please wait a minute and try again."


class SlidingWindowLimiter:
    """Fixed-size sliding window keyed by an arbitrary string."""

    def __init__(self) -> None:
        self._windows: dict[str, deque[float]] = {}

    @staticmethod
    def _prune(hits: deque[float], now: float, window_seconds: float) -> None:
        while hits and now - hits[0] >= window_seconds:
            hits.popleft()

    def check(self, key: str, *, limit: int, window_seconds: float = DEFAULT_WINDOW_SECONDS, detail: str = DEFAULT_TOO_MANY_DETAIL) -> None:
        """Raise 429 when the key already has `limit` hits inside the window."""
        hits = self._windows.setdefault(key, deque())
        now = time.monotonic()
        self._prune(hits, now, window_seconds)
        if len(hits) >= limit:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail)

    def record(self, key: str, *, window_seconds: float = DEFAULT_WINDOW_SECONDS) -> None:
        """Register one hit for `key` (used after `check` succeeded)."""
        hits = self._windows.setdefault(key, deque())
        now = time.monotonic()
        self._prune(hits, now, window_seconds)
        hits.append(now)

    def clear(self, key: str) -> None:
        """Forget a key entirely (e.g. after a successful login)."""
        self._windows.pop(key, None)

    def reset(self) -> None:
        """Drop every recorded hit — for tests."""
        self._windows.clear()


limiter = SlidingWindowLimiter()


def client_ip(request: Request) -> str:
    """Best-effort caller IP (see module docstring for the proxy caveat)."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[-1].strip()
    return request.client.host if request.client else "unknown"


def per_ip_rate_limit(scope: str, limit: int, window_seconds: float = DEFAULT_WINDOW_SECONDS, detail: str = DEFAULT_TOO_MANY_DETAIL):
    """FastAPI dependency factory: check + record one hit per request.

    Use via ``dependencies=[Depends(per_ip_rate_limit("register-start", 3))]``.
    """

    async def dependency(request: Request) -> None:
        key = f"{scope}:{client_ip(request)}"
        limiter.check(key, limit=limit, window_seconds=window_seconds, detail=detail)
        limiter.record(key, window_seconds=window_seconds)

    return dependency
