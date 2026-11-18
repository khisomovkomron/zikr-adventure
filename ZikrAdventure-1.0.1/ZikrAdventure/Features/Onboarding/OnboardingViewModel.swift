import Foundation
import Combine
import ZikrDomain

struct OnboardingStatus: Decodable {
    let onboarded: Bool
    let language: String
}

@MainActor
protocol OnboardingCommandSink {
    func status() async -> OnboardingStatus?
    func complete() async -> Bool
}

@MainActor
struct WebOnboardingCommandSink: OnboardingCommandSink {
    func status() async -> OnboardingStatus? {
        guard let json = await WebViewManager.shared.evaluateQuery("window.zikrNative.onboardingStatus()"),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(OnboardingStatus.self, from: data)
    }
    func complete() async -> Bool {
        await WebViewManager.shared.evaluateCommand("window.zikrNative.completeOnboarding()")
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var isVisible: Bool?
    @Published private(set) var page = 0
    @Published private(set) var isBusy = false
    @Published private(set) var hasError = false
    let localization: LocalizationService
    private var mutationRevision = 0
    private let sink: any OnboardingCommandSink
    private let settings: any SettingsCommandSink

    init(sink: any OnboardingCommandSink, settings: any SettingsCommandSink, localization: LocalizationService) {
        self.sink = sink
        self.settings = settings
        self.localization = localization
    }

    func refresh() async {
        guard !isBusy else { return }
        let revision = mutationRevision
        guard let status = await sink.status(), !isBusy, revision == mutationRevision else { return }
        localization.setLanguage(code: status.language)
        if isVisible != !status.onboarded { isVisible = !status.onboarded }
    }

    func start() async {
        while !Task.isCancelled, isVisible != false {
            await refresh()
            do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
        }
    }

    func next() async {
        guard !isBusy, isVisible == true else { return }
        if page < 2 { page += 1 } else { await finish() }
    }

    func finish() async {
        guard !isBusy, isVisible == true else { return }
        mutationRevision += 1
        isBusy = true
        hasError = false
        defer { isBusy = false }
        guard await sink.complete() else { hasError = true; return }
        isVisible = false
    }

    func selectLanguage(_ language: AppLanguage) async {
        guard !isBusy else { return }
        mutationRevision += 1
        isBusy = true
        hasError = false
        defer { isBusy = false }
        if await settings.setLanguage(language) { localization.setLanguage(language) }
        else { hasError = true }
    }
}
