import Foundation

enum PersistenceManager {
    private static let dir: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HalalBitesData", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static func fileURL(for key: String) -> URL {
        dir.appendingPathComponent("\(key).json")
    }

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            print("PersistenceManager: failed to save \(key): \(error)")
        }
    }

    static func load<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
