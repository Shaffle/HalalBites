import SwiftUI
import CoreLocation

struct ItineraryGeneratorView: View {
    let onGenerate: (Itinerary) -> Void

    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var city = ""
    @State private var country = ""
    @State private var durationDays = 3
    @State private var selectedPreferences: Set<HalalLevel> = [.halal]
    @State private var budgetLevel: BudgetLevel = .moderate
    @State private var travelDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didAutoFill = false
    @State private var useCurrentLocation = true

    private static let countries = [
        "United States", "United Kingdom", "Canada", "Australia",
        "United Arab Emirates", "Saudi Arabia", "Qatar", "Kuwait", "Bahrain", "Oman",
        "Turkey", "Malaysia", "Indonesia", "Singapore", "Pakistan", "India", "Bangladesh",
        "Egypt", "Jordan", "Lebanon", "Morocco", "Tunisia", "Algeria",
        "France", "Germany", "Netherlands", "Belgium", "Sweden", "Norway",
        "South Africa", "Nigeria", "Kenya",
        "Japan", "South Korea", "Thailand", "Philippines",
        "Brazil", "Argentina", "Mexico", "New Zealand"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Travel Date") {
                    DatePicker("Start Date", selection: $travelDate, in: Date()..., displayedComponents: .date)
                }

                Section("Trip Length") {
                    Stepper("\(durationDays) day\(durationDays == 1 ? "" : "s")", value: $durationDays, in: 1...14)
                }

                Section("Destination") {
                    Toggle("Use my current location", isOn: $useCurrentLocation)

                    if !useCurrentLocation {
                        TextField("City (e.g. Istanbul)", text: $city)
                        Picker("Country", selection: $country) {
                            Text("Select a country").tag("")
                            ForEach(Self.countries, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    } else if didAutoFill {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.teal)
                            Text("\(city), \(country)")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Detecting location…")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                }

                Section("Budget") {
                    Picker("Budget", selection: $budgetLevel) {
                        ForEach(BudgetLevel.allCases) { level in
                            Text(level.symbol).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dietary Preferences") {
                    ForEach(HalalLevel.allCases, id: \.self) { level in
                        Toggle(level.description, isOn: Binding(
                            get: { selectedPreferences.contains(level) },
                            set: { isOn in
                                if isOn {
                                    selectedPreferences.insert(level)
                                } else if selectedPreferences.count > 1 {
                                    selectedPreferences.remove(level)
                                }
                            }
                        ))
                    }
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Finding halal restaurants…")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
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
                    Button("Generate") { Task { await generate() } }
                        .disabled(!canGenerate || isLoading)
                }
            }
            .task {
                await autoFillFromLocation()
            }
            .onChange(of: location.currentLocation) { _, _ in
                if !didAutoFill && useCurrentLocation {
                    Task { await autoFillFromLocation() }
                }
            }
            .onChange(of: useCurrentLocation) { _, useCurrent in
                if useCurrent && !didAutoFill {
                    Task { await autoFillFromLocation() }
                }
                if !useCurrent {
                    city = ""
                    country = ""
                }
            }
        }
    }

    private var canGenerate: Bool {
        !city.isEmpty && !country.isEmpty
    }

    private func autoFillFromLocation() async {
        guard useCurrentLocation, let loc = location.currentLocation else { return }

        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(loc).first else { return }

        await MainActor.run {
            city = placemark.locality ?? placemark.administrativeArea ?? ""
            country = placemark.country ?? ""
            didAutoFill = true
        }
    }

    private func generate() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let itinerary = try await LocalItineraryGenerator.generate(
                city: city,
                country: country,
                days: durationDays,
                preferences: selectedPreferences,
                budget: budgetLevel,
                startDate: travelDate
            )
            await MainActor.run {
                onGenerate(itinerary)
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

