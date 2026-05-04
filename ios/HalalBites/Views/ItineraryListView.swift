import SwiftUI

struct ItineraryListView: View {
    @Binding var itineraries: [Itinerary]
    @State private var showingGenerator = false
    @State private var presentedItinerary: Itinerary?
    @State private var showConfetti = false
    @Binding var showSideMenu: Bool
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]

    var body: some View {
        NavigationStack {
            Group {
                if itineraries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(itineraries) { itinerary in
                            Button {
                                presentedItinerary = itinerary
                            } label: {
                                ItineraryRowView(itinerary: itinerary, isFavourite: favouriteIDs.contains(itinerary.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteItinerary(itinerary)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    archiveItinerary(itinerary)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Itineraries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !itineraries.isEmpty {
                        Button(action: { showingGenerator = true }) {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGenerator) {
                ItineraryGeneratorView(onGenerate: handleGenerated)
            }
            .fullScreenCover(item: $presentedItinerary) { presented in
                if let idx = itineraries.firstIndex(where: { $0.id == presented.id }) {
                    ZStack {
                        NavigationStack {
                            ItineraryDetailView(itinerary: $itineraries[idx], favouriteRestaurantIDs: $favouriteRestaurantIDs)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done") { presentedItinerary = nil }
                                    }
                                }
                        }

                        if showConfetti {
                            ConfettiView()
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }
                    }
                    .onAppear {
                        if showConfetti {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showConfetti = false }
                            }
                        }
                    }
                }
            }
            .onAppear { archiveEndedTrips() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 72))
                .foregroundStyle(.teal)

            Text("No trips planned")
                .font(.title2.bold())

            Button {
                showingGenerator = true
            } label: {
                HStack(spacing: 8) {
                    Text("Tap here")
                    Image(systemName: "sparkles")
                    Text("to start!")
                }
                .font(.title3.bold())
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.teal)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func handleGenerated(_ itinerary: Itinerary) {
        itineraries.insert(itinerary, at: 0)
        showConfetti = true
        presentedItinerary = itinerary
    }

    private func deleteItinerary(_ itinerary: Itinerary) {
        withAnimation {
            itineraries.removeAll { $0.id == itinerary.id }
            favouriteIDs.remove(itinerary.id)
            if !recentlyDeleted.contains(where: { $0.id == itinerary.id }) {
                recentlyDeleted.insert(itinerary, at: 0)
            }
        }
    }

    private func archiveItinerary(_ itinerary: Itinerary) {
        withAnimation {
            itineraries.removeAll { $0.id == itinerary.id }
            if !archivedItineraries.contains(where: { $0.id == itinerary.id }) {
                archivedItineraries.insert(itinerary, at: 0)
            }
        }
    }

    private func archiveEndedTrips() {
        let ended = itineraries.filter { $0.hasEnded }
        guard !ended.isEmpty else { return }
        withAnimation {
            for trip in ended {
                itineraries.removeAll { $0.id == trip.id }
                if !archivedItineraries.contains(where: { $0.id == trip.id }) {
                    archivedItineraries.insert(trip, at: 0)
                }
            }
        }
    }
}

struct ItineraryRowView: View {
    let itinerary: Itinerary
    var isFavourite: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(itinerary.tripName)
                        .font(.headline)
                    if itinerary.isShared {
                        Text("Shared")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text("\(itinerary.city), \(itinerary.country) · \(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFavourite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animate = false

    private static let colors: [Color] = [.teal, .orange, .pink, .purple, .yellow, .green, .blue, .red]
    private static let emojis = ["🎉", "🎊", "✨", "⭐", "🌟"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(
                            x: particle.x * geo.size.width,
                            y: animate ? geo.size.height + 50 : -50
                        )
                        .rotationEffect(.degrees(animate ? particle.rotation : 0))
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: particle.duration)
                            .delay(particle.delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            particles = (0..<50).map { _ in
                ConfettiParticle(
                    emoji: Bool.random() ? Self.emojis.randomElement()! : "●",
                    x: Double.random(in: 0...1),
                    size: CGFloat.random(in: 12...28),
                    rotation: Double.random(in: 180...720),
                    duration: Double.random(in: 2.0...3.5),
                    delay: Double.random(in: 0...0.8),
                    color: Self.colors.randomElement()!
                )
            }
            animate = true
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let x: Double
    let size: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
    let color: Color
}
