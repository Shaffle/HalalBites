import Foundation

struct UserReview: Identifiable, Codable {
    let id: UUID
    let restaurantName: String
    let rating: Int
    let text: String
    let authorName: String
    let createdAt: Date
}

class UserReviewStore: ObservableObject {
    static let shared = UserReviewStore()

    @Published private(set) var reviews: [String: [UserReview]] = [:]

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("user_reviews.json")
    }()

    init() {
        load()
    }

    func reviews(for restaurantName: String) -> [UserReview] {
        reviews[restaurantName] ?? []
    }

    func addReview(restaurantName: String, rating: Int, text: String, authorName: String) {
        let review = UserReview(
            id: UUID(),
            restaurantName: restaurantName,
            rating: rating,
            text: text,
            authorName: authorName,
            createdAt: Date()
        )
        reviews[restaurantName, default: []].insert(review, at: 0)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [UserReview]].self, from: data) else { return }
        reviews = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reviews) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
