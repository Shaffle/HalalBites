import SwiftUI
import MapKit
import CoreLocation

// MARK: - Mosque Model

struct MosqueLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
}

// MARK: - Explore Map

struct ExploreMapView: View {
    @EnvironmentObject var location: LocationService
    @Binding var itineraries: [Itinerary]

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
    @State private var selectedCategory: CuisineCategory?

    private var selectedRestaurant: ZabihahRestaurant? {
        restaurants.first { $0.id == selectedID }
    }

    private var locationDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    private var filteredRestaurants: [ZabihahRestaurant] {
        var results = restaurants
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.cuisineType.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let category = selectedCategory {
            results = results.filter { category.matches($0.cuisineType) }
        }
        return results
    }

    var body: some View {
        ZStack {
            Map(position: $position, selection: $selectedID) {
                UserAnnotation()
                ForEach(filteredRestaurants) { restaurant in
                    Annotation(restaurant.name, coordinate: restaurant.coordinate, anchor: .bottom) {
                        HalalMapPin()
                    }
                    .tag(restaurant.id)
                }
                ForEach(mosques) { mosque in
                    Annotation(mosque.name, coordinate: mosque.coordinate, anchor: .bottom) {
                        MosqueMapPin()
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            VStack(spacing: 0) {
                searchBar
                categoryFilters

                if locationDenied {
                    locationDeniedBanner
                }

                Spacer()
            }
        }
        .onAppear {
            if let loc = location.currentLocation {
                centreAndLoad(coordinate: loc.coordinate)
            }
        }
        .onChange(of: location.currentLocation) { _, newLocation in
            guard let loc = newLocation else { return }
            centreAndLoad(coordinate: loc.coordinate)
        }
        .onChange(of: location.authorizationStatus) { _, status in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if let loc = location.currentLocation {
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
                let center = CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413)
                restaurants = ZabihahService.mockRestaurants(near: center.latitude, longitude: center.longitude)
                await searchMosques(near: center)
            }
        }
        .sheet(isPresented: $showManualSearch) {
            manualCitySheet
        }
        .sheet(item: Binding(
            get: { selectedRestaurant },
            set: { _ in selectedID = nil }
        )) { restaurant in
            ZabihahRestaurantSheet(restaurant: restaurant, itineraries: $itineraries)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search restaurants…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(CuisineCategory.allCases) { category in
                    FilterChip(label: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        Task {
            await loadNearby(coordinate: coordinate)
            await searchMosques(near: coordinate)
        }
    }

    private func loadNearby(coordinate: CLLocationCoordinate2D) async {
        let results = (try? await ZabihahService.shared.fetchNearby(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )) ?? ZabihahService.mockRestaurants(near: coordinate.latitude, longitude: coordinate.longitude)
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
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.title2.bold())
                    Text(restaurant.cuisineType)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZabihahBadge(zabiha: restaurant.zabiha)
            }

            Label(restaurant.address, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let rating = restaurant.rating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline.bold())
                    Text("on Zabihah").foregroundStyle(.secondary).font(.subheadline)
                }
            }

            Divider()

            Label("Verified by Zabihah.com", systemImage: "checkmark.shield.fill")
                .font(.footnote)
                .foregroundStyle(.green)

            if !itineraries.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add to Itinerary", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.15))
                        .foregroundStyle(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showAddSheet) {
            AddToItinerarySheet(restaurant: restaurant, itineraries: $itineraries)
                .presentationDetents([.medium])
        }
    }
}

struct ZabihahBadge: View {
    let zabiha: Bool

    var body: some View {
        Text(zabiha ? "Zabiha \u{2713}" : "Halal \u{2713}")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.teal.opacity(0.15))
            .foregroundStyle(.teal)
            .clipShape(Capsule())
    }
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
            halalCertificationLevel: .halal,
            cuisineType: restaurant.cuisineType,
            rating: restaurant.rating ?? 0,
            reviewCount: restaurant.reviewCount,
            phoneNumber: nil,
            websiteURL: nil,
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
