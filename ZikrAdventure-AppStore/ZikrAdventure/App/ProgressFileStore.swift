// ProgressFileStore.swift
// Резервная копия прогресса в файле Application Support/progress.json.
// Данные хранятся только на устройстве и никуда не отправляются.
// Повреждённый файл игнорируется — приложение начинает с безопасного состояния.

import Foundation

final class ProgressFileStore {
    private let fileURL: URL? = {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("progress.json")
    }()

    /// Текст JSON для передачи странице либо "null", если файла нет или он повреждён.
    func loadJSONLiteral() -> String {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any],
              let text = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return text
    }

    /// Сохраняет только корректный JSON-объект; запись атомарная.
    func save(json: String) {
        guard let url = fileURL,
              let data = json.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return }
        try? data.write(to: url, options: .atomic)
    }
}
