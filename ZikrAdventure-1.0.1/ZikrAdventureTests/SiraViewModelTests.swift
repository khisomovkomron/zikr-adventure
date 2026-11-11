// SiraViewModelTests.swift
// ZKR-53: экран «Путь Сиры» — группы и строки как renderPath(), метки «Новое» по снимку при показе вкладки,
// «Читать» / «На карте» / лист главы → команды в веб, предпросмотр, distText(), «Изучить» из баннера «Зикра».

import XCTest
import ZikrContent
import ZikrCore
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class FakeSiraSink: SiraCommandSink {
    enum Call: Equatable {
        case markViewed(String), showChapter(String), explore(String)
    }

    var calls: [Call] = []
    /// Как веб: markViewed → viewed + persist → снимок в zikr-state.json.
    var onViewed: ((String) -> Void)?

    func markViewed(chapterID: String) async -> Bool {
        calls.append(.markViewed(chapterID))
        onViewed?(chapterID)
        return true
    }

    func showChapter(chapterID: String) async -> Bool {
        calls.append(.showChapter(chapterID))
        onViewed?(chapterID)
        return true
    }

    func explore(chapterID: String) async -> Bool {
        calls.append(.explore(chapterID))
        onViewed?(chapterID)
        return true
    }
}

@MainActor
final class FakeWebCommands: WebCommandEvaluating {
    var scripts: [String] = []
    func evaluateCommand(_ script: String) async -> Bool {
        scripts.append(script)
        return true
    }
}

@MainActor
final class SiraViewModelTests: XCTestCase {
    private var repository: FakeProgressRepository!
    private var sink: FakeSiraSink!
    private var localization: LocalizationService!
    private var viewModel: SiraViewModel!
    private var startTask: Task<Void, Never>?

    private func makeState(total: Int64 = 0, unlocked: [String] = [], viewed: [String] = [], preview: Bool = false, lang: AppLanguage = .ru) -> ProgressState {
        ProgressState(total: total, unlocked: unlocked, viewed: viewed, settings: AppSettings(preview: preview, lang: lang), onboarded: true, updatedAt: 100)
    }

    private func setUp(_ state: ProgressState?, language: AppLanguage = .ru) async {
        repository = FakeProgressRepository(state)
        sink = FakeSiraSink()
        localization = LocalizationService(language: language, defaults: nil)
        viewModel = SiraViewModel(
            repository: repository,
            sink: sink,
            contentProvider: BundledZikrContentProvider(),
            localization: localization
        )
        let viewModel = self.viewModel!
        let repository = self.repository!
        sink.onViewed = { id in
            Task {
                var next = await repository.load() ?? ProgressState()
                if !next.viewed.contains(id) { next.viewed.append(id) }
                next.updatedAt = (next.updatedAt ?? 0) + 1
                await repository.emit(next)
            }
        }
        startTask = Task { await viewModel.start() }
        if state != nil {
            await waitUntil { viewModel.isAvailable }
        }
    }

    override func tearDown() async throws {
        startTask?.cancel()
        startTask = nil
    }

    func testNoStateFileKeepsWebScreen() async {
        await setUp(nil)
        await waitUntil { await self.repository.subscriberCount == 1 }
        XCTAssertFalse(viewModel.isAvailable)
    }

    func testMissingContentKeepsWebScreen() async {
        repository = FakeProgressRepository(makeState())
        viewModel = SiraViewModel(
            repository: repository, sink: FakeSiraSink(),
            contentProvider: FailingZikrContentProvider(), localization: LocalizationService(language: .ru, defaults: nil)
        )
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        await waitUntil { viewModel.settings != nil }
        XCTAssertFalse(viewModel.isAvailable)
    }

    func testRowsMatchRenderPath() async {
        await setUp(makeState(total: 120, unlocked: ["ch01", "ch02", "ch03", "ch04"], viewed: ["ch01"]))
        viewModel.didAppear()
        let groups = viewModel.groups
        XCTAssertEqual(groups.map(\.state), [.done, .active, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming])
        XCTAssertEqual(groups[0].chapterIDs, ["ch01", "ch02", "ch03", "ch04"])
        XCTAssertTrue(viewModel.isOpen("ch04"))
        XCTAssertFalse(viewModel.isOpen("ch05"))
        XCTAssertFalse(viewModel.isNew("ch01"), "просмотрена")
        XCTAssertTrue(viewModel.isNew("ch02"))
        XCTAssertFalse(viewModel.isNew("ch05"), "закрытая")
        XCTAssertEqual(viewModel.index(of: "ch05"), 5)
        XCTAssertEqual(viewModel.title("ch01"), "Долина Мекки")
        XCTAssertEqual(viewModel.chapter("ch19")?.city, nil)
    }

