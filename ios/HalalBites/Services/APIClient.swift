import Foundation
import Combine

class APIClient: ObservableObject {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "https://api.halalbites.app/v1")!) {
        self.baseURL = baseURL
    }

    func generateItinerary(city: String, country: String, days: Int, halalLevel: HalalLevel) async throws -> Itinerary {
        var request = URLRequest(url: baseURL.appendingPathComponent("itineraries/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "city": city,
            "country": country,
            "duration_days": days,
            "min_halal_level": halalLevel.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError
        }

        return try JSONDecoder.isoDate.decode(Itinerary.self, from: data)
    }

    func fetchNearbyRestaurants(latitude: Double, longitude: Double, radiusMiles: Double, minLevel: HalalLevel) async throws -> [Restaurant] {
        var components = URLComponents(url: baseURL.appendingPathComponent("restaurants/nearby"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            .init(name: "lat", value: "\(latitude)"),
            .init(name: "lng", value: "\(longitude)"),
            .init(name: "radius_miles", value: "\(radiusMiles)"),
            .init(name: "min_halal_level", value: "\(minLevel.rawValue)")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder.isoDate.decode([Restaurant].self, from: data)
    }
}

enum APIError: LocalizedError {
    case serverError

    var errorDescription: String? { "Unable to reach HalalBites servers. Please try again." }
}

private extension JSONDecoder {
    static let isoDate: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
