import SwiftUI

/// 设置视图
public struct SettingsView: View {
    // MARK: - Properties

    @Bindable var viewModel: SettingsViewModel

    // MARK: - Body

    public var body: some View {
        Form {
            // 时长设置
            Section("时长设置") {
                durationRow(
                    title: "专注时长",
                    value: $viewModel.timerSettings.focusMinutes,
                    range: TimerRules.focusMinutesRange,
                    unit: "分钟"
                )

                durationRow(
                    title: "短休息时长",
                    value: $viewModel.timerSettings.shortBreakMinutes,
                    range: TimerRules.shortBreakMinutesRange,
                    unit: "分钟"
                )

                durationRow(
                    title: "长休息时长",
                    value: $viewModel.timerSettings.longBreakMinutes,
                    range: TimerRules.longBreakMinutesRange,
                    unit: "分钟"
                )

                durationRow(
                    title: "长休息间隔",
                    value: $viewModel.timerSettings.longBreakEvery,
                    range: TimerRules.longBreakEveryRange,
                    unit: "次专注"
                )
            }

            // 自动开始设置
            Section("自动开始") {
                Toggle("休息后自动开始专注", isOn: $viewModel.timerSettings.autoStartFocus)
                Toggle("专注后自动开始休息", isOn: $viewModel.timerSettings.autoStartBreak)
            }

            // 重置
            Section {
                Button("重置为默认设置") {
                    try? viewModel.resetToDefault()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Subviews

    private func durationRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }

    // MARK: - Init

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
}

#Preview {
    let viewModel = SettingsViewModel(settingsRepository: .shared)
    SettingsView(viewModel: viewModel)
        .frame(width: 400, height: 500)
}
