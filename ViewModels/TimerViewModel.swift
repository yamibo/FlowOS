import Foundation
import SwiftUI

/// 计时器 ViewModel
///
/// 连接 TimerEngine 和 SwiftUI View
@MainActor
@Observable
public final class TimerViewModel {
    // MARK: - Properties

    private let coordinator: AppCoordinator

    /// 当前 Session 类型
    public var sessionType: SessionType

    /// 当前状态
    public var status: TimerStatus

    /// 剩余秒数
    public var remainingSeconds: Int

    /// 进度
    public var progress: Double

    /// 今日统计
    public var todayStats: SessionStats

    /// 当前周期已完成的专注数
    public var sessionsCompletedInCycle: Int

    /// 内部刷新定时器
    private var refreshTimer: Timer?

    /// 设置
    public var settings: TimerSettings {
        get { coordinator.settings }
        set { coordinator.saveSettings(newValue) }
    }

    /// 格式化剩余时间
    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 进度环颜色
    public var progressColor: Color {
        switch sessionType {
        case .focus:
            return .red
        case .shortBreak:
            return .green
        case .longBreak:
            return .blue
        }
    }

    // MARK: - Init

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator

        // 初始化状态
        self.sessionType = coordinator.engine.state.sessionType
        self.status = coordinator.engine.state.status
        self.remainingSeconds = coordinator.engine.remainingSeconds
        self.progress = coordinator.engine.progress
        self.todayStats = coordinator.todayStats
        self.sessionsCompletedInCycle = coordinator.engine.state.sessionsCompletedInCycle
    }

    /// 启动刷新定时器（在 View 出现时调用）
    public func startRefreshing() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshFromEngine()
            }
        }
    }

    /// 停止刷新定时器
    public func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Refresh Timer

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshFromEngine()
            }
        }
    }

    private func refreshFromEngine() {
        let engine = coordinator.engine
        sessionType = engine.state.sessionType
        status = engine.state.status
        remainingSeconds = engine.remainingSeconds
        progress = engine.progress
        todayStats = coordinator.todayStats
        sessionsCompletedInCycle = engine.state.sessionsCompletedInCycle
    }

    // MARK: - Actions

    /// 开始当前 Session
    public func start() {
        coordinator.startSession(sessionType)
        refreshFromEngine()
    }

    /// 暂停
    public func pause() {
        coordinator.pause()
        refreshFromEngine()
    }

    /// 恢复
    public func resume() {
        coordinator.resume()
        refreshFromEngine()
    }

    /// 停止
    public func stop() {
        coordinator.stop()
        refreshFromEngine()
    }

    /// 跳过
    public func skip() {
        coordinator.skip()
        refreshFromEngine()
    }

    /// 切换到指定 Session 类型
    public func switchTo(_ type: SessionType) {
        coordinator.stop()
        coordinator.startSession(type)
        refreshFromEngine()
    }
}
