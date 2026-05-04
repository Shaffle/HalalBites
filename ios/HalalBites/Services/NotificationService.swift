import Foundation
import CoreLocation
import UserNotifications

class NotificationService: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    @Published var isAuthorized = false

    private let locationManager = CLLocationManager()
    private let center = UNUserNotificationCenter.current()
    private var monitoredStops: [String: MonitoredStop] = [:]

    private struct MonitoredStop {
        let restaurantName: String
        let mealType: String
        let tripName: String
    }

    override init() {
        super.init()
        locationManager.delegate = self
        center.delegate = self
        refreshAuthorizationStatus()
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.requestAlwaysLocation()
                }
            }
        }
    }

    func updateMonitoredStops(from itineraries: [Itinerary]) {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredStops.removeAll()

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              isAuthorized else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var candidates: [(stop: ItineraryStop, tripName: String)] = []

        for itinerary in itineraries where !itinerary.hasEnded {
            let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: itinerary.startDate), to: today).day ?? 0
            let currentDay = daysSinceStart + 1

            for day in itinerary.days where day.dayNumber == currentDay || day.dayNumber == currentDay + 1 {
                for stop in day.stops {
                    candidates.append((stop, itinerary.tripName))
                }
            }
        }

        for item in candidates.prefix(20) {
            let stop = item.stop
            let id = stop.id.uuidString

            let region = CLCircularRegion(
                center: stop.restaurant.coordinate,
                radius: 200,
                identifier: id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            monitoredStops[id] = MonitoredStop(
                restaurantName: stop.restaurant.name,
                mealType: stop.mealType.rawValue.capitalized,
                tripName: item.tripName
            )

            locationManager.startMonitoring(for: region)
        }
    }

    func scheduleDailyReminders(for itineraries: [Itinerary]) {
        center.removePendingNotificationRequests(withIdentifiers:
            itineraries.map { "daily-\($0.id.uuidString)" }
        )

        guard isAuthorized else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for itinerary in itineraries where !itinerary.hasEnded {
            let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: itinerary.startDate), to: today).day ?? 0
            let currentDay = daysSinceStart + 1

            guard let day = itinerary.days.first(where: { $0.dayNumber == currentDay }),
                  let firstStop = day.stops.first else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Today's \(itinerary.tripName) Plan"
            if day.stops.count == 1 {
                content.body = "You have 1 stop today: \(firstStop.restaurant.name) for \(firstStop.mealType.rawValue)."
            } else {
                content.body = "You have \(day.stops.count) stops today. First up: \(firstStop.restaurant.name) for \(firstStop.mealType.rawValue)!"
            }
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
            dateComponents.hour = 8
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily-\(itinerary.id.uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let item = monitoredStops[region.identifier] else { return }

        let content = UNMutableNotificationContent()
        content.title = "You're near \(item.restaurantName)!"
        content.body = "Your \(item.mealType.lowercased()) stop for \(item.tripName) is close by. Enjoy your meal!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "proximity-\(region.identifier)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - Private

    private func requestAlwaysLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    private func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
}
