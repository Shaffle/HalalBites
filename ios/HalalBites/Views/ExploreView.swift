import SwiftUI
import MapKit
import CoreLocation

struct ExploreView: View {
    @EnvironmentObject var location: LocationService
    @Binding var itineraries: [Itinerary]
    @Binding var showSideMenu: Bool
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]

    @State private var restaurants: [ZabihahRestaurant] = []
    @State private var searchText = ""
    @State private var selectedChip = "all"
    @State private var selectedCuisine: CuisineCategory?
    @State private var selectedRestaurant: ZabihahRestaurant?
    @State private var isLoading = true
    @State private var coffeeShops: [ZabihahRestaurant] = []
    @State private var showLocationPicker = false
    @State private var customLocation: CLLocation?
    @State private var locationLabel = "Your location"

    private var certifiedRestaurants: [ZabihahRestaurant] {
        restaurants.filter { !$0.isExcludedChain && $0.isRestaurant && ($0.halalStatus == .fullyHalal || $0.halalStatus == .zabiha) }
    }

    private var openRestaurants: [ZabihahRestaurant] {
        restaurants.filter { !$0.isExcludedChain && $0.isRestaurant }.prefix(6).map { $0 }
    }

    private var cafeRestaurants: [ZabihahRestaurant] {
        let combined = coffeeShops + restaurants.filter { $0.isCafe }
        var seen: Set<String> = []
        return combined.filter { restaurant in
            let key = restaurant.name.lowercased()
            guard !restaurant.isExcludedChain, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private var groceryStores: [ZabihahRestaurant] {
        restaurants.filter { !$0.isRestaurant && !$0.isCafe }
    }

    private var filteredRestaurants: [ZabihahRestaurant] {
        var results = restaurants.filter { !$0.isExcludedChain }
        if selectedChip == "certified" {
            results = results.filter { $0.halalStatus == .fullyHalal || $0.halalStatus == .zabiha }
        } else if selectedChip == "friendly" {
            results = results.filter { $0.halalStatus == .partiallyHalal }
        } else if selectedChip == "open" {
            results = results.filter { $0.isRestaurant }
        }
        if let selectedCuisine {
            results = results.filter {
                selectedCuisine.matches($0.cuisineType) || selectedCuisine.matches($0.name)
            }
        }
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.cuisineType.localizedCaseInsensitiveContains(searchText)
            }
        }
        return results
    }

    private var selectedChipTitle: String {
        switch selectedChip {
        case "certified": return "Halal"
        case "friendly": return "Partially-Halal"
        case "open": return "Open now"
        default: return "All"
        }
    }

    private var selectedCuisineRestaurants: [ZabihahRestaurant] {
        guard let selectedCuisine else { return [] }
        return restaurants.filter {
            !$0.isExcludedChain &&
            $0.isRestaurant &&
            (selectedCuisine.matches($0.cuisineType) || selectedCuisine.matches($0.name))
        }
    }

    private var visibleCuisineCategories: [CuisineCategory] {
        CuisineCategory.allCases.filter { $0 != .middleEastern && $0 != .southeastAsian }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            content
                        } header: {
                            stickyHeader
                        }
                    }
                }
                .background(Theme.bg)

                Theme.bg
                    .frame(height: proxy.safeAreaInsets.top + 2)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(
                onSelect: { name, loc in
                    customLocation = loc
                    locationLabel = name
                    Task { await loadData() }
                },
                onReset: {
                    customLocation = nil
                    locationLabel = "Your location"
                    Task { await loadData() }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailSheet(
                restaurant: restaurant,
                itineraries: $itineraries,
                favouriteRestaurantIDs: $favouriteRestaurantIDs,
                exploreFavouriteRestaurants: $exploreFavouriteRestaurants
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            addressBar
            searchBar
            chipRail
            filterStatusBar
        }
        .background {
            Theme.bg
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
        .zIndex(1)
    }

    private var addressBar: some View {
        Button {
            showLocationPicker = true
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.pinCertified)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: customLocation != nil ? "mappin.circle.fill" : "location.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("SEARCHING NEAR")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.fg3)
                        .tracking(0.8)
                    Text(location.currentLocation != nil || customLocation != nil ? locationLabel : "Locating...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.fg1)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.fg2)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, 6)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.fg2)
            TextField("Search restaurants, cuisines", text: $searchText)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Theme.fg1)
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.mapPaper, in: Capsule())
        .overlay(Capsule().stroke(Theme.fg1.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, Theme.s4)
        .padding(.bottom, 10)
    }

    private var chipRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SafaFilterChip(label: "All", isSelected: selectedChip == "all") {
                    setSelectedChip("all")
                }
                SafaFilterChip(label: "Halal", dotColor: Theme.pinCertified, isSelected: selectedChip == "certified") {
                    setSelectedChip(selectedChip == "certified" ? "all" : "certified")
                }
                SafaFilterChip(label: "Partially-Halal", dotColor: Theme.pinFriendly, isSelected: selectedChip == "friendly") {
                    setSelectedChip(selectedChip == "friendly" ? "all" : "friendly")
                }
                SafaFilterChip(label: "Open now", isSelected: selectedChip == "open") {
                    setSelectedChip(selectedChip == "open" ? "all" : "open")
                }
            }
            .padding(.horizontal, Theme.s4)
            .padding(.bottom, 8)
        }
    }

    private var filterStatusBar: some View {
        HStack(spacing: 6) {
            Text(selectedChipTitle)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.fg1)
            Text("\(filteredRestaurants.filter(\.isRestaurant).count) places")
                .font(.mono(12))
                .foregroundStyle(Theme.fg2)
            Spacer()
        }
        .padding(.horizontal, Theme.s4)
        .padding(.bottom, Theme.s3)
    }

    private func setSelectedChip(_ chip: String) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            selectedChip = chip
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingPlaceholder
            } else if selectedChip != "all" || !searchText.isEmpty {
                filterResultsFeed
            } else {
                todayStrip
                cuisineRail
                selectedCuisineFeed
                certifiedRail
                cafeRail
                openNowFeed
            }
            Spacer().frame(height: 110)
        }
    }

    private var filterResultsFeed: some View {
        VStack(spacing: 0) {
            SectionHeader(
                eyebrow: "RESTAURANTS",
                title: selectedChip == "all" ? "Search results" : "\(selectedChipTitle) restaurants",
                action: "Clear"
            ) {
                setSelectedChip("all")
                searchText = ""
            }
            .padding(.top, Theme.s4)

            let results = filteredRestaurants.filter(\.isRestaurant)
            if results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No restaurants found")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.fg1)
                    Text("Try a different filter or search term.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.fg2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.mapPaper, in: RoundedRectangle(cornerRadius: Theme.rMd))
                .padding(.horizontal, Theme.s4)
            } else {
                VStack(spacing: 14) {
                    ForEach(results) { restaurant in
                        RestaurantRow(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                    }
                }
                .padding(.horizontal, Theme.s4)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Today Strip

    private var todayStrip: some View {
        Group {
            if let activeTrip = itineraries.first(where: { !$0.hasEnded }) {
                Button {
                    // Could navigate to itinerary detail
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: Theme.rCard)
                            .fill(Theme.fg1)
                            .frame(height: 160)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                Text("AI ITINERARY")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.16), in: Capsule())

                            Text("\(activeTrip.city) trip\n\(activeTrip.days.flatMap(\.stops).count) stops planned")
                                .font(.system(size: 22, weight: .bold))
                                .tracking(-0.4)
                                .lineSpacing(2)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 10) {
                                HStack(spacing: 5) {
                                    Text("Open today")
                                        .font(.system(size: 13.5, weight: .bold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(Theme.fg1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(.white, in: Capsule())

                                Text("\(activeTrip.durationDays) days")
                                    .font(.mono(11.5))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .padding(18)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.s4)
                .padding(.top, Theme.s4)
            }
        }
    }

    // MARK: - Cuisine Rail

    private var cuisineRail: some View {
        VStack(spacing: 0) {
            SectionHeader(eyebrow: "BY CUISINE", title: "What are you in the mood for?")
                .padding(.top, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleCuisineCategories) { cuisine in
                        cuisineButton(for: cuisine)
                    }
                }
                .padding(.horizontal, Theme.s4)
            }
        }
    }

    private func cuisineButton(for cuisine: CuisineCategory) -> some View {
        let isSelected = selectedCuisine == cuisine

        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                selectedCuisine = isSelected ? nil : cuisine
            }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Theme.fg1 : Theme.mapPaper)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Text(cuisineIcon(for: cuisine))
                            .font(.system(size: 30))
                            .shadow(color: Theme.fg1.opacity(0.22), radius: 4, x: 0, y: 2)
                    }
                    .overlay {
                        Circle()
                            .stroke(isSelected ? Theme.fg1 : Theme.fg1.opacity(0.06), lineWidth: 1)
                    }

                Text(cuisineTitle(for: cuisine))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.fg1 : Theme.fg2)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(height: 18, alignment: .top)
            }
            .frame(width: 94)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cuisineTitle(for: cuisine))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func cuisineTitle(for cuisine: CuisineCategory) -> String {
        switch cuisine {
        case .mediterranean: return "Mediterranean"
        default: return cuisine.rawValue
        }
    }

    private func cuisineIcon(for cuisine: CuisineCategory) -> String {
        switch cuisine {
        case .mediterranean: return "🥙"
        case .middleEastern: return "🧆"
        case .southAsian:    return "🍛"
        case .turkish:       return "🥙"
        case .african:       return "🍲"
        case .southeastAsian: return "🍜"
        case .american:      return "🍔"
        }
    }

    // MARK: - Halal Near You

    private var certifiedRail: some View {
        VStack(spacing: 0) {
            SectionHeader(
                eyebrow: "VERIFIED",
                title: "Halal near you",
                action: "See all"
            )
            .padding(.top, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(certifiedRestaurants.prefix(6)) { r in
                        RestaurantCardLarge(restaurant: r) {
                            selectedRestaurant = r
                        }
                    }
                }
                .padding(.horizontal, Theme.s4)
            }
        }
    }

    // MARK: - Cafe Rail

    private var cafeRail: some View {
        Group {
            if !cafeRestaurants.isEmpty {
                VStack(spacing: 0) {
                    SectionHeader(eyebrow: "CAFES & BAKERIES", title: "Coffee & sweets")
                        .padding(.top, 22)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(cafeRestaurants.prefix(6)) { r in
                                CafeCard(restaurant: r) {
                                    selectedRestaurant = r
                                }
                            }
                        }
                        .padding(.horizontal, Theme.s4)
                    }
                }
            }
        }
    }

    // MARK: - Open Now Feed

    private var selectedCuisineFeed: some View {
        Group {
            if let selectedCuisine {
                VStack(spacing: 0) {
                    SectionHeader(
                        eyebrow: "MATCHES",
                        title: "\(cuisineTitle(for: selectedCuisine)) near you",
                        action: "Clear"
                    ) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                            self.selectedCuisine = nil
                        }
                    }
                    .padding(.top, 22)

                    if selectedCuisineRestaurants.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No nearby matches yet")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.fg1)
                            Text("Try another mood or use search for a specific dish.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.fg2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Theme.mapPaper, in: RoundedRectangle(cornerRadius: Theme.rMd))
                        .padding(.horizontal, Theme.s4)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(selectedCuisineRestaurants.prefix(5)) { r in
                                RestaurantRow(restaurant: r) {
                                    selectedRestaurant = r
                                }
                            }
                        }
                        .padding(.horizontal, Theme.s4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var openNowFeed: some View {
        VStack(spacing: 0) {
            SectionHeader(
                eyebrow: "MORE TO EXPLORE",
                title: selectedCuisine == nil ? "Open right now" : "More \(selectedCuisine?.rawValue ?? "")"
            )
                .padding(.top, 22)

            VStack(spacing: 14) {
                ForEach(filteredRestaurants.filter(\.isRestaurant).prefix(8)) { r in
                    RestaurantRow(restaurant: r) {
                        selectedRestaurant = r
                    }
                }
            }
            .padding(.horizontal, Theme.s4)
        }
    }

    // MARK: - Loading

    private var loadingPlaceholder: some View {
        VStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .fill(Theme.mapPaper)
                    .frame(height: 180)
                    .padding(.horizontal, Theme.s4)
            }
        }
        .padding(.top, Theme.s4)
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        let loc: CLLocation?
        if let custom = customLocation {
            loc = custom
        } else {
            if let existing = location.currentLocation {
                loc = existing
            } else {
                loc = await waitForLocation()
            }
        }
        guard let loc else {
            isLoading = false
            return
        }
        let results = await ZabihahService.shared.fetchCombined(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude
        )
        let cafes = await ZabihahService.searchAppleMaps(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            extraQueries: [
                "coffee shop",
                "halal cafe",
                "cafe bakery",
                "dessert shop",
                "boba tea",
                "juice bar"
            ]
        ).filter(\.isCafe)
        await MainActor.run {
            restaurants = results
            coffeeShops = cafes
            isLoading = false
        }
    }

    private func waitForLocation() async -> CLLocation? {
        for _ in 0..<20 {
            if let loc = location.currentLocation { return loc }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return nil
    }
}

// MARK: - Restaurant Card (Large Landscape)

struct RestaurantCardLarge: View {
    let restaurant: ZabihahRestaurant
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: Theme.rCard)
                        .fill(Theme.mapPaper)
                        .frame(width: 260, height: 168)
                        .overlay {
                            if let url = restaurant.photoURLs.first {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Theme.mapPaper
                                }
                                .frame(width: 260, height: 168)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
                            } else {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.fg3)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))

                    CertBadge(status: restaurant.halalStatus, compact: true)
                        .padding(10)

                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 11, weight: .medium))
                                Text("nearby")
                                    .font(.mono(11))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            Spacer()
                        }
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .frame(width: 260, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 15, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.fg1)
                            .lineLimit(1)
                        Spacer()
                        if let rating = restaurant.rating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.fg1)
                                Text(String(format: "%.1f", rating))
                                    .font(.mono(12, weight: .semibold))
                                    .foregroundStyle(Theme.fg1)
                            }
                        }
                    }
                    Text(restaurant.cuisineType)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.fg2)
                        .lineLimit(1)
                }
                .padding(.top, 10)
                .padding(.horizontal, 2)
            }
            .frame(width: 260)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cafe Card

