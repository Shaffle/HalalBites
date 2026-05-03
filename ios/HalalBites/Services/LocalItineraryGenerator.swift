import CoreLocation
import Foundation
import MapKit

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
        let coordinate = try await geocode(city: city, country: country)

        let zabihahRestaurants = (try? await ZabihahService.shared.fetchNearby(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMiles: 10
        )) ?? ZabihahService.mockRestaurants(near: coordinate.latitude, longitude: coordinate.longitude)

        let diningOnly = zabihahRestaurants.filter { $0.isRestaurant }

        guard !diningOnly.isEmpty else {
            throw GeneratorError.noRestaurantsFound(city: city)
        }

        let cuisineFiltered: [ZabihahRestaurant]
        if cuisines.isEmpty {
            cuisineFiltered = diningOnly
        } else {
            let matched = diningOnly.filter { r in
                cuisines.contains { $0.matches(r.cuisineType) }
            }
            cuisineFiltered = matched.isEmpty ? diningOnly : matched
        }

        let allRestaurants = cuisineFiltered.map { $0.toRestaurant() }
        let highRated = allRestaurants.filter { $0.rating >= 3.7 }
        let pool = highRated.isEmpty ? allRestaurants : highRated

        let dayNames = (0..<max(1, days)).map { offset -> String in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }

        let mealTypes: [MealType] = [.breakfast, .lunch, .dinner]
        var breakfastPool = pool.filter { suits(meal: .breakfast, restaurant: $0) }
        let lunchPool = pool.filter { suits(meal: .lunch, restaurant: $0) }
        let dinnerPool = pool.filter { suits(meal: .dinner, restaurant: $0) }

        if breakfastPool.isEmpty {
            let cafeResults = await searchBreakfastSpots(near: coordinate)
            if !cafeResults.isEmpty {
                breakfastPool = cafeResults
            }
        }

        var usedInTrip: Set<UUID> = []
        var indices: [MealType: Int] = [.breakfast: 0, .lunch: 0, .dinner: 0]
        var itineraryDays: [ItineraryDay] = []

        for dayNumber in 1...max(1, days) {
            let dayName = dayNames[(dayNumber - 1) % dayNames.count]
            var usedToday: Set<UUID> = []
            var stops: [ItineraryStop] = []

            for meal in mealTypes {
                let baseMealPool: [Restaurant]
                switch meal {
                case .breakfast:
                    if !breakfastPool.isEmpty {
                        baseMealPool = breakfastPool
                    } else {
                        let cafes = await searchBreakfastSpots(near: coordinate)
                        baseMealPool = cafes.isEmpty
                            ? [makePlaceholderCafe(near: coordinate)]
                            : cafes
                    }
                case .lunch:     baseMealPool = lunchPool.isEmpty ? pool : lunchPool
                case .dinner:    baseMealPool = dinnerPool.isEmpty ? pool : dinnerPool
                case .snack:     baseMealPool = pool
                }

                let mealPool = filterOpenOn(day: dayName, restaurants: baseMealPool, fallback: baseMealPool)

                var idx = indices[meal, default: 0]
                var restaurant = mealPool[idx % mealPool.count]
                var attempts = 0

                while (usedInTrip.contains(restaurant.id) || usedToday.contains(restaurant.id)) && attempts < mealPool.count {
                    idx += 1
                    restaurant = mealPool[idx % mealPool.count]
                    attempts += 1
                }

                if usedInTrip.contains(restaurant.id) || usedToday.contains(restaurant.id) {
                    idx = indices[meal, default: 0]
                    restaurant = mealPool[idx % mealPool.count]
                    attempts = 0
                    while usedToday.contains(restaurant.id) && attempts < mealPool.count {
                        idx += 1
                        restaurant = mealPool[idx % mealPool.count]
                        attempts += 1
                    }
                }

                indices[meal] = idx + 1
                usedToday.insert(restaurant.id)
                usedInTrip.insert(restaurant.id)

                stops.append(ItineraryStop(
                    id: UUID(),
                    restaurant: restaurant,
                    mealType: meal,
                    notes: suggestDish(for: restaurant, meal: meal)
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
            startDate: startDate,
            days: itineraryDays,
            isSaved: false
        )
    }

    // MARK: - Menu Suggestions

    private static func suggestDish(for restaurant: Restaurant, meal: MealType) -> String {
        let cuisine = restaurant.cuisineType.lowercased()
        let name = restaurant.name.lowercased()

        let dish = matchDish(cuisine: cuisine, name: name, meal: meal, seed: restaurant.name)
        return "Try the \(dish)"
    }

    private static func matchDish(cuisine: String, name: String, meal: MealType, seed: String) -> String {
        for entry in dishSuggestions {
            if entry.keywords.contains(where: { cuisine.contains($0) || name.contains($0) }) {
                if let dishes = entry.dishes[meal], !dishes.isEmpty {
                    return pick(from: dishes, seed: seed)
                }
            }
        }
        return pick(from: genericDishes[meal] ?? ["house special"], seed: seed)
    }

    private static func pick(from dishes: [String], seed: String) -> String {
        let hash = abs(seed.hashValue)
        return dishes[hash % dishes.count]
    }

    private struct DishEntry {
        let keywords: [String]
        let dishes: [MealType: [String]]
    }

    private static let dishSuggestions: [DishEntry] = [
        DishEntry(
            keywords: ["bakery", "sweets", "pastry", "dessert", "kunafa"],
            dishes: [
                .breakfast: ["fresh kunafa", "cheese borek with tea", "baklava assortment"],
                .lunch: ["spinach fatayer", "zaatar manakish", "cheese sambousek"],
                .dinner: ["mixed baklava platter", "basbousa", "knafeh nabulsieh"],
            ]
        ),
        DishEntry(
            keywords: ["cafe", "café", "coffee"],
            dishes: [
                .breakfast: ["Turkish coffee and simit", "avocado toast", "eggs and halloumi"],
                .lunch: ["grilled panini", "chicken caesar wrap", "soup and sandwich combo"],
                .dinner: ["pasta arrabbiata", "grilled chicken plate", "mezze board"],
            ]
        ),
        DishEntry(
            keywords: ["mediterranean", "lebanese", "syrian"],
            dishes: [
                .breakfast: ["shakshuka", "manakish with za'atar", "labneh with olive oil"],
                .lunch: ["falafel wrap", "chicken shawarma plate", "fattoush salad"],
                .dinner: ["mixed grill platter", "lamb kofta with hummus", "grilled sea bass"],
            ]
        ),
        DishEntry(
            keywords: ["middle eastern", "arab", "iraqi", "jordanian", "palestinian"],
            dishes: [
                .breakfast: ["ful medames", "hummus with warm pita", "halloumi and eggs"],
                .lunch: ["chicken shawarma", "lamb kebab plate", "maqluba"],
                .dinner: ["mansaf", "mixed grill", "lamb shank with rice"],
            ]
        ),
        DishEntry(
            keywords: ["pakistani", "indian", "south asian", "bangladeshi", "desi"],
            dishes: [
                .breakfast: ["halwa puri", "nihari with naan", "aloo paratha with chai"],
                .lunch: ["chicken biryani", "seekh kebab roll", "daal with garlic naan"],
                .dinner: ["lamb biryani", "karahi gosht", "butter chicken with naan"],
            ]
        ),
        DishEntry(
            keywords: ["turkish"],
            dishes: [
                .breakfast: ["menemen with simit", "Turkish breakfast spread", "gözleme"],
                .lunch: ["döner kebab", "pide", "lahmacun"],
                .dinner: ["Adana kebab", "iskender kebab", "lamb shish with bulgur"],
            ]
        ),
        DishEntry(
            keywords: ["african", "somali", "ethiopian", "moroccan", "nigerian", "egyptian"],
            dishes: [
                .breakfast: ["mandazi with chai", "ful with feta", "lahoh with honey"],
                .lunch: ["jollof rice", "suya skewers", "injera with wot sampler"],
                .dinner: ["lamb tagine", "couscous royale", "goat suqaar with rice"],
            ]
        ),
        DishEntry(
            keywords: ["southeast asian", "malaysian", "indonesian", "thai"],
            dishes: [
                .breakfast: ["nasi lemak", "roti canai with daal", "mee goreng"],
                .lunch: ["chicken satay with peanut sauce", "nasi goreng", "tom yum soup"],
                .dinner: ["beef rendang", "laksa", "murtabak"],
            ]
        ),
        DishEntry(
            keywords: ["american", "burger", "grill", "bbq", "fried"],
            dishes: [
                .breakfast: ["pancake stack", "chicken and waffles", "breakfast burrito"],
                .lunch: ["smash burger", "philly cheesesteak", "crispy chicken sandwich"],
                .dinner: ["BBQ platter", "lamb burger with fries", "steak plate"],
            ]
        ),
        DishEntry(
            keywords: ["chinese", "asian", "wok"],
            dishes: [
                .breakfast: ["congee with sides", "scallion pancakes", "dim sum selection"],
                .lunch: ["kung pao chicken", "beef chow mein", "sesame chicken"],
                .dinner: ["Peking duck", "mapo tofu", "salt and pepper lamb"],
            ]
        ),
        DishEntry(
            keywords: ["pizza", "italian"],
            dishes: [
                .breakfast: ["margherita flatbread", "bruschetta", "caprese salad"],
                .lunch: ["pepperoni pizza", "chicken pesto panini", "pasta carbonara"],
                .dinner: ["quattro formaggi pizza", "lamb ragu pappardelle", "risotto"],
            ]
        ),
        DishEntry(
            keywords: ["mexican", "taco", "burrito"],
            dishes: [
                .breakfast: ["breakfast burrito", "huevos rancheros", "chilaquiles"],
                .lunch: ["chicken tacos", "burrito bowl", "quesadilla"],
                .dinner: ["carne asada plate", "enchiladas", "birria tacos"],
            ]
        ),
    ]

    private static let genericDishes: [MealType: [String]] = [
        .breakfast: ["breakfast platter", "eggs and toast", "morning special"],
        .lunch: ["grilled chicken plate", "combo platter", "chef's lunch special"],
        .dinner: ["house special platter", "grilled lamb plate", "chef's dinner selection"],
        .snack: ["samosa platter", "appetizer combo", "fresh juice"],
    ]

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
                            "pastry", "sweets", "coffee", "diner", "donut",
                            "bagel", "pancake", "egg", "morning"]
            let isBreakfastType = keywords.contains(where: { name.contains($0) || cuisine.contains($0) })
            let isVegFriendly = restaurant.halalCertificationLevel == .vegetarian
                || restaurant.halalCertificationLevel == .vegan

            guard isBreakfastType || isVegFriendly else { return false }

            if restaurant.businessHours.isEmpty { return true }
            guard let earliest = earliestOpenHour(restaurant.businessHours) else { return true }
            return earliest < 10

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

    // MARK: - Breakfast Fallback

    private static func makePlaceholderCafe(near coordinate: CLLocationCoordinate2D) -> Restaurant {
        Restaurant(
            id: UUID(),
            name: "Local Cafe (explore nearby)",
            address: "Search for a cafe or bakery near your hotel",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            halalCertificationLevel: .vegetarian,
            cuisineType: "Cafe",
            rating: 0,
            reviewCount: 0,
            phoneNumber: nil,
            websiteURL: nil,
            photoURLs: [],
            businessHours: []
        )
    }

    private static func searchBreakfastSpots(near coordinate: CLLocationCoordinate2D) async -> [Restaurant] {
        let queries = ["halal breakfast", "halal cafe", "vegetarian breakfast",
                       "vegetarian cafe", "coffee shop", "bakery", "breakfast restaurant"]
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )

        var results: [Restaurant] = []
        var seenNames: Set<String> = []

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region

            guard let response = try? await MKLocalSearch(request: request).start() else { continue }

            for item in response.mapItems {
                guard let name = item.name, !seenNames.contains(name.lowercased()) else { continue }
                seenNames.insert(name.lowercased())

                let level: HalalLevel
                let nameLower = name.lowercased()
                let categories = item.pointOfInterestCategory?.rawValue.lowercased() ?? ""
                if nameLower.contains("halal") {
                    level = .halal
                } else if nameLower.contains("vegan") || categories.contains("vegan") {
                    level = .vegan
                } else {
                    level = .vegetarian
                }

                let address = [
                    item.placemark.subThoroughfare,
                    item.placemark.thoroughfare,
                    item.placemark.locality
                ].compactMap { $0 }.joined(separator: " ")

                results.append(Restaurant(
                    id: UUID(),
                    name: name,
                    address: address.isEmpty ? "Address unavailable" : address,
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    halalCertificationLevel: level,
                    cuisineType: "Cafe",
                    rating: 0,
                    reviewCount: 0,
                    phoneNumber: item.phoneNumber,
                    websiteURL: item.url?.absoluteString,
                    photoURLs: [],
                    businessHours: []
                ))

                if results.count >= 10 { return results }
            }
        }

        return results
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
