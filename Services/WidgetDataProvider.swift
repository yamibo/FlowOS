import Foundation

/// Widget 数据
///
/// 用于与 Widget 共享的数据结构
public struct WidgetData: Codable, Equatable {
    public var sessionType: SessionType
    public var status: TimerStatus
    public var remainingSeconds: Int
    public var progress: Double
    public var sessionsCompletedToday: Int

    public init(
        sessionType: SessionType,
        status: TimerStatus,
        remainingSeconds: Int,
        progress: Double,
        sessionsCompletedToday: Int
    ) {
        self.sessionType = sessionType
        self.status = status
        self.remainingSeconds = remainingSeconds
        self.progress = progress
        self.sessionsCompletedToday = sessionsCompletedToday
    }

    /// 格式化剩余时间
    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Widget 数据提供者
///
/// 负责将计时器状态同步到 App Group 供 Widget 使用
public final class WidgetDataProvider: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = WidgetDataProvider()

    // MARK: - Properties

    private var fileURL: URL? {
        DataFolderManager.widgetDataFileURL
    }

    private let lock = NSLock()

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// 更新 Widget 数据
    public func update(
        sessionType: SessionType,
        status: TimerStatus,
        remainingSeconds: Int,
        progress: Double,
        sessionsCompletedToday: Int
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard let url = fileURL else { return }

        let data = WidgetData(
            sessionType: sessionType,
            status: status,
            remainingSeconds: remainingSeconds,
            progress: progress,
            sessionsCompletedToday: sessionsCompletedToday
        )

        do {
            try DataFolderManager.ensureDirectoriesExist()
            try JSONFileStore.write(data, to: url)
        } catch {
            // 写入失败，忽略
        }
    }

    /// 读取 Widget 数据
    public func read() -> WidgetData? {
        lock.lock()
        defer { lock.unlock() }

        guard let url = fileURL else { return nil }

        do {
            return try JSONFileStore.read(WidgetData.self, from: url)
        } catch {
            return nil
        }
    }
}
