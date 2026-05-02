import Foundation

// MARK: - SessionType

/// 计时阶段类型
public enum SessionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case shortBreak
    case longBreak

    public var id: String { rawValue }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    /// SF Symbol 图标
    public var iconName: String {
        switch self {
        case .focus: return "target"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.fill"
        }
    }
}

// MARK: - TimerStatus

/// 计时器状态
public enum TimerStatus: String, Codable, Sendable {
    case idle
    case running
    case paused
}

// MARK: - TimerSettings

/// 计时设置
public struct TimerSettings: Codable, Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var longBreakEvery: Int
    public var autoStartBreak: Bool
    public var autoStartFocus: Bool

    public static let `default` = TimerSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        longBreakEvery: 4,
        autoStartBreak: false,
        autoStartFocus: false
    )

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        longBreakEvery: Int = 4,
        autoStartBreak: Bool = false,
        autoStartFocus: Bool = false
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.longBreakEvery = longBreakEvery
        self.autoStartBreak = autoStartBreak
        self.autoStartFocus = autoStartFocus
    }

    /// 获取指定类型的时长（秒）
    public func durationSeconds(for type: SessionType) -> Int {
        switch type {
        case .focus: return focusMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }
}

// MARK: - ActiveTimerState

/// 活动计时器状态（用于持久化）
public struct ActiveTimerState: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var updatedAt: Date?
    public var timerId: UUID?
    public var sessionType: SessionType
    public var status: TimerStatus
    public var startedAt: Date?
    public var targetEndAt: Date?
    public var pausedAt: Date?
    public var remainingSecondsWhenPaused: Int?
    public var durationSeconds: Int
    public var sessionsCompletedInCycle: Int
    public var deviceName: String?

    public static func idle(
        sessionType: SessionType = .focus,
        durationSeconds: Int = 25 * 60,
        sessionsCompletedInCycle: Int = 0
    ) -> ActiveTimerState {
        ActiveTimerState(
            schemaVersion: 1,
            updatedAt: nil,
            timerId: nil,
            sessionType: sessionType,
            status: .idle,
            startedAt: nil,
            targetEndAt: nil,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: durationSeconds,
            sessionsCompletedInCycle: sessionsCompletedInCycle,
            deviceName: nil
        )
    }

    public init(
        schemaVersion: Int = 1,
        updatedAt: Date? = nil,
        timerId: UUID? = nil,
        sessionType: SessionType = .focus,
        status: TimerStatus = .idle,
        startedAt: Date? = nil,
        targetEndAt: Date? = nil,
        pausedAt: Date? = nil,
        remainingSecondsWhenPaused: Int? = nil,
        durationSeconds: Int = 25 * 60,
        sessionsCompletedInCycle: Int = 0,
        deviceName: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.timerId = timerId
        self.sessionType = sessionType
        self.status = status
        self.startedAt = startedAt
        self.targetEndAt = targetEndAt
        self.pausedAt = pausedAt
        self.remainingSecondsWhenPaused = remainingSecondsWhenPaused
        self.durationSeconds = durationSeconds
        self.sessionsCompletedInCycle = sessionsCompletedInCycle
        self.deviceName = deviceName
    }
}

// MARK: - SessionRecord

/// 已完成的 Session 记录
public struct SessionRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var schemaVersion: Int
    public var sessionType: SessionType
    public var startedAt: Date
    public var endedAt: Date
    public var durationSeconds: Int
    public var completed: Bool
    public var createdAt: Date
    public var sourceDevice: String?
    public var completedTaskIds: [UUID]?  // 本次完成的任务 ID
    public var taskProgress: [UUID: Int]?  // 任务进度百分比

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        sessionType: SessionType,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        completed: Bool = true,
        createdAt: Date = Date(),
        sourceDevice: String? = nil,
        completedTaskIds: [UUID]? = nil,
        taskProgress: [UUID: Int]? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.sessionType = sessionType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.createdAt = createdAt
        self.sourceDevice = sourceDevice
        self.completedTaskIds = completedTaskIds
        self.taskProgress = taskProgress
    }
}

// MARK: - FlowSettings

/// 完整设置
public struct FlowSettings: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var updatedAt: Date?
    public var timer: TimerSettings

    public static let `default` = FlowSettings(
        schemaVersion: 1,
        updatedAt: nil,
        timer: .default
    )

    public init(
        schemaVersion: Int = 1,
        updatedAt: Date? = nil,
        timer: TimerSettings = .default
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.timer = timer
    }
}

// MARK: - SessionStats

/// Session 统计
public struct SessionStats: Codable, Equatable {
    public let totalSessions: Int
    public let focusSessions: Int
    public let totalFocusSeconds: Int

    public init(
        totalSessions: Int = 0,
        focusSessions: Int = 0,
        totalFocusSeconds: Int = 0
    ) {
        self.totalSessions = totalSessions
        self.focusSessions = focusSessions
        self.totalFocusSeconds = totalFocusSeconds
    }

    public init(sessions: [SessionRecord]) {
        var total = 0
        var focus = 0
        var focusSeconds = 0

        for session in sessions where session.completed {
            total += 1
            if session.sessionType == .focus {
                focus += 1
                focusSeconds += session.durationSeconds
            }
        }

        self.init(totalSessions: total, focusSessions: focus, totalFocusSeconds: focusSeconds)
    }

    public var formattedFocusDuration: String {
        let hours = totalFocusSeconds / 3600
        let minutes = (totalFocusSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
