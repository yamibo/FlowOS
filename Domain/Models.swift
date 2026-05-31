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
        case .focus: return L("Focus", defaultValue: "专注")
        case .shortBreak: return L("Short Break", defaultValue: "短休息")
        case .longBreak: return L("Long Break", defaultValue: "长休息")
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
    public var sourceDevice: DeviceInfo?

    public static func idle(
        sessionType: SessionType = .focus,
        durationSeconds: Int = 25 * 60,
        sessionsCompletedInCycle: Int = 0
    ) -> ActiveTimerState {
        ActiveTimerState(
            schemaVersion: FlowOSDataSchema.currentVersion,
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
            deviceName: nil,
            sourceDevice: .current
        )
    }

    public init(
        schemaVersion: Int = FlowOSDataSchema.currentVersion,
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
        deviceName: String? = nil,
        sourceDevice: DeviceInfo? = .current
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
        self.sourceDevice = sourceDevice
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
    public var sourceDeviceInfo: DeviceInfo?
    public var completedTaskIds: [UUID]?  // 本次完成的任务 ID
    public var taskProgress: [UUID: Int]?  // 任务进度百分比
    public var taskUpdates: [SessionTaskUpdate]?

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = FlowOSDataSchema.currentVersion,
        sessionType: SessionType,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        completed: Bool = true,
        createdAt: Date = Date(),
        sourceDevice: String? = nil,
        sourceDeviceInfo: DeviceInfo? = .current,
        completedTaskIds: [UUID]? = nil,
        taskProgress: [UUID: Int]? = nil,
        taskUpdates: [SessionTaskUpdate]? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.sessionType = sessionType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.createdAt = createdAt
        self.sourceDevice = sourceDevice ?? sourceDeviceInfo?.name
        self.sourceDeviceInfo = sourceDeviceInfo
        self.completedTaskIds = completedTaskIds
        self.taskProgress = taskProgress
        self.taskUpdates = taskUpdates ?? SessionRecord.makeTaskUpdates(from: taskProgress)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case sessionType
        case startedAt
        case endedAt
        case durationSeconds
        case completed
        case createdAt
        case sourceDevice
        case sourceDeviceInfo
        case completedTaskIds
        case taskProgress
        case taskUpdates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? FlowOSDataSchema.legacyVersion
        sessionType = try container.decode(SessionType.self, forKey: .sessionType)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? endedAt
        sourceDevice = try container.decodeIfPresent(String.self, forKey: .sourceDevice)
        sourceDeviceInfo = try container.decodeIfPresent(DeviceInfo.self, forKey: .sourceDeviceInfo)
        completedTaskIds = try container.decodeIfPresent([UUID].self, forKey: .completedTaskIds)
        taskProgress = try container.decodeIfPresent([UUID: Int].self, forKey: .taskProgress)
        taskUpdates = try container.decodeIfPresent([SessionTaskUpdate].self, forKey: .taskUpdates)
            ?? SessionRecord.makeTaskUpdates(from: taskProgress)
    }

    private static func makeTaskUpdates(from progress: [UUID: Int]?) -> [SessionTaskUpdate]? {
        guard let progress, !progress.isEmpty else { return nil }
        return progress.map { taskId, percentage in
            SessionTaskUpdate(
                taskId: taskId,
                completedPercentage: percentage,
                completedAt: percentage >= 100 ? Date() : nil
            )
        }
        .sorted { $0.taskId.uuidString < $1.taskId.uuidString }
    }
}

// MARK: - FlowSettings

/// 完整设置
public struct FlowSettings: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var updatedAt: Date?
    public var timer: TimerSettings
    public var sourceDevice: DeviceInfo?

    public static let `default` = FlowSettings(
        schemaVersion: FlowOSDataSchema.currentVersion,
        updatedAt: nil,
        timer: .default,
        sourceDevice: .current
    )

    public init(
        schemaVersion: Int = FlowOSDataSchema.currentVersion,
        updatedAt: Date? = nil,
        timer: TimerSettings = .default,
        sourceDevice: DeviceInfo? = .current
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.timer = timer
        self.sourceDevice = sourceDevice
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
