import SwiftUI

struct ArchiveView: View {
    @Binding var archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>
    @Binding var recentlyDeleted: [Itinerary]
    var onRestore: (Itinerary) -> Void

    var body: some View {
        Group {
            if archivedItineraries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No archived trips")
                        .font(.title3.bold())
                    Text("Completed trips are automatically moved here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(archivedItineraries) { itinerary in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(itinerary.city), \(itinerary.country)")
                                    .font(.headline)
                                Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if favouriteIDs.contains(itinerary.id) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.pink)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withAnimation {
                                    archivedItineraries.removeAll { $0.id == itinerary.id }
                                    favouriteIDs.remove(itinerary.id)
                                    if !recentlyDeleted.contains(where: { $0.id == itinerary.id }) {
                                        recentlyDeleted.insert(itinerary, at: 0)
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                withAnimation {
                                    if favouriteIDs.contains(itinerary.id) {
                                        _ = favouriteIDs.remove(itinerary.id)
                                    } else {
                                        favouriteIDs.insert(itinerary.id)
                                    }
                                }
                            } label: {
                                Label(
                                    favouriteIDs.contains(itinerary.id) ? "Unfavourite" : "Favourite",
                                    systemImage: favouriteIDs.contains(itinerary.id) ? "heart.slash" : "heart"
                                )
                            }
                            .tint(.pink)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
    }
}
