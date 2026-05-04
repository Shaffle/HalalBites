import CloudKit
import Foundation

enum CloudKitShareService {
    private static let publicDB = CKContainer.default().publicCloudDatabase
    private static let recordType = "SharedItinerary"

    static func upload(_ itinerary: Itinerary, profileName: String) async throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(itinerary)

        for _ in 0..<3 {
            let code = generateCode()
            let recordID = CKRecord.ID(recordName: code)
            let record = CKRecord(recordType: recordType, recordID: recordID)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(code).json")
            try jsonData.write(to: tempURL)
            record["file"] = CKAsset(fileURL: tempURL)
            record["city"] = itinerary.city as CKRecordValue
            record["country"] = itinerary.country as CKRecordValue
            record["sender"] = profileName as CKRecordValue

            do {
                try await publicDB.save(record)
                try? FileManager.default.removeItem(at: tempURL)
                return code
            } catch let ckError as CKError {
                try? FileManager.default.removeItem(at: tempURL)
                if ckError.code == .serverRecordChanged {
                    continue
                }
                throw ckError
            }
        }
        throw ShareError.uploadFailed
    }

    static func fetch(code: String) async throws -> Itinerary {
        let recordID = CKRecord.ID(recordName: code)
        let record = try await publicDB.record(for: recordID)

        guard let asset = record["file"] as? CKAsset,
              let fileURL = asset.fileURL,
              let data = try? Data(contentsOf: fileURL) else {
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
        case uploadFailed

        var errorDescription: String? {
            switch self {
            case .invalidData: return "The shared itinerary data could not be read."
            case .uploadFailed: return "Could not upload itinerary. Please try again."
            }
        }
    }
}
