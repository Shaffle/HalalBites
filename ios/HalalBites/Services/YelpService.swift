import Foundation
import CoreLocation

// MARK: - Yelp Models (Kept intact so your UI doesn't break)

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
    let businessHours: [BusinessHours] // Assuming BusinessHours is defined elsewhere in your project
    let yelpURL: URL?
    let categories: String
    let reviews: [YelpReview]
}

// MARK: - Scrapling-backed Yelp Compatibility Service

class YelpService {
    static let shared = YelpService()

    private init() {}

    var isConfigured: Bool { ScrapingService.shared.isConfigured }

    func searchNearby(latitude: Double, longitude: Double, term: String? = nil, categories: String? = nil, limit: Int = 20) async -> [YelpSearchBusiness] {
        []
    }

    func matchBusiness(name: String, latitude: Double, longitude: Double) async -> YelpSearchBusiness? {
        nil
    }

    func fetchDetail(businessId: String) async -> YelpBusinessDetail? {
        nil
    }

    func fetchReviews(businessId: String) async -> [YelpReview] {
        []
    }

    func fetchPhotoURLs(name: String, address: String = "", latitude: Double, longitude: Double) async -> [URL] {
        await ScrapingService.shared.fetchYelpPhotoURLs(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude
        )
    }

    func enrich(name: String, latitude: Double, longitude: Double) async -> YelpEnrichedData? {
        guard let enrichment = await ScrapingService.shared.fetchYelpEnrichment(
            name: name,
            address: "",
            latitude: latitude,
            longitude: longitude
        ) else {
            return nil
        }

        return YelpEnrichedData(
            rating: enrichment.rating ?? 0,
            reviewCount: enrichment.reviewCount ?? 0,
            phone: enrichment.phone,
            photos: enrichment.photos,
            businessHours: enrichment.businessHours,
            yelpURL: enrichment.yelpURL,
            categories: enrichment.categories ?? "",
            reviews: []
        )
    }
}
