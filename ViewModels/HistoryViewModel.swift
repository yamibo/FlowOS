import Foundation

/// 历史记录 ViewModel
@MainActor
@Observable
public final class HistoryViewModel {
    // MARK: - Properties

    private let sessionRepository: SessionRepository

    /// Session 记录列表
    public var sessions: [SessionRecord] = []

    /// 统计信息
    public var stats: SessionStats = SessionStats()

    /// 日期范围
    public var dateRange: DateInterval?

    /// 是否显示导出面板
    public var showExportPanel = false

    /// 导出的 CSV 内容
    public var exportedCSV: String = ""

    // MARK: - Init

    public init(sessionRepository: SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    // MARK: - Actions

    /// 加载今日数据
    public func loadToday() {
        sessions = sessionRepository.fetchToday()
        stats = sessionRepository.getTodayStats()
        dateRange = nil
    }

    /// 加载最近 7 天数据
    public func loadLast7Days() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: now)!
        sessions = sessionRepository.fetch(from: start, to: now)
        stats = sessionRepository.getStats(from: start, to: now)
        dateRange = DateInterval(start: start, end: now)
    }

    /// 加载最近 30 天数据
    public func loadLast30Days() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: now)!
        sessions = sessionRepository.fetch(from: start, to: now)
        stats = sessionRepository.getStats(from: start, to: now)
        dateRange = DateInterval(start: start, end: now)
    }

    /// 加载全部数据
    public func loadAll() {
        sessions = sessionRepository.loadAll()
        stats = SessionStats(sessions: sessions)
        dateRange = nil
    }

    /// 导出为 CSV
    public func exportToCSV() {
        exportedCSV = sessionRepository.exportToCSV()
        showExportPanel = true
    }

    /// 保存 CSV 到文件
    public func saveCSV(to url: URL) throws {
        try exportedCSV.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 清除所有数据
    public func clearAllData() {
        try? sessionRepository.clearAll()
        sessions = []
        stats = SessionStats()
    }
}
