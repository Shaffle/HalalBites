import SwiftUI
import MapKit
import CoreLocation

struct ItineraryDetailView: View {
    @Binding var itinerary: Itinerary
    @State private var selectedStop: ItineraryStop?
    @State private var swapTarget: SwapTarget?

    private var currentTripDay: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: itinerary.startDate), to: cal.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    private func canSwap(dayNumber: Int) -> Bool {
        currentTripDay >= 2 && dayNumber >= currentTripDay
    }

    private var previousDayStops: [(dayNumber: Int, stop: ItineraryStop)] {
        itinerary.days
            .filter { $0.dayNumber < currentTripDay }
            .flatMap { day in
                day.stops.map { (dayNumber: day.dayNumber, stop: $0) }
            }
    }

    var body: some View {
        List {
            ForEach(Array(itinerary.days.enumerated()), id: \.element.id) { dayIdx, day in
                Section("Day \(day.dayNumber)") {
                    ForEach(Array(day.stops.enumerated()), id: \.element.id) { stopIdx, stop in
                        ItineraryStopRow(stop: stop)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedStop = stop }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if canSwap(dayNumber: day.dayNumber) {
                                    Button {
                                        swapTarget = SwapTarget(dayIndex: dayIdx, stopIndex: stopIdx)
                                    } label: {
                                        Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    .tint(.teal)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(itinerary.city) · \(itinerary.durationDays)d")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStop) { stop in
            StopDetailSheet(stop: stop)
                .presentationDetents([.large])
        }
        .sheet(item: $swapTarget) { target in
            SwapRestaurantSheet(
                previousDayStops: previousDayStops,
                onSelect: { restaurant in
                    let old = itinerary.days[target.dayIndex].stops[target.stopIndex]
                    itinerary.days[target.dayIndex].stops[target.stopIndex] = ItineraryStop(
                        id: UUID(),
                        restaurant: restaurant,
                        mealType: old.mealType,
                        notes: nil
                    )
                    swapTarget = nil
                }
            )
        }
    }
}

// MARK: - Swap Types

private struct SwapTarget: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let stopIndex: Int
}

struct SwapRestaurantSheet: View {
    let previousDayStops: [(dayNumber: Int, stop: ItineraryStop)]
    let onSelect: (Restaurant) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if previousDayStops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No previous restaurants")
                            .font(.title3.bold())
                        Text("Complete a day first to swap restaurants.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(previousDayStops, id: \.stop.id) { item in
                            Button {
                                onSelect(item.stop.restaurant)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.stop.restaurant.name)
                                            .font(.headline)
                                        Text("Day \(item.dayNumber) · \(item.stop.mealType.rawValue.capitalized)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(item.stop.restaurant.cuisineType)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.teal)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Swap Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stop Detail Sheet

struct StopDetailSheet: View {
    let stop: ItineraryStop

    @EnvironmentObject var location: LocationService
    @State private var phoneNumber: String?
    @State private var loadingPhone = true
    @State private var travel: TravelInfo?

    private var restaurant: Restaurant { stop.restaurant }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                addressRow
                ratingsRow
                HalalBadge(level: restaurant.halalCertificationLevel)

                if let travel {
                    travelSection(travel)
                }

                if let notes = stop.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Divider()

                photosSection

                if !restaurant.businessHours.isEmpty {
                    Divider()
                    hoursSection
                }

                Divider()

                actionButtons
            }
            .padding(24)
        }
        .task {
            await lookUpPhoneNumber()
        }
        .task {
            await loadTravel()
        }
    }

    private func lookUpPhoneNumber() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = restaurant.name
        request.region = MKCoordinateRegion(
            center: restaurant.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        let search = MKLocalSearch(request: request)
        let response = try? await search.start()
        let phone = response?.mapItems.first?.phoneNumber

        await MainActor.run {
            phoneNumber = phone
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

    // MARK: - Travel Info

    private func travelSection(_ travel: TravelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From your location")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

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
            Text(stop.mealType.rawValue.capitalized)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.teal.opacity(0.15))
                .foregroundStyle(.teal)
                .clipShape(Capsule())
        }
    }

    private var addressRow: some View {
        Label(restaurant.address, systemImage: "mappin.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var ratingsRow: some View {
        HStack(spacing: 16) {
            if restaurant.rating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", restaurant.rating))
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

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu & Photos")
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

    // MARK: - Hours

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hours of Operation")
                .font(.headline)

            ForEach(restaurant.businessHours, id: \.day) { entry in
                HStack {
                    Text(entry.day)
                        .font(.subheadline)
                        .frame(width: 100, alignment: .leading)
                    Text(entry.hours)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                Label("Open in Maps", systemImage: "map.fill")
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
                let query = "\(restaurant.name) \(restaurant.address)"
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "https://www.yelp.com/search?find_desc=\(query)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("View on Yelp", systemImage: "star.bubble.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

}

// MARK: - Stop Row

struct ItineraryStopRow: View {
    let stop: ItineraryStop

    @EnvironmentObject var location: LocationService
    @State private var travel: TravelInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stop.restaurant.name)
                    .font(.headline)
                Spacer()
                Text(stop.mealType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.teal.opacity(0.15))
                    .foregroundStyle(.teal)
                    .clipShape(Capsule())
            }

            Text(stop.restaurant.cuisineType)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HalalBadge(level: stop.restaurant.halalCertificationLevel)

            if let travel {
                HStack(spacing: 12) {
                    Label("\(travel.walkingTimeMinutes) min", systemImage: "figure.walk")
                    Label("\(travel.drivingTimeMinutes) min", systemImage: "car.fill")
                    Text("·")
                    Text(travel.formattedDistance)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            guard let userLoc = location.currentLocation else { return }
            travel = await TravelCalculator.calculate(
                from: userLoc.coordinate,
                to: stop.restaurant.coordinate
            )
        }
    }
}

// MARK: - Travel Calculator

enum TravelCalculator {
    static func calculate(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> TravelInfo? {
        async let walkResult = route(from: origin, to: destination, type: .walking)
        async let driveResult = route(from: origin, to: destination, type: .automobile)

        let (walking, driving) = await (walkResult, driveResult)
        guard let walkRoute = walking else { return nil }

        return TravelInfo(
            distanceMeters: walkRoute.distance,
            walkingTimeMinutes: max(1, Int(walkRoute.expectedTravelTime / 60)),
            drivingTimeMinutes: max(1, Int((driving?.expectedTravelTime ?? walkRoute.expectedTravelTime) / 60))
        )
    }

    private static func route(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        type: MKDirectionsTransportType
    ) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = type
        return (try? await MKDirections(request: request).calculate())?.routes.first
    }
}

// MARK: - Halal Badge

struct HalalBadge: View {
    let level: HalalLevel

    private var color: Color {
        switch level {
        case .halal: return .green
        case .vegetarian: return .orange
        case .vegan: return .purple
        }
    }

    var body: some View {
        Label(level.description, systemImage: "checkmark.seal.fill")
            .font(.caption.bold())
            .foregroundStyle(color)
    }
}
