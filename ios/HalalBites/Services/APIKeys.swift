import Foundation

enum APIKeys {
    private static let keys: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return [:]
        }
        return dict
    }()

    static var yelpAPIKey: String {
        keys["YELP_API_KEY"] ?? ""
    }
}
