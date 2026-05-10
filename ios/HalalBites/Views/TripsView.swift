import SwiftUI
import MapKit
import CoreLocation

struct TripsView: View {
    @Binding var itineraries: [Itinerary]
    @Binding var showSideMenu: Bool
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]

    @State private var segment: TripSegment = .all
    @State private var showGenerator = false
    @State private var selectedItinerary: Itinerary?
    @State private var shareTrip: Itinerary?
    @State private var shareText: String?
    @State private var isUploading = false
    @AppStorage("profileName") private var profileName = ""

    enum TripSegment: String, CaseIterable {
        case all = "Trips"
        case past = "Past"
    }

    private var filtered: [Itinerary] {
        switch segment {
        case .all: return itineraries
        case .past: return itineraries.filter { $0.hasEnded }
        }
    }

    private var inProgress: [Itinerary] {
        itineraries.filter { trip in
            let now = Date()
            return trip.startDate <= now && !trip.hasEnded
        }
    }

    private var past: [Itinerary] {
        filtered.filter { $0.hasEnded }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    tripContent
                } header: {
                    stickyHeader
                }
            }
        }
        .background(Theme.bg)
        .sheet(isPresented: $showGenerator) {
            ItineraryGeneratorView { newItinerary in
                itineraries.insert(newItinerary, at: 0)
            }
        }
        .sheet(item: $selectedItinerary) { itinerary in
            ItineraryDetailView(
                itinerary: binding(for: itinerary),
                favouriteRestaurantIDs: $favouriteRestaurantIDs
            )
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            if let text = shareText, let trip = shareTrip {
                ShareSheet(items: [ShareItemWithPreview(text: text, title: "\(profileName) has shared \(trip.tripName) with you!")])
            }
        }
    }

    private func binding(for itinerary: Itinerary) -> Binding<Itinerary> {
        Binding(
            get: { itineraries.first(where: { $0.id == itinerary.id }) ?? itinerary },
            set: { newValue in
                if let idx = itineraries.firstIndex(where: { $0.id == itinerary.id }) {
                    itineraries[idx] = newValue
                }
            }
        )
    }

    // MARK: - Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIPS")
                        .eyebrowStyle()
                    Text("Your itineraries")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.fg1)
                }
                Spacer()
                Button {
                    showGenerator = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.fg1, in: Circle())
                }
            }
            .padding(.horizontal, Theme.s4)
            .padding(.top, Theme.s4)

            segmentedControl
                .padding(.horizontal, Theme.s4)
                .padding(.top, Theme.s4)
                .padding(.bottom, Theme.s3)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(TripSegment.allCases, id: \.rawValue) { seg in
                Button {
                    withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.86)) {
                        segment = seg
                    }
                } label: {
                    Text(seg.rawValue)
                        .font(.system(size: 12.5, weight: segment == seg ? .semibold : .medium))
                        .foregroundStyle(segment == seg ? Theme.fg1 : Theme.fg2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            segment == seg
                            ? AnyShapeStyle(.white.shadow(.drop(color: Theme.fg1.opacity(0.06), radius: 2, y: 1)))
                            : AnyShapeStyle(.clear)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(Theme.mapPaper, in: Capsule())
    }

    // MARK: - Content

    private var tripContent: some View {
        VStack(spacing: 0) {
            if segment != .past {
                ForEach(inProgress) { trip in
                    ActiveTripCard(trip: trip) {
                        selectedItinerary = trip
                    }
                    .tripContextMenu(
                        trip: trip,
                        isFavourite: favouriteIDs.contains(trip.id),
                        onFavourite: { toggleFavourite(trip) },
                        onShare: { Task { await shareTrip(trip) } },
                        onArchive: { archiveTrip(trip) },
                        onDelete: { deleteTrip(trip) }
                    )
                    .padding(.horizontal, Theme.s4)
                    .padding(.top, 18)
                }
            }

            if !past.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PAST TRIPS")
                        .eyebrowStyle()
                        .padding(.horizontal, Theme.s4)
                        .padding(.top, 20)

                    ForEach(past) { trip in
                        TripCardView(trip: trip, muted: true) {
                            selectedItinerary = trip
                        }
                        .tripContextMenu(
                            trip: trip,
                            isFavourite: favouriteIDs.contains(trip.id),
                            onFavourite: { toggleFavourite(trip) },
                            onShare: { Task { await shareTrip(trip) } },
                            onArchive: { archiveTrip(trip) },
                            onDelete: { deleteTrip(trip) }
                        )
                        .padding(.horizontal, Theme.s4)
                    }
                }
            }

            planTripCTA
                .padding(.horizontal, Theme.s4)
                .padding(.top, 24)

            Spacer().frame(height: 110)
        }
    }

    // MARK: - Swipe Actions

    private func deleteTrip(_ trip: Itinerary) {
        withAnimation(.easeInOut(duration: 0.25)) {
            itineraries.removeAll { $0.id == trip.id }
            favouriteIDs.remove(trip.id)
            if !recentlyDeleted.contains(where: { $0.id == trip.id }) {
                recentlyDeleted.insert(trip, at: 0)
            }
        }
    }

    private func archiveTrip(_ trip: Itinerary) {
        withAnimation(.easeInOut(duration: 0.25)) {
            itineraries.removeAll { $0.id == trip.id }
            if !archivedItineraries.contains(where: { $0.id == trip.id }) {
                archivedItineraries.insert(trip, at: 0)
            }
        }
    }

    private func toggleFavourite(_ trip: Itinerary) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if favouriteIDs.contains(trip.id) {
                favouriteIDs.remove(trip.id)
            } else {
                favouriteIDs.insert(trip.id)
            }
        }
    }

    private func shareTrip(_ trip: Itinerary) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let code = try await CloudKitShareService.upload(trip, profileName: profileName)
            shareTrip = trip
            shareText = ItineraryShareManager.shareText(for: code, profileName: profileName, tripName: trip.tripName)
        } catch {}
    }

    // MARK: - Plan Trip CTA

    private var planTripCTA: some View {
        Button {
            showGenerator = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Theme.fg1)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan a new trip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.fg1)
                    Text("Tell Safa your city + days · we'll generate the route.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.fg2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.fg2)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                    .foregroundStyle(Theme.fg1.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Trip Card

struct ActiveTripCard: View {
    let trip: Itinerary
    let onTap: () -> Void

    private var totalStops: Int {
        trip.days.flatMap(\.stops).count
    }

    private var progress: Double {
        guard totalStops > 0 else { return 0 }
        let daysPassed = Calendar.current.dateComponents([.day], from: trip.startDate, to: Date()).day ?? 0
        let stopsCompleted = trip.days.prefix(daysPassed).flatMap(\.stops).count
        return Double(stopsCompleted) / Double(totalStops)
    }

    private var nextStop: String? {
        let daysPassed = Calendar.current.dateComponents([.day], from: trip.startDate, to: Date()).day ?? 0
        let currentDay = trip.days.first(where: { $0.dayNumber == daysPassed + 1 })
        return currentDay?.stops.first.map { "\($0.restaurant.name) · \($0.mealType.rawValue.capitalized)" }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LandmarkBackground(
                        city: trip.city,
                        country: trip.country,
                        size: CGSize(width: 400, height: 168)
                    )
                    .frame(height: 168)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.15), .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 22, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0, topTrailingRadius: 22
                        )
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.pinCertified, in: Capsule())

                            Spacer()

                            Text("Day \(dayNumber) of \(trip.durationDays)")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.fg1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.92), in: Capsule())
                        }

                        Spacer()

                        Text("\(trip.country)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.3)
                        Text(trip.city)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .frame(height: 168)
                }

                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.mapPaper)
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Theme.pinCertified)
                                    .frame(width: geo.size.width * progress, height: 4)
                            }
                        }
                        .frame(height: 4)

                        HStack {
                            Text("\(Int(progress * Double(totalStops))) of \(totalStops) stops")
                                .font(.mono(11))
                                .foregroundStyle(Theme.fg2)
                            Spacer()
                            Text("\(totalStops) verified halal")
                                .font(.mono(11))
                                .foregroundStyle(Theme.fg2)
                        }
                    }

                    if let next = nextStop {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Theme.pinCertified)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("UP NEXT")
                                    .eyebrowStyle()
                                Text(next)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.fg1)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("Open")
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.fg1, in: Capsule())
                        }
                        .padding(12)
                        .background(Theme.bgTint, in: RoundedRectangle(cornerRadius: Theme.rMd))
                    }
                }
                .padding(16)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Theme.fg1.opacity(0.06), radius: 2, y: 2)
            .shadow(color: Theme.fg1.opacity(0.10), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var dayNumber: Int {
        let days = Calendar.current.dateComponents([.day], from: trip.startDate, to: Date()).day ?? 0
        return min(days + 1, trip.durationDays)
    }
}