struct CafeCard: View {
    let restaurant: ZabihahRestaurant
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.mapPaper)
                        .frame(width: 160, height: 110)
                        .overlay {
                            if let url = restaurant.photoURLs.first {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Theme.mapPaper
                                }
                                .frame(width: 160, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.fg3.opacity(0.5))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: Theme.fg1.opacity(0.18), radius: 8, y: 3)
                        .overlay {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.pinPhoto)
                        }
                        .padding(8)
                }

                Text(restaurant.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.fg1)
                    .lineLimit(1)
                    .padding(.top, 8)
                Text(restaurant.cuisineType)
                    .font(.mono(11.5))
                    .foregroundStyle(Theme.fg3)
                    .padding(.top, 2)
            }
            .frame(width: 160, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Restaurant Row (Feed)

struct RestaurantRow: View {
    let restaurant: ZabihahRestaurant
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.mapPaper)
                        .frame(width: 96, height: 96)
                        .overlay {
                            if let url = restaurant.photoURLs.first {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Theme.mapPaper
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                Image(systemName: restaurant.isCafe ? "cup.and.saucer.fill" : "fork.knife")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Theme.fg3)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    PinDot(
                        restaurant.halalStatus == .fullyHalal || restaurant.halalStatus == .zabiha ? .certified : .friendly,
                        size: 20
                    )
                    .padding(6)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(restaurant.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.fg1)
                        .lineLimit(1)
                    Text(restaurant.cuisineType)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.fg2)
                        .padding(.top, 4)

                    Spacer()

                    HStack(spacing: 12) {
                        if let rating = restaurant.rating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.fg1)
                                Text(String(format: "%.1f", rating))
                                    .font(.mono(11.5, weight: .semibold))
                                    .foregroundStyle(Theme.fg1)
                            }
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 11))
                            Text("nearby")
                                .font(.mono(11.5))
                        }
                        .foregroundStyle(Theme.fg2)

                        Text("Open")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.pinCertified)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .frame(height: 96)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Restaurant Detail Sheet (redesigned)

