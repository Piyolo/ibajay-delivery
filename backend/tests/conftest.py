"""Test bootstrap: make `app.*` importable and give tests a clean rate-limit store."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402

from app.core.rate_limit import limiter  # noqa: E402


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    """The limiter store is module-level; start (and end) each test empty."""
    limiter.reset()
    yield
    limiter.reset()
