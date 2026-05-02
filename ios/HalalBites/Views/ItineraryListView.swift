import SwiftUI

struct ItineraryListView: View {
    @EnvironmentObject var api: APIClient
    @State private var itineraries: [Itinerary] = []
    @State private var archivedItineraries: [Itinerary] = []
    @State private var showingGenerator = false
    @State private var presentedItinerary: Itinerary?
    @State private var showSideMenu = false
    @State private var favouriteIDs: Set<UUID> = []

    var body: some View {
        ZStack {
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
                                    Button {
                                        archiveItinerary(itinerary)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                    Button {
                                        toggleFavourite(itinerary)
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
            }
            .disabled(showSideMenu)

            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = false
                        }
                    }
            }

            SideMenuView(
                isShowing: $showSideMenu,
                archivedItineraries: $archivedItineraries,
                onRestore: restoreItinerary
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No trips planned")
                .font(.title2.bold())
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
        }
    }

    private func archiveItinerary(_ itinerary: Itinerary) {
        withAnimation {
            itineraries.removeAll { $0.id == itinerary.id }
            archivedItineraries.insert(itinerary, at: 0)
        }
    }

    private func restoreItinerary(_ itinerary: Itinerary) {
        archivedItineraries.removeAll { $0.id == itinerary.id }
        itineraries.insert(itinerary, at: 0)
    }

    private func toggleFavourite(_ itinerary: Itinerary) {
        withAnimation {
            if favouriteIDs.contains(itinerary.id) {
                favouriteIDs.remove(itinerary.id)
            } else {
                favouriteIDs.insert(itinerary.id)
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
