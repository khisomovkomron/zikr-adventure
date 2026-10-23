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
    private let lock = NSLock()
    private var pendingSnapshot: String?
    private var pendingFallback: LegacySources?
    private var enqueued: UInt64 = 0
    private var processed: UInt64 = 0
    private let wake: AsyncStream<Void>.Continuation
    private let worker: Task<Void, Never>

    public init(store: JSONStateStore) {
        self.store = store
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.wake = continuation
        let box = WeakBox()
        self.worker = Task.detached(priority: .utility) {
            for await _ in stream {
                while let mirror = box.value, let job = mirror.take() {
                    if let fallback = job.fallback {
                        await mirror.store.bootstrap(fallback)
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
        lock.lock()
        pendingFallback = sources
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

    private struct Job {
        let snapshot: String?
        let fallback: LegacySources?
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
