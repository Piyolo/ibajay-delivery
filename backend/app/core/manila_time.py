"""Philippine-time helpers for daily analytics.

Everything in the database is UTC (Neon/Render default), but "today" for a
store owner in Ibajay Eats is Manila time. Both /vendor/me/analytics and
/admin/overview bucket sales by day, so an unadjusted UTC split put every
order placed 16:00–24:00 PHT on the wrong date and drew two very different
"daily revenue" charts depending on the time of day the Analytics screen
was opened.
"""
from calendar import timegm
from datetime import date, datetime, timedelta, timezone

MANILA_UTC_OFFSET = timedelta(hours=8)
PH_TZ = timezone(MANILA_UTC_OFFSET)


def manila_date(dt: datetime) -> date:
    """The Manila calendar date of an instant (naive values treated as UTC).

    asyncpg hands tz-aware datetimes for `DateTime(timezone=True)` columns,
    so `dt.tzinfo` is already set in production; the naive branch keeps the
    helper honest for unit tests and hypothetical naive rows."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(PH_TZ).date()


def manila_day_start_utc(day: date) -> datetime:
    """The UTC instant when `day` begins in Manila (00:00 PHT)."""
    return datetime(day.year, day.month, day.day, tzinfo=PH_TZ).astimezone(timezone.utc)


def manila_days_back(n_days: int) -> tuple[date, datetime, datetime]:
    """Half-open UTC window covering the last `n_days` Manila days (today
    included): returns (first_manila_day, window_start_utc, now).

    window_start = 00:00 PHT of (today - n_days + 1); the exclusive upper
    bound is the current instant, which callers encode as `created_at >=
    window_start` (future orders don't exist)."""
    today = manila_date(datetime.now(timezone.utc))
    first = today - timedelta(days=n_days - 1)
    return first, manila_day_start_utc(first), datetime.now(timezone.utc)
