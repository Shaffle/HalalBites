import SwiftUI
import MapKit
import CoreLocation
import WebKit

// MARK: - Mosque Model

struct MosqueLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String

    static func == (lhs: MosqueLocation, rhs: MosqueLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Food Type Filter

enum FoodType: String, CaseIterable, Identifiable {
    case burgers = "Burgers"
    case pizza = "Pizza"
    case kebabs = "Kebabs"
    case biryani = "Biryani"
    case shawarma = "Shawarma"
    case chicken = "Chicken"
    case seafood = "Seafood"
    case desserts = "Desserts"
    case coffee = "Coffee"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .burgers: return "🍔"
        case .pizza: return "🍕"
        case .kebabs: return "🍢"
        case .biryani: return "🍚"
        case .shawarma: return "🌯"
        case .chicken: return "🍗"
        case .seafood: return "🐟"
        case .desserts: return "🍰"
        case .coffee: return "☕"
        }
    }

    var keywords: [String] {
        switch self {
        case .burgers: return ["burger", "burgers", "smash", "american", "fast food", "diner"]
        case .pizza: return ["pizza", "pizzeria", "italian"]
        case .kebabs: return ["kebab", "kabob", "kabab", "grill", "turkish", "persian", "iranian"]
        case .biryani: return ["biryani", "biriyani", "pakistani", "indian", "south asian", "bangladeshi", "desi"]
        case .shawarma: return ["shawarma", "gyro", "doner", "wrap", "middle eastern", "arab", "lebanese", "mediterranean"]
        case .chicken: return ["chicken", "wings", "fried chicken", "poultry", "nashville"]
        case .seafood: return ["seafood", "fish", "shrimp", "sushi"]
        case .desserts: return ["dessert", "bakery", "sweets", "pastry", "cake", "ice cream", "donut", "chocolate"]
        case .coffee: return ["coffee", "cafe", "café", "tea", "espresso", "latte"]
        }
    }

    func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}

// MARK: - Activity & Landmark Types

enum ActivityType: String, CaseIterable, Identifiable {
    case parks = "Parks"
    case museums = "Museums"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case sports = "Sports & Fitness"
    case nightlife = "Nightlife"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .parks: return "🌳"
        case .museums: return "🏛️"
        case .shopping: return "🛍️"
        case .entertainment: return "🎭"
        case .sports: return "⚽"
        case .nightlife: return "🌙"
        }
    }

    var searchQueries: [String] {
        switch self {
        case .parks: return ["park", "garden", "trail", "nature"]
        case .museums: return ["museum"]
        case .shopping: return ["shopping", "mall", "outlet"]
        case .entertainment: return ["movie theater", "bowling", "arcade", "amusement", "fun center", "attraction"]
        case .sports: return ["sports recreation", "gym", "fitness", "stadium"]
        case .nightlife: return ["nightlife"]
        }
    }

    var searchQuery: String { searchQueries[0] }

    var poiCategories: [MKPointOfInterestCategory] {
        switch self {
        case .parks: return [.park, .nationalPark, .beach, .campground, .hiking]
        case .museums: return [.museum]
        case .shopping: return [.store]
        case .entertainment: return [.theater, .movieTheater, .amusementPark, .musicVenue, .aquarium, .zoo]
        case .sports: return [.stadium, .golf, .fitnessCenter, .baseball, .basketball, .soccer, .tennis]
        case .nightlife: return [.nightlife]
        }
    }
}

enum LandmarkType: String, CaseIterable, Identifiable {
    case historical = "Historical"
    case scenic = "Scenic Views"
    case monuments = "Monuments"
    case architecture = "Architecture"
    case culturalCenters = "Cultural Centers"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .historical: return "🏰"
        case .scenic: return "📷"
        case .monuments: return "🗽"
        case .architecture: return "🕌"
        case .culturalCenters: return "🎪"
        }
    }

    var searchQuery: String {
        switch self {
        case .historical: return "historical landmark"
        case .scenic: return "scenic viewpoint"
        case .monuments: return "monument"
        case .architecture: return "famous landmark"
        case .culturalCenters: return "cultural center arts"
        }
    }

    var poiCategories: [MKPointOfInterestCategory] {
        switch self {
        case .historical: return [.landmark, .castle, .fortress, .nationalMonument, .museum]
        case .scenic: return [.park, .nationalPark, .beach, .landmark]
        case .monuments: return [.nationalMonument, .landmark, .fortress]
        case .architecture: return [.landmark, .castle, .fortress, .museum]
        case .culturalCenters: return [.museum, .theater, .musicVenue, .conventionCenter]
        }
    }
}

enum ExploreFilterCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case thingsToDo = "Things to Do"
    case mosques = "Mosques"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .thingsToDo: return "sparkles"
        case .mosques: return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .teal
        case .thingsToDo: return .purple
        case .mosques: return .green
        }
    }
}

// MARK: - Explore Place Model

struct ExplorePlace: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let icon: String
    let placeType: PlaceType

    enum PlaceType: String, Hashable {
        case activity, landmark
    }

    static func == (lhs: ExplorePlace, rhs: ExplorePlace) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Explore Map

