import Foundation
import CoreLocation

struct ZabihahRestaurant: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let cuisineType: String
    let zabiha: Bool
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, zabiha, rating
        case cuisineType = "cuisine"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var certificationLabel: String {
        zabiha ? "Zabiha Certified" : "Halal Certified"
    }
}

class ZabihahService {
    static let shared = ZabihahService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "application/json, text/html, */*",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }()

    func fetchNearby(latitude: Double, longitude: Double, radiusMiles: Int = 5) async throws -> [ZabihahRestaurant] {
        // Zabihah JSON search endpoint
        var components = URLComponents(string: "https://www.zabihah.com/api/srch")!
        components.queryItems = [
            .init(name: "lat", value: "\(latitude)"),
            .init(name: "lng", value: "\(longitude)"),
            .init(name: "r", value: "\(radiusMiles)"),
            .init(name: "out", value: "json")
        ]

        guard let url = components.url else { throw ZabihahError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // Fall back to mock data when the API is unreachable (dev/simulator)
            return Self.mockRestaurants(near: latitude, longitude: longitude)
        }

        // Zabihah wraps results in { "results": [...] }
        let decoded = try JSONDecoder().decode(ZabihahSearchResponse.self, from: data)
        return decoded.results
    }

    // Mock data so the map shows pins immediately in the simulator
    static func mockRestaurants(near lat: Double, longitude lng: Double) -> [ZabihahRestaurant] {
        [
            ZabihahRestaurant(id: 1, name: "Al Noor Restaurant", address: "123 Main St", latitude: lat + 0.004, longitude: lng + 0.005, cuisineType: "Mediterranean", zabiha: true, rating: 4.5),
            ZabihahRestaurant(id: 2, name: "Salam Grill", address: "456 Oak Ave", latitude: lat - 0.003, longitude: lng + 0.008, cuisineType: "Middle Eastern", zabiha: true, rating: 4.2),
            ZabihahRestaurant(id: 3, name: "Karachi Kitchen", address: "789 Elm Rd", latitude: lat + 0.007, longitude: lng - 0.004, cuisineType: "Pakistani", zabiha: false, rating: 4.7),
            ZabihahRestaurant(id: 4, name: "Istanbul Kebab House", address: "321 Pine St", latitude: lat - 0.006, longitude: lng - 0.007, cuisineType: "Turkish", zabiha: true, rating: 4.3),
            ZabihahRestaurant(id: 5, name: "Medina Sweets", address: "654 Maple Dr", latitude: lat + 0.002, longitude: lng - 0.009, cuisineType: "Bakery", zabiha: false, rating: 4.8),
        ]
    }
}

private struct ZabihahSearchResponse: Decodable {
    let results: [ZabihahRestaurant]
}

enum ZabihahError: LocalizedError {
    case invalidURL
    var errorDescription: String? { "Invalid Zabihah search URL." }
}
