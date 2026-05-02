import Foundation

/// 计时规则
///
/// 定义：
/// - 时长范围限制
/// - Session 切换逻辑
/// - 设置验证
public enum TimerRules {
    // MARK: - Duration Limits

    /// 专注时长范围（分钟）
    public static let focusMinutesRange = 1...180

    /// 短休息时长范围（分钟）
    public static let shortBreakMinutesRange = 1...60

    /// 长休息时长范围（分钟）
    public static let longBreakMinutesRange = 1...120

    /// 长休息间隔范围
    public static let longBreakEveryRange = 1...12

    // MARK: - Session Transition

    /// 计算下一个 Session 类型
    public static func nextSessionType(
        after current: SessionType,
        sessionsCompletedInCycle: Int,
        longBreakEvery: Int
    ) -> SessionType {
        switch current {
        case .focus:
            // 专注后判断是否需要长休息
            if sessionsCompletedInCycle >= longBreakEvery {
                return .longBreak
            } else {
                return .shortBreak
            }
        case .shortBreak, .longBreak:
            // 休息后回到专注
            return .focus
        }
    }

    // MARK: - Settings Validation

    /// 验证设置是否有效
    public static func validate(settings: TimerSettings) -> Bool {
        focusMinutesRange.contains(settings.focusMinutes) &&
        shortBreakMinutesRange.contains(settings.shortBreakMinutes) &&
        longBreakMinutesRange.contains(settings.longBreakMinutes) &&
        longBreakEveryRange.contains(settings.longBreakEvery)
    }

    /// Clamp 设置到有效范围
    public static func clamped(settings: TimerSettings) -> TimerSettings {
        TimerSettings(
            focusMinutes: max(focusMinutesRange.lowerBound, min(focusMinutesRange.upperBound, settings.focusMinutes)),
            shortBreakMinutes: max(shortBreakMinutesRange.lowerBound, min(shortBreakMinutesRange.upperBound, settings.shortBreakMinutes)),
            longBreakMinutes: max(longBreakMinutesRange.lowerBound, min(longBreakMinutesRange.upperBound, settings.longBreakMinutes)),
            longBreakEvery: max(longBreakEveryRange.lowerBound, min(longBreakEveryRange.upperBound, settings.longBreakEvery)),
            autoStartBreak: settings.autoStartBreak,
            autoStartFocus: settings.autoStartFocus
        )
    }
}
