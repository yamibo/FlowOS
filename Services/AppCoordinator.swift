import Foundation
import Combine

/// 应用协调器
///
/// 协调各个组件之间的交互
@MainActor
@Observable
public final class AppCoordinator {
    // MARK: - Properties

    /// 计时引擎
    public let engine: TimerEngine

    /// 设置仓库
    public let settingsRepository: SettingsRepository

    /// Session 仓库
    public let sessionRepository: SessionRepository

    /// 活动计时器仓库
    public let activeTimerRepository: ActiveTimerRepository

    /// 通知服务
    public let notificationService: NotificationService

    /// Widget 数据提供者
    public let widgetDataProvider: WidgetDataProvider

    /// 快捷键管理器
    public let keyboardShortcutManager: KeyboardShortcutManager

    /// Todo 仓库
    public let todoRepository: TodoRepository

    /// TodoList ViewModel（保持单例，避免切换标签页时数据丢失）
    public let todoListViewModel: TodoListViewModel

    /// 是否显示任务完成视图
    public var showSessionCompletion = false

    /// 当前 Session 完成回调
    private var sessionCompletionHandler: (([UUID], [UUID: Int]) -> Void)?

    /// 当前设置
    public var settings: TimerSettings = .default

    /// 今日统计
    public var todayStats: SessionStats = SessionStats()

    /// 是否已初始化
    public var isInitialized = false

    // MARK: - Init

    public init() {
        self.engine = TimerEngine()
        self.settingsRepository = .shared
        self.sessionRepository = .shared
        self.activeTimerRepository = .shared
        self.notificationService = .shared
        self.widgetDataProvider = .shared
        self.keyboardShortcutManager = .shared
        self.todoRepository = .shared
        self.todoListViewModel = TodoListViewModel(todoRepository: .shared)

        setupEngineCallbacks()
        setupKeyboardShortcut()
    }

    // MARK: - Public API

    /// 初始化
    public func initialize() async {
        // 加载设置
        settings = settingsRepository.load().timer

        // 加载今日统计
        todayStats = sessionRepository.getTodayStats()

        // 请求通知权限
        _ = await notificationService.requestAuthorization()

        // 恢复活动计时器状态
        if let savedState = activeTimerRepository.load() {
            restoreState(savedState)
        }

        isInitialized = true
    }

    /// 开始 Session
    public func startSession(_ type: SessionType) {
        engine.start(sessionType: type, durationSeconds: settings.durationSeconds(for: type))
    }

    /// 切换计时器（开始/暂停）
    public func toggleTimer() {
        switch engine.state.status {
        case .idle:
            startSession(engine.state.sessionType)
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    /// 暂停
    public func pause() {
        engine.pause()
        saveCurrentState()
    }

    /// 恢复
    public func resume() {
        engine.resume()
        saveCurrentState()
    }

    /// 停止
    public func stop() {
        engine.stop()
        clearSavedState()
    }

    /// 跳过
    public func skip() {
        engine.skip()
        saveCurrentState()
    }

    /// 保存设置
    public func saveSettings(_ newSettings: TimerSettings) {
        settings = newSettings
        var flowSettings = settingsRepository.load()
        flowSettings.timer = newSettings
        try? settingsRepository.save(flowSettings)
    }

    // MARK: - Private

    private func setupEngineCallbacks() {
        engine.onTick = { [weak self] remaining, progress in
            Task { @MainActor in
                self?.updateWidgetData()
                self?.saveCurrentState()
            }
        }

        engine.onComplete = { [weak self] in
            Task { @MainActor in
                await self?.handleSessionComplete()
            }
        }
    }

    private func handleSessionComplete() async {
        let sessionType = engine.state.sessionType

        // 记录 Session
        if sessionType == .focus, engine.state.startedAt != nil {
            // 显示任务选择视图
            showSessionCompletion = true
        }

        // 发送通知
        await notificationService.sendSessionCompleteNotification(sessionType: sessionType)

        // 更新 Widget
        updateWidgetData()
    }

    /// 处理任务选择完成
    public func handleTaskSelection(completedTaskIds: [UUID], taskProgress: [UUID: Int]) {
        showSessionCompletion = false

        let sessionType = engine.state.sessionType

        // 更新任务进度
        for (taskId, progress) in taskProgress {
            if let item = todoRepository.load().items.first(where: { $0.id == taskId }) {
                var updated = item
                updated.completedPercentage = progress
                if progress == 100 {
                    updated.isCompleted = true
                    updated.completedAt = Date()
                }
                try? todoRepository.update(updated)
            }
        }

        // 记录 Session
        if sessionType == .focus, let startedAt = engine.state.startedAt {
            let record = SessionRecord(
                sessionType: sessionType,
                startedAt: startedAt,
                endedAt: Date(),
                durationSeconds: engine.state.durationSeconds,
                completedTaskIds: completedTaskIds,
                taskProgress: taskProgress
            )
            try? sessionRepository.append(record)

            // 更新今日统计
            todayStats = sessionRepository.getTodayStats()
        }
    }

    private func updateWidgetData() {
        widgetDataProvider.update(
            sessionType: engine.state.sessionType,
            status: engine.state.status,
            remainingSeconds: engine.remainingSeconds,
            progress: engine.progress,
            sessionsCompletedToday: todayStats.focusSessions
        )
    }

    private func saveCurrentState() {
        try? activeTimerRepository.save(engine.state)
    }

    private func clearSavedState() {
        try? activeTimerRepository.clear()
    }

    private func restoreState(_ state: ActiveTimerState) {
        // 如果之前是运行中，计算剩余时间并恢复
        if state.status == .running, let targetEnd = state.targetEndAt {
            let remaining = Int(targetEnd.timeIntervalSinceNow)
            if remaining > 0 {
                // 还有剩余时间，恢复为暂停状态让用户手动恢复
                let pausedState = ActiveTimerState(
                    schemaVersion: state.schemaVersion,
                    updatedAt: state.updatedAt,
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
                engine.restoreState(pausedState)
            } else {
                // 已超时，重置为 idle
                let idleState = ActiveTimerState.idle(
                    sessionType: state.sessionType,
                    durationSeconds: settings.durationSeconds(for: state.sessionType),
                    sessionsCompletedInCycle: state.sessionsCompletedInCycle
                )
                engine.restoreState(idleState)
            }
        } else {
            engine.restoreState(state)
        }
    }

    private func setupKeyboardShortcut() {
        keyboardShortcutManager.setToggleHandler { [weak self] in
            DispatchQueue.main.async {
                self?.toggleTimer()
            }
        }
        // 延迟启动快捷键监听
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.keyboardShortcutManager.startListening()
        }
    }
}
