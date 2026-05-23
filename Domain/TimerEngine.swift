import Foundation

/// 计时引擎
///
/// 核心职责：
/// - 基于 targetEndAt 计算剩余时间（防止漂移）
/// - 管理计时器状态转换
/// - 提供时间更新回调
public final class TimerEngine {
    // MARK: - Properties

    /// 时间更新回调（remainingSeconds, progress）
    public var onTick: ((Int, Double) -> Void)?

    /// Session 完成回调（sessionType, startedAt, durationSeconds）
    public var onComplete: ((SessionType, Date, Int) -> Void)?

    /// Session 停止回调（sessionType, startedAt, elapsedSeconds）
    public var onStop: ((SessionType, Date, Int) -> Void)?

    /// Session 跳过回调（sessionType, startedAt, elapsedSeconds）
    public var onSkip: ((SessionType, Date, Int) -> Void)?

    /// 当前状态
    public private(set) var state: ActiveTimerState

    /// 设置
    public var settings: TimerSettings

    /// 内部计时器
    private var timer: Timer?

    /// 是否已启动
    public private(set) var isRunning: Bool = false

    // MARK: - Init

    public init(settings: TimerSettings = .default) {
        self.settings = settings
        self.state = .idle(durationSeconds: settings.durationSeconds(for: .focus))
    }

    // MARK: - Public API

    /// 开始计时
    public func start(sessionType: SessionType, durationSeconds: Int? = nil) {
        stopTimer()

        let duration = durationSeconds ?? settings.durationSeconds(for: sessionType)
        let now = Date()
        let targetEnd = now.addingTimeInterval(TimeInterval(duration))

        state = ActiveTimerState(
            schemaVersion: 1,
            updatedAt: now,
            timerId: UUID(),
            sessionType: sessionType,
            status: .running,
            startedAt: now,
            targetEndAt: targetEnd,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: duration,
            sessionsCompletedInCycle: state.sessionsCompletedInCycle,
            deviceName: Host.current().localizedName
        )

        isRunning = true
        startTimer()
        notifyTick()
    }

    /// 暂停
    public func pause() {
        guard state.status == .running else { return }
        stopTimer()

        let remaining = remainingSeconds
        state = ActiveTimerState(
            schemaVersion: state.schemaVersion,
            updatedAt: Date(),
            timerId: state.timerId,
            sessionType: state.sessionType,
            status: .paused,
            startedAt: state.startedAt,
            targetEndAt: nil,
            pausedAt: Date(),
            remainingSecondsWhenPaused: remaining,
            durationSeconds: state.durationSeconds,
            sessionsCompletedInCycle: state.sessionsCompletedInCycle,
            deviceName: state.deviceName
        )

        isRunning = false
        notifyTick()
    }

    /// 恢复
    public func resume() {
        guard state.status == .paused else { return }

        let remaining = state.remainingSecondsWhenPaused ?? state.durationSeconds
        let now = Date()
        let targetEnd = now.addingTimeInterval(TimeInterval(remaining))

        state = ActiveTimerState(
            schemaVersion: state.schemaVersion,
            updatedAt: now,
            timerId: state.timerId,
            sessionType: state.sessionType,
            status: .running,
            startedAt: state.startedAt,
            targetEndAt: targetEnd,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: state.durationSeconds,
            sessionsCompletedInCycle: state.sessionsCompletedInCycle,
            deviceName: state.deviceName
        )

        isRunning = true
        startTimer()
        notifyTick()
    }

    /// 停止（取消当前 Session）
    public func stop() {
        // 在重置状态之前保存信息
        let stoppedSessionType = state.sessionType
        let startedAt = state.startedAt ?? Date()
        let elapsedSeconds = calculateElapsedSeconds()

        stopTimer()

        state = ActiveTimerState(
            schemaVersion: 1,
            updatedAt: Date(),
            timerId: nil,
            sessionType: state.sessionType,
            status: .idle,
            startedAt: nil,
            targetEndAt: nil,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: state.durationSeconds,
            sessionsCompletedInCycle: state.sessionsCompletedInCycle,
            deviceName: nil
        )

        isRunning = false
        notifyTick()

        // 通知停止事件（传递完整信息）
        onStop?(stoppedSessionType, startedAt, elapsedSeconds)
    }

