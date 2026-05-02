import asyncio
from dataclasses import dataclass

import httpx
from bs4 import BeautifulSoup


@dataclass
class ScrapedRestaurant:
    name: str
    address: str
    phone: str | None
    website: str | None
    cuisine_type: str
    rating: float
    review_count: int


async def scrape_halal_restaurants(city: str, country: str) -> list[ScrapedRestaurant]:
    """
    Scrapes publicly available restaurant listings for a given city.
    Extend this with additional sources (Yelp, Google Places, TripAdvisor) as needed.
    """
    results: list[ScrapedRestaurant] = []

    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        tasks = [
            _scrape_zabihah(client, city, country),
        ]
        scraped_lists = await asyncio.gather(*tasks, return_exceptions=True)

    for scraped in scraped_lists:
        if isinstance(scraped, list):
            results.extend(scraped)

    return results


async def _scrape_zabihah(client: httpx.AsyncClient, city: str, country: str) -> list[ScrapedRestaurant]:
    url = f"https://www.zabihah.com/sub/{country.lower().replace(' ', '-')}/{city.lower().replace(' ', '-')}"
    try:
        response = await client.get(url, headers={"User-Agent": "HalalBites/1.0 (research)"})
        response.raise_for_status()
    except httpx.HTTPError:
        return []

    soup = BeautifulSoup(response.text, "html.parser")
    restaurants: list[ScrapedRestaurant] = []

    for card in soup.select(".restaurant-item"):
        name_el = card.select_one(".restaurant-name")
        address_el = card.select_one(".restaurant-address")
        if not name_el or not address_el:
            continue

        rating_el = card.select_one(".rating-value")
        rating = float(rating_el.text.strip()) if rating_el else 0.0

        review_el = card.select_one(".review-count")
        review_count = int(review_el.text.strip().split()[0]) if review_el else 0

        cuisine_el = card.select_one(".cuisine-type")
        cuisine = cuisine_el.text.strip() if cuisine_el else "International"

        restaurants.append(
            ScrapedRestaurant(
                name=name_el.text.strip(),
                address=address_el.text.strip(),
                phone=None,
                website=None,
                cuisine_type=cuisine,
                rating=rating,
                review_count=review_count,
            )
        )

    return restaurants
