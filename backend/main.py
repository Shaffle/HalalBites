from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import itineraries, restaurants

app = FastAPI(
    title="HalalBites API",
    description="Backend for the HalalBites location-aware halal travel itinerary app.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(restaurants.router, prefix="/v1")
app.include_router(itineraries.router, prefix="/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
