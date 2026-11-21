import Foundation
import ZikrCore

@MainActor
final class HijriCalendarModel: ObservableObject {
    @Published private(set) var engine: HijriCalendarEngine
    @Published private(set) var storageError = false
    private let preferences: HijriCalendarPreferences
    init(defaults: UserDefaults = .standard) {
        preferences = HijriCalendarPreferences(defaults: defaults)
        do { engine = try preferences.load() }
        catch { engine = try! HijriCalendarEngine(); storageError = true }
    }
    @discardableResult
    func set(_ month: HijriMonth, day: Int?) -> Bool {
        var anchors = engine.anchors.filter { $0.month != month }
        // A previously selected end may no longer be 29/30 days after the new start.
        // Reject the edit instead of silently deleting a locally announced date.
        if let day { anchors.append(.init(month: month, day: day)) }
        do {
            let next = try preferences.save(anchors)
            engine = next; storageError = false
            return true
        } catch { return false }
    }
    func reset(year: Int) {
        let anchors = engine.anchors.filter { $0.month.year != year }
        guard let next = try? preferences.save(anchors) else { return }
        engine = next; storageError = false
    }
}
