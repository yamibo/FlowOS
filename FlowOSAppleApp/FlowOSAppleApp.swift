import SwiftUI
import Darwin

// 全局日志文件路径
private let logURL: URL = {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("FlowOSApple.log")
    FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
    return url
}()

// 自定义日志函数：同时输出到控制台和文件
func logPrint(_ message: String) {
    print(message)
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logLine = "[\(timestamp)] \(message)\n"
    if let data = logLine.data(using: .utf8) {
        // 追加写入
        if let fileHandle = try? FileHandle(forWritingTo: logURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            try? data.write(to: logURL)
        }
    }
}

@main
struct FlowOSAppleAppApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var languageManager = LanguageManager.shared
    @State private var settingsViewModel = SettingsViewModel(settingsRepository: .shared)

    init() {
        logPrint("=== App started at \(Date()) ===")
        logPrint("Log file location: \(logURL.path)")
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(coordinator: coordinator)
                .environment(\.locale, languageManager.currentLocale)
                .environment(\.languageVersion, languageManager.languageVersion)
                .frame(minWidth: 720, minHeight: 620)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        #if os(macOS)
        Settings {
            SettingsView(viewModel: settingsViewModel)
                .environment(\.locale, languageManager.currentLocale)
                .environment(\.languageVersion, languageManager.languageVersion)
                .frame(width: 560, height: 640)
        }
        #endif

        #if os(macOS)
        MenuBarExtra(menuBarTitle) {
            MenuBarExtraView(coordinator: coordinator)
                .environment(\.locale, languageManager.currentLocale)
                .environment(\.languageVersion, languageManager.languageVersion)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// 菜单栏标题（显示倒计时）
    private var menuBarTitle: String {
        let remaining = coordinator.menuBarRemainingSeconds
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)

        // 根据状态添加指示符
        switch coordinator.menuBarStatus {
        case .idle:
            return "⏱︎ \(timeString)"
        case .running:
            return "▶︎ \(timeString)"
        case .paused:
            return "⏸︎ \(timeString)"
        }
    }
}

#if os(macOS)
/// 菜单栏视图
struct MenuBarExtraView: View {
    let coordinator: AppCoordinator
    @Environment(\.languageVersion) private var languageVersion

    var body: some View {
        VStack(spacing: 12) {
            // 时间显示
            Text(formattedTime)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            // Session 类型
            Text(coordinator.engine.state.sessionType.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 控制按钮
            HStack(spacing: 16) {
                Button {
                    if coordinator.engine.state.status == .running {
                        coordinator.pause()
                    } else if coordinator.engine.state.status == .paused {
                        coordinator.resume()
                    } else {
                        coordinator.startSession(coordinator.engine.state.sessionType)
                    }
                } label: {
                    Image(systemName: coordinator.engine.state.status == .running ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(L("Stop", defaultValue: "停止")) {
                    coordinator.stop()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Button(L("Open FlowOSApple", defaultValue: "打开 FlowOSApple")) {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            Button(L("Settings", defaultValue: "设置...")) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if #available(macOS 14, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }

            Divider()

            Button(L("Quit", defaultValue: "退出")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }

    private var formattedTime: String {
        let remaining = coordinator.engine.remainingSeconds
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
