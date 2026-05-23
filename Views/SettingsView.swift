import SwiftUI

/// 设置视图
public struct SettingsView: View {
    // MARK: - Properties

    @Bindable var viewModel: SettingsViewModel
    @State private var directoryChangeMessage: String?
    @State private var isChangingDirectory = false
    @Environment(\.languageVersion) private var languageVersion

    // MARK: - Body

    public var body: some View {
        FlowOSPage {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Settings", defaultValue: "设置"))
                        .font(.title2.bold())
                    Text(L("Tune the timer, language, and sync location.", defaultValue: "调整计时、语言和同步位置。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                FlowOSPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionTitle(L("Language", defaultValue: "语言"), icon: "globe")
                        Picker(L("Language", defaultValue: "语言"), selection: Binding(
                            get: { LanguageManager.shared.currentLanguage },
                            set: { LanguageManager.shared.currentLanguage = $0 }
                        )) {
                            Text("简体中文").tag("zh-Hans")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                FlowOSPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionTitle(L("Data Sync", defaultValue: "数据同步"), icon: "externaldrive.fill")
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L("Data Storage Directory", defaultValue: "数据存储目录"))
                                    .font(.subheadline.weight(.medium))
                                Text(storageDirectoryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button {
                                Task {
                                    await changeDirectory()
                                }
                            } label: {
                                Label(L("Change", defaultValue: "更改"), systemImage: "folder")
                            }
                            .disabled(isChangingDirectory)
                        }
                    }
                }

                FlowOSPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionTitle(L("Duration Settings", defaultValue: "时长设置"), icon: "slider.horizontal.3")
                        durationRow(
                            title: L("Focus Duration", defaultValue: "专注时长"),
                            value: $viewModel.timerSettings.focusMinutes,
                            range: TimerRules.focusMinutesRange,
                            unit: L("minutes", defaultValue: "分钟")
                        )

                        durationRow(
                            title: L("Short Break Duration", defaultValue: "短休息时长"),
                            value: $viewModel.timerSettings.shortBreakMinutes,
                            range: TimerRules.shortBreakMinutesRange,
                            unit: L("minutes", defaultValue: "分钟")
                        )

                        durationRow(
                            title: L("Long Break Duration", defaultValue: "长休息时长"),
                            value: $viewModel.timerSettings.longBreakMinutes,
                            range: TimerRules.longBreakMinutesRange,
                            unit: L("minutes", defaultValue: "分钟")
                        )

                        durationRow(
                            title: L("Long Break Every", defaultValue: "长休息间隔"),
                            value: $viewModel.timerSettings.longBreakEvery,
                            range: TimerRules.longBreakEveryRange,
                            unit: L("focus sessions", defaultValue: "次专注")
                        )
                    }
                }

                FlowOSPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle(L("Auto-start", defaultValue: "自动开始"), icon: "play.circle.fill")
                        Toggle(L("Auto-start Focus After Break", defaultValue: "休息后自动开始专注"), isOn: $viewModel.timerSettings.autoStartFocus)
                        Toggle(L("Auto-start Break After Focus", defaultValue: "专注后自动开始休息"), isOn: $viewModel.timerSettings.autoStartBreak)
                    }
                }

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        try? viewModel.resetToDefault()
                    } label: {
                        Label(L("Reset to Default", defaultValue: "重置为默认设置"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .onAppear {
            if !viewModel.isLoaded {
                viewModel.load()
            }
        }
        .alert(
            L("Storage Directory", defaultValue: "存储目录"),
            isPresented: Binding(
                get: { directoryChangeMessage != nil },
                set: { if !$0 { directoryChangeMessage = nil } }
            )
        ) {
            Button(L("OK", defaultValue: "确定"), role: .cancel) {
                directoryChangeMessage = nil
            }
        } message: {
            Text(directoryChangeMessage ?? "")
        }
    }

    // MARK: - Private

    private func changeDirectory() async {
        let syncManager = iCloudDriveSyncManager.shared
        isChangingDirectory = true
        defer { isChangingDirectory = false }

        do {
            guard let result = try await syncManager.changeDataDirectory() else {
                return
            }
            viewModel.load()
            directoryChangeMessage = directoryChangeSummary(for: result)
        } catch {
            directoryChangeMessage = L("Could not change the storage directory.", defaultValue: "无法更改存储目录。") + "\n\(error.localizedDescription)"
        }
    }

    private func directoryChangeSummary(for result: DirectoryChangeResult) -> String {
        var lines = [
            L("Storage directory updated.", defaultValue: "存储目录已更新。"),
            result.directory.path
        ]

        if result.didCopyFiles {
            lines.append(
                L("Migrated data files:", defaultValue: "已迁移数据文件：") + " " + result.copiedFiles.joined(separator: ", ")
            )
        }

        if result.didKeepExistingFiles {
            lines.append(
                L("Kept existing files in the new directory:", defaultValue: "已保留新目录中的现有文件：") + " " + result.keptExistingFiles.joined(separator: ", ")
            )
        }

        if !result.didCopyFiles && !result.didKeepExistingFiles {
            lines.append(L("No existing data files needed to be migrated.", defaultValue: "没有需要迁移的已有数据文件。"))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Subviews

    private var storageDirectoryText: String {
        if let dir = iCloudDriveSyncManager.shared.appDataDirectory {
            return dir.path
        }
        return L("Not Set", defaultValue: "未设置")
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func durationRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
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
