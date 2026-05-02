import json
from dataclasses import dataclass

import openai
import google.generativeai as genai

from config import settings


@dataclass
class GeneratedStop:
    restaurant_name: str
    meal_type: str
    notes: str


@dataclass
class GeneratedDay:
    day_number: int
    stops: list[GeneratedStop]


@dataclass
class GeneratedItinerary:
    days: list[GeneratedDay]


ITINERARY_PROMPT_TEMPLATE = """
You are a halal travel assistant. Generate a {duration_days}-day walking itinerary
in {city}, {country} using ONLY the following verified halal restaurants.

Available restaurants (JSON):
{restaurants_json}

Rules:
- Assign one breakfast, one lunch, and one dinner per day from the list above.
- Prefer restaurants that are geographically close to minimise travel time.
- Provide a brief, friendly note (1-2 sentences) for each stop.
- Return ONLY valid JSON matching this schema:
{{
  "days": [
    {{
      "day_number": 1,
      "stops": [
        {{"restaurant_name": "...", "meal_type": "breakfast|lunch|dinner", "notes": "..."}}
      ]
    }}
  ]
}}
"""


async def generate_itinerary(
    city: str,
    country: str,
    duration_days: int,
    restaurants: list[dict],
) -> GeneratedItinerary:
    restaurants_json = json.dumps(restaurants, indent=2)
    prompt = ITINERARY_PROMPT_TEMPLATE.format(
        duration_days=duration_days,
        city=city,
        country=country,
        restaurants_json=restaurants_json,
    )

    raw = await _call_ai(prompt)
    data = json.loads(raw)
    return _parse_response(data)


async def _call_ai(prompt: str) -> str:
    if settings.ai_provider == "gemini":
        return await _call_gemini(prompt)
    return await _call_openai(prompt)


async def _call_openai(prompt: str) -> str:
    client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
    response = await client.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    return response.choices[0].message.content


async def _call_gemini(prompt: str) -> str:
    genai.configure(api_key=settings.gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-pro")
    response = await model.generate_content_async(prompt)
    return response.text


def _parse_response(data: dict) -> GeneratedItinerary:
    days = [
        GeneratedDay(
            day_number=day["day_number"],
            stops=[
                GeneratedStop(
                    restaurant_name=s["restaurant_name"],
                    meal_type=s["meal_type"],
                    notes=s.get("notes", ""),
                )
                for s in day["stops"]
            ],
        )
        for day in data["days"]
    ]
    return GeneratedItinerary(days=days)
