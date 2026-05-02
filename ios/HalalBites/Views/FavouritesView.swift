import SwiftUI

struct FavouritesView: View {
    let itineraries: [Itinerary]
    let archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>

    private var favourites: [Itinerary] {
        (itineraries + archivedItineraries).filter { favouriteIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if favourites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No favourites yet")
                        .font(.title3.bold())
                    Text("Swipe on an archived trip to add it to your favourites.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(favourites) { itinerary in
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
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}
