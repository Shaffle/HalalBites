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
    var photoURLs: [URL]
    var businessHours: [BusinessHours]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum CuisineCategory: String, CaseIterable, Identifiable, Codable {
    case mediterranean = "Mediterranean"
    case middleEastern = "Middle Eastern"
    case southAsian = "South Asian"
    case turkish = "Turkish"
    case african = "African"
    case southeastAsian = "Southeast Asian"
    case american = "American"

    var id: String { rawValue }

    var keywords: [String] {
        switch self {
        case .mediterranean: return ["mediterranean", "greek", "lebanese"]
        case .middleEastern: return ["middle eastern", "arab", "syrian", "iraqi", "persian", "iranian", "yemeni", "palestinian", "egyptian"]
        case .southAsian: return ["pakistani", "indian", "bangladeshi", "south asian", "biryani", "desi"]
        case .turkish: return ["turkish", "kebab", "ottoman"]
        case .african: return ["african", "somali", "ethiopian", "nigerian", "moroccan", "north african"]
        case .southeastAsian: return ["malaysian", "indonesian", "thai", "southeast asian"]
        case .american: return ["american", "burger", "pizza", "fried chicken", "bbq"]
        }
    }

    func matches(_ cuisineType: String) -> Bool {
        let lower = cuisineType.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}

enum BudgetLevel: Int, CaseIterable, Identifiable, Codable {
    case budget = 1
    case moderate = 2
    case upscale = 3

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .budget: return "$"
        case .moderate: return "$$"
        case .upscale: return "$$$"
        }
    }

    var label: String {
        switch self {
        case .budget: return "Budget-friendly"
        case .moderate: return "Moderate"
        case .upscale: return "Fine dining"
        }
    }
}

enum HalalLevel: Int, Codable, Hashable, CustomStringConvertible, CaseIterable {
    case halal = 1
    case partiallyHalal = 2
    case vegetarian = 3
    case vegan = 4

    var description: String {
        switch self {
        case .halal: return "Halal"
        case .partiallyHalal: return "Partially Halal"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        }
    }
}
