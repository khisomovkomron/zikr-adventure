import XCTest
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private func make(_ onboarded: Bool? = false) -> (OnboardingViewModel, OnboardingSinkStub, FakeSettingsSink) {
        let sink = OnboardingSinkStub()
        sink.value = onboarded.map { OnboardingStatus(onboarded: $0, language: "ru") }
        let settings = FakeSettingsSink()
        return (OnboardingViewModel(sink: sink, settings: settings,
                    localization: LocalizationService(language: .en, defaults: nil)), sink, settings)
    }

    func testRestoredStatusInitializesWithoutIntermediateModal() {
        let model = OnboardingViewModel(sink: OnboardingSinkStub(), settings: FakeSettingsSink(),
            localization: LocalizationService(language: .en, defaults: nil),
            initialStatus: OnboardingStatus(onboarded: true, language: "ky"))
        XCTAssertEqual(model.isVisible, false)
        XCTAssertEqual(model.localization.language, .ky)
    }

    func testWaitsForRestoredState() async {
        let (model, sink, _) = make(nil)
        await model.refresh()
        XCTAssertNil(model.isVisible)
        await model.finish()
        XCTAssertEqual(sink.completions, 0)
        sink.value = OnboardingStatus(onboarded: true, language: "tg")
        await model.refresh()
        XCTAssertEqual(model.isVisible, false)
        XCTAssertEqual(model.localization.language, .tg)
    }

    func testThreeStepsAndRelaunch() async {
        let (model, sink, _) = make()
        await model.refresh()
        XCTAssertEqual(model.isVisible, true)
        await model.next(); XCTAssertEqual(model.page, 1)
        await model.next(); XCTAssertEqual(model.page, 2)
        await model.next(); XCTAssertEqual(model.isVisible, false)
        await model.finish(); XCTAssertEqual(sink.completions, 1)
        await model.refresh(); XCTAssertEqual(model.isVisible, false)
    }

    func testSkipEachPageAndRetryFailure() async {
        for page in 0...2 {
            let (model, sink, _) = make()
            await model.refresh()
            for _ in 0..<page { await model.next() }
            sink.succeeds = false
            await model.finish()
            XCTAssertTrue(model.hasError)
            XCTAssertEqual(model.isVisible, true)
            XCTAssertFalse(model.isBusy)
            sink.succeeds = true
            await model.finish()
            XCTAssertEqual(model.isVisible, false)
            XCTAssertFalse(model.hasError)
        }
    }

    func testLanguagePersistsOnlyOnSuccessWithoutChangingStep() async {
        let (model, _, settings) = make()
        await model.refresh(); await model.next()
        for language in AppLanguage.allCases {
            await model.selectLanguage(language)
            XCTAssertEqual(model.localization.language, language)
            XCTAssertEqual(model.page, 1)
        }
        settings.result = false
        await model.selectLanguage(.en)
        XCTAssertTrue(model.hasError)
        XCTAssertNotEqual(model.localization.language, .en)
    }

    func testConcurrentCompletionIsSentOnce() async {
        let (model, sink, _) = make()
        await model.refresh()
        sink.delays = true
        let first = Task { await model.finish() }
        while sink.continuation == nil { await Task.yield() }
        await model.finish()
        await model.next()
        XCTAssertEqual(sink.completions, 1)
        sink.resume()
        await first.value
        XCTAssertEqual(model.isVisible, false)
    }
}

@MainActor
private final class OnboardingSinkStub: OnboardingCommandSink {
    var value: OnboardingStatus?
    var succeeds = true
    var completions = 0
    var delays = false
    var continuation: CheckedContinuation<Void, Never>?
    func status() async -> OnboardingStatus? { value }
    func complete() async -> Bool {
        completions += 1
        if delays { await withCheckedContinuation { continuation = $0 } }
        if succeeds { value = OnboardingStatus(onboarded: true, language: value?.language ?? "ru") }
        return succeeds
    }
    func resume() { continuation?.resume(); continuation = nil }
}
