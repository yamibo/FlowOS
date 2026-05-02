import Foundation

/// Session 记录仓库
///
/// 管理已完成的 Session 记录（JSONL 格式）
public final class SessionRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = SessionRepository()

    // MARK: - Properties

    private let fileURL: URL
    private let lock = NSLock()

    // MARK: - Init

    public init(fileURL: URL = DataFolderManager.sessionsFileURL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// 加载所有 Session 记录
    public func loadAll() -> [SessionRecord] {
        lock.lock()
        defer { lock.unlock() }

        do {
            try DataFolderManager.ensureDirectoriesExist()
            return try JSONLFileStore.readAll(SessionRecord.self, from: fileURL)
        } catch {
            return []
        }
    }

    /// 追加一条 Session 记录
    public func append(_ record: SessionRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        try DataFolderManager.ensureDirectoriesExist()
        try JSONLFileStore.append(record, to: fileURL)
    }

    /// 获取指定日期范围的 Session 记录
    public func fetch(from startDate: Date, to endDate: Date) -> [SessionRecord] {
        let all = loadAll()
        return all.filter { record in
            record.startedAt >= startDate && record.endedAt <= endDate
        }
    }

    /// 获取今天的 Session 记录
    public func fetchToday() -> [SessionRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return fetch(from: startOfDay, to: endOfDay)
    }

    /// 获取统计信息
    public func getStats(from startDate: Date, to endDate: Date) -> SessionStats {
        let sessions = fetch(from: startDate, to: endDate)
        return SessionStats(sessions: sessions)
    }

    /// 获取今日统计
    public func getTodayStats() -> SessionStats {
        let sessions = fetchToday()
        return SessionStats(sessions: sessions)
    }

    /// 清除所有记录
    public func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }

        try JSONLFileStore.delete(at: fileURL)
    }

    /// 导出为 CSV
    public func exportToCSV() -> String {
        let sessions = loadAll()

        var csv = "id,session_type,started_at,ended_at,duration_seconds,completed,source_device\n"

        let formatter = ISO8601DateFormatter()
        for session in sessions {
            let startedAt = formatter.string(from: session.startedAt)
            let endedAt = formatter.string(from: session.endedAt)
            let line = "\(session.id),\(session.sessionType.rawValue),\(startedAt),\(endedAt),\(session.durationSeconds),\(session.completed),\(session.sourceDevice ?? "")\n"
            csv += line
        }

        return csv
    }
}
