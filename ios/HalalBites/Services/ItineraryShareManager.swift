import Foundation

// MARK: - Compact Share Payload

private struct SharePayload: Codable {
    let c: String
    let n: String
    let d: Int
    let s: String
    let p: String
    let dy: [ShareDay]
}

private struct ShareDay: Codable {
    let dn: Int
    let st: [ShareStop]
}

private struct ShareStop: Codable {
    let nm: String
    let ad: String
    let la: Double
    let lo: Double
    let cu: String
    let rt: Double
    let hl: Int
    let mt: String
}

// MARK: - Share Manager

enum ItineraryShareManager {
    private static let scheme = "safa-halal"
    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func shareText(for itinerary: Itinerary, profileName: String) -> String? {
        guard let encoded = encodeCompact(itinerary) else { return nil }
        let stops = itinerary.days.flatMap(\.stops).count
        return """
        \(profileName) shared their \(itinerary.city), \(itinerary.country) itinerary with you!
        \(itinerary.durationDays) days · \(stops) stops

        Tap to open in Safa Halal:
        \(scheme)://s/\(encoded)
        """
    }

    static func itinerary(from url: URL) -> Itinerary? {
        guard url.scheme == scheme else {
            if url.isFileURL { return itineraryFromFile(url) }
            return nil
        }

        if url.host == "s" {
            let encoded = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
            return decodeCompact(encoded)
        }

        if url.host == "import", url.pathComponents.count > 1 {
            return decodeLegacy(url.pathComponents[1])
        }

        return nil
    }

    // MARK: - Compact Encode / Decode

    private static func encodeCompact(_ itinerary: Itinerary) -> String? {
        let payload = SharePayload(
            c: itinerary.city,
            n: itinerary.country,
            d: itinerary.durationDays,
            s: dateFormat.string(from: itinerary.startDate),
            p: "",
            dy: itinerary.days.map { day in
                ShareDay(dn: day.dayNumber, st: day.stops.map { stop in
                    ShareStop(
                        nm: stop.restaurant.name,
                        ad: stop.restaurant.address,
                        la: round(stop.restaurant.latitude, places: 4),
                        lo: round(stop.restaurant.longitude, places: 4),
                        cu: stop.restaurant.cuisineType,
                        rt: round(stop.restaurant.rating, places: 1),
                        hl: stop.restaurant.halalCertificationLevel.rawValue,
                        mt: stop.mealType.rawValue
                    )
                })
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        guard let json = try? encoder.encode(payload) else { return nil }
        guard let compressed = try? (json as NSData).compressed(using: .zlib) as Data else { return nil }

        return compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeCompact(_ encoded: String) -> Itinerary? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let compressed = Data(base64Encoded: base64) else { return nil }
        guard let json = try? (compressed as NSData).decompressed(using: .zlib) as Data else { return nil }
        guard let payload = try? JSONDecoder().decode(SharePayload.self, from: json) else { return nil }

        let startDate = dateFormat.date(from: payload.s) ?? Date()

        let days = payload.dy.map { day in
            ItineraryDay(
                id: UUID(),
                dayNumber: day.dn,
                stops: day.st.map { stop in
                    ItineraryStop(
                        id: UUID(),
                        restaurant: Restaurant(
                            id: UUID(),
                            name: stop.nm,
                            address: stop.ad,
                            latitude: stop.la,
                            longitude: stop.lo,
                            halalCertificationLevel: HalalLevel(rawValue: stop.hl) ?? .halal,
                            cuisineType: stop.cu,
                            rating: stop.rt,
                            reviewCount: 0,
                            phoneNumber: nil,
                            websiteURL: nil,
                            photoURLs: [],
                            businessHours: []
                        ),
                        mealType: MealType(rawValue: stop.mt) ?? .lunch,
                        notes: nil
                    )
                }
            )
        }

        return Itinerary(
            city: payload.c,
            country: payload.n,
            durationDays: payload.d,
            createdAt: Date(),
            startDate: startDate,
            days: days,
            isSaved: true,
            isShared: true
        )
    }

    // MARK: - Legacy URL Decode

    private static func decodeLegacy(_ encoded: String) -> Itinerary? {
        var base64 = encoded
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

    // MARK: - File Import

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

    // MARK: - Helpers

    private static func round(_ value: Double, places: Int) -> Double {
        let m = pow(10.0, Double(places))
        return (value * m).rounded() / m
    }
}
