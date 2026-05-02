import Foundation

struct Itinerary: Identifiable, Codable {
    let id: UUID
    let city: String
    let country: String
    let durationDays: Int
    let createdAt: Date
    var days: [ItineraryDay]
    var isSaved: Bool
}

struct ItineraryDay: Identifiable, Codable {
    let id: UUID
    let dayNumber: Int
    var stops: [ItineraryStop]
}

struct ItineraryStop: Identifiable, Codable {
    let id: UUID
    let restaurant: Restaurant
    let mealType: MealType
    let walkingTimeFromPrevious: Int?  // minutes
    let notes: String?
}

enum MealType: String, Codable {
    case breakfast, lunch, dinner, snack
}
