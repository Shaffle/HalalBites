import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var itineraries: [Itinerary]
    @Binding var archivedItineraries: [Itinerary]
    @Binding var recentlyDeleted: [Itinerary]
    @Binding var favouriteIDs: Set<UUID>
    @Binding var favouriteRestaurantIDs: Set<UUID>
    @Binding var exploreFavouriteRestaurants: [Restaurant]
    var onRestore: (Itinerary) -> Void

    @State private var showArchive = false
    @State private var showFavourites = false
    @State private var showRecent = false
    @State private var showSettings = false
    @State private var showProfile = false
    @AppStorage("lightsOn") private var lightsOn = true

    private let menuWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                profileHeader
                Divider()
                menuItems
                Spacer()
                Divider()
                settingsButton
            }
            .frame(width: menuWidth)
            .background(Color(.systemBackground))

            Spacer()
        }
        .offset(x: isShowing ? 0 : -menuWidth)
        .sheet(isPresented: $showArchive) {
            NavigationStack {
                ArchiveView(
                    archivedItineraries: $archivedItineraries,
                    favouriteIDs: $favouriteIDs,
                    favouriteRestaurantIDs: $favouriteRestaurantIDs,
                    recentlyDeleted: $recentlyDeleted,
                    onRestore: onRestore
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showArchive = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showFavourites) {
            NavigationStack {
                FavouritesView(
                    itineraries: itineraries,
                    archivedItineraries: archivedItineraries,
                    favouriteIDs: $favouriteIDs,
                    favouriteRestaurantIDs: $favouriteRestaurantIDs,
                    exploreFavouriteRestaurants: exploreFavouriteRestaurants
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showFavourites = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showRecent) {
            NavigationStack {
                RecentView(
                    itineraries: itineraries,
                    archivedItineraries: archivedItineraries,
                    recentlyDeleted: $recentlyDeleted,
                    onRestore: onRestore
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showRecent = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileEditorView()
        }
    }

    @AppStorage("profileName") private var profileName = "My Profile"
    @AppStorage("profileCity") private var profileCity = ""
    @AppStorage("profileImageData") private var profileImageData: Data?

    private var profileHeader: some View {
        Button {
            closeSideMenu()
            showProfile = true
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if let data = profileImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.teal)
                    }

                    Text(profileName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    if !profileCity.isEmpty {
                        Text(profileCity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .padding(.top, 40)
    }

    private var menuItems: some View {
        VStack(alignment: .leading, spacing: 4) {
            SideMenuRow(icon: "archivebox", title: "Archive", badge: archivedItineraries.count) {
                closeSideMenu()
                showArchive = true
            }

            SideMenuRow(icon: "heart", title: "Favourites", badge: favouriteIDs.count + favouriteRestaurantIDs.count) {
                closeSideMenu()
                showFavourites = true
            }

            SideMenuRow(icon: "clock.arrow.circlepath", title: "Recent") {
                closeSideMenu()
                showRecent = true
            }
        }
        .padding(.vertical, 8)
    }

    private var settingsButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            SideMenuRow(icon: "gearshape", title: "Settings") {
                closeSideMenu()
                showSettings = true
            }
            HStack(spacing: 14) {
                Image(systemName: lightsOn ? "sun.max.fill" : "moon.fill")
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(.teal)
                Text("Lights")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $lightsOn)
                    .labelsHidden()
                    .tint(.teal)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .padding(.bottom, 30)
    }

    private func closeSideMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isShowing = false
        }
    }
}

struct SideMenuRow: View {
    let icon: String
    let title: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(.teal)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.teal.opacity(0.2))
                        .foregroundStyle(.teal)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}
