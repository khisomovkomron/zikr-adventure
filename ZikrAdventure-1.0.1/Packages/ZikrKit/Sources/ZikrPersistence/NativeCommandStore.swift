import Foundation
import ZikrDomain

extension JSONStateStore {
    /// Применение и запись — одна actor-операция, без await между чтением и commit.
    /// Требует завершённого bootstrap: отсутствие/недоступность данных не превращается в fresh.
    /// Пока не подключено к AppContainer: одновременно web/native writer запрещены.
    public func execute(
        _ command: NativeProgressCommand, catalog: NativeCommandCatalog,
        timeZone: TimeZone = .current
    ) throws -> NativeCommandResult? {
        guard let document = document() else { throw NativeCommandError.notBootstrapped }
        guard let result = try NativeProgressReducer.apply(command, to: document.progress,
                                                          at: commandDate, timeZone: timeZone, catalog: catalog) else {
            return nil
        }
        if result.didChange {
            let progress = result.progress
            _ = try update { $0 = progress }
        }
        return result
    }
}
