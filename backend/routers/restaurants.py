from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.functions import ST_DWithin, ST_MakePoint, ST_Distance

from database import get_db
from models.restaurant import Restaurant

router = APIRouter(prefix="/restaurants", tags=["restaurants"])


class RestaurantOut(BaseModel):
    id: int
    name: str
    address: str
    city: str
    country: str
    latitude: float
    longitude: float
    halal_certification_level: int
    cuisine_type: str
    rating: float
    review_count: int
    phone_number: str | None
    website_url: str | None

    model_config = {"from_attributes": True}


@router.get("/nearby", response_model=list[RestaurantOut])
async def get_nearby_restaurants(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    radius_miles: float = Query(2.0, ge=0.1, le=50.0),
    min_halal_level: int = Query(1, ge=1, le=3),
    db: AsyncSession = Depends(get_db),
):
    radius_meters = radius_miles * 1609.34
    point = ST_MakePoint(lng, lat)

    stmt = (
        select(Restaurant)
        .where(
            ST_DWithin(Restaurant.location, func.ST_SetSRID(point, 4326), radius_meters),
            Restaurant.halal_certification_level >= min_halal_level,
        )
        .order_by(ST_Distance(Restaurant.location, func.ST_SetSRID(point, 4326)))
        .limit(50)
    )

    result = await db.execute(stmt)
    return result.scalars().all()
