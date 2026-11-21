// SerialCommandQueue.swift
// ZKR-52: последовательная очередь команд в веб. Пользователи жмут быстро (десятки раз подряд):
// каждая команда ждёт ответа предыдущей, поэтому нажатия не теряются и не переставляются.
// `pending` — сколько команд ещё не подтверждено (пока > 0, снимки zikr-state.json не откатывают UI).

import Foundation

@MainActor
final class SerialCommandQueue {
    private var tail: Task<Void, Never>?
    private(set) var pending = 0

    func enqueue(_ work: @escaping @MainActor () async -> Void) {
        pending += 1
        let previous = tail
        tail = Task { @MainActor [weak self] in
            await previous?.value
            await work()
            self?.pending -= 1
        }
    }

    /// Ждёт, пока выполнятся все команды, поставленные до вызова (тесты, сброс).
    func drain() async {
        await tail?.value
    }
}
