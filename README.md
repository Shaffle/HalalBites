# HalalBites

Building the first app that helps Muslims confidently eat halal/zabiha options wherever they are in the world.

---

## Tech Stack

### iOS App — `ios/`
| Concern | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Mapping | MapKit (native, zero overhead) |
| Location | CoreLocation |
| Networking | `URLSession` async/await |

**Key screens**
- `ItineraryListView` — browse and generate trips
- `ItineraryDetailView` — day-by-day stop breakdown with halal certification badges
- `ExploreMapView` — live map of nearby halal restaurants
- `ItineraryGeneratorView` — city, duration, and halal-level picker sheet

---

### Python Backend — `backend/`
| Concern | Technology |
|---|---|
| Language | Python 3.12 |
| Framework | FastAPI (async) |
| ORM | SQLAlchemy 2.0 (async) |
| DB Driver | asyncpg |
| AI — primary | OpenAI GPT-4o |
| AI — alternative | Google Gemini 1.5 Pro |
| Scraping | BeautifulSoup 4 + httpx |
| Hosting | AWS Lambda (on-demand generation) / EC2 (scraping jobs) |

**API endpoints**
```
GET  /v1/restaurants/nearby   lat, lng, radius_miles, min_halal_level
POST /v1/itineraries/generate  city, country, duration_days, min_halal_level
GET  /health
```

**Run locally**
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env   # fill in DB URL + AI key
uvicorn main:app --reload
```

---

### Database — `database/`
| Concern | Technology |
|---|---|
| Engine | PostgreSQL 16 |
| Geospatial | PostGIS extension |
| Hosting | Amazon RDS |

**Schema highlights**
- `restaurants.location` — `GEOGRAPHY(POINT, 4326)` column with a GIST index enabling sub-millisecond `ST_DWithin` radius searches
- `halal_certification_level` — 3-tier scale: 1 = self-certified, 2 = third-party certified, 3 = zabiha certified
- Cascade deletes keep `itinerary_days` and `itinerary_stops` clean when a parent itinerary is removed

**Apply schema**
```bash
psql -U halalbites -d halalbites -f database/migrations/001_initial.sql
```

---

## How It Works

```
User opens app
  └─> taps "Generate Itinerary" for Athens, 3 days
        └─> iOS POSTs to FastAPI /v1/itineraries/generate
              └─> FastAPI queries PostgreSQL for halal restaurants in Athens
                    └─> sends verified restaurant list + prompt to GPT-4o / Gemini
                          └─> AI returns a structured JSON itinerary
                                └─> saved to DB, returned to iOS app
                                      └─> rendered in SwiftUI with MapKit routes
```

---

## Repo Layout

```
HalalBites/
├── ios/
│   └── HalalBites/
│       ├── App/          # Entry point, ContentView
│       ├── Models/       # Restaurant, Itinerary (Codable structs)
│       ├── Services/     # APIClient, LocationService
│       └── Views/        # SwiftUI screens
├── backend/
│   ├── main.py           # FastAPI app
│   ├── config.py         # Settings (pydantic-settings)
│   ├── database.py       # Async SQLAlchemy engine + session
│   ├── models/           # SQLAlchemy ORM models
│   ├── routers/          # FastAPI route handlers
│   ├── services/         # ai_service.py, scraper.py
│   └── requirements.txt
└── database/
    └── migrations/
        └── 001_initial.sql
```
