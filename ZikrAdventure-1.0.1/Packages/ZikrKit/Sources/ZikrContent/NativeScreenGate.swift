// NativeScreenGate.swift
// ZKR-48: когда показывать нативный экран «Инфо» поверх веб-вкладки.
// Веб-онбординг (#onb) — полноэкранный слой внутри web view, в 1.1.1 он закрывает и «Инфо»;
// пока он показан или его состояние неизвестно, остаётся веб-экран (поведение 1.1.1).

public enum NativeScreenGate {
    public static func shouldShowNativeInfo(
        isEnabled: Bool,
        isInfoSelected: Bool,
        isWebOnboardingVisible: Bool?
    ) -> Bool {
        isEnabled && isInfoSelected && isWebOnboardingVisible == false
    }
}

/// Последнее известное состояние веб-онбординга.
/// «Завершён» фиксируется навсегда: онбординг не возвращается (onboarded сохраняется при сбросе),
/// поэтому ответы nil/true после перезагрузки страницы его не откатывают.
public struct WebOnboardingTracker: Equatable, Sendable {
    public private(set) var isVisible: Bool?

    public init(isVisible: Bool? = nil) {
        self.isVisible = isVisible
    }

    public mutating func record(_ visible: Bool?) {
        guard isVisible != false else { return }
        if let visible {
            isVisible = visible
        }
    }
}