    func testReadOpensSheetMarksViewedButBadgeStaysUntilReentry() async {
        await setUp(makeState(total: 10, unlocked: ["ch01"]))
        viewModel.didAppear()
        XCTAssertTrue(viewModel.isNew("ch01"))
        viewModel.read("ch01")
        XCTAssertEqual(viewModel.sheet, SiraChapterSheetState(chapterID: "ch01", showsMapButton: true))
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.markViewed("ch01")])
        await waitUntil { self.viewModel.viewed == ["ch01"] }
        XCTAssertTrue(viewModel.isNew("ch01"), "как renderPath(): метка до следующего показа вкладки")
        viewModel.closeSheet()
        XCTAssertNil(viewModel.sheet)
        viewModel.didDisappear()
        viewModel.didAppear()
        XCTAssertFalse(viewModel.isNew("ch01"))
    }

    func testLockedChapterCannotBeRead() async {
        await setUp(makeState(total: 10, unlocked: ["ch01"]))
        viewModel.read("ch02")
        viewModel.showOnMap("ch02")
        await viewModel.drainCommands()
        XCTAssertNil(viewModel.sheet)
        XCTAssertTrue(sink.calls.isEmpty)
    }

    func testPreviewOpensAllButNoNewBadges() async {
        await setUp(makeState(total: 0, preview: true))
        viewModel.didAppear()
        XCTAssertTrue(viewModel.isOpen("ch19"))
        XCTAssertFalse(viewModel.isNew("ch01"))
        viewModel.read("ch05")
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.markViewed("ch05")], "placeCard отмечает просмотр и в предпросмотре")
    }

    func testShowOnMapAndSheetMapButton() async {
        await setUp(makeState(total: 100_000_000, unlocked: ChapterCatalog.thresholds.map(\.id)))
        viewModel.showOnMap("ch05")
        viewModel.showOnMap("ch19")
        viewModel.read("ch09")
        viewModel.exploreFromSheet()
        XCTAssertNil(viewModel.sheet)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.showChapter("ch05"), .markViewed("ch09"), .explore("ch09")], "ch19 без города — без карты")
    }

    func testLeavingTabClosesSheet() async {
        await setUp(makeState(total: 10, unlocked: ["ch01"]))
        viewModel.read("ch01")
        viewModel.didDisappear()
        XCTAssertNil(viewModel.sheet)
    }

    func testBannerOpensCitylessChapterSheet() async {
        await setUp(makeState(total: 100_000_000, unlocked: ChapterCatalog.thresholds.map(\.id), viewed: ["ch01"]))
        XCTAssertFalse(viewModel.openFromBanner("ch01"), "с городом — карта, как раньше")
        XCTAssertTrue(viewModel.openFromBanner("ch19"))
        XCTAssertEqual(viewModel.sheet, SiraChapterSheetState(chapterID: "ch19", showsMapButton: false))
        viewModel.didAppear()
        XCTAssertTrue(viewModel.isNew("ch19"), "selectTab(\"path\") рисует метку до markViewed")
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.markViewed("ch19")])
        viewModel.didAppear()
        XCTAssertFalse(viewModel.isNew("ch19"))
    }

    func testLanguageChangeRetakesBadges() async {
        await setUp(makeState(total: 10, unlocked: ["ch01"]))
        viewModel.didAppear()
        viewModel.read("ch01")
        await viewModel.drainCommands()
        // Веб записал viewed (снимок в zikr-state.json), затем пользователь меняет язык.
        await waitUntil { await self.repository.load()?.viewed == ["ch01"] }
        XCTAssertTrue(viewModel.isNew("ch01"))
        var next = makeState(total: 10, unlocked: ["ch01"], viewed: ["ch01"], lang: .en)
        next.updatedAt = 200
        await repository.emit(next)
        await waitUntil { self.viewModel.settings?.lang == .en }
        XCTAssertFalse(viewModel.isNew("ch01"), "renderAll() перерисовывает вкладку")
    }

    func testDistanceTextMatchesWeb() async {
        await setUp(makeState(), language: .ru)
        let content = try! BundledZikrContentProvider().loadZikrContent()
        XCTAssertEqual(viewModel.distanceText(content.places["hira"]!), "От Каабы: ~4,8 км, северо-восток")
        XCTAssertEqual(viewModel.distanceText(content.places["kaaba"]!), "От Каабы: центр карты")
        XCTAssertEqual(viewModel.distanceText(content.places["safamarwa"]!), "От Каабы: Сафа: ~130 м, юго-восток · Марва: ~300 м, северо-восток")
        XCTAssertEqual(viewModel.distanceText(content.places["quba"]!), "От Мечети Пророка: ~3,2 км, юг")
        localization.setLanguage(.en)
        XCTAssertEqual(viewModel.distanceText(content.places["thawr"]!), "From the Kaaba: ~5.5 km, south")
    }

    func testWebSinkScripts() async {
        let web = FakeWebCommands()
        let sink = WebSiraCommandSink { web }
        _ = await sink.markViewed(chapterID: "ch01")
        _ = await sink.showChapter(chapterID: "ch05")
        _ = await sink.explore(chapterID: "ch\"19")
        XCTAssertEqual(web.scripts, [
            "(function(){try{return !!(window.zikrNative && window.zikrNative.markViewed(\"ch01\"));}catch(e){return false;}})()",
            "(function(){try{return !!(window.zikrNative && window.zikrNative.showChapter(\"ch05\"));}catch(e){return false;}})()",
            "(function(){try{return !!(window.zikrNative && window.zikrNative.explore(\"ch\\\"19\"));}catch(e){return false;}})()",
        ])
    }

    func testCategoryIconsMatchCatIcon() {
        XCTAssertEqual(SiraChapterSheet.categoryIcon("sacred"), "SiraSacred")
        XCTAssertEqual(SiraChapterSheet.categoryIcon("sira"), "SiraScroll")
        XCTAssertEqual(SiraChapterSheet.categoryIcon("nature"), "SiraMountain")
        XCTAssertEqual(SiraChapterSheet.categoryIcon("city"), "InfoUrban")
        for name in ["SiraSacred", "SiraMosque", "SiraScroll", "SiraMountain", "SiraMemorial", "InfoUrban", "InfoStar", "InfoLock", "InfoBook"] {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }
}
