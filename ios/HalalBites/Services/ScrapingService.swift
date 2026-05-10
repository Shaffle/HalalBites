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

struct ScraplingYelpEnrichment: Decodable {
    let rating: Double?
    let reviewCount: Int?
    let phone: String?
    let photos: [URL]
    let businessHours: [BusinessHours]
    let yelpURL: URL?
    let categories: String?

    enum CodingKeys: String, CodingKey {
        case rating, phone, photos, categories
        case reviewCount = "review_count"
        case businessHours = "business_hours"
        case yelpURL = "yelp_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        categories = try container.decodeIfPresent(String.self, forKey: .categories)

        let photoStrings = try container.decodeIfPresent([String].self, forKey: .photos) ?? []
        photos = photoStrings.compactMap(URL.init(string:))

        businessHours = try container.decodeIfPresent([BusinessHours].self, forKey: .businessHours) ?? []

        if let urlString = try container.decodeIfPresent(String.self, forKey: .yelpURL) {
            yelpURL = URL(string: urlString)
        } else {
            yelpURL = nil
        }
    }
}

class ScrapingService {
    static let shared = ScrapingService()

    private let baseURL = "https://safa-halal-backend.onrender.com"

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    private func makeJSONPostRequest(path: String, body: [String: Any], timeout: TimeInterval = 20) -> URLRequest? {
        guard isConfigured,
              let url = URL(string: "\(baseURL)\(path)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    func fetchRestaurants(latitude: Double, longitude: Double) async throws -> [[String: Any]] {
        guard let request = makeJSONPostRequest(
            path: "/api/restaurants",
            body: ["latitude": latitude, "longitude": longitude],
            timeout: 30
        ) else { return [] }

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
        guard let request = makeJSONPostRequest(path: "/api/menu", body: [
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude
        ]) else { return [] }

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
        guard let request = makeJSONPostRequest(
            path: "/api/restaurants",
            body: ["latitude": latitude, "longitude": longitude],
            timeout: 5
        ) else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let restaurants = json["restaurants"] else {
            return nil
        }

        return try? JSONSerialization.data(withJSONObject: restaurants)
    }

    func fetchYelpEnrichment(name: String, address: String, latitude: Double, longitude: Double) async -> ScraplingYelpEnrichment? {
        guard let request = makeJSONPostRequest(path: "/api/yelp/enrich", body: [
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude
        ]) else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        struct EnrichmentResponse: Decodable {
            let yelp: ScraplingYelpEnrichment?
            let enrichment: ScraplingYelpEnrichment?
        }

        if let wrapped = try? JSONDecoder().decode(EnrichmentResponse.self, from: data) {
            return wrapped.yelp ?? wrapped.enrichment
        }

        return try? JSONDecoder().decode(ScraplingYelpEnrichment.self, from: data)
    }

    func fetchYelpPhotoURLs(name: String, address: String, latitude: Double, longitude: Double) async -> [URL] {
        let enrichmentPhotos = await fetchYelpEnrichment(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude
        )?.photos ?? []

        if !enrichmentPhotos.isEmpty {
            return enrichmentPhotos
        }

        guard let request = makeJSONPostRequest(path: "/api/yelp/photos", body: [
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude
        ]) else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        struct PhotoResponse: Decodable {
            let photos: [String]
        }

        guard let decoded = try? JSONDecoder().decode(PhotoResponse.self, from: data) else {
            return []
        }

        return decoded.photos.compactMap(URL.init(string:))
    }
}
