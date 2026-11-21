import CoreLocation
import SwiftUI
import ZikrCore

struct QiblaPlace: Codable, Equatable {
    let point: GeoPoint
    let city: String? // nil — координаты телефона; не адрес/аккаунт пользователя.
    let accuracy: Double?
    let timestamp: Date
}

@MainActor
final class QiblaViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let storageKey = "qibla.lastPlace.v1"
    static let cities: [(id: String, point: GeoPoint)] = [
        ("dushanbe", GeoPoint(latitude: 38.5598, longitude: 68.7870)),
        ("moscow", GeoPoint(latitude: 55.7558, longitude: 37.6173)),
        ("istanbul", GeoPoint(latitude: 41.0082, longitude: 28.9784)),
        ("london", GeoPoint(latitude: 51.5074, longitude: -0.1278)),
        ("newYork", GeoPoint(latitude: 40.7128, longitude: -74.0060))
    ]
    @Published private(set) var place: QiblaPlace?
    @Published private(set) var permission: CLAuthorizationStatus = .notDetermined
    @Published private(set) var heading: Double?
    @Published private(set) var headingAccuracy: Double?
    @Published private(set) var headingTime: Date?
    @Published private(set) var locationFailed = false
    @Published private(set) var headingAvailable = false
    @Published private(set) var aligned = false
    private let manager: CLLocationManager
    private let defaults: UserDefaults?
    private var visible = false
    private var manual = false

    init(defaults: UserDefaults? = .standard, manager: CLLocationManager = CLLocationManager()) {
        self.defaults = defaults; self.manager = manager
        super.init()
        if let data = defaults?.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(QiblaPlace.self, from: data), saved.point.isValid {
            place = saved
            manual = saved.city != nil
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10
        manager.headingFilter = 1
        // Приложение поддерживает только портретную ориентацию.
        manager.headingOrientation = .portrait
        permission = manager.authorizationStatus
        headingAvailable = CLLocationManager.headingAvailable()
    }

    var bearing: Double? { place.flatMap { QiblaDirection.bearing(from: $0.point) } }
    var isDenied: Bool { permission == .denied || permission == .restricted }

    var combinedAccuracy: Double {
        guard let headingAccuracy, let place else { return 360 }
        guard let accuracy = place.accuracy,
              let distance = QiblaDirection.distanceToKaaba(from: place.point) else { return headingAccuracy }
        // Азимут неустойчив также около антипода Каабы.
        let separation = min(distance, Double.pi * 6_371_008.8 - distance)
        guard separation > accuracy else { return 360 }
        return headingAccuracy + atan2(accuracy, separation - accuracy) * 180 / .pi
    }

    func offset(at now: Date) -> Double? {
        guard visible, let bearing, let heading, let accuracy = headingAccuracy,
              accuracy >= 0, accuracy <= 20, let time = headingTime,
              (0...15).contains(now.timeIntervalSince(time)), let place,
              place.city != nil || (0...120).contains(now.timeIntervalSince(place.timestamp)) else { return nil }
        return QiblaDirection.offset(bearing: bearing, heading: heading)
    }

    func start() {
        visible = true
        permission = manager.authorizationStatus
        if permission == .authorizedWhenInUse || permission == .authorizedAlways {
            // При новом входе/возврате предпочитаем телефон сохранённому городу.
            manual = false
            manager.startUpdatingLocation()
            if headingAvailable { manager.startUpdatingHeading() }
        }
    }

    func stop() {
        visible = false
        manager.stopUpdatingHeading(); manager.stopUpdatingLocation()
        heading = nil; headingAccuracy = nil; headingTime = nil; aligned = false
    }

    /// Вызывается только кнопкой после пояснения, не при открытии экрана.
    func usePhoneLocation() {
        visible = true
        manual = false
        locationFailed = false
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { start() }
    }

    func choose(_ city: String, point: GeoPoint) {
        guard point.isValid else { return }
        manual = true
        place = QiblaPlace(point: point, city: city, accuracy: nil, timestamp: Date())
        aligned = false
        save()
    }

    func forget() {
        stop()
        manual = false; place = nil
        defaults?.removeObject(forKey: Self.storageKey)
    }

    private func save() {
        if let place, let data = try? JSONEncoder().encode(place) { defaults?.set(data, forKey: Self.storageKey) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permission = manager.authorizationStatus
        if isDenied { stop() }
        else if visible { start() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard visible, !manual, let location = locations.last,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 10_000,
              (0...120).contains(Date().timeIntervalSince(location.timestamp)) else { return }
        let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        guard point.isValid else { return }
        place = QiblaPlace(point: point, city: nil, accuracy: location.horizontalAccuracy, timestamp: location.timestamp)
        locationFailed = false
        aligned = false
        save()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard visible else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : nil
        headingAccuracy = newHeading.headingAccuracy >= 0 ? newHeading.headingAccuracy : nil
        headingTime = newHeading.timestamp
        let next = offset(at: Date()).map { QiblaDirection.isWithinGuide(offset: $0, accuracy: combinedAccuracy) } ?? false
        aligned = next
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { visible }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationFailed = true
        heading = nil; aligned = false
    }
}
