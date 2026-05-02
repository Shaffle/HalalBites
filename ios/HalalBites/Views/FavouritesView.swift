import SwiftUI

struct FavouritesView: View {
    let itineraries: [Itinerary]
    let archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>

    private var favourited: [Itinerary] {
        (itineraries + archivedItineraries).filter { favouriteIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if favourited.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No favourites yet")
                        .font(.title3.bold())
                    Text("Swipe left on a trip to favourite it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(favourited) { itinerary in
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
