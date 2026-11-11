// MapViewModelTests.swift
// ZKR-57: экран «Карта» — обзорная карта (selectWorldCity → selectCity), openCity / explore / showChapter,
// placeCard / objectCard по нажатию, список мест и легенда, камера (saveCam → saveCamera), проявление объектов,
// команды в веб (window.zikrNative.selectCity / saveCamera / markViewed).

import XCTest
import ZikrContent
import ZikrCore
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class FakeMapSink: MapCommandSink {
    enum Call: Equatable {
        case selectCity(String?), saveCamera(String, Double, Double, Double), markViewed(String)
    }

    var calls: [Call] = []

    func selectCity(_ cityID: String?) async -> Bool {
        calls.append(.selectCity(cityID))
        return true
    }

    func saveCamera(cityID: String, x: Double, y: Double, z: Double) async -> Bool {
        calls.append(.saveCamera(cityID, x, y, z))
        return true
    }

    func markViewed(chapterID: String) async -> Bool {
        calls.append(.markViewed(chapterID))
        return true
    }
}

@MainActor
final class MapViewModelTests: XCTestCase {
    private var repository: FakeProgressRepository!
    private var sink: FakeMapSink!
    private var viewModel: MapViewModel!
    private var startTask: Task<Void, Never>?

    private func makeState(
        total: Int64 = 0, unlocked: [String] = [], preview: Bool = false, animations: Bool = false,
        cameras: [String: CameraPosition] = [:], city: String? = nil
    ) -> ProgressState {
        var settings = AppSettings(preview: preview, lang: .ru)
        settings.animations = animations
        return ProgressState(total: total, unlocked: unlocked, settings: settings, onboarded: true, cameras: cameras, city: city, updatedAt: 100)
    }

    private func setUp(_ state: ProgressState) async {
        repository = FakeProgressRepository(state)
        sink = FakeMapSink()
        viewModel = MapViewModel(
            repository: repository,
            sink: sink,
            mapContentProvider: BundledMapContentProvider(),
            contentProvider: BundledZikrContentProvider(),
            localization: LocalizationService(language: .ru, defaults: nil)
        )
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        await waitUntil { viewModel.isAvailable }
    }

    override func tearDown() async throws {
        startTask?.cancel()
        startTask = nil
    }

    func testWorldSelectionStartsFromSavedCityAndWritesThroughWeb() async {
        await setUp(makeState(city: "medina"))
        XCTAssertEqual(viewModel.mode, .world)
        XCTAssertEqual(viewModel.selectedCity, "medina", "mapView.selected = state.city")
        viewModel.selectCity("mecca")
        viewModel.selectCity(nil)
        viewModel.selectCity("cairo")
        await viewModel.drainCommands()
        XCTAssertNil(viewModel.selectedCity)
        XCTAssertEqual(sink.calls, [.selectCity("mecca"), .selectCity(nil)], "неизвестный город игнорируется")
    }

    func testChapterCountsUseReallyOpenChaptersAndProgressChip() async {
        await setUp(makeState(total: 500, unlocked: ["ch01", "ch02", "ch09"], preview: true))
        let content = try! BundledZikrContentProvider().loadZikrContent()
        let meccaTotal = content.chapters.filter { $0.city == "mecca" }.count
        XCTAssertEqual(viewModel.chapterCounts(city: "mecca").open, 2, "isReallyOpen: предпросмотр не считается")
        XCTAssertEqual(viewModel.chapterCounts(city: "mecca").total, meccaTotal)
        XCTAssertEqual(viewModel.chapterCounts(city: "medina").open, 1)
        XCTAssertEqual(viewModel.chapterCount, content.chapters.count)
        XCTAssertTrue(viewModel.isOpen("ch19"), "предпросмотр открывает всё для isOpen")
    }

