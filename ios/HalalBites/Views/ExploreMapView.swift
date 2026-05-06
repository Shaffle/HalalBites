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

    var searchQuery: String {
        switch self {
        case .parks: return "park"
        case .museums: return "museum"
        case .shopping: return "shopping"
        case .entertainment: return "entertainment"
        case .sports: return "sports recreation"
        case .nightlife: return "nightlife"
        }
    }

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
    @State private var selectedPlace: ExplorePlace?
    @State private var selectedActivityTypes: Set<ActivityType> = []
    @State private var selectedLandmarkTypes: Set<LandmarkType> = []
    @State private var showMosques = true
    @State private var hasInitiallyLoaded = false
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413)

    private var selectedRestaurant: ZabihahRestaurant? {
        restaurants.first { $0.id == selectedID }
    }

    private var explorePlaces: [ExplorePlace] {
        if selectedActivityTypes.isEmpty && selectedLandmarkTypes.isEmpty {
            return []
        }
        let activeActivityQueries = Set(selectedActivityTypes.map { $0.searchQuery.capitalized })
        let activeLandmarkQueries = Set(selectedLandmarkTypes.map { $0.searchQuery.capitalized })
        return allExplorePlaces.filter { place in
            switch place.placeType {
            case .activity: return activeActivityQueries.contains(place.category)
            case .landmark: return activeLandmarkQueries.contains(place.category)
            }
        }
    }

    private var locationDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    private var filteredRestaurants: [ZabihahRestaurant] {
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
                        if restaurant.isCafe {
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
                        if place.placeType == .activity {
                            ActivityMapPin()
                                .onTapGesture { selectedPlace = place }
                        } else {
                            LandmarkMapPin()
                                .onTapGesture { selectedPlace = place }
                        }
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 12)
                    .padding(.top, 8)
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
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                }
                exploreFilters

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
        .task {
            if restaurants.isEmpty {
                await loadNearby(coordinate: mapCenter)
                await searchMosques(near: mapCenter)
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

    private var searchBar: some View {
        HStack {
            if searchExpanded {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search cities, places, restaurants…", text: $searchText)
                    .textFieldStyle(.plain)
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
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        searchExpanded = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .padding(.top, 8)
    }

    // MARK: - Explore Filters

    private var activeFilterLabel: String {
        let count = selectedFoodTypes.count + selectedActivityTypes.count + selectedLandmarkTypes.count
        if count > 1 { return "\(count) Filters" }
        if let food = selectedFoodTypes.first { return food.rawValue }
        if let activity = selectedActivityTypes.first { return activity.rawValue }
        if let landmark = selectedLandmarkTypes.first { return landmark.rawValue }
        if !showMosques { return "Mosques Hidden" }
        return "Filters"
    }

    private var hasActiveFilter: Bool {
        !selectedFoodTypes.isEmpty || !selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty
    }

    private func clearAllFilters() {
        selectedFoodTypes.removeAll()
        selectedActivityTypes.removeAll()
        selectedLandmarkTypes.removeAll()
        showMosques = true
    }

    private var exploreFilters: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilters.toggle()
                        if !showFilters { expandedCategory = nil }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        Text(activeFilterLabel)
                            .font(.caption.bold())
                        Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                    .foregroundStyle(hasActiveFilter ? .teal : .primary)
                }

                if hasActiveFilter {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            clearAllFilters()
                        }
                    } label: {
                        Text("Clear")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

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
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
        switch category {
        case .food: return !selectedFoodTypes.isEmpty ? category.color : Color(.systemGray5)
        case .thingsToDo: return (!selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty) ? category.color : Color(.systemGray5)
        case .mosques: return showMosques ? category.color : Color(.systemGray5)
        }
    }

    private func categoryChipForeground(_ category: ExploreFilterCategory) -> Color {
        switch category {
        case .food: return !selectedFoodTypes.isEmpty ? .white : .primary
        case .thingsToDo: return (!selectedActivityTypes.isEmpty || !selectedLandmarkTypes.isEmpty) ? .white : .primary
        case .mosques: return showMosques ? .white : .primary
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
                            .background(selectedFoodTypes.contains(type) ? Color.teal : Color(.systemGray6))
                            .foregroundStyle(selectedFoodTypes.contains(type) ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                case .thingsToDo:
                    ForEach(ActivityType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedActivityTypes.contains(type) {
                                    selectedActivityTypes.remove(type)
                                } else {
                                    selectedActivityTypes.insert(type)
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
                            .background(selectedActivityTypes.contains(type) ? Color.purple : Color(.systemGray6))
                            .foregroundStyle(selectedActivityTypes.contains(type) ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                    ForEach(LandmarkType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedLandmarkTypes.contains(type) {
                                    selectedLandmarkTypes.remove(type)
                                } else {
                                    selectedLandmarkTypes.insert(type)
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
                            .background(selectedLandmarkTypes.contains(type) ? Color.indigo : Color(.systemGray6))
                            .foregroundStyle(selectedLandmarkTypes.contains(type) ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                case .mosques:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Location Denied Banner

    private var locationDeniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text("Location access denied.")
                .font(.caption.bold())
            Spacer()
            Button("Search by city") {
                showManualSearch = true
            }
            .font(.caption.bold())
            .foregroundStyle(.teal)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
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
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        Task {
            async let nearby: () = loadNearby(coordinate: coordinate)
            async let mosques: () = searchMosques(near: coordinate)
            async let places: () = loadAllExplorePlaces()
            _ = await (nearby, mosques, places)
        }
    }

    private func loadNearby(coordinate: CLLocationCoordinate2D) async {
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

    private func loadAllExplorePlaces() async {
        async let activityResults = withTaskGroup(of: [ExplorePlace].self) { group -> [ExplorePlace] in
            for activity in ActivityType.allCases {
                group.addTask { await self.fetchPlaces(type: .activity, query: activity.searchQuery, poiCategories: activity.poiCategories) }
            }
            var results: [ExplorePlace] = []
            for await batch in group { results.append(contentsOf: batch) }
            return results
        }
        async let landmarkResults = withTaskGroup(of: [ExplorePlace].self) { group -> [ExplorePlace] in
            for landmark in LandmarkType.allCases {
                group.addTask { await self.fetchPlaces(type: .landmark, query: landmark.searchQuery, poiCategories: landmark.poiCategories) }
            }
            var results: [ExplorePlace] = []
            for await batch in group { results.append(contentsOf: batch) }
            return results
        }

        let activities = await activityResults
        let landmarks = await landmarkResults

        var seen: Set<String> = []
        var deduped: [ExplorePlace] = []
        for place in activities + landmarks {
            let key = place.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                deduped.append(place)
            }
        }
        await MainActor.run { allExplorePlaces = deduped }
    }

    private func fetchPlaces(type: ExplorePlace.PlaceType, query: String, poiCategories: [MKPointOfInterestCategory] = []) async -> [ExplorePlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
        request.resultTypes = .pointOfInterest
        if !poiCategories.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: poiCategories)
        }

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.compactMap { item -> ExplorePlace? in
            guard let name = item.name,
                  item.pointOfInterestCategory != nil else { return nil }
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

struct ActivityMapPin: View {
    private let pinColor = Color.purple.opacity(0.8)

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "figure.walk")
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

// MARK: - Landmark Map Pin

struct LandmarkMapPin: View {
    private let pinColor = Color.indigo.opacity(0.8)

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "building.columns.fill")
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
    @State private var showAddSheet = false
    @State private var showSwapSheet = false
    @State private var travel: TravelInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                addressRow
                ratingsRow
                if !restaurant.isCafe && restaurant.isRestaurant {
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
                if !restaurant.isCafe && restaurant.isRestaurant {
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

            if restaurant.photoURLs.isEmpty {
                Label("No photos available", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(restaurant.photoURLs, id: \.absoluteString) { url in
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
                } else if menuCategories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "menucard")
                            .font(.system(size: 48))
                            .foregroundStyle(.quaternary)
                        Text("Menu not available")
                            .font(.headline)
                        Text("We couldn't find a menu for this restaurant.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
        case .zabiha: return "Zabiha \u{2713}"
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
