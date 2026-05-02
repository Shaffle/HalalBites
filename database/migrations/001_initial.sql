-- Enable PostGIS for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- ─────────────────────────────────────────────
-- Restaurants
-- ─────────────────────────────────────────────
CREATE TABLE restaurants (
    id                        SERIAL PRIMARY KEY,
    name                      VARCHAR(255)  NOT NULL,
    address                   TEXT          NOT NULL,
    city                      VARCHAR(100)  NOT NULL,
    country                   VARCHAR(100)  NOT NULL,
    latitude                  DOUBLE PRECISION NOT NULL,
    longitude                 DOUBLE PRECISION NOT NULL,
    -- Geography column enables ST_DWithin distance queries in metres
    location                  GEOGRAPHY(POINT, 4326) NOT NULL,
    -- 1 = self-certified, 2 = third-party certified, 3 = zabiha certified
    halal_certification_level SMALLINT      NOT NULL CHECK (halal_certification_level BETWEEN 1 AND 3),
    cuisine_type              VARCHAR(100)  NOT NULL,
    rating                    NUMERIC(3,2)  NOT NULL DEFAULT 0.00,
    review_count              INTEGER       NOT NULL DEFAULT 0,
    phone_number              VARCHAR(50),
    website_url               TEXT,
    created_at                TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Spatial index for fast proximity searches
CREATE INDEX idx_restaurants_location ON restaurants USING GIST (location);
CREATE INDEX idx_restaurants_city_country ON restaurants (city, country);
CREATE INDEX idx_restaurants_halal_level ON restaurants (halal_certification_level);

-- ─────────────────────────────────────────────
-- Itineraries
-- ─────────────────────────────────────────────
CREATE TABLE itineraries (
    id            SERIAL PRIMARY KEY,
    user_id       VARCHAR(128)  NOT NULL,
    city          VARCHAR(100)  NOT NULL,
    country       VARCHAR(100)  NOT NULL,
    duration_days SMALLINT      NOT NULL CHECK (duration_days BETWEEN 1 AND 14),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_itineraries_user_id ON itineraries (user_id);

-- ─────────────────────────────────────────────
-- Itinerary Days
-- ─────────────────────────────────────────────
CREATE TABLE itinerary_days (
    id             SERIAL PRIMARY KEY,
    itinerary_id   INTEGER      NOT NULL REFERENCES itineraries (id) ON DELETE CASCADE,
    day_number     SMALLINT     NOT NULL CHECK (day_number >= 1),
    UNIQUE (itinerary_id, day_number)
);

-- ─────────────────────────────────────────────
-- Itinerary Stops
-- ─────────────────────────────────────────────
CREATE TABLE itinerary_stops (
    id                           SERIAL PRIMARY KEY,
    day_id                       INTEGER     NOT NULL REFERENCES itinerary_days (id) ON DELETE CASCADE,
    restaurant_id                INTEGER     NOT NULL REFERENCES restaurants (id),
    meal_type                    VARCHAR(20) NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    stop_order                   SMALLINT    NOT NULL,
    walking_time_from_previous   INTEGER,           -- minutes
    notes                        TEXT,
    UNIQUE (day_id, stop_order)
);

-- ─────────────────────────────────────────────
-- Helper function: auto-update updated_at
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_restaurants_updated_at
    BEFORE UPDATE ON restaurants
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