struct ExploreMapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var location: LocationService
    @Binding var itineraries: [Itinerary]
    @Binding var showSideMenu: Bool
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]

    @State private var restaurants: [ZabihahRestaurant] = []
    @State private var mosques: [MosqueLocation] = []
    @State private var selectedID: String?
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    ))
    @State private var showLocationDeniedBanner = false
    @State private var manualCity = ""
    @State private var showManualSearch = false
    @State private var searchText = ""
    @State private var searchExpanded = false
    @State private var selectedFoodTypes: Set<FoodType> = []
    @State private var showFilters = false
    @State private var expandedCategory: ExploreFilterCategory?
    @State private var selectedMosque: MosqueLocation?
    @State private var allExplorePlaces: [ExplorePlace] = []
    @State private var selectedExplorePlaces: [ExplorePlace] = []
    @State private var selectedPlace: ExplorePlace?
    @State private var selectedActivityTypes: Set<ActivityType> = []
    @State private var selectedLandmarkTypes: Set<LandmarkType> = []
    @State private var loadingExploreCategoryKeys: Set<String> = []
    @State private var showMosques = true
    @State private var hasInitiallyLoaded = false
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413)
    @State private var exploreLoadGeneration = UUID()

    private var selectedRestaurant: ZabihahRestaurant? {
        restaurants.first { $0.id == selectedID }
    }

    private var explorePlaces: [ExplorePlace] {
        selectedExplorePlaces
    }

    private var locationDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    private var hasPlaceFilters: Bool {
        !selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty
    }

    private var filteredRestaurants: [ZabihahRestaurant] {
        if hasPlaceFilters && selectedFoodTypes.isEmpty {
            return []
        }

        var results = restaurants.filter { !$0.isExcludedChain }
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.cuisineType.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !selectedFoodTypes.isEmpty {
            results = results.filter { restaurant in
                selectedFoodTypes.contains { $0.matches(restaurant.cuisineType) || $0.matches(restaurant.name) }
            }
        }
        return results
    }

    var body: some View {
        ZStack {
            Map(position: $position, selection: $selectedID) {
                UserAnnotation()
                ForEach(filteredRestaurants) { restaurant in
                    Annotation(restaurant.name, coordinate: restaurant.coordinate, anchor: .bottom) {
                        if restaurant.isDessertShop {
                            DessertMapPin()
                        } else if restaurant.isCafe {
                            CafeMapPin()
                        } else if restaurant.isRestaurant {
                            HalalMapPin()
                        } else {
                            GroceryMapPin()
                        }
                    }
                    .tag(restaurant.id)
                }
                if showMosques {
                    ForEach(mosques) { mosque in
                        Annotation(mosque.name, coordinate: mosque.coordinate, anchor: .bottom) {
                            MosqueMapPin()
                                .onTapGesture { selectedMosque = mosque }
                        }
                    }
                }
                ForEach(explorePlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        ExplorePlaceMapPin(icon: place.icon, placeType: place.placeType)
                            .onTapGesture { selectedPlace = place }
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))

            VStack(spacing: 0) {
                mapHeader

                if locationDenied {
                    locationDeniedBanner
                }

                Spacer()
            }
        }
        .onAppear {
            if !hasInitiallyLoaded, let loc = location.currentLocation {
                hasInitiallyLoaded = true
                centreAndLoad(coordinate: loc.coordinate)
            }
        }
        .onChange(of: location.currentLocation) { _, newLocation in
            guard !hasInitiallyLoaded, let loc = newLocation else { return }
            hasInitiallyLoaded = true
            centreAndLoad(coordinate: loc.coordinate)
        }
        .onChange(of: location.authorizationStatus) { _, status in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if !hasInitiallyLoaded, let loc = location.currentLocation {
                    hasInitiallyLoaded = true
                    centreAndLoad(coordinate: loc.coordinate)
                }
            case .denied, .restricted:
                showLocationDeniedBanner = true
            default:
                break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && restaurants.isEmpty, let loc = location.currentLocation {
                centreAndLoad(coordinate: loc.coordinate)
            }
        }
        .task {
            if restaurants.isEmpty && !hasInitiallyLoaded {
                for _ in 0..<10 {
                    if location.currentLocation != nil { break }
                    try? await Task.sleep(for: .milliseconds(300))
                }
                guard !hasInitiallyLoaded else { return }
                if let loc = location.currentLocation {
                    hasInitiallyLoaded = true
                    centreAndLoad(coordinate: loc.coordinate)
                } else {
                    await loadNearby(coordinate: mapCenter)
                    await searchMosques(near: mapCenter)
                }
            }
        }
        .sheet(isPresented: $showManualSearch) {
            manualCitySheet
        }
        .sheet(item: Binding(
            get: { selectedRestaurant },
            set: { _ in selectedID = nil }
        )) { restaurant in
            ZabihahRestaurantSheet(restaurant: restaurant, itineraries: $itineraries, favouriteRestaurantIDs: $favouriteRestaurantIDs, exploreFavouriteRestaurants: $exploreFavouriteRestaurants)
                .presentationDetents([.large])
        }
        .sheet(item: $selectedMosque) { mosque in
            MosqueDetailSheet(mosque: mosque)
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedPlace) { place in
            ExplorePlaceSheet(place: place)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Search Bar

    private var mapHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSideMenu = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.fg1)
                        .frame(width: 40, height: 40)
                        .background(Theme.mapPaper, in: RoundedRectangle(cornerRadius: Theme.rSm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rSm)
                                .stroke(Theme.stroke1, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                searchBar

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        position = .userLocation(fallback: .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        ))
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.pinCertified)
                        .frame(width: 40, height: 40)
                        .background(Theme.mapPaper, in: RoundedRectangle(cornerRadius: Theme.rSm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rSm)
                                .stroke(Theme.stroke1, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.s4)
            .padding(.top, Theme.s3)
            .padding(.bottom, Theme.s2)

            exploreFilters
        }
        .background {
            Theme.bg
                .opacity(0.96)
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.28)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            if searchExpanded {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.fg2)
                TextField("Search cities, places, restaurants…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Theme.fg1)
                    .submitLabel(.search)
                    .onSubmit {
                        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !query.isEmpty else { return }
                        Task { await performSearch(query: query) }
                    }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        searchText = ""
                        searchExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.fg3)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        searchExpanded = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.fg2)
                        Text("Search map")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Theme.fg2)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 14)
        .background(Theme.mapPaper, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke1, lineWidth: 1))
    }

    // MARK: - Explore Filters

    private var activeFilterLabel: String {
        let count = selectedFoodTypes.count + selectedActivityTypes.count + selectedLandmarkTypes.count + (showMosques ? 0 : 1)
        if count > 1 { return "\(count) Filters" }
        if let food = selectedFoodTypes.first { return food.rawValue }
        if let activity = selectedActivityTypes.first { return activity.rawValue }
        if let landmark = selectedLandmarkTypes.first { return landmark.rawValue }
        if !showMosques { return "Mosques Hidden" }
        return "Filters"
    }

    private var hasActiveFilter: Bool {
        !selectedFoodTypes.isEmpty || !selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty || !showMosques
    }

    private func clearAllFilters() {
        selectedFoodTypes.removeAll()
        selectedActivityTypes.removeAll()
        selectedLandmarkTypes.removeAll()
        selectedExplorePlaces.removeAll()
        showMosques = true
    }

    private var exploreFilters: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilters.toggle()
                        if !showFilters { expandedCategory = nil }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(activeFilterLabel)
                            .font(.system(size: 12.5, weight: .semibold))
                        Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(hasActiveFilter ? .white : Theme.fg1)
                    .background(hasActiveFilter ? Theme.fg1 : .white, in: Capsule())
                    .overlay(
                        Capsule().stroke(hasActiveFilter ? .clear : Theme.stroke1, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if hasActiveFilter {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            clearAllFilters()
                        }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                            .foregroundStyle(Theme.fg2)
                            .overlay(Capsule().stroke(Theme.stroke1, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.s4)
            .padding(.bottom, Theme.s2)

            if showFilters {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ExploreFilterCategory.allCases) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if category == .mosques {
                                            showMosques.toggle()
                                        } else {
                                            expandedCategory = expandedCategory == category ? nil : category
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: category.icon)
                                            .font(.caption2)
                                        Text(category.rawValue)
                                            .font(.caption.bold())
                                        if category != .mosques {
                                            Image(systemName: expandedCategory == category ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 8))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(categoryChipBackground(category))
                                    .foregroundStyle(categoryChipForeground(category))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(categoryChipStroke(category), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.s4)
                        .padding(.bottom, Theme.s2)
                    }

                    if let expanded = expandedCategory {
                        subcategoryChips(for: expanded)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func categoryChipBackground(_ category: ExploreFilterCategory) -> Color {
        isCategoryActive(category) ? Theme.fg1 : .white
    }

    private func categoryChipForeground(_ category: ExploreFilterCategory) -> Color {
        isCategoryActive(category) ? .white : Theme.fg1
    }

    private func categoryChipStroke(_ category: ExploreFilterCategory) -> Color {
        isCategoryActive(category) ? .clear : Theme.stroke1
    }

    private func isCategoryActive(_ category: ExploreFilterCategory) -> Bool {
        switch category {
        case .food: return !selectedFoodTypes.isEmpty
        case .thingsToDo: return !selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty
        case .mosques: return showMosques
        }
    }

    @ViewBuilder
    private func subcategoryChips(for category: ExploreFilterCategory) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                switch category {
                case .food:
                    ForEach(FoodType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedFoodTypes.contains(type) {
                                    selectedFoodTypes.remove(type)
                                } else {
                                    selectedFoodTypes.insert(type)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(type.icon)
                                    .font(.caption2)
                                Text(type.rawValue)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFoodTypes.contains(type) ? Theme.fg1 : .white)
                            .foregroundStyle(selectedFoodTypes.contains(type) ? .white : Theme.fg1)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(selectedFoodTypes.contains(type) ? .clear : Theme.stroke1, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                case .thingsToDo:
                    ForEach(ActivityType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedActivityTypes.contains(type) {
                                    selectedActivityTypes.remove(type)
                                    removeExplorePlaces(for: type)
                                } else {
                                    selectedActivityTypes.insert(type)
                                    let generation = exploreLoadGeneration
                                    Task {
                                        await loadExplorePlaces(for: type, generation: generation)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(type.icon)
                                    .font(.caption2)
                                Text(type.rawValue)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedActivityTypes.contains(type) ? Theme.fg1 : .white)
                            .foregroundStyle(selectedActivityTypes.contains(type) ? .white : Theme.fg1)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(selectedActivityTypes.contains(type) ? .clear : Theme.stroke1, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(LandmarkType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedLandmarkTypes.contains(type) {
                                    selectedLandmarkTypes.remove(type)
                                    removeExplorePlaces(for: type)
                                } else {
                                    selectedLandmarkTypes.insert(type)
                                    let generation = exploreLoadGeneration
                                    Task {
                                        await loadExplorePlaces(for: type, generation: generation)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(type.icon)
                                    .font(.caption2)
                                Text(type.rawValue)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedLandmarkTypes.contains(type) ? Theme.fg1 : .white)
                            .foregroundStyle(selectedLandmarkTypes.contains(type) ? .white : Theme.fg1)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(selectedLandmarkTypes.contains(type) ? .clear : Theme.stroke1, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                case .mosques:
                    EmptyView()
                }
            }
            .padding(.horizontal, Theme.s4)
            .padding(.bottom, Theme.s3)
        }
    }

    // MARK: - Location Denied Banner

    private var locationDeniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(Theme.warning)
            Text("Location access denied.")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.fg1)
            Spacer()
            Button("Search by city") {
                showManualSearch = true
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.pinCertified)
        }
        .padding(12)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.rSm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rSm)
                .stroke(Theme.stroke1, lineWidth: 1)
        )
        .padding(.horizontal, Theme.s4)
        .padding(.top, Theme.s3)
    }

    // MARK: - Manual City Search Sheet

    private var manualCitySheet: some View {
        NavigationStack {
            Form {
                Section("Enter a city to find halal restaurants") {
                    TextField("e.g. Chandler AZ", text: $manualCity)
                }
            }
            .navigationTitle("Search by City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        showManualSearch = false
                        Task { await loadByCity(manualCity) }
                    }
                    .disabled(manualCity.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualSearch = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func centreAndLoad(coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
        allExplorePlaces.removeAll()
        selectedExplorePlaces.removeAll()
        loadingExploreCategoryKeys.removeAll()
        exploreLoadGeneration = UUID()
        let generation = exploreLoadGeneration
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        Task {
            async let nearby: () = loadNearby(coordinate: coordinate)
            async let mosques: () = searchMosques(near: coordinate)
            _ = await (nearby, mosques)
            await loadSelectedExplorePlaces(generation: generation)
        }
    }

    private func loadExplorePlaces(for activity: ActivityType, generation: UUID) async {
        let category = activity.searchQuery.capitalized
        let key = exploreCategoryKey(type: .activity, category: category)

        let alreadyCached = await MainActor.run { () -> Bool in
            guard exploreLoadGeneration == generation, selectedActivityTypes.contains(activity) else {
                return true
            }
            let existing = allExplorePlaces.filter {
                exploreCategoryKey(type: $0.placeType, category: $0.category) == key
            }
            if !existing.isEmpty {
                mergeSelectedExplorePlaces(existing)
                return true
            }
            if loadingExploreCategoryKeys.contains(key) { return true }
            loadingExploreCategoryKeys.insert(key)
            return false
        }
        guard !alreadyCached else { return }

        var allResults: [ExplorePlace] = []
        for query in activity.searchQueries {
            let results = await fetchPlaces(
                type: .activity,
                query: query,
                icon: activity.icon,
                poiCategories: activity.poiCategories
            )
            allResults.append(contentsOf: results)
        }
        var seen: Set<String> = []
        let deduped = allResults.filter { place in
            let k = place.name.lowercased()
            guard !seen.contains(k) else { return false }
            seen.insert(k)
            return true
        }
        let tagged = deduped.map { place in
            ExplorePlace(
                name: place.name,
                address: place.address,
                coordinate: place.coordinate,
                category: category,
                icon: place.icon,
                placeType: place.placeType
            )
        }
        await MainActor.run {
            guard exploreLoadGeneration == generation, selectedActivityTypes.contains(activity) else {
                loadingExploreCategoryKeys.remove(key)
                return
            }
            mergeExplorePlaces(tagged)
            mergeSelectedExplorePlaces(tagged)
            loadingExploreCategoryKeys.remove(key)
        }
    }

    private func loadExplorePlaces(for landmark: LandmarkType, generation: UUID) async {
        await loadExplorePlaces(
            type: .landmark,
            query: landmark.searchQuery,
            icon: landmark.icon,
            poiCategories: landmark.poiCategories,
            generation: generation,
            isStillSelected: { selectedLandmarkTypes.contains(landmark) }
        )
    }

    private func loadExplorePlaces(
        type: ExplorePlace.PlaceType,
        query: String,
        icon: String,
        poiCategories: [MKPointOfInterestCategory] = [],
        generation: UUID,
        isStillSelected: @escaping () -> Bool
    ) async {
        let category = query.capitalized
        let key = exploreCategoryKey(type: type, category: category)
        let alreadyLoaded = await MainActor.run { () -> Bool in
            guard exploreLoadGeneration == generation, isStillSelected() else {
                return true
            }
            let existingPlaces = allExplorePlaces.filter {
                exploreCategoryKey(type: $0.placeType, category: $0.category) == key
            }
            if !existingPlaces.isEmpty {
                mergeSelectedExplorePlaces(existingPlaces)
                return true
            }
            if loadingExploreCategoryKeys.contains(key) {
                return true
            }
            loadingExploreCategoryKeys.insert(key)
            return false
        }
        guard !alreadyLoaded else { return }

        let places = await fetchPlaces(
            type: type,
            query: query,
            icon: icon,
            poiCategories: poiCategories
        )
        await MainActor.run {
            guard exploreLoadGeneration == generation, isStillSelected() else {
                loadingExploreCategoryKeys.remove(key)
                return
            }
            mergeExplorePlaces(places)
            mergeSelectedExplorePlaces(places)
            loadingExploreCategoryKeys.remove(key)
        }
    }

    private func loadSelectedExplorePlaces(generation: UUID) async {
        for activity in selectedActivityTypes {
            await loadExplorePlaces(for: activity, generation: generation)
        }
        for landmark in selectedLandmarkTypes {
            await loadExplorePlaces(for: landmark, generation: generation)
        }
    }

    private func removeExplorePlaces(for activity: ActivityType) {
        removeExplorePlaces(type: .activity, category: activity.searchQuery.capitalized)
    }

    private func removeExplorePlaces(for landmark: LandmarkType) {
        removeExplorePlaces(type: .landmark, category: landmark.searchQuery.capitalized)
    }

    private func removeExplorePlaces(type: ExplorePlace.PlaceType, category: String) {
        let key = exploreCategoryKey(type: type, category: category)
        selectedExplorePlaces.removeAll {
            exploreCategoryKey(type: $0.placeType, category: $0.category) == key
        }
    }

    private func loadNearby(coordinate: CLLocationCoordinate2D) async {
        let seedResults = await ZabihahService.searchAppleMaps(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            queries: [
                "halal restaurant",
                "halal food",
                "halal grocery",
                "halal meat",
                "middle eastern restaurant",
                "mediterranean restaurant",
                "ice cream",
                "dessert",
                "cafe"
            ]
        )
        if !seedResults.isEmpty {
            await MainActor.run { restaurants = seedResults }
        }

        let results = await ZabihahService.shared.fetchCombined(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        await MainActor.run { restaurants = results }
    }

    private func loadByCity(_ cityString: String) async {
        guard let coordinate = try? await CLGeocoder()
            .geocodeAddressString(cityString)
            .first?.location?.coordinate else { return }
        await MainActor.run {
            centreAndLoad(coordinate: coordinate)
        }
    }

    private func performSearch(query: String) async {
        await MainActor.run { searchText = "" }

        if let placemarks = try? await CLGeocoder().geocodeAddressString(query),
           let placemark = placemarks.first,
           let coordinate = placemark.location?.coordinate {
            let isCity = placemark.locality != nil || placemark.administrativeArea != nil
            await MainActor.run {
                centreAndLoad(coordinate: coordinate)
            }
            if !isCity {
                return
            }
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )

        guard let response = try? await MKLocalSearch(request: request).start(),
              let firstItem = response.mapItems.first else { return }

        let coord = firstItem.placemark.coordinate
        await MainActor.run {
            centreAndLoad(coordinate: coord)
        }
    }

    private func searchMosques(near coordinate: CLLocationCoordinate2D) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "mosque"
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        let results = response.mapItems.map { item in
            MosqueLocation(
                name: item.name ?? "Mosque",
                coordinate: item.placemark.coordinate,
                address: [item.placemark.thoroughfare, item.placemark.locality]
                    .compactMap { $0 }.joined(separator: ", ")
            )
        }
        await MainActor.run { mosques = results }
    }

    private func mergeExplorePlaces(_ places: [ExplorePlace]) {
        var merged = allExplorePlaces
        var seen = Set(merged.map { explorePlaceKey($0) })
        for place in places {
            let key = explorePlaceKey(place)
            if !seen.contains(key) {
                seen.insert(key)
                merged.append(place)
            }
        }
        allExplorePlaces = merged
    }

    private func mergeSelectedExplorePlaces(_ places: [ExplorePlace]) {
        var merged = selectedExplorePlaces
        var seen = Set(merged.map { explorePlaceKey($0) })
        for place in places {
            let key = explorePlaceKey(place)
            if !seen.contains(key) {
                seen.insert(key)
                merged.append(place)
            }
        }
        selectedExplorePlaces = merged
    }

    private func explorePlaceKey(_ place: ExplorePlace) -> String {
        "\(place.placeType.rawValue)-\(place.category)-\(place.name)".lowercased()
    }

    private func exploreCategoryKey(type: ExplorePlace.PlaceType, category: String) -> String {
        "\(type.rawValue)-\(category)".lowercased()
    }

    private func fetchPlaces(type: ExplorePlace.PlaceType, query: String, icon: String, poiCategories: [MKPointOfInterestCategory] = []) async -> [ExplorePlace] {
        let region = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
        let expandedRegion = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )

        var items = await searchMapItems(query: query, region: region, poiCategories: poiCategories)
        if items.isEmpty {
            items = await searchMapItems(query: query, region: expandedRegion, poiCategories: poiCategories)
        }
        if items.isEmpty && !poiCategories.isEmpty {
            items = await searchMapItems(query: query, region: region, poiCategories: [])
        }
        if items.isEmpty && !poiCategories.isEmpty {
            items = await searchMapItems(query: query, region: expandedRegion, poiCategories: [])
        }

        return mapItemsToExplorePlaces(items, type: type, query: query, icon: icon)
    }

    private func searchMapItems(query: String, region: MKCoordinateRegion, poiCategories: [MKPointOfInterestCategory]) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        if !poiCategories.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: poiCategories)
        }

        return (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
    }

    private func mapItemsToExplorePlaces(_ items: [MKMapItem], type: ExplorePlace.PlaceType, query: String, icon: String) -> [ExplorePlace] {
        items.compactMap { item -> ExplorePlace? in
            guard let name = item.name else { return nil }
            let address = [
                item.placemark.subThoroughfare,
                item.placemark.thoroughfare,
                item.placemark.locality
            ].compactMap { $0 }.joined(separator: " ")

            return ExplorePlace(
                name: name,
                address: address.isEmpty ? "Nearby" : address,
                coordinate: item.placemark.coordinate,
                category: query.capitalized,
                icon: icon,
                placeType: type
            )
        }
    }

}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.teal : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Halal Map Pin

struct HalalMapPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.teal)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: "fork.knife")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color.teal)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

