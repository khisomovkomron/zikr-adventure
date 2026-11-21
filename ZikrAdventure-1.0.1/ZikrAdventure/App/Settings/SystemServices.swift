// SystemServices.swift
// ZKR-50: системные зависимости экрана «Настройки» за протоколами (подменяются в тестах и превью).

import Combine
import SafariServices
import UIKit

/// Системная настройка «Уменьшение движения» (строка set.systemRM).
@MainActor
protocol ReduceMotionProviding: AnyObject {
    var isReduceMotionEnabled: Bool { get }
    /// Новые значения после UIAccessibility.reduceMotionStatusDidChangeNotification.
    var changes: AnyPublisher<Bool, Never> { get }
}

@MainActor
final class SystemReduceMotionProvider: ReduceMotionProviding {
    var isReduceMotionEnabled: Bool { UIAccessibility.isReduceMotionEnabled }

    var changes: AnyPublisher<Bool, Never> {
        NotificationCenter.default
            .publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .map { _ in UIAccessibility.isReduceMotionEnabled }
            .eraseToAnyPublisher()
    }
}

/// Открытие внешних ссылок (как мост openURL: только http/https, SFSafariViewController).
@MainActor
protocol URLOpening: AnyObject {
    func open(_ url: URL)
}

@MainActor
final class SafariURLOpener: URLOpening {
    private let presenter: any PresenterProviding

    init(presenter: any PresenterProviding) {
        self.presenter = presenter
    }

    func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let top = presenter.topViewController() else { return }
        top.present(SFSafariViewController(url: url), animated: true)
    }
}
