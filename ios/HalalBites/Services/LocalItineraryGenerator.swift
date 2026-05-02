import CoreLocation
import Foundation

/// Generates a halal itinerary entirely on-device:
/// 1. Geocodes the city name → coordinates
/// 2. Fetches nearby restaurants from Zabihah
/// 3. Assigns meal slots across the requested number of days
enum LocalItineraryGenerator {

    static func generate(
        city: String,
        country: String,
        days: Int,
        preferences: Set<HalalLevel>,
        cuisines: Set<CuisineCategory> = [],
        budget: BudgetLevel = .moderate,
        startDate: Date = Date()
    ) async throws -> Itinerary {
        // Step 1 — geocode city
        let coordinate = try await geocode(city: city, country: country)

        // Step 2 — fetch Zabihah restaurants (falls back to mock data automatically)
        let zabihahRestaurants = (try? await ZabihahService.shared.fetchNearby(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMiles: 10
        )) ?? ZabihahService.mockRestaurants(near: coordinate.latitude, longitude: coordinate.longitude)

        // Step 3 — filter to restaurants only (exclude groceries, butchers, etc.)
        let diningOnly = zabihahRestaurants.filter { $0.isRestaurant }

        guard !diningOnly.isEmpty else {
            throw GeneratorError.noRestaurantsFound(city: city)
        }

        // Step 4 — filter by cuisine preference
        let cuisineFiltered: [ZabihahRestaurant]
        if cuisines.isEmpty {
            cuisineFiltered = diningOnly
        } else {
            let matched = diningOnly.filter { r in
                cuisines.contains { $0.matches(r.cuisineType) }
            }
            cuisineFiltered = matched.isEmpty ? diningOnly : matched
        }

        // Step 5 — filter to 3.7+ stars (Zabihah ratings), keep unrated as fallback
        let allRestaurants = cuisineFiltered.map { $0.toRestaurant() }
        let highRated = allRestaurants.filter { $0.rating >= 3.7 }
        let pool = highRated.isEmpty ? allRestaurants : highRated

        // Step 6 — build day names for the trip dates
        let dayNames = (0..<max(1, days)).map { offset -> String in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }

        // Step 7 — build meal-appropriate pools
        let mealTypes: [MealType] = [.breakfast, .lunch, .dinner]
        let breakfastPool = pool.filter { suits(meal: .breakfast, restaurant: $0) }
        let lunchPool = pool.filter { suits(meal: .lunch, restaurant: $0) }
        let dinnerPool = pool.filter { suits(meal: .dinner, restaurant: $0) }

        // Step 8 — assign meals across days, avoiding same-day repeats
        var indices: [MealType: Int] = [.breakfast: 0, .lunch: 0, .dinner: 0]
        var itineraryDays: [ItineraryDay] = []

        for dayNumber in 1...max(1, days) {
            let dayName = dayNames[(dayNumber - 1) % dayNames.count]
            var usedToday: Set<UUID> = []
            var stops: [ItineraryStop] = []

            for meal in mealTypes {
                let baseMealPool: [Restaurant]
                switch meal {
                case .breakfast: baseMealPool = breakfastPool.isEmpty ? pool : breakfastPool
                case .lunch:     baseMealPool = lunchPool.isEmpty ? pool : lunchPool
                case .dinner:    baseMealPool = dinnerPool.isEmpty ? pool : dinnerPool
                case .snack:     baseMealPool = pool
                }

                let mealPool = filterOpenOn(day: dayName, restaurants: baseMealPool, fallback: baseMealPool)

                var idx = indices[meal, default: 0]
                var restaurant = mealPool[idx % mealPool.count]
                var attempts = 0
                while usedToday.contains(restaurant.id) && attempts < mealPool.count {
                    idx += 1
                    restaurant = mealPool[idx % mealPool.count]
                    attempts += 1
                }
                indices[meal] = idx + 1

                usedToday.insert(restaurant.id)
                stops.append(ItineraryStop(
                    id: UUID(),
                    restaurant: restaurant,
                    mealType: meal,
                    notes: meal.note(for: restaurant.name)
                ))
            }

            itineraryDays.append(ItineraryDay(id: UUID(), dayNumber: dayNumber, stops: stops))
        }

        return Itinerary(
            id: UUID(),
            city: city,
            country: country,
            durationDays: days,
            createdAt: Date(),
            days: itineraryDays,
            isSaved: false
        )
    }

