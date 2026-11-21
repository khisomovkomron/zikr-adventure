import XCTest
@testable import ZikrCore

final class QiblaDirectionTests: XCTestCase {
    func testCitiesAgainstIndependentVectorCalculation() throws {
        // Эталон вычислен через 3D-векторы: проекция вектора Каабы на
        // локальные East/North в точке города, независимо от формулы bearing.
        for point in [GeoPoint(latitude: 38.5598, longitude: 68.7870),
                      GeoPoint(latitude: 55.7558, longitude: 37.6173),
                      GeoPoint(latitude: 41.0082, longitude: 28.9784),
                      GeoPoint(latitude: 51.5074, longitude: -0.1278),
                      GeoPoint(latitude: 40.7128, longitude: -74.0060)] {
            let r = Double.pi / 180
            let p = point.latitude * r, l = point.longitude * r
            let t = QiblaDirection.kaaba.latitude * r, a = QiblaDirection.kaaba.longitude * r
            let target = (x: cos(t) * cos(a), y: cos(t) * sin(a), z: sin(t))
            let east = -sin(l) * target.x + cos(l) * target.y
            let north = -sin(p) * cos(l) * target.x - sin(p) * sin(l) * target.y + cos(p) * target.z
            let reference = QiblaDirection.normalize(atan2(east, north) / r)
            XCTAssertEqual(try XCTUnwrap(QiblaDirection.bearing(from: point)), reference, accuracy: 0.001)
        }
    }
    func testCardinalsAndWrap() throws {
        XCTAssertEqual(try XCTUnwrap(QiblaDirection.bearing(from: GeoPoint(latitude: 0, longitude: 39.8262))), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(QiblaDirection.bearing(from: GeoPoint(latitude: 40, longitude: 39.8262))), 180, accuracy: 0.001)
        XCTAssertEqual(QiblaDirection.offset(bearing: 1, heading: 359), 2)
        XCTAssertEqual(QiblaDirection.offset(bearing: 359, heading: 1), -2)
    }
    func testInvalidAndUndefined() {
        XCTAssertEqual(QiblaDirection.distanceToKaaba(from: QiblaDirection.kaaba), 0)
        XCTAssertNil(QiblaDirection.distanceToKaaba(from: GeoPoint(latitude: 91, longitude: 0)))
        for p in [QiblaDirection.kaaba, GeoPoint(latitude: -21.4225, longitude: -140.1738),
                  GeoPoint(latitude: 90, longitude: 0), GeoPoint(latitude: .nan, longitude: 0),
                  GeoPoint(latitude: 0, longitude: 181)] {
            XCTAssertNil(QiblaDirection.bearing(from: p))
        }
    }
    func testGuideAccountsForSensorError() {
        XCTAssertTrue(QiblaDirection.isWithinGuide(offset: 10, accuracy: 5))
        XCTAssertTrue(QiblaDirection.isWithinGuide(offset: -15, accuracy: 0))
        XCTAssertFalse(QiblaDirection.isWithinGuide(offset: 10, accuracy: 6))
        XCTAssertFalse(QiblaDirection.isWithinGuide(offset: 0, accuracy: -1))
        XCTAssertFalse(QiblaDirection.isWithinGuide(offset: .nan, accuracy: 1))
    }
}
