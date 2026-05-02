import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("distanceUnit") private var distanceUnit = "miles"
    @AppStorage("searchRadius") private var searchRadius = 10.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showClosedPlaces") private var showClosedPlaces = false
    @AppStorage("mapType") private var mapType = "standard"
    @AppStorage("autoDetectLocation") private var autoDetectLocation = true

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    Toggle("Auto-detect location", isOn: $autoDetectLocation)

                    Picker("Distance unit", selection: $distanceUnit) {
                        Text("Miles").tag("miles")
                        Text("Kilometres").tag("km")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search radius: \(Int(searchRadius)) \(distanceUnit == "miles" ? "mi" : "km")")
                        Slider(value: $searchRadius, in: 1...50, step: 1)
                            .tint(.teal)
                    }

                    Button("Open Location Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("Map") {
                    Picker("Map style", selection: $mapType) {
                        Text("Standard").tag("standard")
                        Text("Satellite").tag("satellite")
                        Text("Hybrid").tag("hybrid")
                    }

                    Toggle("Show closed places", isOn: $showClosedPlaces)
                }

                Section("Notifications") {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                }

                Section("Data") {
                    Button("Clear cached data") {}
                        .foregroundStyle(.red)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