    func testOpenCityAndBack() async {
        await setUp(makeState())
        viewModel.openCity("mecca")
        XCTAssertEqual(viewModel.mode, .city("mecca"))
        XCTAssertEqual(viewModel.selectedCity, "mecca")
        XCTAssertNil(viewModel.cameraRequest)
        viewModel.backToWorld()
        XCTAssertEqual(viewModel.mode, .world)
        XCTAssertEqual(viewModel.selectedCity, "mecca", "панель выбранного города остаётся")
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.selectCity("mecca")])
    }

    func testExploreFocusesPlaceAndOpensChapterSheetAfterDelay() async {
        await setUp(makeState(unlocked: ["ch01", "ch05"]))
        XCTAssertTrue(viewModel.explore("ch05"))
        XCTAssertEqual(viewModel.mode, .city("mecca"))
        XCTAssertEqual(viewModel.selectedObjectID, "nur", "hira → объект nur (chapterFocus)")
        XCTAssertEqual(viewModel.cameraRequest?.kind, .focus("nur"))
        XCTAssertNil(viewModel.sheet, "лист — через 50 мс без анимаций")
        await waitUntil { self.viewModel.sheet != nil }
        XCTAssertEqual(viewModel.sheet, .chapter(SiraChapterSheetState(chapterID: "ch05", showsMapButton: false)))
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.markViewed("ch05"), .selectCity("mecca")])
        viewModel.closeSheet()
        XCTAssertNil(viewModel.selectedObjectID, "закрытие листа снимает выбор")
    }

    func testExploreAndShowChapterRejectCitylessChapters() async {
        await setUp(makeState(unlocked: ["ch19"]))
        XCTAssertFalse(viewModel.explore("ch19"))
        XCTAssertFalse(viewModel.showChapter("ch19"))
        XCTAssertFalse(viewModel.explore("nope"))
        XCTAssertEqual(viewModel.mode, .world)
    }

    func testShowChapterFocusesWithoutSheet() async {
        await setUp(makeState(unlocked: ["ch06"]))
        XCTAssertTrue(viewModel.showChapter("ch06"))
        XCTAssertEqual(viewModel.selectedObjectID, "safa", "safamarwa → safa")
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(viewModel.sheet)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.markViewed("ch06"), .selectCity("mecca")])
    }

    func testTapOpenPlaceShowsPlaceCardAndMarksViewed() async {
        await setUp(makeState(unlocked: ["ch16"]))
        viewModel.openCity("mecca")
        viewModel.selectObject("kaaba")
        XCTAssertEqual(viewModel.selectedObjectID, "kaaba")
        XCTAssertEqual(viewModel.sheet, .chapter(SiraChapterSheetState(chapterID: "ch16", showsMapButton: false, siraFirst: false)))
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls.last, .markViewed("ch16"))
    }

    func testTapLockedPlaceDoesNotMarkViewed() async {
        await setUp(makeState())
        viewModel.openCity("medina")
        viewModel.selectObject("quba")
        XCTAssertEqual(viewModel.sheet, .chapter(SiraChapterSheetState(chapterID: "ch09", showsMapButton: false, siraFirst: false)))
        XCTAssertFalse(viewModel.isOpen("ch09"))
        await viewModel.drainCommands()
        XCTAssertFalse(sink.calls.contains(.markViewed("ch09")))
    }

    func testTapLifeObjectShowsObjectCardAndEmptyTapClearsSelection() async {
        await setUp(makeState(unlocked: ["ch01", "ch02", "ch03"]))
        viewModel.openCity("mecca")
        let city = viewModel.city("mecca")!
        let life = city.objects.first { $0.place == nil && $0.isInteractive }!
        viewModel.selectObject(life.id)
        XCTAssertEqual(viewModel.sheet, .object(life.id))
        XCTAssertFalse(viewModel.objectName(life).isEmpty)
        viewModel.closeSheet()
        viewModel.selectObject(nil)
        XCTAssertNil(viewModel.selectedObjectID)
        XCTAssertNil(viewModel.sheet)
    }

    func testPlaceListMatchesWeb() async {
        await setUp(makeState(unlocked: CH.allIDs))
        let places = viewModel.listPlaces(city: "mecca")
        XCTAssertFalse(places.contains { $0.id == "marwa" }, "sub 1 (Марва) не в списке")
        XCTAssertTrue(places.contains { $0.id == "safa" })
        XCTAssertEqual(places.count, viewModel.city("mecca")!.objects.filter { $0.place != nil }.count - 1)
        let life = viewModel.listLife(city: "medina")
        XCTAssertLessThanOrEqual(life.count, 12)
        XCTAssertTrue(life.allSatisfy { $0.place == nil && $0.layer != nil && $0.isInteractive })
    }

    func testPickFromListFocusesThenSelects() async {
        await setUp(makeState(unlocked: ["ch02"]))
        viewModel.openCity("mecca")
        viewModel.openList()
        XCTAssertEqual(viewModel.sheet, .list("mecca"))
        viewModel.pickFromList("zamzam")
        XCTAssertNil(viewModel.sheet)
        XCTAssertEqual(viewModel.cameraRequest?.kind, .focus("zamzam"))
        await waitUntil { self.viewModel.sheet != nil }
        XCTAssertEqual(viewModel.selectedObjectID, "zamzam")
        viewModel.cameraRequestHandled(viewModel.cameraRequest!.id)
        XCTAssertNil(viewModel.cameraRequest)
    }

    func testCameraControlsAndSettleWritesOnce() async {
        await setUp(makeState(cameras: ["mecca": CameraPosition(x: 10, y: 600, z: 1.2)]))
        XCTAssertEqual(viewModel.savedCamera("mecca"), CityGeometry.Camera(x: 10, y: 600, z: 1.2))
        viewModel.openCity("mecca")
        viewModel.zoomIn()
        XCTAssertEqual(viewModel.cameraRequest?.kind, .zoom(1.4))
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.cameraRequest?.kind, .zoom(1 / 1.4))
        viewModel.resetCamera()
        XCTAssertEqual(viewModel.cameraRequest?.kind, .home)
        viewModel.cameraDidSettle(city: "mecca", camera: .init(x: 1, y: 2, z: 1))
        viewModel.cameraDidSettle(city: "mecca", camera: .init(x: 1, y: 2, z: 1))
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls.filter { if case .saveCamera = $0 { return true } else { return false } }, [.saveCamera("mecca", 1, 2, 1)])
        XCTAssertEqual(viewModel.savedCamera("mecca"), CityGeometry.Camera(x: 1, y: 2, z: 1))
    }

    func testRevealOnlyNewlyOpenedLayersOnRepeatVisit() async {
        await setUp(makeState(unlocked: ["ch01"]))
        XCTAssertEqual(viewModel.takeRevealedObjects(city: "mecca", reduceMotion: false), [], "первый показ — без проявления")
        await repository.emit(makeState(unlocked: ["ch01", "ch02", "ch03"]))
        await waitUntil { self.viewModel.unlocked.count == 3 }
        let revealed = viewModel.takeRevealedObjects(city: "mecca", reduceMotion: false)
        let expected = Set(viewModel.city("mecca")!.objects.filter { ["ch02", "ch03"].contains($0.layer ?? "") }.map(\.id))
        XCTAssertEqual(revealed, expected)
        XCTAssertFalse(revealed.isEmpty)
        XCTAssertEqual(viewModel.takeRevealedObjects(city: "mecca", reduceMotion: false), [], "ключ обновлён")
    }

    func testLabelsMatchMarkerText() async {
        await setUp(makeState())
        let mecca = viewModel.city("mecca")!
        XCTAssertEqual(viewModel.label(mecca.object(id: "safa")!), "Сафа")
        XCTAssertEqual(viewModel.label(mecca.object(id: "marwa")!), "Марва")
        XCTAssertFalse(viewModel.label(mecca.object(id: "kaaba")!).contains("("))
    }

    func testWebSinkScripts() async {
        let web = FakeWebCommands()
        let sink = WebMapCommandSink { web }
        _ = await sink.selectCity("mecca")
        _ = await sink.selectCity(nil)
        _ = await sink.saveCamera(cityID: "medina", x: 1.5, y: -2, z: 1)
        _ = await sink.saveCamera(cityID: "medina", x: .nan, y: 0, z: 1)
        _ = await sink.markViewed(chapterID: "ch05")
        XCTAssertEqual(web.scripts, [
            "(function(){try{return !!(window.zikrNative && window.zikrNative.selectCity(\"mecca\"));}catch(e){return false;}})()",
            "(function(){try{return !!(window.zikrNative && window.zikrNative.selectCity(null));}catch(e){return false;}})()",
            "(function(){try{return !!(window.zikrNative && window.zikrNative.saveCamera(\"medina\",1.5,-2,1));}catch(e){return false;}})()",
            "(function(){try{return !!(window.zikrNative && window.zikrNative.markViewed(\"ch05\"));}catch(e){return false;}})()",
        ])
    }
}

private enum CH {
    static var allIDs: [String] { (try? BundledZikrContentProvider().loadZikrContent().chapters.map(\.id)) ?? [] }
}
