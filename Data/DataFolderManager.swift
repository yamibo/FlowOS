import Foundation

/// 数据文件夹管理器
///
/// 负责创建和管理应用数据存储目录
public enum DataFolderManager {
    // MARK: - App Group

    /// App Group ID（用于 Widget 数据共享）
    public static let appGroupID = "group.com.flowosapple"

    // MARK: - Paths

    /// 应用数据目录
    public static var appDataURL: URL {
        #if os(macOS)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlowOSApple")
        #else
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("FlowOSApple")
        #endif
    }

    /// App Group 共享目录（用于 Widget）
    public static var sharedURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Session 记录文件路径
    public static var sessionsFileURL: URL {
        appDataURL.appendingPathComponent("sessions.jsonl")
    }

    /// 设置文件路径
    public static var settingsFileURL: URL {
        appDataURL.appendingPathComponent("settings.json")
    }

    /// 活动计时器状态文件路径
    public static var activeTimerFileURL: URL {
        appDataURL.appendingPathComponent("active_timer.json")
    }

    /// Widget 数据文件路径（App Group）
    public static var widgetDataFileURL: URL? {
        sharedURL?.appendingPathComponent("widget_data.json")
    }

    // MARK: - Setup

    /// 确保数据目录存在
    public static func ensureDirectoriesExist() throws {
        try FileManager.default.createDirectory(at: appDataURL, withIntermediateDirectories: true)

        // App Group 目录是可选的（仅当配置了 App Group 时才需要）
        if let sharedURL = sharedURL {
            do {
                try FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true)
            } catch {
                // App Group 目录创建失败时只打印警告，不阻止应用运行
                logPrint("[DataFolderManager] Warning: Could not create App Group directory: \(error)")
            }
        }
    }
}
