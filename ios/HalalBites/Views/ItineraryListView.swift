import SwiftUI

struct ItineraryListView: View {
    @EnvironmentObject var api: APIClient
    @Binding var itineraries: [Itinerary]
    @State private var showingGenerator = false
    @State private var presentedItinerary: Itinerary?
    @Binding var showSideMenu: Bool
    @Binding var favouriteIDs: Set<UUID>
    @Binding var archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]

    var body: some View {
        NavigationStack {
            Group {
                if itineraries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(itineraries) { itinerary in
                            Button {
                                presentedItinerary = itinerary
                            } label: {
                                ItineraryRowView(itinerary: itinerary, isFavourite: favouriteIDs.contains(itinerary.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteItinerary(itinerary)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Itineraries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingGenerator = true }) {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingGenerator) {
                ItineraryGeneratorView(onGenerate: handleGenerated)
            }
            .fullScreenCover(item: $presentedItinerary) { itinerary in
                NavigationStack {
                    ItineraryDetailView(itinerary: itinerary)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { presentedItinerary = nil }
                            }
                        }
                }
            }
            .onAppear { archiveEndedTrips() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No trips planned")
                .font(.headline)
            HStack(spacing: 4) {
                Text("Click the")
                Image(systemName: "sparkles")
                    .foregroundStyle(.teal)
                Text("to start!")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func handleGenerated(_ itinerary: Itinerary) {
        itineraries.insert(itinerary, at: 0)
        presentedItinerary = itinerary
    }

    private func deleteItinerary(_ itinerary: Itinerary) {
        withAnimation {
            itineraries.removeAll { $0.id == itinerary.id }
            favouriteIDs.remove(itinerary.id)
            if !recentlyDeleted.contains(where: { $0.id == itinerary.id }) {
                recentlyDeleted.insert(itinerary, at: 0)
            }
        }
    }

    func restoreItinerary(_ itinerary: Itinerary) {
        archivedItineraries.removeAll { $0.id == itinerary.id }
        itineraries.insert(itinerary, at: 0)
    }

    private func archiveEndedTrips() {
        let ended = itineraries.filter { $0.hasEnded }
        guard !ended.isEmpty else { return }
        withAnimation {
            for trip in ended {
                itineraries.removeAll { $0.id == trip.id }
                if !archivedItineraries.contains(where: { $0.id == trip.id }) {
                    archivedItineraries.insert(trip, at: 0)
                }
            }
        }
    }
}

struct ItineraryRowView: View {
    let itinerary: Itinerary
    var isFavourite: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(itinerary.city), \(itinerary.country)")
                    .font(.headline)
                Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFavourite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
