import SwiftUI

struct ItineraryListView: View {
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
                    if !itineraries.isEmpty {
                        Button(action: { showingGenerator = true }) {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGenerator) {
                ItineraryGeneratorView(onGenerate: handleGenerated)
            }
            .fullScreenCover(item: $presentedItinerary) { presented in
                if let idx = itineraries.firstIndex(where: { $0.id == presented.id }) {
                    NavigationStack {
                        ItineraryDetailView(itinerary: $itineraries[idx])
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { presentedItinerary = nil }
                                }
                            }
                    }
                }
            }
            .onAppear { archiveEndedTrips() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            Text("No trips planned")
                .font(.title2.bold())

            Button {
                showingGenerator = true
            } label: {
                HStack(spacing: 8) {
                    Text("Tap here")
                    Image(systemName: "sparkles")
                    Text("to start!")
                }
                .font(.title3.bold())
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.teal)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
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
