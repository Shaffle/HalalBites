import Foundation

enum ItineraryShareManager {
    private static let scheme = "safa-halal"

    static func shareURL(for itinerary: Itinerary) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(itinerary) else { return nil }
        let compressed = (try? (json as NSData).compressed(using: .zlib)) as Data? ?? json
        let base64 = compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(scheme)://import/\(base64)")
    }

    static func itinerary(from url: URL) -> Itinerary? {
        guard url.scheme == scheme,
              url.host == "import",
              url.pathComponents.count > 1 else { return nil }

        var base64 = url.pathComponents[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let compressed = Data(base64Encoded: base64) else { return nil }
        let json = (try? (compressed as NSData).decompressed(using: .zlib)) as Data? ?? compressed

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var itinerary = try? decoder.decode(Itinerary.self, from: json) else { return nil }

        itinerary = Itinerary(
            id: UUID(),
            city: itinerary.city,
            country: itinerary.country,
            durationDays: itinerary.durationDays,
            createdAt: Date(),
            startDate: itinerary.startDate,
            days: itinerary.days,
            isSaved: true,
            isShared: true
        )
        return itinerary
    }
}
