import Foundation

enum ItineraryShareManager {
    private static let scheme = "safa-halal"

    static func shareText(for code: String, itinerary: Itinerary, profileName: String) -> String {
        let stops = itinerary.days.flatMap(\.stops).count
        return """
        \(profileName) shared their \(itinerary.city), \(itinerary.country) itinerary with you on Safa Halal!
        \(itinerary.durationDays) days · \(stops) stops

        \(scheme)://c/\(code)
        """
    }

    static func parseShareCode(from url: URL) -> String? {
        guard url.scheme == scheme,
              url.host == "c",
              url.pathComponents.count > 1 else { return nil }
        return url.pathComponents[1]
    }
}
