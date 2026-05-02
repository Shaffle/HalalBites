import CoreLocation

/// Generates a halal itinerary entirely on-device:
/// 1. Geocodes the city name → coordinates
/// 2. Fetches nearby restaurants from Zabihah
/// 3. Assigns meal slots across the requested number of days
enum LocalItineraryGenerator {

    static func generate(city: String, country: String, days: Int, minLevel: HalalLevel) async throws -> Itinerary {
        // Step 1 — geocode city
        let coordinate = try await geocode(city: city, country: country)

        // Step 2 — fetch Zabihah restaurants (falls back to mock data automatically)
        let zabihahRestaurants = (try? await ZabihahService.shared.fetchNearby(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMiles: 10
        )) ?? ZabihahService.mockRestaurants(near: coordinate.latitude, longitude: coordinate.longitude)

        guard !zabihahRestaurants.isEmpty else {
            throw GeneratorError.noRestaurantsFound(city: city)
        }

        // Step 3 — convert to Restaurant model and filter by halal level
        let restaurants = zabihahRestaurants
            .filter { minLevel == .level1 || ($0.zabiha && minLevel == .level3) || minLevel == .level2 }
            .map { $0.toRestaurant() }

        let pool = restaurants.isEmpty ? zabihahRestaurants.map { $0.toRestaurant() } : restaurants

        // Step 4 — assign breakfast / lunch / dinner across days
        let mealTypes: [MealType] = [.breakfast, .lunch, .dinner]
        var poolIndex = 0

        let itineraryDays: [ItineraryDay] = (1...max(1, days)).map { dayNumber in
            let stops: [ItineraryStop] = mealTypes.map { meal in
                let restaurant = pool[poolIndex % pool.count]
                poolIndex += 1
                return ItineraryStop(
                    id: UUID(),
                    restaurant: restaurant,
                    mealType: meal,
                    walkingTimeFromPrevious: meal == .breakfast ? nil : Int.random(in: 5...20),
                    notes: meal.note(for: restaurant.name)
                )
            }
            return ItineraryDay(id: UUID(), dayNumber: dayNumber, stops: stops)
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
            return "Couldn't find "\(city)". Check the city name and try again."
        case .noRestaurantsFound(let city):
            return "No halal restaurants found near \(city). Try lowering the halal standard."
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
            halalCertificationLevel: zabiha ? .level3 : .level2,
            cuisineType: cuisineType,
            rating: rating ?? 0.0,
            reviewCount: 0,
            phoneNumber: nil,
            websiteURL: "https://www.zabihah.com"
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
