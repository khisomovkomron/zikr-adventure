// AppSheetSupport.swift
// ZKR-64: общие детали нижних листов (лист «Инфо», будущие листы других экранов).
// Вынесены из InfoSheetView.swift.

import SwiftUI

/// Высота содержимого листа: `.sheet` max-height 86% + overflow-y auto (прокрутка — только если не влезает).
struct SheetContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Скругление только сверху: border-radius 22px 22px 0 0 (iOS 16 — без UnevenRoundedRectangle).
struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}
