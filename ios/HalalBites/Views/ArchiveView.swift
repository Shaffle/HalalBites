import SwiftUI

struct ArchiveView: View {
    @Binding var archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var recentlyDeleted: [Itinerary]
    var onRestore: (Itinerary) -> Void

    @State private var selectedItinerary: Itinerary?

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
                        Button {
                            selectedItinerary = itinerary
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(itinerary.city), \(itinerary.country)")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
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
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
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
                            Button {
                                withAnimation {
                                    archivedItineraries.removeAll { $0.id == itinerary.id }
                                    onRestore(itinerary)
                                }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.teal)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItinerary) { itinerary in
            NavigationStack {
                ItineraryDetailView(
                    itinerary: .constant(itinerary),
                    favouriteRestaurantIDs: $favouriteRestaurantIDs
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { selectedItinerary = nil }
                    }
                }
            }
        }
    }
}
