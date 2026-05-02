import Foundation
import CoreLocation

struct Restaurant: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let halalCertificationLevel: HalalLevel
    let cuisineType: String
    let rating: Double
    let reviewCount: Int
    let phoneNumber: String?
    let websiteURL: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum HalalLevel: Int, Codable, Hashable, CustomStringConvertible {
    case level1 = 1   // Self-certified
    case level2 = 2   // Third-party certified
    case level3 = 3   // Zabiha + third-party certified

    var description: String {
        switch self {
        case .level1: return "Self-Certified"
        case .level2: return "Certified Halal"
        case .level3: return "Zabiha Certified"
        }
    }
}
