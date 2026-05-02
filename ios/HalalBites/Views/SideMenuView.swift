import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var archivedItineraries: [Itinerary]
    var onRestore: (Itinerary) -> Void

    @State private var showArchive = false
    @State private var showSettings = false

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
        .navigationDestination(isPresented: $showArchive) {
            ArchiveView(
                archivedItineraries: $archivedItineraries,
                onRestore: onRestore
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.teal)

            Text("My Profile")
                .font(.title3.bold())

            Text("Halal Explorer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .padding(.top, 40)
    }

    private var menuItems: some View {
        VStack(alignment: .leading, spacing: 4) {
            SideMenuRow(icon: "archivebox", title: "Archive", badge: archivedItineraries.count) {
                showArchive = true
                closeSideMenu()
            }

            SideMenuRow(icon: "heart", title: "Favourites") {
                closeSideMenu()
            }

            SideMenuRow(icon: "clock.arrow.circlepath", title: "Recent") {
                closeSideMenu()
            }
        }
        .padding(.vertical, 8)
    }

    private var settingsButton: some View {
        SideMenuRow(icon: "gearshape", title: "Settings") {
            showSettings = true
            closeSideMenu()
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
                        .background(.teal.opacity(0.15))
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
