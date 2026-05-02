import SwiftUI

@main
struct FlowOSAppleAppApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            MainTabView(coordinator: coordinator)
                .frame(minWidth: 400, minHeight: 500)
        }
        .windowStyle(.automatic)
        .commands {
            // 移除新建菜单
            CommandGroup(replacing: .newItem) { }

            // 添加设置菜单
            CommandGroup(after: .appSettings) {
                Button("设置...") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // 设置窗口
        #if os(macOS)
        WindowGroup("设置", id: "settings") {
            SettingsView(viewModel: SettingsViewModel(settingsRepository: coordinator.settingsRepository))
                .frame(width: 400, height: 400)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 400, height: 400)
        #endif

        #if os(macOS)
        // 菜单栏计时器
        MenuBarExtra("FlowOSApple", systemImage: "timer") {
            MenuBarExtraView(coordinator: coordinator, showSettings: $showSettings)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

#if os(macOS)
/// 菜单栏视图
struct MenuBarExtraView: View {
    @Bindable var coordinator: AppCoordinator
    @Binding var showSettings: Bool

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

                Button("停止") {
                    coordinator.stop()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // 打开主窗口
            Button("打开主窗口") {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            // 设置
            Button("设置...") {
                showSettings = true
            }

            Divider()

            // 退出
            Button("退出") {
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