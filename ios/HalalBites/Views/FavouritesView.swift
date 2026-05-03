import SwiftUI

struct FavouritesView: View {
    let itineraries: [Itinerary]
    let archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>

    private var favouritedTrips: [Itinerary] {
        (itineraries + archivedItineraries).filter { favouriteIDs.contains($0.id) }
    }

    private var favouritedRestaurants: [Restaurant] {
        let allStops = (itineraries + archivedItineraries).flatMap { $0.days.flatMap(\.stops) }
        var seen: Set<UUID> = []
        return allStops.compactMap { stop -> Restaurant? in
            guard favouriteRestaurantIDs.contains(stop.restaurant.id),
                  !seen.contains(stop.restaurant.id) else { return nil }
            seen.insert(stop.restaurant.id)
            return stop.restaurant
        }
    }

    private var isEmpty: Bool {
        favouritedTrips.isEmpty && favouritedRestaurants.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No favourites yet")
                        .font(.title3.bold())
                    Text("Tap the heart on a restaurant to save it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    if !favouritedRestaurants.isEmpty {
                        Section("Restaurants") {
                            ForEach(favouritedRestaurants) { restaurant in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(restaurant.name)
                                            .font(.headline)
                                        Text(restaurant.cuisineType)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if restaurant.rating > 0 {
                                            HStack(spacing: 3) {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(.yellow)
                                                    .font(.caption)
                                                Text(String(format: "%.1f", restaurant.rating))
                                                    .font(.caption.bold())
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.pink)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        withAnimation {
                                            _ = favouriteRestaurantIDs.remove(restaurant.id)
                                        }
                                    } label: {
                                        Label("Unfavourite", systemImage: "heart.slash")
                                    }
                                    .tint(.pink)
                                }
                            }
                        }
                    }

                    if !favouritedTrips.isEmpty {
                        Section("Trips") {
                            ForEach(favouritedTrips) { itinerary in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(itinerary.city), \(itinerary.country)")
                                            .font(.headline)
                                        Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.pink)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        withAnimation {
                                            _ = favouriteIDs.remove(itinerary.id)
                                        }
                                    } label: {
                                        Label("Unfavourite", systemImage: "heart.slash")
                                    }
                                    .tint(.pink)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}
