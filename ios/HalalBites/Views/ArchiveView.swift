import SwiftUI

struct ArchiveView: View {
    @Binding var archivedItineraries: [Itinerary]
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
                    Text("Swipe left on a trip to archive it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(archivedItineraries) { itinerary in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(itinerary.city), \(itinerary.country)")
                                .font(.headline)
                            Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withAnimation {
                                    archivedItineraries.removeAll { $0.id == itinerary.id }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                withAnimation {
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
    }
}
