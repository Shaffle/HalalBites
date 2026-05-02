import SwiftUI
import MapKit

struct ExploreMapView: View {
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var api: APIClient
    @State private var restaurants: [Restaurant] = []
    @State private var selectedRestaurant: Restaurant?
    @State private var selectedID: UUID?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(restaurants) { restaurant in
                Annotation(restaurant.name, coordinate: restaurant.coordinate, anchor: .bottom) {
                    RestaurantMapPin(restaurant: restaurant)
                }
                .tag(restaurant.id)
            }
        }
        .onChange(of: selectedID) { _, id in
            selectedRestaurant = restaurants.first { $0.id == id }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear { location.requestPermission() }
        .onChange(of: location.currentLocation) { _, newLocation in
            guard let loc = newLocation else { return }
            Task { await loadNearby(location: loc) }
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailSheet(restaurant: restaurant)
                .presentationDetents([.medium])
        }
    }

    private func loadNearby(location: CLLocation) async {
        guard let results = try? await api.fetchNearbyRestaurants(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMiles: 2.0,
            minLevel: .level1
        ) else { return }
        await MainActor.run { restaurants = results }
    }
}

struct RestaurantMapPin: View {
    let restaurant: Restaurant

    var body: some View {
        ZStack {
            Circle()
                .fill(.teal)
                .frame(width: 32, height: 32)
            Image(systemName: "fork.knife")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(radius: 4)
    }
}

struct RestaurantDetailSheet: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(restaurant.name)
                .font(.title2.bold())
            Text(restaurant.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HalalBadge(level: restaurant.halalCertificationLevel)
            HStack {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                Text(String(format: "%.1f", restaurant.rating))
                Text("(\(restaurant.reviewCount) reviews)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Spacer()
        }
        .padding(24)
    }
}
