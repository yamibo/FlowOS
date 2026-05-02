import Foundation

/// 设置仓库
///
/// 管理应用设置的持久化
public final class SettingsRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = SettingsRepository()

    // MARK: - Properties

    private let fileURL: URL
    private var cachedSettings: FlowSettings?
    private let lock = NSLock()

    // MARK: - Init

    public init(fileURL: URL = DataFolderManager.settingsFileURL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// 加载设置
    public func load() -> FlowSettings {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedSettings {
            return cached
        }

        do {
            try DataFolderManager.ensureDirectoriesExist()
            if let settings = try JSONFileStore.read(FlowSettings.self, from: fileURL) {
                cachedSettings = settings
                return settings
            }
        } catch {
            // 读取失败，返回默认值
        }

        let defaults = FlowSettings.default
        cachedSettings = defaults
        return defaults
    }

    /// 保存设置
    public func save(_ settings: FlowSettings) throws {
        lock.lock()
        defer { lock.unlock() }

        try DataFolderManager.ensureDirectoriesExist()

        var updated = settings
        updated.updatedAt = Date()
        updated.schemaVersion = 1

        try JSONFileStore.write(updated, to: fileURL)
        cachedSettings = updated
    }

    /// 更新 Timer 设置
    public func updateTimerSettings(_ timerSettings: TimerSettings) throws {
        var settings = load()
        settings.timer = timerSettings
        try save(settings)
    }

    /// 清除缓存
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedSettings = nil
    }
}
