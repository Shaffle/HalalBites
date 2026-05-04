import Foundation

enum ItineraryShareManager {
    private static let fileExtension = "safahalal"

    static func shareItems(for itinerary: Itinerary, profileName: String) -> [Any]? {
        guard let fileURL = createShareFile(for: itinerary) else { return nil }
        let stops = itinerary.days.flatMap(\.stops).count
        let text = "\(profileName) shared their \(itinerary.city), \(itinerary.country) itinerary with you on Safa Halal!\n\(itinerary.durationDays) days · \(stops) stops"
        return [text, fileURL]
    }

    static func itinerary(from url: URL) -> Itinerary? {
        if url.isFileURL || url.pathExtension == fileExtension {
            return itineraryFromFile(url)
        }
        return nil
    }

    // MARK: - File Create / Import

    private static func createShareFile(for itinerary: Itinerary) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(itinerary) else { return nil }

        let safe = itinerary.city
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ",", with: "")
        let fileName = "\(safe)_\(itinerary.durationDays)d.\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard (try? json.write(to: tempURL)) != nil else { return nil }
        return tempURL
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
}
