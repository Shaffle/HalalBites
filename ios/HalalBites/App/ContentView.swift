import SwiftUI

struct ContentView: View {
    @AppStorage("lightsOn") private var lightsOn = true
    @State private var showSideMenu = false
    @State private var itineraries: [Itinerary] = []
    @State private var favouriteIDs: Set<UUID> = []
    @State private var favouriteRestaurantIDs: Set<UUID> = []
    @State private var exploreFavouriteRestaurants: [Restaurant] = []
    @State private var archivedItineraries: [Itinerary] = []
    @State private var recentlyDeleted: [Itinerary] = []
    @Binding var pendingItinerary: Itinerary?
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        mainContent
            .preferredColorScheme(lightsOn ? .light : .dark)
            .onAppear(perform: loadData)
            .onChange(of: pendingItinerary) { _, newValue in
                if let shared = newValue {
                    if !itineraries.contains(where: { $0.id == shared.id }) {
                        itineraries.insert(shared, at: 0)
                    }
                    pendingItinerary = nil
                }
            }
            .modifier(PersistItineraries(itineraries: $itineraries, archivedItineraries: $archivedItineraries, recentlyDeleted: $recentlyDeleted))
            .modifier(PersistFavourites(favouriteIDs: $favouriteIDs, favouriteRestaurantIDs: $favouriteRestaurantIDs, exploreFavouriteRestaurants: $exploreFavouriteRestaurants))
            .onChange(of: itineraries) { _, newValue in
                notificationService.updateMonitoredStops(from: newValue)
                notificationService.scheduleDailyReminders(for: newValue)
            }
    }

    private var mainContent: some View {
        ZStack {
            tabContent
                .disabled(showSideMenu)

            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = false
                        }
                    }
                    .zIndex(1)
            }

            SideMenuView(
                isShowing: $showSideMenu,
                itineraries: $itineraries,
                archivedItineraries: $archivedItineraries,
                recentlyDeleted: $recentlyDeleted,
                favouriteIDs: $favouriteIDs,
                favouriteRestaurantIDs: $favouriteRestaurantIDs,
                exploreFavouriteRestaurants: $exploreFavouriteRestaurants,
                onRestore: restoreItinerary
            )
            .zIndex(2)
        }
    }

    private var tabContent: some View {
        TabView {
            ExploreMapView(itineraries: $itineraries, showSideMenu: $showSideMenu, favouriteRestaurantIDs: $favouriteRestaurantIDs, exploreFavouriteRestaurants: $exploreFavouriteRestaurants)
                .tabItem {
                    Label("Explore", systemImage: "mappin.and.ellipse")
                }

            ItineraryListView(
                itineraries: $itineraries,
                showSideMenu: $showSideMenu,
                favouriteIDs: $favouriteIDs,
                favouriteRestaurantIDs: $favouriteRestaurantIDs,
                archivedItineraries: $archivedItineraries,
                recentlyDeleted: $recentlyDeleted
            )
            .tabItem {
                Label("Itineraries", systemImage: "map")
            }
        }
    }

    private func restoreItinerary(_ itinerary: Itinerary) {
        archivedItineraries.removeAll { $0.id == itinerary.id }
        recentlyDeleted.removeAll { $0.id == itinerary.id }
        if !itineraries.contains(where: { $0.id == itinerary.id }) {
            itineraries.insert(itinerary, at: 0)
        }
    }

    private func loadData() {
        itineraries = PersistenceManager.load(forKey: "itineraries", as: [Itinerary].self) ?? []
        favouriteIDs = PersistenceManager.load(forKey: "favouriteIDs", as: Set<UUID>.self) ?? []
        favouriteRestaurantIDs = PersistenceManager.load(forKey: "favouriteRestaurantIDs", as: Set<UUID>.self) ?? []
        exploreFavouriteRestaurants = PersistenceManager.load(forKey: "exploreFavouriteRestaurants", as: [Restaurant].self) ?? []
        archivedItineraries = PersistenceManager.load(forKey: "archivedItineraries", as: [Itinerary].self) ?? []
        recentlyDeleted = PersistenceManager.load(forKey: "recentlyDeleted", as: [Itinerary].self) ?? []
    }
}

private struct PersistItineraries: ViewModifier {
    @Binding var itineraries: [Itinerary]
    @Binding var archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]

    func body(content: Content) -> some View {
        content
            .onChange(of: itineraries) { _, val in PersistenceManager.save(val, forKey: "itineraries") }
            .onChange(of: archivedItineraries) { _, val in PersistenceManager.save(val, forKey: "archivedItineraries") }
            .onChange(of: recentlyDeleted) { _, val in PersistenceManager.save(val, forKey: "recentlyDeleted") }
    }
}

private struct PersistFavourites: ViewModifier {
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]

    func body(content: Content) -> some View {
        content
            .onChange(of: favouriteIDs) { _, val in PersistenceManager.save(val, forKey: "favouriteIDs") }
            .onChange(of: favouriteRestaurantIDs) { _, val in PersistenceManager.save(val, forKey: "favouriteRestaurantIDs") }
            .onChange(of: exploreFavouriteRestaurants) { _, val in PersistenceManager.save(val, forKey: "exploreFavouriteRestaurants") }
    }
}
