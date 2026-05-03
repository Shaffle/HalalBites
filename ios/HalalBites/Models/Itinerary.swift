import Foundation

struct Itinerary: Identifiable, Codable, Equatable {
    let id: UUID
    let city: String
    let country: String
    let durationDays: Int
    let createdAt: Date
    let startDate: Date
    var days: [ItineraryDay]
    var isSaved: Bool

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
    }

    var hasEnded: Bool {
        endDate < Date()
    }
}

struct ItineraryDay: Identifiable, Codable, Equatable {
    let id: UUID
    let dayNumber: Int
    var stops: [ItineraryStop]
}

struct TravelInfo: Codable, Equatable {
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

struct ItineraryStop: Identifiable, Codable, Equatable {
    let id: UUID
    let restaurant: Restaurant
    let mealType: MealType
    let notes: String?
}

enum MealType: String, Codable {
    case breakfast, lunch, dinner, snack
}