    // MARK: - Day-of-Week Filter

    private static func filterOpenOn(day: String, restaurants: [Restaurant], fallback: [Restaurant]) -> [Restaurant] {
        let open = restaurants.filter { r in
            guard !r.businessHours.isEmpty else { return true }
            let entry = r.businessHours.first { $0.day.caseInsensitiveCompare(day) == .orderedSame }
            if let hours = entry?.hours {
                return !hours.lowercased().contains("closed")
            }
            return true
        }
        return open.isEmpty ? fallback : open
    }

    // MARK: - Meal Suitability

    private static func suits(meal: MealType, restaurant: Restaurant) -> Bool {
        let name = restaurant.name.lowercased()
        let cuisine = restaurant.cuisineType.lowercased()

        switch meal {
        case .breakfast:
            let keywords = ["bakery", "cafe", "café", "breakfast", "brunch",
                            "pastry", "sweets", "coffee", "diner", "donut", "bagel"]
            if keywords.contains(where: { name.contains($0) || cuisine.contains($0) }) {
                return true
            }
            if let open = earliestOpenHour(restaurant.businessHours), open <= 9 {
                return true
            }
            return false

        case .lunch:
            guard !restaurant.businessHours.isEmpty else { return true }
            return restaurant.businessHours.contains { isOpenAt(hour: 12, hours: $0.hours) }

        case .dinner:
            guard !restaurant.businessHours.isEmpty else { return true }
            return restaurant.businessHours.contains { isOpenAt(hour: 18, hours: $0.hours) }

        case .snack:
            return true
        }
    }

    private static func earliestOpenHour(_ hours: [BusinessHours]) -> Int? {
        hours.compactMap { parseHour($0.hours.components(separatedBy: " - ").first ?? "") }.min()
    }

    private static func isOpenAt(hour: Int, hours: String) -> Bool {
        let parts = hours.components(separatedBy: " - ")
        guard parts.count == 2,
              let open = parseHour(parts[0]),
              let close = parseHour(parts[1]) else { return true }
        return open <= hour && close >= hour
    }

    private static func parseHour(_ timeString: String) -> Int? {
        let trimmed = timeString.trimmingCharacters(in: .whitespaces).uppercased()
        let isPM = trimmed.hasSuffix("PM")
        let cleaned = trimmed
            .replacingOccurrences(of: "AM", with: "")
            .replacingOccurrences(of: "PM", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let hour = Int(cleaned.components(separatedBy: ":").first ?? "") else { return nil }
        if isPM && hour != 12 { return hour + 12 }
        if !isPM && hour == 12 { return 0 }
        return hour
    }

    // MARK: - Geocoding

    private static func geocode(city: String, country: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString("\(city), \(country)")
        guard let location = placemarks.first?.location else {
            throw GeneratorError.cityNotFound(city: city)
        }
        return location.coordinate
    }
}

// MARK: - Errors

enum GeneratorError: LocalizedError {
    case cityNotFound(city: String)
    case noRestaurantsFound(city: String)

    var errorDescription: String? {
        switch self {
        case .cityNotFound(let city):
            return "Couldn't find \"\(city)\". Check the city name and try again."
        case .noRestaurantsFound(let city):
            return "No halal restaurants found near \(city). Try updating the halal filter."
        }
    }
}

// MARK: - ZabihahRestaurant → Restaurant conversion

extension ZabihahRestaurant {
    func toRestaurant() -> Restaurant {
        Restaurant(
            id: UUID(),
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            halalCertificationLevel: .halal,
            cuisineType: cuisineType,
            rating: rating ?? 0.0,
            reviewCount: reviewCount,
            phoneNumber: nil,
            websiteURL: "https://www.zabihah.com",
            photoURLs: photoURLs,
            businessHours: businessHours
        )
    }
}

// MARK: - Friendly meal notes

private extension MealType {
    func note(for name: String) -> String {
        switch self {
        case .breakfast: return "Start your morning at \(name)."
        case .lunch:     return "Grab lunch at \(name) — a local favourite."
        case .dinner:    return "End the day with dinner at \(name)."
        case .snack:     return "Quick stop at \(name)."
        }
    }
}