// MARK: - Cafe Map Pin

struct CafeMapPin: View {
    private let pinColor = Color.brown.opacity(0.7)

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

// MARK: - Dessert Map Pin

struct DessertMapPin: View {
    private let pinColor = Color.pink.opacity(0.8)

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

// MARK: - Grocery Map Pin

struct GroceryMapPin: View {
    private let pinColor = Color.orange.opacity(0.65)

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "cart.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

// MARK: - Mosque Map Pin

struct MosqueMapPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: "moon.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color.green)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

// MARK: - Activity Map Pin

struct ExplorePlaceMapPin: View {
    let icon: String
    let placeType: ExplorePlace.PlaceType

    private var pinColor: Color {
        switch placeType {
        case .activity: return Theme.pinCultural
        case .landmark: return Theme.info
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Text(icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 7)
                .offset(y: 7)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Restaurant Detail Sheet

struct ZabihahRestaurantSheet: View {
    let restaurant: ZabihahRestaurant
    @Binding var itineraries: [Itinerary]
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]

    @EnvironmentObject var location: LocationService
    @State private var phoneNumber: String?
    @State private var loadingPhone = true
    @State private var menuCategories: [MenuCategory] = []
    @State private var loadingMenu = false
    @State private var showMenuSheet = false
    @State private var menuFallbackURL: URL?
    @State private var showAddSheet = false
    @State private var showSwapSheet = false
    @State private var travel: TravelInfo?
    @State private var photoURLs: [URL] = []
    @State private var loadingPhotos = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                addressRow
                ratingsRow
                if !restaurant.isCafe && !restaurant.isDessertShop && restaurant.isRestaurant {
                    halalBadge
                }

                if let travel {
                    travelSection(travel)
                }

                Divider()

                photosSection

                Divider()

                aboutSection

                Divider()

                actionButtons
            }
            .padding(24)
        }
        .task { await lookUpDetails() }
        .task { await loadTravel() }
        .task { await loadPhotos() }
        .sheet(isPresented: $showMenuSheet) { menuSheet }
        .sheet(isPresented: $showAddSheet) {
            AddToItinerarySheet(restaurant: restaurant, itineraries: $itineraries)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapInItinerarySheet(restaurant: restaurant, itineraries: $itineraries)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.title2.bold())
                Text(restaurant.cuisineType)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if !restaurant.isCafe && !restaurant.isDessertShop && restaurant.isRestaurant {
                    ZabihahBadge(status: restaurant.halalStatus)
                }

