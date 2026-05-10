import Foundation
import CoreLocation
import MapKit

struct BusinessHours: Hashable, Codable {
    let day: String
    let hours: String
}

enum ZabihahHalalStatus: String, Hashable {
    case fullyHalal
    case partiallyHalal
    case zabiha
    case unverified
}

struct ZabihahRestaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let cuisineType: String
    let zabiha: Bool
    let rating: Double?
    let reviewCount: Int
    let halalDescription: String?
    let isRestaurant: Bool
    let halalStatus: ZabihahHalalStatus
    let photoURLs: [URL]
    let businessHours: [BusinessHours]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var certificationLabel: String {
        switch halalStatus {
        case .zabiha: return "Halal"
        case .partiallyHalal: return "Partially-Halal"
        case .fullyHalal: return "Halal"
        case .unverified: return "Verify Halal"
        }
    }

    var halalLevel: HalalLevel {
        switch halalStatus {
        case .zabiha: return .halal
        case .fullyHalal: return .halal
        case .partiallyHalal, .unverified: return .partiallyHalal
        }
    }

    private static let dessertNameKeywords = ["ice cream", "icecream", "gelato", "frozen yogurt", "froyo", "frozen custard", "custard", "creamery", "dessert", "sweets", "donut", "doughnut", "pastry", "patisserie", "bakeshop", "cupcake", "cookie", "candy", "chocolate", "churro"]
    private static let dessertCuisineKeywords = ["dessert", "desserts", "ice cream", "ice cream & frozen yogurt", "gelato", "frozen yogurt", "frozen desserts", "frozen custard", "custard", "donut", "donuts", "bakery", "pastry", "sweets"]

    var isDessertShop: Bool {
        let lowerName = name.lowercased()
        let lowerCuisine = cuisineType.lowercased()
        return Self.dessertNameKeywords.contains { lowerName.contains($0) }
            || Self.dessertCuisineKeywords.contains { lowerCuisine.contains($0) }
    }

    private static let cafeNameKeywords = ["cafe", "café", "coffee", "espresso", "roastery", "tea", "boba", "juice", "smoothie"]
    private static let cafeCuisineKeywords = ["cafe", "café", "coffee", "tea", "juice", "smoothie"]

    var isCafe: Bool {
        if isDessertShop { return false }
        let lowerName = name.lowercased()
        let lowerCuisine = cuisineType.lowercased()
        return Self.cafeNameKeywords.contains { lowerName.contains($0) }
            || Self.cafeCuisineKeywords.contains { lowerCuisine.contains($0) }
    }

    private static let excludedChains = ["starbucks", "dunkin", "mcdonalds", "subway", "burger king", "carls jr.", "wendy's", "pizza hut", "chipotle", "taco bell", "red lobster", "jack in the box", "kfc", "costco", "culver"]

    var isExcludedChain: Bool {
        let lower = name.lowercased()
        return Self.excludedChains.contains { lower.contains($0) }
    }

    func withPhotoURLs(_ urls: [URL]) -> ZabihahRestaurant {
        ZabihahRestaurant(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            cuisineType: cuisineType,
            zabiha: zabiha,
            rating: rating,
            reviewCount: reviewCount,
            halalDescription: halalDescription,
            isRestaurant: isRestaurant,
            halalStatus: halalStatus,
            photoURLs: urls,
            businessHours: businessHours
        )
    }
}

