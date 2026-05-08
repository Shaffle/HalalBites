import Foundation

struct MenuCategory: Decodable, Identifiable {
    var id: String { category }
    let category: String
    let items: [MenuItem]
}

struct MenuItem: Decodable, Identifiable {
    var id: String { name + price }
    let name: String
    let description: String
    let price: String
}

class ScrapingService {
    static let shared = ScrapingService()

    private let baseURL = "https://safa-halal-backend.onrender.com"

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    func fetchRestaurants(latitude: Double, longitude: Double) async throws -> [[String: Any]] {
        guard isConfigured else { return [] }

        guard let url = URL(string: "\(baseURL)/api/restaurants") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let restaurants = json["restaurants"] as? [[String: Any]] else {
            return []
        }

        return restaurants
    }

    func fetchMenu(name: String, address: String, latitude: Double, longitude: Double) async -> [MenuCategory] {
        guard isConfigured,
              let url = URL(string: "\(baseURL)/api/menu") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        struct MenuResponse: Decodable {
            let menu: [MenuCategory]
        }

        guard let decoded = try? JSONDecoder().decode(MenuResponse.self, from: data) else {
            return []
        }
        return decoded.menu
    }

    func fetchRestaurantsDecoded(latitude: Double, longitude: Double) async -> Data? {
        guard isConfigured,
              let url = URL(string: "\(baseURL)/api/restaurants") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let restaurants = json["restaurants"] else {
            return nil
        }

        return try? JSONSerialization.data(withJSONObject: restaurants)
    }
}
