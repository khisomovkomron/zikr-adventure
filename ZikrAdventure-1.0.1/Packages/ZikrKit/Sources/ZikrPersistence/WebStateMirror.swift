// WebStateMirror.swift
// Очередь зеркалирования веб-состояния в JSONStateStore.
// enqueue вызывается с главного потока на каждое сообщение "save" и не блокирует его.
// Снимки схлопываются: обрабатывается только самый новый ожидающий (поведение bufferingNewest(1)).

import Foundation
import ZikrCore
import ZikrDomain

public final class WebStateMirror: @unchecked Sendable {
    // @unchecked: изменяемое состояние только в `mailbox` под NSLock; остальное — неизменяемые Sendable.
    private let store: JSONStateStore
    /// Читает progress.json; вызывается только из фонового обработчика (ZKR-61).
    private let progressFileReader: @Sendable (URL) -> String?
    private let lock = NSLock()
    private var pendingSnapshot: String?
    private var pendingFallback: Fallback?
    private var enqueued: UInt64 = 0
    private var processed: UInt64 = 0
    private let wake: AsyncStream<Void>.Continuation
    private let worker: Task<Void, Never>

    public init(
        store: JSONStateStore,
        progressFileReader: @escaping @Sendable (URL) -> String? = { LegacySources.progressFile(at: $0).progressFileJSON }
    ) {
        self.store = store
        self.progressFileReader = progressFileReader
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.wake = continuation
        let box = WeakBox()
        self.worker = Task.detached(priority: .utility) {
            for await _ in stream {
                while let mirror = box.value, let job = mirror.take() {
                    if let fallback = job.fallback {
                        var sources = fallback.sources
                        if let url = fallback.progressFileURL {
                            sources.progressFileJSON = mirror.progressFileReader(url)
                        }
                        await mirror.store.bootstrap(sources)
                    }
                    if let snapshot = job.snapshot {
                        await mirror.store.replaceFromWeb(json: snapshot)
                    }
                    mirror.markProcessed(job.sequence)
                }
            }
        }
        box.value = self
    }

    deinit {
        wake.finish()
        worker.cancel()
    }

    /// Снимок JSON.stringify(state) из сообщения "save" или из живой страницы.
    public func enqueue(_ json: String) {
        lock.lock()
        pendingSnapshot = json
        enqueued &+= 1
        lock.unlock()
        wake.yield(())
    }

    /// Нет живого состояния страницы: первичная миграция из localStorage / progress.json.
    public func enqueueFallback(_ sources: LegacySources) {
        enqueue(fallback: Fallback(sources: sources, progressFileURL: nil))
    }

    /// То же, но progress.json читается в фоновом обработчике, а не на вызывающем (главном) потоке.
    /// nil URL — файла нет.
    public func enqueueFallback(progressFileURL: URL?, localStorageV2: String?, localStorageV1: String?) {
        let sources = LegacySources(localStorageV2: localStorageV2, localStorageV1: localStorageV1)
        enqueue(fallback: Fallback(sources: sources, progressFileURL: progressFileURL))
    }

    private func enqueue(fallback: Fallback) {
        lock.lock()
        pendingFallback = fallback
        enqueued &+= 1
        lock.unlock()
        wake.yield(())
    }

    /// Ждёт обработки всего, что было поставлено в очередь до вызова. Только для тестов.
    public func flushForTesting() async {
        let target = counters().enqueued
        while counters().processed < target {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// Синхронное чтение счётчиков под замком (NSLock нельзя трогать напрямую из async-контекста).
    private func counters() -> (enqueued: UInt64, processed: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        return (enqueued, processed)
    }

    private struct Fallback {
        let sources: LegacySources
        let progressFileURL: URL?
    }

    private struct Job {
        let snapshot: String?
        let fallback: Fallback?
        let sequence: UInt64
    }

    private func take() -> Job? {
        lock.lock()
        defer { lock.unlock() }
        guard pendingSnapshot != nil || pendingFallback != nil else { return nil }
        let job = Job(snapshot: pendingSnapshot, fallback: pendingFallback, sequence: enqueued)
        pendingSnapshot = nil
        pendingFallback = nil
        return job
    }

    private func markProcessed(_ sequence: UInt64) {
        lock.lock()
        processed = max(processed, sequence)
        lock.unlock()
    }
}

private final class WeakBox: @unchecked Sendable {
    weak var value: WebStateMirror?
}
