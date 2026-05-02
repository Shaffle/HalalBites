import SwiftUI

struct ItineraryDetailView: View {
    let itinerary: Itinerary

    var body: some View {
        List {
            ForEach(itinerary.days) { day in
                Section("Day \(day.dayNumber)") {
                    ForEach(day.stops) { stop in
                        ItineraryStopRow(stop: stop)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(itinerary.city) · \(itinerary.durationDays)d")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItineraryStopRow: View {
    let stop: ItineraryStop

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stop.restaurant.name)
                    .font(.headline)
                Spacer()
                Text(stop.mealType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.teal.opacity(0.15))
                    .foregroundStyle(.teal)
                    .clipShape(Capsule())
            }

            Text(stop.restaurant.cuisineType)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HalalBadge(level: stop.restaurant.halalCertificationLevel)

            if let walk = stop.walkingTimeFromPrevious {
                Label("\(walk) min walk from previous stop", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HalalBadge: View {
    let level: HalalLevel

    private var color: Color {
        switch level {
        case .level1: return .orange
        case .level2: return .green
        case .level3: return .mint
        }
    }

    var body: some View {
        Label(level.description, systemImage: "checkmark.seal.fill")
            .font(.caption.bold())
            .foregroundStyle(color)
    }
}
