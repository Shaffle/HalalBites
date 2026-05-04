import Foundation

enum ItineraryShareManager {
    private static let scheme = "safa-halal"
    private static let fileExtension = "safahalal"

    static func shareFile(for itinerary: Itinerary) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(itinerary) else { return nil }

        let safe = itinerary.city.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safe)_\(itinerary.durationDays)d.\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard (try? json.write(to: tempURL)) != nil else { return nil }
        return tempURL
    }

    static func itinerary(from url: URL) -> Itinerary? {
        if url.isFileURL || url.pathExtension == fileExtension {
            return itineraryFromFile(url)
        }
        if url.scheme == scheme {
            return itineraryFromCustomURL(url)
        }
        return nil
    }

    private static func itineraryFromFile(_ url: URL) -> Itinerary? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Itinerary.self, from: data) else { return nil }

        return Itinerary(
            id: UUID(),
            city: decoded.city,
            country: decoded.country,
            durationDays: decoded.durationDays,
            createdAt: Date(),
            startDate: decoded.startDate,
            days: decoded.days,
            isSaved: true,
            isShared: true
        )
    }

    private static func itineraryFromCustomURL(_ url: URL) -> Itinerary? {
        guard url.host == "import",
              url.pathComponents.count > 1 else { return nil }

        var base64 = url.pathComponents[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let compressed = Data(base64Encoded: base64) else { return nil }
        let json = (try? (compressed as NSData).decompressed(using: .zlib)) as Data? ?? compressed

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Itinerary.self, from: json) else { return nil }

        return Itinerary(
            id: UUID(),
            city: decoded.city,
            country: decoded.country,
            durationDays: decoded.durationDays,
            createdAt: Date(),
            startDate: decoded.startDate,
            days: decoded.days,
            isSaved: true,
            isShared: true
        )
    }
}
