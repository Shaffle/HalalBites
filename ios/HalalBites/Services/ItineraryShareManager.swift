import Foundation

enum ItineraryShareManager {
    private static let scheme = "safa-halal"

    static func shareText(for code: String, profileName: String, tripName: String) -> String {
        """
        \(profileName) has shared \(tripName) with you!

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
