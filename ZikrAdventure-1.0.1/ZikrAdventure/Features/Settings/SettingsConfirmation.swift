// SettingsConfirmation.swift
// ZKR-50: подтверждения экрана «Настройки» — те же тексты, что confirmDialog() в renderSettings().

enum SettingsConfirmation: String, Identifiable, CaseIterable {
    case signOut
    case deleteAccount
    case clearHistory
    case resetDefaults
    case resetProgress

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .signOut: return .authOutTitle
        case .deleteAccount: return .authDeleteTitle
        case .clearHistory: return .historyConfirmT
        case .resetDefaults: return .setDefaults
        case .resetProgress: return .setResetT
        }
    }

    /// nil — без текста (у «Настройки по умолчанию» в вебе пустое сообщение).
    var messageKey: L10nKey? {
        switch self {
        case .signOut: return .authOutBody
        case .deleteAccount: return .authDeleteBody
        case .clearHistory: return .historyConfirmM
        case .resetDefaults: return nil
        case .resetProgress: return .setResetM
        }
    }

    var actionKey: L10nKey {
        switch self {
        case .signOut: return .authOut
        case .deleteAccount: return .authDelete
        case .clearHistory: return .historyClear
        case .resetDefaults: return .setDefaultsA
        case .resetProgress: return .setResetA
        }
    }
}
