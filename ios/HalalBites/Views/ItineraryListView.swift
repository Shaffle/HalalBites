import SwiftUI

struct ItineraryListView: View {
    @EnvironmentObject var api: APIClient
    @State private var itineraries: [Itinerary] = []
    @State private var isGenerating = false
    @State private var showingGenerator = false

    var body: some View {
        NavigationStack {
            Group {
                if itineraries.isEmpty && !isGenerating {
                    emptyState
                } else {
                    List(itineraries) { itinerary in
                        NavigationLink(destination: ItineraryDetailView(itinerary: itinerary)) {
                            ItineraryRowView(itinerary: itinerary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Itineraries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingGenerator = true }) {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingGenerator) {
                ItineraryGeneratorView(onGenerate: handleGenerated)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No itineraries yet")
                .font(.title2.bold())
            Text("Tap the sparkle button to generate your first halal travel itinerary.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func handleGenerated(_ itinerary: Itinerary) {
        itineraries.insert(itinerary, at: 0)
    }
}

struct ItineraryRowView: View {
    let itinerary: Itinerary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(itinerary.city), \(itinerary.country)")
                .font(.headline)
            Text("\(itinerary.durationDays) days · \(itinerary.days.flatMap(\.stops).count) stops")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
