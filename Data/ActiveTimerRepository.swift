import Foundation

/// 活动计时器仓库
///
/// 管理当前计时器状态的持久化（用于 App 重启恢复）
public final class ActiveTimerRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = ActiveTimerRepository()

    // MARK: - Properties

    private let fileURL: URL
    private let lock = NSLock()

    // MARK: - Init

    public init(fileURL: URL = DataFolderManager.activeTimerFileURL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// 加载活动计时器状态
    public func load() -> ActiveTimerState? {
        lock.lock()
        defer { lock.unlock() }

        do {
            try DataFolderManager.ensureDirectoriesExist()
            return try JSONFileStore.read(ActiveTimerState.self, from: fileURL)
        } catch {
            return nil
        }
    }

    /// 保存活动计时器状态
    public func save(_ state: ActiveTimerState) throws {
        lock.lock()
        defer { lock.unlock() }

        try DataFolderManager.ensureDirectoriesExist()

        var updated = state
        updated.updatedAt = Date()
        updated.schemaVersion = 1

        try JSONFileStore.write(updated, to: fileURL)
    }

    /// 清除活动计时器状态
    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        try JSONFileStore.delete(at: fileURL)
    }
}