// MARK: - Trip Card

struct TripCardView: View {
    let trip: Itinerary
    var muted: Bool = false
    let onTap: () -> Void

    private var totalStops: Int {
        trip.days.flatMap(\.stops).count
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let start = f.string(from: trip.startDate)
        let end = f.string(from: trip.endDate)
        return "\(start)–\(end)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ZStack {
                    LandmarkBackground(
                        city: trip.city,
                        country: trip.country,
                        size: CGSize(width: 116, height: 132)
                    )
                    .frame(width: 116, height: 132)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.1), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipped()

                    VStack {
                        HStack {
                            Text(trip.hasEnded ? "Past" : "Upcoming")
                                .font(.system(size: 9.5, weight: .bold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    trip.hasEnded
                                    ? Theme.fg1.opacity(0.55)
                                    : Theme.pinFriendly,
                                    in: Capsule()
                                )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(width: 116, height: 132)

                VStack(alignment: .leading, spacing: 0) {
                    Text(trip.country)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.fg3)
                        .tracking(0.3)

                    Text(trip.city)
                        .font(.system(size: 19, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.fg1)
                        .padding(.top, 2)

                    Text(dateString)
                        .font(.mono(11.5))
                        .foregroundStyle(Theme.fg2)
                        .padding(.top, 6)

                    Spacer()

                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text("\(totalStops)")
                                .font(.mono(11.5, weight: .semibold))
                                .foregroundStyle(Theme.fg1)
                            Text("stops")
                                .font(.mono(11.5))
                        }
                        .foregroundStyle(Theme.fg2)

                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.pinCertified)
                            Text("\(totalStops)")
                                .font(.mono(11.5, weight: .semibold))
                                .foregroundStyle(Theme.pinCertified)
                            Text("verified")
                                .font(.mono(11.5))
                                .foregroundStyle(Theme.fg2)
                        }

                        Text("\(trip.durationDays)d")
                            .font(.mono(11.5, weight: .semibold))
                            .foregroundStyle(Theme.fg1)
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 14)
            }
            .frame(height: 132)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .stroke(Theme.fg1.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Theme.fg1.opacity(0.04), radius: 2, y: 1)
            .opacity(muted ? 0.95 : 1)
        }
        .buttonStyle(.plain)
    }

    private var miniPinCluster: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 35))
                path.addQuadCurve(to: CGPoint(x: 80, y: 58), control: CGPoint(x: 46, y: 30))
                path.addQuadCurve(to: CGPoint(x: 116, y: 93), control: CGPoint(x: 100, y: 70))
            }
            .stroke(Theme.fg1.opacity(0.12), lineWidth: 1.5)

            PinDot(.certified, size: 18)
                .position(x: 26, y: 32)
            PinDot(.photo, size: 18)
                .position(x: 70, y: 55)
            PinDot(.cultural, size: 18)
                .position(x: 44, y: 92)
            PinDot(.certified, size: 18)
                .position(x: 90, y: 110)
        }
    }
}

