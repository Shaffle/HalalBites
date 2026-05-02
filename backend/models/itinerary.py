from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class Itinerary(Base):
    __tablename__ = "itineraries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    country: Mapped[str] = mapped_column(String(100), nullable=False)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    days: Mapped[list["ItineraryDay"]] = relationship(
        "ItineraryDay", back_populates="itinerary", cascade="all, delete-orphan", order_by="ItineraryDay.day_number"
    )


class ItineraryDay(Base):
    __tablename__ = "itinerary_days"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    itinerary_id: Mapped[int] = mapped_column(ForeignKey("itineraries.id"), nullable=False)
    day_number: Mapped[int] = mapped_column(Integer, nullable=False)
    itinerary: Mapped["Itinerary"] = relationship("Itinerary", back_populates="days")
    stops: Mapped[list["ItineraryStop"]] = relationship(
        "ItineraryStop", back_populates="day", cascade="all, delete-orphan", order_by="ItineraryStop.stop_order"
    )


class ItineraryStop(Base):
    __tablename__ = "itinerary_stops"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    day_id: Mapped[int] = mapped_column(ForeignKey("itinerary_days.id"), nullable=False)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), nullable=False)
    meal_type: Mapped[str] = mapped_column(String(20), nullable=False)
    stop_order: Mapped[int] = mapped_column(Integer, nullable=False)
    walking_time_from_previous: Mapped[int | None] = mapped_column(Integer)
    notes: Mapped[str | None] = mapped_column(Text)
    day: Mapped["ItineraryDay"] = relationship("ItineraryDay", back_populates="stops")
