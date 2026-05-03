import SwiftUI
import MapKit
import CoreLocation
import WebKit

struct ItineraryDetailView: View {
    @Binding var itinerary: Itinerary
    @State private var selectedStop: ItineraryStop?
    @State private var swapTarget: SwapTarget?
    @State private var showDayFeedback = false
    @State private var lastPromptedDay = 0

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

    private var feedbackDay: ItineraryDay? {
        itinerary.days.first { $0.dayNumber == currentTripDay - 1 }
    }

    private var hasRemainingDays: Bool {
        itinerary.days.contains { $0.dayNumber >= currentTripDay }
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
        .onAppear {
            let key = "lastPromptedDay_\(itinerary.id.uuidString)"
            lastPromptedDay = UserDefaults.standard.integer(forKey: key)
            if currentTripDay > 1 && currentTripDay > lastPromptedDay && hasRemainingDays {
                showDayFeedback = true
            }
        }
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
        .sheet(isPresented: $showDayFeedback) {
            if let day = feedbackDay {
                DayFeedbackSheet(
                    dayNumber: day.dayNumber,
                    stops: day.stops,
                    onApply: { likedStops in
                        propagateLiked(likedStops)
                        markPrompted()
                    },
                    onSkip: {
                        markPrompted()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func markPrompted() {
        let key = "lastPromptedDay_\(itinerary.id.uuidString)"
        UserDefaults.standard.set(currentTripDay, forKey: key)
        lastPromptedDay = currentTripDay
    }

    private func propagateLiked(_ likedStops: [ItineraryStop]) {
        for dayIdx in itinerary.days.indices {
            guard itinerary.days[dayIdx].dayNumber >= currentTripDay else { continue }
            for liked in likedStops {
                if let stopIdx = itinerary.days[dayIdx].stops.firstIndex(where: { $0.mealType == liked.mealType }) {
                    itinerary.days[dayIdx].stops[stopIdx] = ItineraryStop(
                        id: UUID(),
                        restaurant: liked.restaurant,
                        mealType: liked.mealType,
                        notes: liked.notes
                    )
                }
            }
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

// MARK: - Day Feedback Sheet

struct DayFeedbackSheet: View {
    let dayNumber: Int
    let stops: [ItineraryStop]
    let onApply: ([ItineraryStop]) -> Void
    let onSkip: () -> Void

    @State private var liked: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("How was Day \(dayNumber)?")
                        .font(.title3.bold())
                    Text("Select any favourites to add them to your remaining days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(stops) { stop in
                        Button {
                            if liked.contains(stop.id) {
                                liked.remove(stop.id)
                            } else {
                                liked.insert(stop.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stop.restaurant.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(stop.mealType.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: liked.contains(stop.id) ? "heart.fill" : "heart")
                                    .foregroundStyle(liked.contains(stop.id) ? .red : .secondary)
                                    .font(.title3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Day \(dayNumber) Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let selected = stops.filter { liked.contains($0.id) }
                        onApply(selected)
                        dismiss()
                    }
                    .disabled(liked.isEmpty)
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
    @State private var menuURL: URL?
    @State private var loadingMenu = true
    @State private var showMenuSheet = false

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

                Divider()

                photosSection

                Divider()

                aboutSection

                Divider()

                actionButtons
            }
            .padding(24)
        }
        .task {
            await lookUpDetails()
        }
        .task {
            await loadTravel()
        }
        .sheet(isPresented: $showMenuSheet) {
            NavigationStack {
                Group {
                    if loadingMenu {
                        ProgressView("Loading menu…")
                    } else if let url = menuURL {
                        MenuWebView(url: url)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        let query = "\(restaurant.name) \(restaurant.address) menu"
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "https://www.yelp.com/search?find_desc=\(query)") {
                            MenuWebView(url: url)
                                .ignoresSafeArea(edges: .bottom)
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
        }
    }

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
        let phone = item?.phoneNumber
        let website = item?.url

        await MainActor.run {
            phoneNumber = phone
            loadingPhone = false
            if let website, website.host() != nil {
                menuURL = website
            }
            loadingMenu = false
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
            VStack(alignment: .trailing, spacing: 6) {
                Text(stop.mealType.rawValue.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.teal.opacity(0.15))
                    .foregroundStyle(.teal)
                    .clipShape(Capsule())

                if let status = OpenStatusHelper.status(for: restaurant.businessHours, mealType: stop.mealType) {
                    Text(status.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(status.color.opacity(0.15))
                        .foregroundStyle(status.color)
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

            if let notes = stop.notes {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.orange)
                    Text(notes)
                        .font(.subheadline)
                        .italic()
                }
            }
        }
    }

    private var restaurantSummary: String {
        var parts: [String] = []
        parts.append(restaurant.cuisineType)
        parts.append(restaurant.halalCertificationLevel.description)
        if restaurant.rating > 0 {
            parts.append("\(String(format: "%.1f", restaurant.rating))★")
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
                showMenuSheet = true
            } label: {
                Label("View Menu", systemImage: "menucard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
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
                if let status = OpenStatusHelper.status(for: stop.restaurant.businessHours, mealType: stop.mealType) {
                    Text(status.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(status.color.opacity(0.15))
                        .foregroundStyle(status.color)
                        .clipShape(Capsule())
                }
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

// MARK: - Open Status

enum OpenStatus {
    case open, closed, openingSoon

    var label: String {
        switch self {
        case .open: return "Open"
        case .closed: return "Closed"
        case .openingSoon: return "Opening Soon"
        }
    }

    var color: Color {
        switch self {
        case .open: return .green
        case .closed: return .red
        case .openingSoon: return .orange
        }
    }
}

enum OpenStatusHelper {
    static func status(for hours: [BusinessHours], mealType: MealType? = nil) -> OpenStatus? {
        guard !hours.isEmpty else { return nil }
        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = formatter.string(from: now)

        guard let entry = hours.first(where: { $0.day.caseInsensitiveCompare(today) == .orderedSame }) else {
            return nil
        }

        if entry.hours.lowercased().contains("closed") { return .closed }

        let parts = entry.hours.components(separatedBy: " - ")
        guard parts.count == 2,
              let openMin = parseTimeMinutes(parts[0]),
              let closeMin = parseTimeMinutes(parts[1]) else { return nil }

        let checkTime: Int
        if let meal = mealType {
            checkTime = meal.typicalHour * 60
        } else {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            checkTime = hour * 60 + minute
        }

        if checkTime >= openMin && checkTime <= closeMin {
            return .open
        } else if openMin > checkTime && (openMin - checkTime) <= 60 {
            return .openingSoon
        } else {
            return .closed
        }
    }

    private static func parseTimeMinutes(_ timeString: String) -> Int? {
        let trimmed = timeString.trimmingCharacters(in: .whitespaces).uppercased()
        let isPM = trimmed.hasSuffix("PM")
        let cleaned = trimmed
            .replacingOccurrences(of: "AM", with: "")
            .replacingOccurrences(of: "PM", with: "")
            .trimmingCharacters(in: .whitespaces)
        let components = cleaned.components(separatedBy: ":")
        guard let hour = Int(components[0]) else { return nil }
        let minute = components.count > 1 ? (Int(components[1]) ?? 0) : 0

        var h = hour
        if isPM && h != 12 { h += 12 }
        if !isPM && h == 12 { h = 0 }

        return h * 60 + minute
    }
}

// MARK: - MealType Helpers

extension MealType {
    var typicalHour: Int {
        switch self {
        case .breakfast: return 8
        case .lunch: return 12
        case .dinner: return 18
        case .snack: return 15
        }
    }
}

// MARK: - Embedded Menu Web View

struct MenuWebView: UIViewRepresentable {
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
