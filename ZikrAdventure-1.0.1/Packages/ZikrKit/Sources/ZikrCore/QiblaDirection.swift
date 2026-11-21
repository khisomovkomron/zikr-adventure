import Foundation

public struct GeoPoint: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public enum QiblaDirection {
    public static let kaaba = GeoPoint(latitude: 21.4225, longitude: 39.8262)
    /// Визуальный сектор наведения, не религиозное заключение о намазе.
    public static let guidanceHalfAngle = 15.0

    /// Начальный азимут дуги большого круга относительно истинного севера.
    /// В самой Каабе, антиподе и на полюсе единственного направления нет.
    public static func bearing(from point: GeoPoint) -> Double? {
        guard point.isValid, abs(point.latitude) < 90 else { return nil }
        let radians = Double.pi / 180
        let phi = point.latitude * radians, target = kaaba.latitude * radians
        let delta = (kaaba.longitude - point.longitude) * radians
        let y = sin(delta) * cos(target)
        let x = cos(phi) * sin(target) - sin(phi) * cos(target) * cos(delta)
        guard hypot(x, y) > 1e-12 else { return nil }
        return normalize(atan2(y, x) / radians)
    }

    public static func normalize(_ angle: Double) -> Double {
        let result = angle.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    public static func distanceToKaaba(from point: GeoPoint) -> Double? {
        guard point.isValid else { return nil }
        let r = Double.pi / 180
        let dPhi = (kaaba.latitude - point.latitude) * r
        let dLambda = (kaaba.longitude - point.longitude) * r
        let a = pow(sin(dPhi / 2), 2) + cos(point.latitude * r) * cos(kaaba.latitude * r) * pow(sin(dLambda / 2), 2)
        return 6_371_008.8 * 2 * asin(sqrt(min(1, max(0, a))))
    }

    /// Знак + — повернуть вправо; кратчайшая дуга корректна на границе 0/360.
    public static func offset(bearing: Double, heading: Double) -> Double {
        normalize(bearing - heading + 180) - 180
    }

    /// Сигнал допускается, только когда весь интервал заявленной ошибки курса
    /// внутри сектора. Погрешность датчика не прибавляется к разрешённому углу.
    public static func isWithinGuide(offset: Double, accuracy: Double) -> Bool {
        offset.isFinite && accuracy.isFinite && accuracy >= 0 && abs(offset) + accuracy <= guidanceHalfAngle
    }
}
