import SwiftUI
import MapKit
import CoreLocation

struct ExploreMapView: View {
    @EnvironmentObject var location: LocationService
    @State private var restaurants: [ZabihahRestaurant] = []
    @State private var selectedID: Int?
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.3062, longitude: -111.8413),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    ))
    @State private var showLocationDeniedBanner = false
    @State private var manualCity = ""
    @State private var showManualSearch = false

    private var selectedRestaurant: ZabihahRestaurant? {
        restaurants.first { $0.id == selectedID }
    }

    private var locationDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    var body: some View {
        ZStack {
            Map(position: $position, selection: $selectedID) {
                UserAnnotation()
                ForEach(restaurants) { restaurant in
                    Annotation(restaurant.name, coordinate: restaurant.coordinate, anchor: .bottom) {
                        HalalMapPin(zabiha: restaurant.zabiha)
                    }
                    .tag(restaurant.id)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Overlays
            VStack {
                MapLegend()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)

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
            }
        }
        .sheet(isPresented: $showManualSearch) {
            manualCitySheet
        }
        .sheet(item: Binding(
            get: { selectedRestaurant },
            set: { _ in selectedID = nil }
        )) { restaurant in
            ZabihahRestaurantSheet(restaurant: restaurant)
                .presentationDetents([.medium])
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
        Task { await loadNearby(coordinate: coordinate) }
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
}

// MARK: - Halal Map Pin

struct HalalMapPin: View {
    let zabiha: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(zabiha ? Color.green : Color.teal)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            VStack(spacing: 0) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if zabiha {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(zabiha ? Color.green : Color.teal)
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

// MARK: - Map Legend

struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: .green, label: "Zabiha Certified")
            LegendRow(color: .teal, label: "Halal Certified")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2.bold())
        }
    }
}

// MARK: - Restaurant Detail Sheet

struct ZabihahRestaurantSheet: View {
    let restaurant: ZabihahRestaurant

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

            Spacer()
        }
        .padding(24)
    }
}

struct ZabihahBadge: View {
    let zabiha: Bool

    var body: some View {
        Text(zabiha ? "Zabiha ✓" : "Halal ✓")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(zabiha ? Color.green.opacity(0.15) : Color.teal.opacity(0.15))
            .foregroundStyle(zabiha ? .green : .teal)
            .clipShape(Capsule())
    }
}
