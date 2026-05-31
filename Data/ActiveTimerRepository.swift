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
    private let iCloudSync = iCloudDriveSyncManager.shared

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
            if let iCloudURL = iCloudSync.activeTimerFileURL,
               let state = iCloudSync.read(ActiveTimerState.self, from: iCloudURL) {
                return state
            }

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
        updated.schemaVersion = FlowOSDataSchema.currentVersion
        updated.sourceDevice = .current

        try JSONFileStore.write(updated, to: fileURL)

        if let iCloudURL = iCloudSync.activeTimerFileURL {
            try? iCloudSync.write(updated, to: iCloudURL)
        }
    }

    /// 清除活动计时器状态
    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        try JSONFileStore.delete(at: fileURL)
        if let iCloudURL = iCloudSync.activeTimerFileURL {
            try? JSONFileStore.delete(at: iCloudURL)
        }
    }
}