    /// 跳过当前 Session
    public func skip() {
        // 在重置状态之前保存信息
        let skippedSessionType = state.sessionType
        let startedAt = state.startedAt ?? Date()
        let elapsedSeconds = calculateElapsedSeconds()

        stopTimer()

        // 通知跳过事件（传递完整信息）
        onSkip?(skippedSessionType, startedAt, elapsedSeconds)

        advanceToNextSession()
    }

    /// 计算已运行的时长（秒）
    private func calculateElapsedSeconds() -> Int {
        guard let startedAt = state.startedAt else { return 0 }
        let elapsed = state.durationSeconds - remainingSeconds
        return max(0, elapsed)
    }

    /// 恢复状态（用于 App 重启后恢复）
    public func restoreState(_ state: ActiveTimerState) {
        stopTimer()
        self.state = state
        self.isRunning = false
        notifyTick()
    }

    /// 完成当前 Session
    public func complete() {
        stopTimer()

        // 在重置状态之前保存信息
        let completedSessionType = state.sessionType
        let startedAt = state.startedAt ?? Date()
        let duration = state.durationSeconds

        // 更新 cycle 计数
        let newSessionsCompleted: Int
        if state.sessionType == .focus {
            newSessionsCompleted = state.sessionsCompletedInCycle + 1
        } else {
            newSessionsCompleted = state.sessionsCompletedInCycle
        }

        state = ActiveTimerState(
            schemaVersion: 1,
            updatedAt: Date(),
            timerId: nil,
            sessionType: state.sessionType,
            status: .idle,
            startedAt: nil,
            targetEndAt: nil,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: state.durationSeconds,
            sessionsCompletedInCycle: newSessionsCompleted,
            deviceName: nil
        )

        isRunning = false
        onComplete?(completedSessionType, startedAt, duration)
    }

    // MARK: - State Query

    /// 当前剩余秒数
    public var remainingSeconds: Int {
        switch state.status {
        case .idle:
            return state.durationSeconds
        case .running:
            guard let targetEnd = state.targetEndAt else { return state.durationSeconds }
            let remaining = Int(targetEnd.timeIntervalSinceNow)
            return max(0, remaining)
        case .paused:
            return state.remainingSecondsWhenPaused ?? state.durationSeconds
        }
    }

    /// 当前进度 (0.0 - 1.0)
    public var progress: Double {
        guard state.durationSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(state.durationSeconds)
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.handleTick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTick() {
        let remaining = remainingSeconds

        if remaining <= 0 {
            // 时间到，自动完成
            complete()
            advanceToNextSession()
            return
        }

        notifyTick()
    }

    private func notifyTick() {
        onTick?(remainingSeconds, progress)
    }

    private func advanceToNextSession() {
        let nextType = TimerRules.nextSessionType(
            after: state.sessionType,
            sessionsCompletedInCycle: state.sessionsCompletedInCycle,
            longBreakEvery: settings.longBreakEvery
        )

        // 如果是休息后回到专注，重置 cycle 计数
        let newSessionsCompleted: Int
        if state.sessionType == .longBreak {
            newSessionsCompleted = 0
        } else {
            newSessionsCompleted = state.sessionsCompletedInCycle
        }

        let newDuration = settings.durationSeconds(for: nextType)

        state = ActiveTimerState(
            schemaVersion: 1,
            updatedAt: Date(),
            timerId: nil,
            sessionType: nextType,
            status: .idle,
            startedAt: nil,
            targetEndAt: nil,
            pausedAt: nil,
            remainingSecondsWhenPaused: nil,
            durationSeconds: newDuration,
            sessionsCompletedInCycle: newSessionsCompleted,
            deviceName: nil
        )

        notifyTick()
    }
}