class ZabihahService {
    static let shared = ZabihahService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html, */*",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }()

    func fetchNearby(latitude: Double, longitude: Double, radiusMiles: Int = 5) async throws -> [ZabihahRestaurant] {
        var components = URLComponents(string: "https://www.zabihah.com/search")!
        components.queryItems = [
            .init(name: "lat", value: "\(latitude)"),
            .init(name: "lng", value: "\(longitude)")
        ]

        guard let url = components.url else { throw ZabihahError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return Self.mockRestaurants(near: latitude, longitude: longitude)
        }

        let restaurants = Self.parseRestaurants(from: html)
        return restaurants.isEmpty
            ? Self.mockRestaurants(near: latitude, longitude: longitude)
            : restaurants
    }

    func fetchCombined(latitude: Double, longitude: Double) async -> [ZabihahRestaurant] {
        async let zabihahResults = Self.withTimeout(seconds: 5) {
            (try? await self.fetchNearby(latitude: latitude, longitude: longitude)) ?? []
        } ?? []
        async let appleResults = Self.searchAppleMaps(latitude: latitude, longitude: longitude)
        async let backendResults = Self.withTimeout(seconds: 5) {
            await Self.fetchScraplingRestaurants(latitude: latitude, longitude: longitude)
        } ?? []

        let zabihah = await zabihahResults
        let apple = await appleResults
        let backend = await backendResults

        var merged = zabihah

        for restaurant in apple + backend {
            let isDuplicate = merged.contains { existing in
                let nameSimilar = existing.name.lowercased().contains(restaurant.name.lowercased().prefix(8))
                    || restaurant.name.lowercased().contains(existing.name.lowercased().prefix(8))
                let distance = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                    .distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
                return nameSimilar && distance < 200
            }
            if !isDuplicate {
                merged.append(restaurant)
            }
        }
        return merged.isEmpty ? Self.mockRestaurants(near: latitude, longitude: longitude) : merged
    }

    private static func withTimeout<T>(seconds: Double, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private static func fillMissingYelpPhotos(in restaurants: [ZabihahRestaurant]) async -> [ZabihahRestaurant] {
        guard YelpService.shared.isConfigured else { return restaurants }

        let targetIndexes = restaurants.indices.filter {
            restaurants[$0].photoURLs.isEmpty && restaurants[$0].isRestaurant
        }.prefix(16)

        guard !targetIndexes.isEmpty else { return restaurants }

        var updated = restaurants
        await withTaskGroup(of: (Int, [URL]).self) { group in
            for index in targetIndexes {
                let restaurant = restaurants[index]
                group.addTask {
                    let urls = await YelpService.shared.fetchPhotoURLs(
                        name: restaurant.name,
                        address: restaurant.address,
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude
                    )
                    return (index, urls)
                }
            }

            for await (index, urls) in group where !urls.isEmpty {
                updated[index] = updated[index].withPhotoURLs(urls)
            }
        }

        return updated
    }

    private static func fetchScraplingRestaurants(latitude: Double, longitude: Double) async -> [ZabihahRestaurant] {
        guard let data = await ScrapingService.shared.fetchRestaurantsDecoded(
            latitude: latitude, longitude: longitude
        ) else { return [] }

        guard let decoded = try? JSONDecoder().decode([APIRestaurant].self, from: data),
              !decoded.isEmpty else { return [] }

        return decoded.map { $0.toZabihahRestaurant() }
    }

    static func searchAppleMaps(latitude: Double, longitude: Double, extraQueries: [String] = [], queries: [String]? = nil) async -> [ZabihahRestaurant] {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25))

        let baseQueries = queries ?? [
            "halal restaurant", "halal food", "halal grocery", "halal meat",
            "cafe", "bakery", "coffee shop", "ice cream", "dessert",
            "mediterranean restaurant", "middle eastern restaurant",
            "pakistani restaurant", "afghan restaurant", "turkish restaurant",
            "lebanese restaurant", "indian restaurant", "somali restaurant",
            "shawarma", "kebab", "falafel", "biryani"
        ]
        let queries = baseQueries + extraQueries
        let allResults = await withTaskGroup(of: [(MKMapItem, Bool)].self) { group in
            for query in queries {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = query
                    request.region = region
                    let hasHalalSearchSignal = Self.hasHalalSignal(in: query)
                    let items = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
                    return items.map { ($0, hasHalalSearchSignal) }
                }
            }
            var items: [(MKMapItem, Bool)] = []
            for await batch in group { items.append(contentsOf: batch) }
            return items
        }

        var seenNames: Set<String> = []
        var unique: [(MKMapItem, Bool)] = []
        for (item, hasHalalSearchSignal) in allResults {
            let key = (item.name ?? "").lowercased()
            if let index = unique.firstIndex(where: { ($0.0.name ?? "").lowercased() == key }) {
                unique[index].1 = unique[index].1 || hasHalalSearchSignal
            } else if !seenNames.contains(key) {
                seenNames.insert(key)
                unique.append((item, hasHalalSearchSignal))
            }
        }

        return mapItemsToRestaurants(unique)
    }

    private static let rejectedNames = [
        "chevron", "shell", "exxon", "mobil", "bp ", "arco", "76 ", "sinclair",
        "gas station", "fuel", "7-eleven", "circle k", "maverick", "quiktrip", "wawa",
        "mcdonald", "burger king", "wendy's", "taco bell", "jack in the box",
        "popeyes", "kfc", "chick-fil-a", "panda express", "chipotle", "subway",
        "culver",
        "applebee's", "chili's", "olive garden", "red lobster", "outback",
        "denny's", "ihop", "cheesecake factory", "panera", "buffalo wild wings",
        "walmart", "target", "costco", "dollar", "home depot", "lowes",
        "walgreens", "cvs", "rite aid", "autozone", "o'reilly", "fedex", "ups store"
    ]

    private static let nonFoodPOIs: Set<MKPointOfInterestCategory> = [
        .gasStation, .parking, .hotel, .hospital, .pharmacy, .police,
        .fireStation, .school, .university, .postOffice, .bank, .atm,
        .carRental, .evCharger, .laundry, .store, .fitnessCenter, .movieTheater
    ]

    private static func mapItemsToRestaurants(_ items: [(item: MKMapItem, hasHalalSearchSignal: Bool)]) -> [ZabihahRestaurant] {
        items.compactMap { item, hasHalalSearchSignal -> ZabihahRestaurant? in
            guard let name = item.name else { return nil }
            let coord = item.placemark.coordinate
            let nameLower = name.lowercased()

            if rejectedNames.contains(where: { nameLower.contains($0) }) { return nil }

            let poi = item.pointOfInterestCategory
            if let poi, nonFoodPOIs.contains(poi) { return nil }

            let isCafeOrBakery = poi == .cafe || poi == .bakery
            let isGrocery = poi == .foodMarket

            let groceryKeywords = ["grocery", "market", "meat", "butcher", "supermarket"]
            let dessertKeywords = ["ice cream", "icecream", "gelato", "frozen yogurt", "froyo", "frozen custard", "custard", "creamery", "dessert", "sweets", "donut", "doughnut", "cupcake", "candy", "chocolate", "churro"]
            let cafeKeywords = ["cafe", "café", "coffee", "tea", "juice", "smoothie"]
            let bakeryKeywords = ["bakery", "bakeshop", "pastry", "patisserie"]
            let isGroceryByName = groceryKeywords.contains { nameLower.contains($0) }
            let isDessertByName = dessertKeywords.contains { nameLower.contains($0) }
            let isCafeByName = cafeKeywords.contains { nameLower.contains($0) }
            let isBakeryByName = bakeryKeywords.contains { nameLower.contains($0) }
            let isCafe = !isDessertByName && (isCafeOrBakery || isCafeByName || isBakeryByName)

            let address = [
                item.placemark.subThoroughfare,
                item.placemark.thoroughfare,
                item.placemark.locality,
                item.placemark.administrativeArea
            ].compactMap { $0 }.joined(separator: " ")

            let cuisineType: String
            if isDessertByName {
                cuisineType = "Dessert"
            } else if isCafe {
                cuisineType = "Cafe"
            } else if isGrocery || isGroceryByName {
                cuisineType = "Grocery"
            } else {
                cuisineType = "Restaurant"
            }

            let halalStatus: ZabihahHalalStatus = hasHalalSearchSignal || Self.hasHalalSignal(in: name)
                ? .fullyHalal
                : .unverified

            return ZabihahRestaurant(
                id: "apple-\(name.hashValue)-\(coord.latitude)",
                name: name,
                address: address.isEmpty ? "Nearby" : address,
                latitude: coord.latitude,
                longitude: coord.longitude,
                cuisineType: cuisineType,
                zabiha: false,
                rating: nil,
                reviewCount: 0,
                halalDescription: halalStatus == .unverified ? "Apple Maps result. Verify halal status before visiting." : "Verify halal status",
                isRestaurant: !(isGrocery || isGroceryByName),
                halalStatus: halalStatus,
                photoURLs: [],
                businessHours: []
            )
        }
    }

    private static func hasHalalSignal(in text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("halal") || lower.contains("zabiha") || lower.contains("zabihah")
    }

    static func parseRestaurants(from html: String) -> [ZabihahRestaurant] {
        let unescaped = html
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")

        guard let startRange = unescaped.range(of: "\"initialRestaurants\":[") else { return [] }

        let arrayStart = unescaped.index(startRange.upperBound, offsetBy: -1)
        var depth = 0
        var inString = false
        var escaped = false
        var arrayEnd = arrayStart

        for i in unescaped[arrayStart...].indices {
            let c = unescaped[i]
            if escaped { escaped = false; continue }
            if c == "\\" { escaped = true; continue }
            if c == "\"" { inString = !inString; continue }
            if !inString {
                if c == "[" { depth += 1 }
                else if c == "]" { depth -= 1 }
                if depth == 0 { arrayEnd = unescaped.index(after: i); break }
            }
        }

        let jsonString = String(unescaped[arrayStart..<arrayEnd])
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }

        let decoded = (try? JSONDecoder().decode([APIRestaurant].self, from: jsonData)) ?? []
        return decoded.map { $0.toZabihahRestaurant() }
    }

    static func mockRestaurants(near lat: Double, longitude lng: Double) -> [ZabihahRestaurant] {
        let mockHours = [
            BusinessHours(day: "Monday", hours: "11:00 AM - 9:00 PM"),
            BusinessHours(day: "Tuesday", hours: "11:00 AM - 9:00 PM"),
            BusinessHours(day: "Wednesday", hours: "11:00 AM - 9:00 PM"),
            BusinessHours(day: "Thursday", hours: "11:00 AM - 9:00 PM"),
            BusinessHours(day: "Friday", hours: "11:00 AM - 10:00 PM"),
            BusinessHours(day: "Saturday", hours: "11:00 AM - 10:00 PM"),
            BusinessHours(day: "Sunday", hours: "12:00 PM - 8:00 PM"),
        ]
        return [
            ZabihahRestaurant(id: "mock-1", name: "Al Noor Restaurant", address: "123 Main St", latitude: lat + 0.004, longitude: lng + 0.005, cuisineType: "Mediterranean", zabiha: true, rating: 4.5, reviewCount: 0, halalDescription: nil, isRestaurant: true, halalStatus: .zabiha, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-2", name: "Salam Grill", address: "456 Oak Ave", latitude: lat - 0.003, longitude: lng + 0.008, cuisineType: "Middle Eastern", zabiha: true, rating: 4.2, reviewCount: 0, halalDescription: nil, isRestaurant: true, halalStatus: .zabiha, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-3", name: "Karachi Kitchen", address: "789 Elm Rd", latitude: lat + 0.007, longitude: lng - 0.004, cuisineType: "Pakistani", zabiha: false, rating: 4.7, reviewCount: 0, halalDescription: nil, isRestaurant: true, halalStatus: .fullyHalal, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-4", name: "Istanbul Kebab House", address: "321 Pine St", latitude: lat - 0.006, longitude: lng - 0.007, cuisineType: "Turkish", zabiha: true, rating: 4.3, reviewCount: 0, halalDescription: nil, isRestaurant: true, halalStatus: .zabiha, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-5", name: "Medina Grocery & Halal Meat", address: "654 Maple Dr", latitude: lat + 0.002, longitude: lng - 0.009, cuisineType: "Grocery", zabiha: true, rating: 4.8, reviewCount: 0, halalDescription: nil, isRestaurant: false, halalStatus: .fullyHalal, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-6", name: "Al Baraka Market", address: "220 Cedar Ln", latitude: lat - 0.005, longitude: lng + 0.003, cuisineType: "Grocery", zabiha: true, rating: 4.4, reviewCount: 0, halalDescription: nil, isRestaurant: false, halalStatus: .fullyHalal, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-7", name: "Noor Cafe & Bakery", address: "415 Walnut St", latitude: lat + 0.006, longitude: lng + 0.002, cuisineType: "Cafe", zabiha: false, rating: 4.6, reviewCount: 0, halalDescription: nil, isRestaurant: true, halalStatus: .fullyHalal, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-8", name: "Olive Garden", address: "900 Broadway", latitude: lat - 0.002, longitude: lng + 0.006, cuisineType: "Italian", zabiha: false, rating: 3.8, reviewCount: 0, halalDescription: "Partially halal menu available", isRestaurant: true, halalStatus: .partiallyHalal, photoURLs: [], businessHours: mockHours),
        ]
    }
}

// MARK: - API Response Model

struct APIRestaurant: Decodable {
    let id: String
    let name: String
    let address: String
    let latitude: String
    let longitude: String
    let cuisine: [String]?
    let rating: String?
    let reviewCount: Int?
    let handSlaughtered: Bool?
    let halalSummary: HalalSummary?
    let restaurantType: Int?
    let coverImage: String?
    let galleryPhotos: [String]?
    let businessHours: [APIBusinessHours]?

    struct HalalSummary: Decodable {
        let description: String?
        let meatHalalStatus: String?
    }

    struct APIBusinessHours: Decodable {
        let day: String
        let hours: String
    }

    private static let nonRestaurantKeywords = [
        "groceries", "halal meat", "butcher", "market", "supermarket"
    ]

    func toZabihahRestaurant() -> ZabihahRestaurant {
        let cuisines = cuisine ?? []
        let joinedCuisine = cuisines.joined(separator: ", ")

        let hasOnlyNonRestaurantCuisines = !cuisines.isEmpty && cuisines.allSatisfy { tag in
            Self.nonRestaurantKeywords.contains(where: { tag.localizedCaseInsensitiveContains($0) })
        }
        let isRestaurant = restaurantType == 1 && !hasOnlyNonRestaurantCuisines

        var allPhotos: [URL] = []
        if let cover = coverImage, let url = URL(string: cover) {
            allPhotos.append(url)
        }
        if let gallery = galleryPhotos {
            allPhotos.append(contentsOf: gallery.compactMap { URL(string: $0) })
        }

        let hours = (businessHours ?? []).map {
            BusinessHours(day: $0.day, hours: $0.hours)
        }

        let isZabiha = handSlaughtered ?? false
        let meatStatus = (halalSummary?.meatHalalStatus ?? "").lowercased()
        let descLower = (halalSummary?.description ?? "").lowercased()

        let status: ZabihahHalalStatus
        if meatStatus.contains("partial") || descLower.contains("partially halal") || descLower.contains("partial halal") {
            status = .partiallyHalal
        } else if isZabiha {
            status = .zabiha
        } else {
            status = .fullyHalal
        }

        return ZabihahRestaurant(
            id: id,
            name: name,
            address: address,
            latitude: Double(latitude) ?? 0,
            longitude: Double(longitude) ?? 0,
            cuisineType: joinedCuisine.isEmpty ? "Restaurant" : joinedCuisine,
            zabiha: isZabiha,
            rating: rating.flatMap { Double($0) },
            reviewCount: reviewCount ?? 0,
            halalDescription: halalSummary?.description,
            isRestaurant: isRestaurant,
            halalStatus: status,
            photoURLs: allPhotos,
            businessHours: hours
        )
    }
}

enum ZabihahError: LocalizedError {
    case invalidURL
    var errorDescription: String? { "Invalid Zabihah search URL." }
}
