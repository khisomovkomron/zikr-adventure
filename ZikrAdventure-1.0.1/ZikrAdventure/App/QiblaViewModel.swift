import CoreLocation
import SwiftUI
import ZikrCore

struct QiblaPlace: Equatable {
    let point: GeoPoint
    let accuracy: Double
    let timestamp: Date
}

@MainActor
final class QiblaViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var place: QiblaPlace?
    @Published private(set) var permission: CLAuthorizationStatus = .notDetermined
    @Published private(set) var heading: Double?
    @Published private(set) var magneticHeading: Double?
    @Published private(set) var headingAccuracy: Double?
    @Published private(set) var headingTime: Date?
    @Published private(set) var locationFailed = false
    private let manager: CLLocationManager
    private var visible = false

    init(defaults: UserDefaults? = .standard, manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        // Старый экспериментальный ручной режим больше не используется.
        defaults?.removeObject(forKey: "qibla.lastPlace.v1")
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
        permission = manager.authorizationStatus
    }

    var hasLocationPermission: Bool { permission == .authorizedWhenInUse || permission == .authorizedAlways }
    var isDenied: Bool { permission == .denied || permission == .restricted }

    func bearing(at now: Date) -> Double? {
        guard visible, hasLocationPermission, let place,
              (0...120).contains(now.timeIntervalSince(place.timestamp)) else { return nil }
        return QiblaDirection.bearing(from: place.point)
    }

    private func validHeading(at now: Date) -> Bool {
        guard visible, let accuracy = headingAccuracy, (0...20).contains(accuracy),
              let time = headingTime else { return false }
        return (0...15).contains(now.timeIntervalSince(time))
    }

    func offset(at now: Date) -> Double? {
        guard validHeading(at: now), let bearing = bearing(at: now), let heading else { return nil }
        return QiblaDirection.offset(bearing: bearing, heading: heading)
    }

    /// Север не зависит от направления киблы. Без геолокации это магнитный север.
    func northHeading(at now: Date) -> Double? {
        guard validHeading(at: now) else { return nil }
        if hasLocationPermission, bearing(at: now) != nil, let heading { return heading }
        return magneticHeading
    }

    func start() {
        visible = true
        permission = manager.authorizationStatus
        // Магнитный компас не запрашивает координаты пользователя.
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        if hasLocationPermission { manager.startUpdatingLocation() }
        else { manager.stopUpdatingLocation(); place = nil; heading = nil }
    }

    func stop() {
        visible = false
        manager.stopUpdatingHeading(); manager.stopUpdatingLocation()
        place = nil; heading = nil; magneticHeading = nil; headingAccuracy = nil; headingTime = nil
    }

    /// Пояснение и отдельная кнопка предшествуют системному запросу.
    func usePhoneLocation() {
        visible = true
        locationFailed = false
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { start() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permission = manager.authorizationStatus
        if !hasLocationPermission { place = nil; heading = nil }
        if visible { start() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard visible, hasLocationPermission, let location = locations.last,
              (0...10_000).contains(location.horizontalAccuracy),
              (0...120).contains(Date().timeIntervalSince(location.timestamp)) else { return }
        let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        guard point.isValid else { return }
        place = QiblaPlace(point: point, accuracy: location.horizontalAccuracy, timestamp: location.timestamp)
        locationFailed = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard visible else { return }
        heading = hasLocationPermission && (0..<360).contains(newHeading.trueHeading) ? newHeading.trueHeading : nil
        magneticHeading = (0..<360).contains(newHeading.magneticHeading) ? newHeading.magneticHeading : nil
        headingAccuracy = newHeading.headingAccuracy >= 0 ? newHeading.headingAccuracy : nil
        headingTime = newHeading.timestamp
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { visible }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationFailed = true
        place = nil; heading = nil
    }
}