                if let status = OpenStatusHelper.status(for: restaurant.businessHours) {
                    Text(status.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(status.color.opacity(0.2))
                        .foregroundStyle(status.color)
                        .clipShape(Capsule())
                } else {
                    Text("Open")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var addressRow: some View {
        Label(restaurant.address, systemImage: "mappin.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var ratingsRow: some View {
        HStack(spacing: 16) {
            if let rating = restaurant.rating, rating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline.bold())
                }
            }

            if restaurant.reviewCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    Text("\(restaurant.reviewCount) reviews")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var halalBadge: some View {
        Label(
            restaurant.certificationLabel,
            systemImage: restaurant.halalStatus == .partiallyHalal ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
        )
        .font(.caption.bold())
        .foregroundStyle(restaurant.halalStatus == .partiallyHalal ? .orange : .green)
    }

    // MARK: - Travel Info

    private func travelSection(_ travel: TravelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("\(travel.walkingTimeMinutes) min")
                            .font(.subheadline.bold())
                        Text(travel.formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading) {
                        Text("\(travel.drivingTimeMinutes) min")
                            .font(.subheadline.bold())
                        Text(travel.formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.headline)

            if loadingPhotos && photoURLs.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading photos…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            } else if photoURLs.isEmpty {
                Label("No photos available", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoURLs, id: \.absoluteString) { url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    photoPlaceholder
                                case .empty:
                                    ProgressView()
                                        .frame(width: 200, height: 150)
                                @unknown default:
                                    photoPlaceholder
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 200, height: 150)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.quaternary)
            }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)

            Text(restaurantSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var restaurantSummary: String {
        var parts: [String] = []
        parts.append(restaurant.cuisineType)
        if !restaurant.isCafe && restaurant.isRestaurant {
            parts.append(restaurant.certificationLabel)
        }
        if let rating = restaurant.rating, rating > 0 {
            parts.append("\(String(format: "%.1f", rating))★")
        }
        if !restaurant.businessHours.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let today = formatter.string(from: Date())
            if let entry = restaurant.businessHours.first(where: { $0.day.caseInsensitiveCompare(today) == .orderedSame }) {
                parts.append("Today: \(entry.hours)")
            }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                let placemark = MKPlacemark(coordinate: restaurant.coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = restaurant.name
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                Label("Directions", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)

            if let phone = phoneNumber {
                Button {
                    let digits = phone.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel:\(digits)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Call \(phone)", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if loadingPhone {
                HStack {
                    ProgressView()
                    Text("Looking up phone number…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            }

            Button {
                showMenuSheet = true
            } label: {
                Label("View Menu", systemImage: "menucard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if !itineraries.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add to Itinerary", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.2))
                        .foregroundStyle(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    showSwapSheet = true
                } label: {
                    Label("Swap in Itinerary", systemImage: "arrow.triangle.swap")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let rid = stableRestaurantID
                    if favouriteRestaurantIDs.contains(rid) {
                        favouriteRestaurantIDs.remove(rid)
                        exploreFavouriteRestaurants.removeAll { $0.id == rid }
                    } else {
                        favouriteRestaurantIDs.insert(rid)
                        if !exploreFavouriteRestaurants.contains(where: { $0.id == rid }) {
                            exploreFavouriteRestaurants.append(restaurantFromZabihah)
                        }
                    }
                }
            } label: {
                Label(
                    favouriteRestaurantIDs.contains(stableRestaurantID) ? "Favourited" : "Add to Favourites",
                    systemImage: favouriteRestaurantIDs.contains(stableRestaurantID) ? "heart.fill" : "heart"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
    }

    private var stableRestaurantID: UUID {
        if let uuid = UUID(uuidString: restaurant.id) { return uuid }
        var data = Data(restaurant.id.utf8)
        while data.count < 16 { data.append(0) }
        return UUID(uuid: (
            data[0], data[1], data[2], data[3],
            data[4], data[5], data[6], data[7],
            data[8], data[9], data[10], data[11],
            data[12], data[13], data[14], data[15]
        ))
    }

    private var restaurantFromZabihah: Restaurant {
        Restaurant(
            id: stableRestaurantID,
            name: restaurant.name,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
            halalCertificationLevel: restaurant.halalLevel,
            cuisineType: restaurant.cuisineType,
            rating: restaurant.rating ?? 0,
            reviewCount: restaurant.reviewCount,
            phoneNumber: nil,
            websiteURL: nil,
            halalDescription: restaurant.halalDescription,
            photoURLs: restaurant.photoURLs,
            businessHours: restaurant.businessHours
        )
    }

    // MARK: - Menu Sheet

    private var menuSheet: some View {
        NavigationStack {
            Group {
                if loadingMenu {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding menu…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !menuCategories.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(menuCategories) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.category)
                                        .font(.title3.bold())
                                        .padding(.horizontal, 20)

                                    ForEach(category.items) { item in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(alignment: .top) {
                                                Text(item.name)
                                                    .font(.subheadline.bold())
                                                Spacer()
                                                if !item.price.isEmpty {
                                                    Text(item.price)
                                                        .font(.subheadline.bold())
                                                        .foregroundStyle(.teal)
                                                }
                                            }
                                            if !item.description.isEmpty {
                                                Text(item.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .padding(.horizontal, 16)
                                    }
                                }

                                if category.id != menuCategories.last?.id {
                                    Divider()
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                } else if let fallbackURL = menuFallbackURL {
                    ExploreMenuWebView(url: fallbackURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    let query = "\(restaurant.name) \(restaurant.address) menu"
                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    ExploreMenuWebView(url: URL(string: "https://www.google.com/search?q=\(query)")!)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showMenuSheet = false }
                }
            }
        }
        .task {
            guard menuCategories.isEmpty else { return }
            loadingMenu = true
            menuCategories = await ScrapingService.shared.fetchMenu(
                name: restaurant.name,
                address: restaurant.address,
                latitude: restaurant.latitude,
                longitude: restaurant.longitude
            )
            if menuCategories.isEmpty {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = restaurant.name
                request.region = MKCoordinateRegion(
                    center: restaurant.coordinate,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                )
                if let response = try? await MKLocalSearch(request: request).start(),
                   let website = response.mapItems.first?.url {
                    menuFallbackURL = website
                }
            }
            loadingMenu = false
        }
    }

    // MARK: - Helpers

    private func lookUpDetails() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = restaurant.name
        request.region = MKCoordinateRegion(
            center: restaurant.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        let search = MKLocalSearch(request: request)
        let response = try? await search.start()
        let item = response?.mapItems.first

        await MainActor.run {
            phoneNumber = item?.phoneNumber
            loadingPhone = false
        }
    }

    private func loadPhotos() async {
        if !restaurant.photoURLs.isEmpty {
            await MainActor.run { photoURLs = restaurant.photoURLs }
            return
        }
        await MainActor.run { loadingPhotos = true }
        let urls = await YelpService.shared.fetchPhotoURLs(
            name: restaurant.name,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        await MainActor.run {
            photoURLs = urls
            loadingPhotos = false
        }
    }

    private func loadTravel() async {
        guard let userLoc = location.currentLocation else { return }
        travel = await TravelCalculator.calculate(
            from: userLoc.coordinate,
            to: restaurant.coordinate
        )
    }
}

struct ZabihahBadge: View {
    let status: ZabihahHalalStatus

    private var label: String {
        switch status {
        case .zabiha: return "Halal \u{2713}"
        case .fullyHalal: return "Halal \u{2713}"
        case .partiallyHalal: return "Partially Halal \u{26A0}"
        }
    }

    private var badgeColor: Color {
        status == .partiallyHalal ? .orange : .teal
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
}

// MARK: - Mosque Detail Sheet

struct MosqueDetailSheet: View {
    let mosque: MosqueLocation

    @EnvironmentObject var location: LocationService
    @State private var travel: TravelInfo?
    @State private var phoneNumber: String?
    @State private var loadingDetails = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mosque.name)
                            .font(.title2.bold())
                        Text("Mosque")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "moon.fill")
                        .font(.title3)
                        .padding(10)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Circle())
                }

                if !mosque.address.isEmpty {
                    Label(mosque.address, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let travel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text("\(travel.walkingTimeMinutes) min")
                                        .font(.subheadline.bold())
                                    Text(travel.formattedDistance)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.teal)
                                VStack(alignment: .leading) {
                                    Text("\(travel.drivingTimeMinutes) min")
                                        .font(.subheadline.bold())
                                    Text(travel.formattedDistance)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Divider()

                VStack(spacing: 10) {
                    Button {
                        let placemark = MKPlacemark(coordinate: mosque.coordinate)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = mosque.name
                        mapItem.openInMaps(launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                        ])
                    } label: {
                        Label("Directions", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    if let phone = phoneNumber {
                        Button {
                            let digits = phone.filter { $0.isNumber || $0 == "+" }
                            if let url = URL(string: "tel:\(digits)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Call \(phone)", systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    } else if loadingDetails {
                        HStack {
                            ProgressView()
                            Text("Looking up details…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 6)
                        }
                    }
                }
            }
            .padding(24)
        }
        .task { await lookUpDetails() }
        .task { await loadTravel() }
    }

    private func lookUpDetails() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = mosque.name
        request.region = MKCoordinateRegion(
            center: mosque.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        let item = (try? await MKLocalSearch(request: request).start())?.mapItems.first
        await MainActor.run {
            phoneNumber = item?.phoneNumber
            loadingDetails = false
        }
    }

    private func loadTravel() async {
        guard let userLoc = location.currentLocation else { return }
        travel = await TravelCalculator.calculate(
            from: userLoc.coordinate,
            to: mosque.coordinate
        )
    }
}

// MARK: - Explore Menu Web View

struct ExploreMenuWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.scrollView.bounces = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Add to Itinerary Sheet

struct AddToItinerarySheet: View {
    let restaurant: ZabihahRestaurant
    @Binding var itineraries: [Itinerary]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItineraryID: UUID?
    @State private var selectedDayIndex = 0
    @State private var selectedMealType: MealType = .lunch

    private var selectedItinerary: Itinerary? {
        itineraries.first { $0.id == selectedItineraryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    Picker("Itinerary", selection: $selectedItineraryID) {
                        Text("Select a trip").tag(nil as UUID?)
                        ForEach(itineraries) { it in
                            Text("\(it.city), \(it.country)")
                                .tag(it.id as UUID?)
                        }
                    }
                }

                if let itinerary = selectedItinerary {
                    Section("Day") {
                        Picker("Day", selection: $selectedDayIndex) {
                            ForEach(Array(itinerary.days.enumerated()), id: \.offset) { idx, day in
                                Text("Day \(day.dayNumber)").tag(idx)
                            }
                        }
                    }
                }

                Section("Meal") {
                    Picker("Meal Type", selection: $selectedMealType) {
                        Text("Breakfast").tag(MealType.breakfast)
                        Text("Lunch").tag(MealType.lunch)
                        Text("Dinner").tag(MealType.dinner)
                        Text("Snack").tag(MealType.snack)
                    }
                }
            }
            .navigationTitle("Add to Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStop()
                        dismiss()
                    }
                    .disabled(selectedItineraryID == nil)
                }
            }
        }
    }

    private func addStop() {
        guard let itID = selectedItineraryID,
              let itIdx = itineraries.firstIndex(where: { $0.id == itID }) else { return }

        let rest = Restaurant(
            id: UUID(),
            name: restaurant.name,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
            halalCertificationLevel: restaurant.halalLevel,
            cuisineType: restaurant.cuisineType,
            rating: restaurant.rating ?? 0,
            reviewCount: restaurant.reviewCount,
            phoneNumber: nil,
            websiteURL: nil,
            halalDescription: restaurant.halalDescription,
            photoURLs: restaurant.photoURLs,
            businessHours: restaurant.businessHours
        )

        let stop = ItineraryStop(
            id: UUID(),
            restaurant: rest,
            mealType: selectedMealType,
            notes: nil
        )

        let dayIdx = min(selectedDayIndex, itineraries[itIdx].days.count - 1)
        itineraries[itIdx].days[dayIdx].stops.append(stop)
    }
}

// MARK: - Swap In Itinerary Sheet

struct SwapInItinerarySheet: View {
    let restaurant: ZabihahRestaurant
    @Binding var itineraries: [Itinerary]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItineraryID: UUID?
    @State private var selectedDayIndex = 0
    @State private var selectedStopID: UUID?

    private var selectedItinerary: Itinerary? {
        itineraries.first { $0.id == selectedItineraryID }
    }

    private var currentDayStops: [ItineraryStop] {
        guard let itinerary = selectedItinerary,
              selectedDayIndex < itinerary.days.count else { return [] }
        return itinerary.days[selectedDayIndex].stops
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    Picker("Itinerary", selection: $selectedItineraryID) {
                        Text("Select a trip").tag(nil as UUID?)
                        ForEach(itineraries) { it in
                            Text("\(it.city), \(it.country)")
                                .tag(it.id as UUID?)
                        }
                    }
                }

                if let itinerary = selectedItinerary {
                    Section("Day") {
                        Picker("Day", selection: $selectedDayIndex) {
                            ForEach(Array(itinerary.days.enumerated()), id: \.offset) { idx, day in
                                Text("Day \(day.dayNumber)").tag(idx)
                            }
                        }
                    }

                    Section("Replace") {
                        if currentDayStops.isEmpty {
                            Text("No stops on this day")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(currentDayStops) { stop in
                                Button {
                                    selectedStopID = stop.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(stop.restaurant.name)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)
                                            Text(stop.mealType.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedStopID == stop.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }

                    if let stopID = selectedStopID,
                       let stop = currentDayStops.first(where: { $0.id == stopID }) {
                        Section {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.restaurant.name)
                                        .font(.caption)
                                        .strikethrough()
                                        .foregroundStyle(.secondary)
                                    Text(restaurant.name)
                                        .font(.caption.bold())
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundStyle(.orange)
                            }
                        } header: {
                            Text("Preview")
                        }
                    }
                }
            }
            .navigationTitle("Swap in Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Swap") {
                        performSwap()
                        dismiss()
                    }
                    .disabled(selectedItineraryID == nil || selectedStopID == nil)
                }
            }
            .onChange(of: selectedItineraryID) { _, _ in
                selectedDayIndex = 0
                selectedStopID = nil
            }
            .onChange(of: selectedDayIndex) { _, _ in
                selectedStopID = nil
            }
        }
    }

    private func performSwap() {
        guard let itID = selectedItineraryID,
              let itIdx = itineraries.firstIndex(where: { $0.id == itID }),
              let stopID = selectedStopID else { return }

        let dayIdx = min(selectedDayIndex, itineraries[itIdx].days.count - 1)
        guard let stopIdx = itineraries[itIdx].days[dayIdx].stops.firstIndex(where: { $0.id == stopID }) else { return }

        let existingStop = itineraries[itIdx].days[dayIdx].stops[stopIdx]

        let rest = Restaurant(
            id: UUID(),
            name: restaurant.name,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
            halalCertificationLevel: restaurant.halalLevel,
            cuisineType: restaurant.cuisineType,
            rating: restaurant.rating ?? 0,
            reviewCount: restaurant.reviewCount,
            phoneNumber: nil,
            websiteURL: nil,
            halalDescription: restaurant.halalDescription,
            photoURLs: restaurant.photoURLs,
            businessHours: restaurant.businessHours
        )

        let newStop = ItineraryStop(
            id: UUID(),
            restaurant: rest,
            mealType: existingStop.mealType,
            notes: existingStop.notes
        )

        itineraries[itIdx].days[dayIdx].stops[stopIdx] = newStop
    }
}

// MARK: - Explore Place Sheet

struct ExplorePlaceSheet: View {
    let place: ExplorePlace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.title2.bold())
                        Text(place.category)
                            .font(.subheadline)
                            .foregroundStyle(place.placeType == .activity ? .purple : .indigo)
                    }
                    Spacer()
                    Image(systemName: place.placeType == .activity ? "figure.walk" : "building.columns.fill")
                        .font(.title2)
                        .foregroundStyle(place.placeType == .activity ? .purple : .indigo)
                }

                Label(place.address, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Button {
                    let placemark = MKPlacemark(coordinate: place.coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = place.name
                    mapItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                } label: {
                    Label("Directions", systemImage: "map.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(place.placeType == .activity ? .purple : .indigo)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
