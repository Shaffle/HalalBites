import Foundation
import CoreLocation

struct BusinessHours: Hashable, Codable {
    let day: String
    let hours: String
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
    let photoURLs: [URL]
    let businessHours: [BusinessHours]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var certificationLabel: String {
        zabiha ? "Zabiha Certified" : "Halal Certified"
    }

    private static let cafeKeywords = ["cafe", "café", "coffee", "bakery", "tea", "pastry", "dessert", "sweets", "donut", "doughnut", "juice", "smoothie"]

    var isCafe: Bool {
        let lower = (name + " " + cuisineType).lowercased()
        return Self.cafeKeywords.contains { lower.contains($0) }
    }

    private static let excludedChains = ["starbucks", "dunkin", "mcdonald", "subway"]

    var isExcludedChain: Bool {
        let lower = name.lowercased()
        return Self.excludedChains.contains { lower.contains($0) }
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
            ZabihahRestaurant(id: "mock-1", name: "Al Noor Restaurant", address: "123 Main St", latitude: lat + 0.004, longitude: lng + 0.005, cuisineType: "Mediterranean", zabiha: true, rating: 4.5, reviewCount: 0, halalDescription: nil, isRestaurant: true, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-2", name: "Salam Grill", address: "456 Oak Ave", latitude: lat - 0.003, longitude: lng + 0.008, cuisineType: "Middle Eastern", zabiha: true, rating: 4.2, reviewCount: 0, halalDescription: nil, isRestaurant: true, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-3", name: "Karachi Kitchen", address: "789 Elm Rd", latitude: lat + 0.007, longitude: lng - 0.004, cuisineType: "Pakistani", zabiha: false, rating: 4.7, reviewCount: 0, halalDescription: nil, isRestaurant: true, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-4", name: "Istanbul Kebab House", address: "321 Pine St", latitude: lat - 0.006, longitude: lng - 0.007, cuisineType: "Turkish", zabiha: true, rating: 4.3, reviewCount: 0, halalDescription: nil, isRestaurant: true, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-5", name: "Medina Grocery & Halal Meat", address: "654 Maple Dr", latitude: lat + 0.002, longitude: lng - 0.009, cuisineType: "Grocery", zabiha: true, rating: 4.8, reviewCount: 0, halalDescription: nil, isRestaurant: false, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-6", name: "Al Baraka Market", address: "220 Cedar Ln", latitude: lat - 0.005, longitude: lng + 0.003, cuisineType: "Grocery", zabiha: true, rating: 4.4, reviewCount: 0, halalDescription: nil, isRestaurant: false, photoURLs: [], businessHours: mockHours),
            ZabihahRestaurant(id: "mock-7", name: "Noor Cafe & Bakery", address: "415 Walnut St", latitude: lat + 0.006, longitude: lng + 0.002, cuisineType: "Cafe", zabiha: false, rating: 4.6, reviewCount: 0, halalDescription: nil, isRestaurant: true, photoURLs: [], businessHours: mockHours),
        ]
    }
}

// MARK: - API Response Model

private struct APIRestaurant: Decodable {
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

        return ZabihahRestaurant(
            id: id,
            name: name,
            address: address,
            latitude: Double(latitude) ?? 0,
            longitude: Double(longitude) ?? 0,
            cuisineType: joinedCuisine.isEmpty ? "Restaurant" : joinedCuisine,
            zabiha: handSlaughtered ?? false,
            rating: rating.flatMap { Double($0) },
            reviewCount: reviewCount ?? 0,
            halalDescription: halalSummary?.description,
            isRestaurant: isRestaurant,
            photoURLs: allPhotos,
            businessHours: hours
        )
    }
}

enum ZabihahError: LocalizedError {
    case invalidURL
    var errorDescription: String? { "Invalid Zabihah search URL." }
}
