// JSNumber.swift
// Числовые правила JavaScript, нужные для точного порта sanitize() из index.html.

import Foundation

public enum JSNumber {
    /// Number.MAX_SAFE_INTEGER.
    public static let maxSafeInteger: Int64 = 9_007_199_254_740_991

    /// Math.round: округление к +∞ при .5 (Math.round(-0.5) == -0, Math.round(2.5) == 3).
    public static func round(_ x: Double) -> Double {
        (x + 0.5).rounded(.down)
    }

    /// Безопасное приведение конечного неотрицательного числа к Int64 с потолком MAX_SAFE_INTEGER.
    /// Возвращает nil для NaN/±∞.
    public static func clampedInt64(_ x: Double) -> Int64? {
        guard x.isFinite else { return nil }
        let f = x.rounded(.down)
        if f >= Double(maxSafeInteger) { return maxSafeInteger }
        if f <= -Double(maxSafeInteger) { return -maxSafeInteger }
        return Int64(f)
    }
}
