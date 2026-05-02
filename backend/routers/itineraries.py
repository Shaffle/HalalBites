from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.functions import ST_DWithin, ST_MakePoint, ST_Centroid, ST_Collect

from database import get_db
from models.restaurant import Restaurant
from models.itinerary import Itinerary, ItineraryDay, ItineraryStop
from services import ai_service

router = APIRouter(prefix="/itineraries", tags=["itineraries"])


class GenerateRequest(BaseModel):
    city: str
    country: str
    duration_days: int
    min_halal_level: int = 1
    user_id: str = "anonymous"


class StopOut(BaseModel):
    id: int
    restaurant_id: int
    meal_type: str
    stop_order: int
    walking_time_from_previous: int | None
    notes: str | None

    model_config = {"from_attributes": True}


class DayOut(BaseModel):
    id: int
    day_number: int
    stops: list[StopOut]

    model_config = {"from_attributes": True}


class ItineraryOut(BaseModel):
    id: int
    city: str
    country: str
    duration_days: int
    days: list[DayOut]

    model_config = {"from_attributes": True}


@router.post("/generate", response_model=ItineraryOut)
async def generate_itinerary(req: GenerateRequest, db: AsyncSession = Depends(get_db)):
    # Pull all restaurants for the city
    stmt = select(Restaurant).where(
        Restaurant.city.ilike(req.city),
        Restaurant.country.ilike(req.country),
        Restaurant.halal_certification_level >= req.min_halal_level,
    )
    result = await db.execute(stmt)
    restaurants = result.scalars().all()

    if not restaurants:
        raise HTTPException(
            status_code=404,
            detail=f"No halal restaurants found in {req.city}, {req.country} at the requested certification level.",
        )

    restaurant_dicts = [
        {"name": r.name, "cuisine": r.cuisine_type, "address": r.address, "rating": r.rating}
        for r in restaurants
    ]

    generated = await ai_service.generate_itinerary(
        city=req.city,
        country=req.country,
        duration_days=req.duration_days,
        restaurants=restaurant_dicts,
    )

    restaurant_by_name = {r.name.lower(): r for r in restaurants}

    itinerary = Itinerary(
        user_id=req.user_id,
        city=req.city,
        country=req.country,
        duration_days=req.duration_days,
    )
    db.add(itinerary)
    await db.flush()

    for gen_day in generated.days:
        day = ItineraryDay(itinerary_id=itinerary.id, day_number=gen_day.day_number)
        db.add(day)
        await db.flush()

        for order, gen_stop in enumerate(gen_day.stops):
            matched = restaurant_by_name.get(gen_stop.restaurant_name.lower())
            if not matched:
                continue
            stop = ItineraryStop(
                day_id=day.id,
                restaurant_id=matched.id,
                meal_type=gen_stop.meal_type,
                stop_order=order,
                notes=gen_stop.notes,
            )
            db.add(stop)

    await db.commit()
    await db.refresh(itinerary)
    return itinerary
