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

    /// 当前完成的 Session 类型（用于显示）
    public var completedSessionType: SessionType = .focus

    /// 休息结束后是否应自动切换到计时器标签页
    public var shouldSwitchToTimerTab = false

    /// 当前 Session 完成回调
    private var sessionCompletionHandler: (([UUID], [UUID: Int]) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    /// 当前设置
    public var settings: TimerSettings = .default

    /// 今日统计
    public var todayStats: SessionStats = SessionStats()

    /// 是否已初始化
    public var isInitialized = false

    /// 菜单栏显示用的剩余时间（用于触发 UI 更新）
    public var menuBarRemainingSeconds: Int = 25 * 60

    /// 菜单栏显示用的计时器状态
    public var menuBarStatus: TimerStatus = .idle

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
        setupDataDirectoryObserver()
    }

    // MARK: - Public API

    /// 初始化
    public func initialize() async {
        // 请求数据目录授权
        await requestDirectoryAuthorization()

        // 加载设置
        settings = settingsRepository.load().timer

        // 初始化菜单栏显示
        menuBarRemainingSeconds = settings.durationSeconds(for: .focus)

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

    /// 请求数据目录授权
    private func requestDirectoryAuthorization() async {
        let syncManager = iCloudDriveSyncManager.shared
        if !syncManager.isICloudDriveAvailable {
            _ = await syncManager.ensureAuthorized()
        }
    }

    /// 开始 Session
    public func startSession(_ type: SessionType) {
        // 重新加载设置以获取最新值
        settings = settingsRepository.load().timer
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
                guard let self = self else { return }
                // 更新菜单栏显示属性（触发 UI 刷新）
                self.menuBarRemainingSeconds = remaining
                self.menuBarStatus = self.engine.state.status
                self.updateWidgetData()
                self.saveCurrentState()
            }
        }

        engine.onComplete = { [weak self] completedSessionType, startedAt, durationSeconds in
            Task { @MainActor in
                guard let self = self else { return }
                self.menuBarStatus = .idle
                await self.handleSessionComplete(
                    completedSessionType: completedSessionType,
                    startedAt: startedAt,
                    durationSeconds: durationSeconds
                )
            }
        }

        engine.onStop = { [weak self] stoppedSessionType, startedAt, elapsedSeconds in
            Task { @MainActor in
                guard let self = self else { return }
                self.menuBarStatus = .idle
                self.handleSessionStopped(
                    sessionType: stoppedSessionType,
                    startedAt: startedAt,
                    elapsedSeconds: elapsedSeconds
                )
            }
        }

        engine.onSkip = { [weak self] skippedSessionType, startedAt, elapsedSeconds in
            Task { @MainActor in
                guard let self = self else { return }
                self.menuBarStatus = .idle
                self.handleSessionSkipped(
                    sessionType: skippedSessionType,
                    startedAt: startedAt,
                    elapsedSeconds: elapsedSeconds
                )
            }
        }
    }

    private func handleSessionComplete(completedSessionType: SessionType, startedAt: Date, durationSeconds: Int) async {
        self.completedSessionType = completedSessionType

        if completedSessionType == .focus {
            showSessionCompletion = true
        } else {
            recordSession(
                sessionType: completedSessionType,
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                completed: true,
                completedTaskIds: nil,
                taskProgress: nil
            )
            shouldSwitchToTimerTab = true
        }

        // 发送通知
        await notificationService.sendSessionCompleteNotification(sessionType: completedSessionType)

        // 更新 Widget
        updateWidgetData()
    }

    /// 处理停止事件
    private func handleSessionStopped(sessionType: SessionType, startedAt: Date, elapsedSeconds: Int) {
        self.completedSessionType = sessionType

        // 只有运行了一段时间才记录
        if elapsedSeconds > 0 {
            if sessionType == .focus {
                // 专注时段停止，显示任务选择
                showSessionCompletion = true
            } else {
                // 非专注时段，直接记录
                recordSession(
                    sessionType: sessionType,
                    startedAt: startedAt,
                    durationSeconds: elapsedSeconds,
                    completed: false,
                    completedTaskIds: nil,
                    taskProgress: nil
                )
            }
        }

        // 更新 Widget
        updateWidgetData()
    }

    /// 处理跳过事件
    private func handleSessionSkipped(sessionType: SessionType, startedAt: Date, elapsedSeconds: Int) {
        self.completedSessionType = sessionType

        if sessionType == .focus {
            // 专注时段跳过，显示任务选择
            showSessionCompletion = true
        } else {
            // 非专注时段，直接记录
            recordSession(
                sessionType: sessionType,
                startedAt: startedAt,
                durationSeconds: elapsedSeconds,
                completed: false,
                completedTaskIds: nil,
                taskProgress: nil
            )
            // 休息跳过，跳转到计时器标签页
            shouldSwitchToTimerTab = true
        }

        // 更新 Widget
        updateWidgetData()
    }

    /// 记录 Session
    private func recordSession(
        sessionType: SessionType,
        startedAt: Date,
        durationSeconds: Int,
        completed: Bool,
        completedTaskIds: [UUID]?,
        taskProgress: [UUID: Int]?
    ) {
        let record = SessionRecord(
            sessionType: sessionType,
            startedAt: startedAt,
            endedAt: Date(),
            durationSeconds: durationSeconds,
            completed: completed,
            completedTaskIds: completedTaskIds,
            taskProgress: taskProgress
        )
        try? sessionRepository.append(record)

        // 更新今日统计
        todayStats = sessionRepository.getTodayStats()
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
        if let startedAt = engine.state.startedAt {
            recordSession(
                sessionType: sessionType,
                startedAt: startedAt,
                durationSeconds: engine.state.durationSeconds,
                completed: true,
                completedTaskIds: completedTaskIds.isEmpty ? nil : completedTaskIds,
                taskProgress: taskProgress.isEmpty ? nil : taskProgress
            )
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

    private func setupDataDirectoryObserver() {
        NotificationCenter.default.publisher(for: .dataDirectoryDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.settings = self.settingsRepository.load().timer
                self.todayStats = self.sessionRepository.getTodayStats()
                self.todoListViewModel.load()
            }
            .store(in: &cancellables)
    }
}