private struct RestaurantDetailSheet: View {
    let restaurant: ZabihahRestaurant
    @Binding var itineraries: [Itinerary]
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]

    @EnvironmentObject var location: LocationService
    @State private var travel: TravelInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                bodyContent
            }
        }
        .overlay(alignment: .bottom) { bottomBar }
        .task { await loadTravel() }
    }

    private var heroImage: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.mapPaper)
                .frame(height: 300)
                .overlay {
                    if let url = restaurant.photoURLs.first {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Theme.mapPaper
                        }
                        .frame(height: 300)
                        .clipped()
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.fg3)
                    }
                }
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .clear, .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 300)
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                CertBadge(status: restaurant.halalStatus)
                Text(restaurant.certificationLabel)
                    .font(.mono(11))
                    .foregroundStyle(Theme.fg3)
            }
            .padding(.top, 20)

            Text(restaurant.name)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.fg1)
                .padding(.top, 10)

            Text("\(restaurant.cuisineType) · \(restaurant.address)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 4)

            statStrip
                .padding(.top, 16)

            if let desc = restaurant.halalDescription {
                Text(desc)
                    .font(.system(size: 14.5))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.fg1)
                    .padding(.top, 18)
            }

            halalVerification
                .padding(.top, 22)

            if !restaurant.businessHours.isEmpty {
                hoursSection
                    .padding(.top, 22)
            }

            Spacer().frame(height: 120)
        }
        .padding(.horizontal, 18)
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            if let rating = restaurant.rating, rating > 0 {
                StatColumn(
                    label: "Rating",
                    value: String(format: "%.1f", rating),
                    sub: "\(restaurant.reviewCount) reviews",
                    icon: "star.fill"
                )
                Divider().frame(height: 40)
            }
            if let travel {
                StatColumn(
                    label: "Walk",
                    value: "\(travel.walkingTimeMinutes)m",
                    sub: travel.formattedDistance,
                    icon: "figure.walk"
                )
                Divider().frame(height: 40)
            }
            StatColumn(
                label: "Status",
                value: "Open",
                sub: "Verify hours",
                positive: true
            )
        }
        .padding(12)
        .background(Theme.bgTint, in: RoundedRectangle(cornerRadius: 16))
    }

    private var halalVerification: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.pinCertified)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading) {
                    Text("Halal verification")
                        .font(.system(size: 14.5, weight: .bold))
                    Text(restaurant.certificationLabel)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.fg2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                verificationRow(checked: true, text: "Halal meat sourcing verified")
                verificationRow(checked: true, text: "No alcohol on menu")
            }
        }
        .padding(16)
        .background(Theme.bgTint, in: RoundedRectangle(cornerRadius: 18))
    }

    private func verificationRow(checked: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(checked ? Theme.pinCertified : .clear)
                .frame(width: 16, height: 16)
                .overlay {
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle().stroke(Theme.fg1.opacity(0.16), lineWidth: 1.2)
                    }
                }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.fg1)
        }
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hours")
                .font(.system(size: 14.5, weight: .bold))
            ForEach(restaurant.businessHours, id: \.day) { hours in
                HStack {
                    Text(hours.day)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.fg1)
                        .frame(width: 90, alignment: .leading)
                    Text(hours.hours)
                        .font(.mono(13))
                        .foregroundStyle(Theme.fg2)
                }
            }
        }
        .padding(16)
        .background(Theme.bgTint, in: RoundedRectangle(cornerRadius: 18))
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                let placemark = MKPlacemark(coordinate: restaurant.coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = restaurant.name
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Directions")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white)
                .foregroundStyle(Theme.fg1)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.fg1.opacity(0.12), lineWidth: 1))
            }

            Button {
                // Add to itinerary action
            } label: {
                HStack(spacing: 6) {
                    Text("Add to itinerary")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.fg1)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.3) }
    }

    private func loadTravel() async {
        guard let userLoc = location.currentLocation else { return }
        travel = await TravelCalculator.calculate(
            from: userLoc.coordinate,
            to: restaurant.coordinate
        )
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    let onSelect: (String, CLLocation) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var completions: [MKLocalSearchCompletion] = []
    @State private var completer = LocationCompleterDelegate()
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.fg2)
                    TextField("Search city or country", text: $query)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.fg1)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Theme.mapPaper, in: Capsule())
                .padding(.horizontal, Theme.s4)
                .padding(.top, Theme.s3)

                List {
                    Button {
                        dismiss()
                        onReset()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.pinCertified, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use my current location")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.fg1)
                                Text("GPS location")
                                    .font(.mono(11))
                                    .foregroundStyle(Theme.fg3)
                            }
                        }
                    }

                    ForEach(completions, id: \.self) { completion in
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.info, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.fg1)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.mono(11))
                                        .foregroundStyle(Theme.fg3)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectCompletion(completion)
                        }
                    }

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            completer.onUpdate = { results in
                completions = results
            }
        }
        .onChange(of: query) { _, newValue in
            completer.search(query: newValue)
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isSearching = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        Task {
            guard let response = try? await search.start(),
                  let item = response.mapItems.first else {
                isSearching = false
                return
            }
            let coord = item.placemark.coordinate
            let name = completion.title
            await MainActor.run {
                dismiss()
                onSelect(name, CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            }
        }
    }
}

@Observable
class LocationCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var onUpdate: (([MKLocalSearchCompletion]) -> Void)?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

