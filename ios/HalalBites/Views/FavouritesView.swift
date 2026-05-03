import SwiftUI
import MapKit

struct FavouritesView: View {
    let itineraries: [Itinerary]
    let archivedItineraries: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    let exploreFavouriteRestaurants: [Restaurant]

    @State private var selectedRestaurant: Restaurant?
    @State private var selectedTrip: Itinerary?

    private var favouritedTrips: [Itinerary] {
        (itineraries + archivedItineraries).filter { favouriteIDs.contains($0.id) }
    }

    private var favouritedRestaurants: [Restaurant] {
        var seen: Set<UUID> = []
        var results: [Restaurant] = []

        let allStops = (itineraries + archivedItineraries).flatMap { $0.days.flatMap(\.stops) }
        for stop in allStops {
            let rid = stop.restaurant.id
            guard favouriteRestaurantIDs.contains(rid), !seen.contains(rid) else { continue }
            seen.insert(rid)
            results.append(stop.restaurant)
        }

        for restaurant in exploreFavouriteRestaurants {
            guard favouriteRestaurantIDs.contains(restaurant.id), !seen.contains(restaurant.id) else { continue }
            seen.insert(restaurant.id)
            results.append(restaurant)
        }

        return results
    }

    private var isEmpty: Bool {
        favouritedTrips.isEmpty && favouritedRestaurants.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No favourites yet")
                        .font(.title3.bold())
                    Text("Tap the heart on a restaurant to save it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    if !favouritedRestaurants.isEmpty {
                        Section("Restaurants") {
                            ForEach(favouritedRestaurants) { restaurant in
                                Button {
                                    selectedRestaurant = restaurant
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(restaurant.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(restaurant.cuisineType)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            if restaurant.rating > 0 {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .foregroundStyle(.yellow)
                                                        .font(.caption)
                                                    Text(String(format: "%.1f", restaurant.rating))
                                                        .font(.caption.bold())
                                                }
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.pink)
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        withAnimation {
                                            _ = favouriteRestaurantIDs.remove(restaurant.id)
                                        }
                                    } label: {
                                        Label("Unfavourite", systemImage: "heart.slash")
                                    }
                                    .tint(.pink)
                                }
                            }
                        }
                    }

                    if !favouritedTrips.isEmpty {
                        Section("Trips") {
                            ForEach(favouritedTrips) { itinerary in
                                Button {
                                    selectedTrip = itinerary
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(itinerary.city), \(itinerary.country)")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.pink)
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        withAnimation {
                                            _ = favouriteIDs.remove(itinerary.id)
                                        }
                                    } label: {
                                        Label("Unfavourite", systemImage: "heart.slash")
                                    }
                                    .tint(.pink)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRestaurant) { restaurant in
            FavouriteRestaurantDetailSheet(
                restaurant: restaurant,
                isFavourited: favouriteRestaurantIDs.contains(restaurant.id),
                onToggleFavourite: {
                    if favouriteRestaurantIDs.contains(restaurant.id) {
                        favouriteRestaurantIDs.remove(restaurant.id)
                    } else {
                        favouriteRestaurantIDs.insert(restaurant.id)
                    }
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $selectedTrip) { itinerary in
            NavigationStack {
                ItineraryDetailView(
                    itinerary: .constant(itinerary),
                    favouriteRestaurantIDs: $favouriteRestaurantIDs
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { selectedTrip = nil }
                    }
                }
            }
        }
    }
}

// MARK: - Favourite Restaurant Detail Sheet

struct FavouriteRestaurantDetailSheet: View {
    let restaurant: Restaurant
    let isFavourited: Bool
    let onToggleFavourite: () -> Void

    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber: String?
    @State private var loadingPhone = true
    @State private var travel: TravelInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
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
                        Button {
                            onToggleFavourite()
                        } label: {
                            Image(systemName: isFavourited ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(.pink)
                        }
                    }

                    Label(restaurant.address, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if restaurant.rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", restaurant.rating))
                                .font(.subheadline.bold())
                        }
                    }

                    HalalBadge(level: restaurant.halalCertificationLevel)

                    if let travel {
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
                                Text("\(travel.drivingTimeMinutes) min")
                                    .font(.subheadline.bold())
                            }
                        }
                    }

                    if !restaurant.photoURLs.isEmpty {
                        Divider()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(restaurant.photoURLs, id: \.self) { url in
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                                .frame(width: 160, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()

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
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await lookUpPhone() }
            .task { await loadTravel() }
        }
    }

    private func lookUpPhone() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = restaurant.name
        request.region = MKCoordinateRegion(
            center: restaurant.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        let item = (try? await MKLocalSearch(request: request).start())?.mapItems.first
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
