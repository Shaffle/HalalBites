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

struct TravelInfo: Codable {
    let distanceMeters: Double
    let walkingTimeMinutes: Int
    let drivingTimeMinutes: Int

    var formattedDistance: String {
        let miles = distanceMeters / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", distanceMeters * 3.28084)
        }
        return String(format: "%.1f mi", miles)
    }
}

struct ItineraryStop: Identifiable, Codable {
    let id: UUID
    let restaurant: Restaurant
    let mealType: MealType
    let notes: String?
}

enum MealType: String, Codable {
    case breakfast, lunch, dinner, snack
}
