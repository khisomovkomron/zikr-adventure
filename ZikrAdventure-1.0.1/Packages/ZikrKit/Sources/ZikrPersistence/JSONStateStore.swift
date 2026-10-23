// JSONStateStore.swift
// Нативный файл состояния Application Support/zikr-state.json (schemaVersion 3).
// В ZKR-49 работает в теневом режиме: только зеркалит веб-состояние; progress.json
// и localStorage не изменяются. Ошибки логируются (без пользовательских данных) и не роняют приложение.

import Foundation
import ZikrCore
import ZikrDomain

public actor JSONStateStore: StateStore {
    public static let fileName = "zikr-state.json"

    private let fileURL: URL
    private let clock: any AppClock
    private let appVersion: String
    private let preferredLanguages: [String]
    private let readData: @Sendable (URL) throws -> Data

    private var loaded = false
    private var cached: StateDocument?
    /// Файл из будущей схемы: запись отключена до конца сессии.
    private var readOnlySchema: Int?
    /// ZKR-61: файл есть, но не читается (например, защита данных до первой разблокировки).
    /// Файл не трогается и не перезаписывается; чтение повторяется при следующем обращении.
    private var unreadable = false
    private var lastWrittenProgress: Data?
    private var observers: [UUID: AsyncStream<ProgressState>.Continuation] = [:]

    public init(
        fileURL: URL,
        clock: any AppClock = SystemClock(),
        appVersion: String,
        preferredLanguages: [String] = Locale.preferredLanguages,
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) }
    ) {
        self.fileURL = fileURL
        self.clock = clock
        self.appVersion = appVersion
        self.preferredLanguages = preferredLanguages
        self.readData = readData
    }

    /// Application Support/zikr-state.json.
    public static func defaultFileURL() throws -> URL {
        do {
            let dir = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            return dir.appendingPathComponent(fileName)
        } catch {
            throw AppError.storageRead("applicationSupportDirectory unavailable")
        }
    }

    // MARK: - Bootstrap

    /// Первичная загрузка/миграция. Повторный вызов ничего не переписывает.
    @discardableResult
    public func bootstrap(_ sources: LegacySources) -> BootstrapResult {
        loadIfNeeded()
        if unreadable { return .unavailable(reason: Self.unreadableReason) }
        if let schema = readOnlySchema {
            return .readOnly(reason: "schemaVersion \(schema) > \(StateDocument.currentSchemaVersion)")
        }
        if cached != nil { return .existing }

        guard let (progress, source) = LegacyMigrator.resolve(sources, preferredLanguages: preferredLanguages) else {
            return .empty
        }
        let document = StateDocument(
            progress: progress,
            meta: .init(createdAt: clock.now, createdFrom: source, writtenByAppVersion: appVersion)
        )
        guard write(document) else { return .empty }
        return .created(from: source)
    }

    public func document() -> StateDocument? {
        loadIfNeeded()
        return cached
    }

    // MARK: - Зеркало веба

    /// Полная замена прогресса снимком страницы (без слияния).
    /// Пишет файл, только если закодированный прогресс изменился. Возвращает true при записи.
    @discardableResult
    public func replaceFromWeb(json: String, source: String = "webSave") -> Bool {
        loadIfNeeded()
        guard !unreadable, readOnlySchema == nil else { return false }
        guard let value = JSONValue.parse(json), value.objectValue != nil else {
            Log.persistence.error("replaceFromWeb: invalid JSON snapshot ignored")
            return false
        }
        let progress = LegacySanitizer.sanitize(value, preferredLanguages: preferredLanguages)
        guard let encoded = Self.encodeProgress(progress) else { return false }
        if let current = cached, encoded == (lastWrittenProgress ?? Self.encodeProgress(current.progress)) {
            return false
        }
        var document = cached ?? StateDocument(
            progress: progress,
            meta: .init(createdAt: clock.now, createdFrom: LegacyMigrator.Source.webLive, writtenByAppVersion: appVersion)
        )
        document.progress = progress
        document.meta.lastWebSyncAt = clock.now
        document.meta.writtenByAppVersion = appVersion
        return write(document)
    }

    // MARK: - Нативные изменения (в ZKR-49 приложением не вызывается)

    @discardableResult
    public func update(_ mutate: @Sendable (inout ProgressState) -> Void) throws -> ProgressState {
        loadIfNeeded()
        if unreadable { throw AppError.storageRead(Self.unreadableReason) }
        if let schema = readOnlySchema { throw AppError.unsupportedSchema(schema) }
        var document = cached ?? StateDocument(
            progress: .fresh(preferredLanguages: preferredLanguages),
            meta: .init(createdAt: clock.now, createdFrom: LegacyMigrator.Source.fresh, writtenByAppVersion: appVersion)
        )
        mutate(&document.progress)
        document.meta.writtenByAppVersion = appVersion
        guard write(document) else { throw AppError.storageWrite("zikr-state.json") }
        return document.progress
    }

    public func changes() -> AsyncStream<ProgressState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ProgressState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    // MARK: - Файл

    static let unreadableReason = "zikr-state.json unreadable"

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        unreadable = false
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }

        let data: Data
        do {
            data = try readData(fileURL)
        } catch {
            // ZKR-61: ошибка ввода-вывода — не повреждение. Файл остаётся на месте,
            // запись блокируется, при следующем обращении чтение повторяется.
            Log.persistence.error("zikr-state.json unreadable; will retry")
            loaded = false
            unreadable = true
            return
        }

        struct Probe: Decodable { let schemaVersion: Int }
        let decoder = Self.makeDecoder()
        if let probe = try? decoder.decode(Probe.self, from: data) {
            if probe.schemaVersion > StateDocument.currentSchemaVersion {
                readOnlySchema = probe.schemaVersion
                Log.persistence.error("zikr-state.json has a newer schemaVersion; read-only session")
                return
            }
            if probe.schemaVersion == StateDocument.currentSchemaVersion,
               let document = try? decoder.decode(StateDocument.self, from: data) {
                cached = document
                lastWrittenProgress = Self.encodeProgress(document.progress)
                return
            }
        }
        Log.persistence.error("zikr-state.json corrupt or outdated; moved aside")
        quarantine()
    }

    /// Переименовывает файл в zikr-state.corrupt-<unix-ms>.json.
    private func quarantine() {
        let ms = Int64((clock.now.timeIntervalSince1970 * 1000).rounded(.down))
        let target = fileURL.deletingLastPathComponent().appendingPathComponent("zikr-state.corrupt-\(ms).json")
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: fileURL, to: target)
        } catch {
            Log.persistence.error("zikr-state.json quarantine failed")
        }
    }

    private func write(_ document: StateDocument) -> Bool {
        guard !unreadable, readOnlySchema == nil else { return false }
        do {
            let data = try Self.makeEncoder().encode(document)
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: fileURL, options: [.atomic])
            #endif
            cached = document
            lastWrittenProgress = Self.encodeProgress(document.progress)
            for continuation in observers.values { continuation.yield(document.progress) }
            return true
        } catch {
            Log.persistence.error("zikr-state.json write failed")
            return false
        }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encodeProgress(_ progress: ProgressState) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(progress)
    }
}
