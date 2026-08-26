from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.core.config import get_settings
from app.routers import addresses, auth, chat, orders, realtime_ws, tracking, vendors, vendor_portal, waitlist

settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    description="Backend API for the local food delivery platform (customer + vendor apps).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api = settings.API_V1_PREFIX
app.include_router(auth.router, prefix=api)
app.include_router(addresses.router, prefix=api)
app.include_router(vendors.router, prefix=api)
app.include_router(vendor_portal.router, prefix=api)
app.include_router(orders.router, prefix=api)
app.include_router(tracking.router, prefix=api)
app.include_router(chat.router, prefix=api)
app.include_router(waitlist.router, prefix=api)
app.include_router(realtime_ws.router)  # WebSocket routes: no versioned prefix needed


@app.get("/", include_in_schema=False)
async def root():
    # Bare "/" has no API meaning of its own — send visitors to the
    # interactive docs instead of a bare 404.
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["System"])
async def health_check():
    return {"status": "ok", "environment": settings.ENVIRONMENT}

