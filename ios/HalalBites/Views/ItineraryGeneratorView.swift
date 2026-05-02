import SwiftUI

struct ItineraryGeneratorView: View {
    let onGenerate: (Itinerary) -> Void

    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var city = ""
    @State private var country = ""
    @State private var durationDays = 3
    @State private var minHalalLevel: HalalLevel = .level2
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("City (e.g. Athens)", text: $city)
                    TextField("Country (e.g. Greece)", text: $country)
                }

                Section("Trip Length") {
                    Stepper("\(durationDays) day\(durationDays == 1 ? "" : "s")", value: $durationDays, in: 1...14)
                }

                Section("Halal Standard") {
                    Picker("Minimum Level", selection: $minHalalLevel) {
                        ForEach([HalalLevel.level1, .level2, .level3], id: \.self) { level in
                            Text(level.description).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Plan a Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Generate") { Task { await generate() } }
                            .disabled(city.isEmpty || country.isEmpty)
                    }
                }
            }
        }
    }

    private func generate() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.generateItinerary(city: city, country: country, days: durationDays, halalLevel: minHalalLevel)
            await MainActor.run {
                onGenerate(result)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