// MARK: - Trip Context Menu

extension View {
    func tripContextMenu(
        trip: Itinerary,
        isFavourite: Bool,
        onFavourite: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.contextMenu {
            Button {
                onFavourite()
            } label: {
                Label(
                    isFavourite ? "Unfavourite" : "Favourite",
                    systemImage: isFavourite ? "heart.slash" : "heart"
                )
            }

            Button {
                onShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Landmark Image Cache

actor LandmarkImageCache {
    static let shared = LandmarkImageCache()

    private var cache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func loadImage(city: String, country: String, size: CGSize) async -> UIImage? {
        let key = "\(city)-\(country)".lowercased()

        if let cached = cache[key] { return cached }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let coord = await Self.findLandmark(city: city, country: country) else { return nil }

            let camera = MKMapCamera(
                lookingAtCenter: coord,
                fromDistance: 1500,
                pitch: 55,
                heading: 0
            )
            let options = MKMapSnapshotter.Options()
            options.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            options.camera = camera
            options.size = size

            return (try? await MKMapSnapshotter(options: options).start())?.image
        }

        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { cache[key] = image }
        return image
    }

    private static func findLandmark(city: String, country: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(city) famous landmark"
        request.resultTypes = .pointOfInterest

        if let response = try? await MKLocalSearch(request: request).start(),
           let first = response.mapItems.first {
            return first.placemark.coordinate
        }

        if let placemarks = try? await CLGeocoder().geocodeAddressString("\(city), \(country)"),
           let loc = placemarks.first?.location {
            return loc.coordinate
        }

        return nil
    }
}

// MARK: - Landmark Background

struct LandmarkBackground: View {
    let city: String
    let country: String
    let size: CGSize

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.mapPaper2
            }
        }
        .task {
            image = await LandmarkImageCache.shared.loadImage(
                city: city,
                country: country,
                size: CGSize(width: size.width * 2, height: size.height * 2)
            )
        }
    }
}
