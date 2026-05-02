import Foundation

struct YelpBusiness: Decodable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, rating
        case reviewCount = "review_count"
    }
}

struct YelpBusinessDetail: Decodable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let photos: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, rating, photos
        case reviewCount = "review_count"
    }
}

class YelpService {
    static let shared = YelpService()

    // Paste your Yelp Fusion API key here — get one free at https://fusion.yelp.com
    private let apiKey = "YOUR_YELP_API_KEY"

    private var isConfigured: Bool { apiKey != "YOUR_YELP_API_KEY" }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }()

    func matchBusiness(name: String, latitude: Double, longitude: Double) async -> YelpBusiness? {
        guard isConfigured else { return nil }

        var components = URLComponents(string: "https://api.yelp.com/v3/businesses/search")!
        components.queryItems = [
            .init(name: "term", value: name),
            .init(name: "latitude", value: "\(latitude)"),
            .init(name: "longitude", value: "\(longitude)"),
            .init(name: "limit", value: "1")
        ]

        guard let url = components.url else { return nil }

        let response: YelpSearchResponse? = try? await fetch(url: url)
        return response?.businesses.first
    }

    func fetchBusinessDetail(businessId: String) async -> YelpBusinessDetail? {
        guard isConfigured else { return nil }

        let url = URL(string: "https://api.yelp.com/v3/businesses/\(businessId)")!
        return try? await fetch(url: url)
    }

    func ratingAndPhotos(name: String, latitude: Double, longitude: Double) async -> (rating: Double, reviewCount: Int, photos: [URL])? {
        guard let match = await matchBusiness(name: name, latitude: latitude, longitude: longitude) else {
            return nil
        }
        guard let detail = await fetchBusinessDetail(businessId: match.id) else {
            return (match.rating, match.reviewCount, [])
        }
        let photoURLs = detail.photos.compactMap { URL(string: $0) }
        return (detail.rating, detail.reviewCount, photoURLs)
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct YelpSearchResponse: Decodable {
    let businesses: [YelpBusiness]
}
