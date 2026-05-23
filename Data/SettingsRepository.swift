import Foundation

/// 设置仓库
///
/// 管理应用设置的持久化，支持 iCloud Drive 同步
public final class SettingsRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = SettingsRepository()

    // MARK: - Properties

    private let fileURL: URL
    private var cachedSettings: FlowSettings?
    private let lock = NSLock()
    private let iCloudSync = iCloudDriveSyncManager.shared

    // MARK: - Init

    public init(fileURL: URL = DataFolderManager.settingsFileURL) {
        self.fileURL = fileURL

        // 监听 iCloud Drive 外部变更
        iCloudSync.onExternalChange = { [weak self] in
            self?.handleExternalChange()
        }
    }

    // MARK: - Public API

    /// 加载设置
    public func load() -> FlowSettings {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedSettings {
            return cached
        }

        // 优先从 iCloud Drive 加载
        if let iCloudURL = iCloudSync.settingsFileURL,
           let iCloudSettings = iCloudSync.read(FlowSettings.self, from: iCloudURL) {
            cachedSettings = iCloudSettings
            return iCloudSettings
        }

        // 回退到本地文件
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

        // 保存到本地
        try JSONFileStore.write(updated, to: fileURL)
        cachedSettings = updated

        // 同步到 iCloud Drive
        if let iCloudURL = iCloudSync.settingsFileURL {
            try? iCloudSync.write(updated, to: iCloudURL)
        }
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

    /// 处理 iCloud Drive 外部变更
    private func handleExternalChange() {
        lock.lock()
        defer { lock.unlock() }

        // 从 iCloud Drive 重新加载
        if let iCloudURL = iCloudSync.settingsFileURL,
           let iCloudSettings = iCloudSync.read(FlowSettings.self, from: iCloudURL) {
            cachedSettings = iCloudSettings

            // 同时更新本地文件
            try? JSONFileStore.write(iCloudSettings, to: fileURL)
        }
    }
}