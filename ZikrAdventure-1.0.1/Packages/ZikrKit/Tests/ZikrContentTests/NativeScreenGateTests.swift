// NativeScreenGateTests.swift
// ZKR-48: нативный «Инфо» показывается только когда флаг включён, выбрана вкладка Info
// и веб-онбординг точно не показан; иначе остаётся веб-экран (поведение 1.1.1).

import XCTest
@testable import ZikrContent

final class NativeScreenGateTests: XCTestCase {
    func testShowsNativeOnlyWhenAllConditionsHold() {
        XCTAssertTrue(NativeScreenGate.shouldShowNativeInfo(isEnabled: true, isInfoSelected: true, isWebOnboardingVisible: false))
    }

    func testFlagOffKeepsWeb() {
        XCTAssertFalse(NativeScreenGate.shouldShowNativeInfo(isEnabled: false, isInfoSelected: true, isWebOnboardingVisible: false))
    }

    func testOtherTabKeepsWeb() {
        XCTAssertFalse(NativeScreenGate.shouldShowNativeInfo(isEnabled: true, isInfoSelected: false, isWebOnboardingVisible: false))
    }

    func testOnboardingVisibleOrUnknownKeepsWeb() {
        XCTAssertFalse(NativeScreenGate.shouldShowNativeInfo(isEnabled: true, isInfoSelected: true, isWebOnboardingVisible: true))
        XCTAssertFalse(NativeScreenGate.shouldShowNativeInfo(isEnabled: true, isInfoSelected: true, isWebOnboardingVisible: nil))
    }

    func testOnboardingTrackerLatchesFinished() {
        var tracker = WebOnboardingTracker()
        XCTAssertNil(tracker.isVisible)
        tracker.record(nil)
        XCTAssertNil(tracker.isVisible)
        tracker.record(true)
        XCTAssertEqual(tracker.isVisible, true)
        tracker.record(false)
        XCTAssertEqual(tracker.isVisible, false)
        // Онбординг не возвращается (сброс прогресса сохраняет onboarded = true):
        // после «завершён» ответы nil/true (страница перезагружается) не откатывают состояние.
        tracker.record(nil)
        XCTAssertEqual(tracker.isVisible, false)
        tracker.record(true)
        XCTAssertEqual(tracker.isVisible, false)
    }
}
