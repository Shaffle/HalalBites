import SwiftUI

struct RecentView: View {
    let itineraries: [Itinerary]
    let archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]
    var onRestore: (Itinerary) -> Void

    @State private var selectedItinerary: Itinerary?

    private var activeIDs: Set<UUID> {
        Set(itineraries.map(\.id))
    }

    private var archivedIDs: Set<UUID> {
        Set(archivedItineraries.map(\.id))
    }

    private var allSorted: [Itinerary] {
        (itineraries + archivedItineraries + recentlyDeleted)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func isDeleted(_ itinerary: Itinerary) -> Bool {
        !activeIDs.contains(itinerary.id) && !archivedIDs.contains(itinerary.id)
    }

    private func status(for itinerary: Itinerary) -> (String, Color) {
        if activeIDs.contains(itinerary.id) {
            return ("Active", .teal)
        } else if archivedIDs.contains(itinerary.id) {
            return ("Completed", .secondary)
        } else {
            return ("Deleted", .red)
        }
    }

    var body: some View {
        Group {
            if allSorted.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No recent trips")
                        .font(.title3.bold())
                    Text("Trips you create will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(allSorted) { itinerary in
                        let (label, color) = status(for: itinerary)
                        Button {
                            selectedItinerary = itinerary
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(itinerary.city), \(itinerary.country)")
                                        .font(.headline)
                                    Spacer()
                                    Text(label)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(color.opacity(0.15))
                                        .foregroundStyle(color)
                                        .clipShape(Capsule())
                                }
                                Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Created \(itinerary.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isDeleted(itinerary) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        recentlyDeleted.removeAll { $0.id == itinerary.id }
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Recent")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedItinerary) { itinerary in
            NavigationStack {
                RecentDetailWrapperView(
                    itinerary: itinerary,
                    showRestore: isDeleted(itinerary),
                    onRestore: {
                        recentlyDeleted.removeAll { $0.id == itinerary.id }
                        onRestore(itinerary)
                        selectedItinerary = nil
                    },
                    onDismiss: { selectedItinerary = nil }
                )
            }
        }
    }
}

struct RecentDetailWrapperView: View {
    let itinerary: Itinerary
    let showRestore: Bool
    let onRestore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ItineraryDetailView(itinerary: itinerary)

            if showRestore {
                Button(action: onRestore) {
                    Label("Restore to My Itineraries", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", action: onDismiss)
            }
        }
    }
}
