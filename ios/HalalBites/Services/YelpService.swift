import Foundation
import CoreLocation

// MARK: - Yelp API Response Models

struct YelpSearchResponse: Decodable {
    let businesses: [YelpSearchBusiness]
}

struct YelpSearchBusiness: Decodable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let phone: String?
    let price: String?
    let imageUrl: String?
    let url: String?
    let categories: [YelpCategory]
    let coordinates: YelpCoordinates
    let location: YelpLocation

    enum CodingKeys: String, CodingKey {
        case id, name, rating, phone, price, categories, coordinates, location, url
        case reviewCount = "review_count"
        case imageUrl = "image_url"
    }
}

struct YelpBusinessDetail: Decodable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let phone: String?
    let displayPhone: String?
    let price: String?
    let photos: [String]
    let url: String?
    let categories: [YelpCategory]
    let coordinates: YelpCoordinates
    let location: YelpLocation
    let hours: [YelpHoursGroup]?

    enum CodingKeys: String, CodingKey {
        case id, name, rating, phone, price, photos, url, categories, coordinates, location, hours
        case reviewCount = "review_count"
        case displayPhone = "display_phone"
    }
}

struct YelpCategory: Decodable {
    let alias: String
    let title: String
}

struct YelpCoordinates: Decodable {
    let latitude: Double
    let longitude: Double
}

struct YelpLocation: Decodable {
    let address1: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let displayAddress: [String]?

    enum CodingKeys: String, CodingKey {
        case address1, city, state
        case zipCode = "zip_code"
        case displayAddress = "display_address"
    }
}

struct YelpHoursGroup: Decodable {
    let open: [YelpOpenSlot]
    let isOpenNow: Bool?

    enum CodingKeys: String, CodingKey {
        case open
        case isOpenNow = "is_open_now"
    }
}

struct YelpOpenSlot: Decodable {
    let day: Int
    let start: String
    let end: String
    let isOvernight: Bool

    enum CodingKeys: String, CodingKey {
        case day, start, end
        case isOvernight = "is_overnight"
    }
}

struct YelpReviewsResponse: Decodable {
    let reviews: [YelpReview]
}

struct YelpReview: Decodable {
    let id: String
    let rating: Int
    let text: String
    let user: YelpUser

    struct YelpUser: Decodable {
        let name: String
    }
}

// MARK: - Enriched Data

struct YelpEnrichedData {
    let rating: Double
    let reviewCount: Int
    let phone: String?
    let photos: [URL]
    let businessHours: [BusinessHours]
    let yelpURL: URL?
    let categories: String
    let reviews: [YelpReview]
}

// MARK: - Yelp Service

class YelpService {
    static let shared = YelpService()

    // Paste your Yelp Fusion API key here — get one free at https://fusion.yelp.com
    private let apiKey = "YOUR_YELP_API_KEY"

    var isConfigured: Bool { apiKey != "YOUR_YELP_API_KEY" }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }()

    func searchNearby(latitude: Double, longitude: Double, term: String? = nil, categories: String? = nil, limit: Int = 20) async -> [YelpSearchBusiness] {
        guard isConfigured else { return [] }

        var components = URLComponents(string: "https://api.yelp.com/v3/businesses/search")!
        var items: [URLQueryItem] = [
            .init(name: "latitude", value: "\(latitude)"),
            .init(name: "longitude", value: "\(longitude)"),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "sort_by", value: "distance")
        ]
        if let term { items.append(.init(name: "term", value: term)) }
        if let categories { items.append(.init(name: "categories", value: categories)) }
        components.queryItems = items

        guard let url = components.url else { return [] }
        let response: YelpSearchResponse? = try? await fetch(url: url)
        return response?.businesses ?? []
    }

    func matchBusiness(name: String, latitude: Double, longitude: Double) async -> YelpSearchBusiness? {
        guard isConfigured else { return nil }

        var components = URLComponents(string: "https://api.yelp.com/v3/businesses/search")!
        components.queryItems = [
            .init(name: "term", value: name),
            .init(name: "latitude", value: "\(latitude)"),
            .init(name: "longitude", value: "\(longitude)"),
            .init(name: "limit", value: "3")
        ]

        guard let url = components.url else { return nil }
        let response: YelpSearchResponse? = try? await fetch(url: url)

        return response?.businesses.first { biz in
            let bizLoc = CLLocation(latitude: biz.coordinates.latitude, longitude: biz.coordinates.longitude)
            let targetLoc = CLLocation(latitude: latitude, longitude: longitude)
            let nameMatch = biz.name.lowercased().contains(name.lowercased().prefix(8))
                || name.lowercased().contains(biz.name.lowercased().prefix(8))
            return nameMatch && bizLoc.distance(from: targetLoc) < 500
        } ?? response?.businesses.first
    }

    func fetchDetail(businessId: String) async -> YelpBusinessDetail? {
        guard isConfigured else { return nil }
        let escaped = businessId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? businessId
        guard let url = URL(string: "https://api.yelp.com/v3/businesses/\(escaped)") else { return nil }
        return try? await fetch(url: url)
    }

    func fetchReviews(businessId: String) async -> [YelpReview] {
        guard isConfigured else { return [] }
        let escaped = businessId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? businessId
        guard let url = URL(string: "https://api.yelp.com/v3/businesses/\(escaped)/reviews?limit=3&sort_by=yelp_sort") else { return [] }
        let response: YelpReviewsResponse? = try? await fetch(url: url)
        return response?.reviews ?? []
    }

    func enrich(name: String, latitude: Double, longitude: Double) async -> YelpEnrichedData? {
        guard let match = await matchBusiness(name: name, latitude: latitude, longitude: longitude) else { return nil }

        async let detailResult = fetchDetail(businessId: match.id)
        async let reviewsResult = fetchReviews(businessId: match.id)

        let detail = await detailResult
        let reviews = await reviewsResult

        let photos = (detail?.photos ?? []).compactMap { URL(string: $0) }
        let hours = detail?.hours?.first?.open.compactMap { slot -> BusinessHours? in
            let dayName = Self.dayName(from: slot.day)
            let startFormatted = Self.formatTime(slot.start)
            let endFormatted = Self.formatTime(slot.end)
            return BusinessHours(day: dayName, hours: "\(startFormatted) - \(endFormatted)")
        } ?? []

        let categoryString = (detail?.categories ?? match.categories)
            .map(\.title)
            .joined(separator: ", ")

        return YelpEnrichedData(
            rating: detail?.rating ?? match.rating,
            reviewCount: detail?.reviewCount ?? match.reviewCount,
            phone: detail?.displayPhone ?? detail?.phone ?? match.phone,
            photos: photos,
            businessHours: hours,
            yelpURL: URL(string: detail?.url ?? match.url ?? ""),
            categories: categoryString,
            reviews: reviews
        )
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private static func dayName(from index: Int) -> String {
        guard index >= 0 && index < dayNames.count else { return "Unknown" }
        return dayNames[index]
    }

    private static func formatTime(_ military: String) -> String {
        guard military.count == 4,
              let hour = Int(military.prefix(2)),
              let minute = Int(military.suffix(2)) else { return military }

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour):00 \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}
