import Foundation

/// 设置 ViewModel
@MainActor
@Observable
public final class SettingsViewModel {
    // MARK: - Properties

    private let settingsRepository: SettingsRepository

    /// Timer 设置
    public var timerSettings: TimerSettings = .default

    /// 是否已加载
    public var isLoaded = false

    // MARK: - Init

    public init(settingsRepository: SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    // MARK: - Actions

    /// 加载设置
    public func load() {
        let flowSettings = settingsRepository.load()
        timerSettings = flowSettings.timer
        isLoaded = true
    }

    /// 保存设置
    public func save() throws {
        let clamped = TimerRules.clamped(settings: timerSettings)
        timerSettings = clamped

        var flowSettings = settingsRepository.load()
        flowSettings.timer = clamped
        try settingsRepository.save(flowSettings)
    }

    /// 重置为默认设置
    public func resetToDefault() throws {
        timerSettings = .default
        try save()
    }

    /// 验证当前设置是否有效
    public var isValid: Bool {
        TimerRules.validate(settings: timerSettings)
    }
}
