import CloudKit

enum CloudKitShareService {
    private static let publicDB = CKContainer.default().publicCloudDatabase
    private static let recordType = "SharedItinerary"

    static func upload(_ itinerary: Itinerary, profileName: String) async throws -> String {
        let code = generateCode()
        let recordID = CKRecord.ID(recordName: code)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(itinerary)

        record["jsonData"] = String(data: jsonData, encoding: .utf8)
        record["city"] = itinerary.city
        record["country"] = itinerary.country
        record["sharedBy"] = profileName

        try await publicDB.save(record)
        return code
    }

    static func fetch(code: String) async throws -> Itinerary {
        let recordID = CKRecord.ID(recordName: code)
        let record = try await publicDB.record(for: recordID)

        guard let jsonString = record["jsonData"] as? String,
              let data = jsonString.data(using: .utf8) else {
            throw ShareError.invalidData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Itinerary.self, from: data)

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

    private static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    enum ShareError: LocalizedError {
        case invalidData
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .invalidData: return "The shared itinerary data is invalid."
            case .notSignedIn: return "Sign in to iCloud in Settings to share itineraries."
            }
        }
    }
}
