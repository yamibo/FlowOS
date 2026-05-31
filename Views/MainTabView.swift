import SwiftUI

/// 主标签视图
public struct MainTabView: View {
    // MARK: - Properties

    @Bindable var coordinator: AppCoordinator
    @State private var selectedTab = 0
    @State private var isReady = false
    @State private var timerViewModel: TimerViewModel?
    @State private var settingsViewModel = SettingsViewModel(settingsRepository: .shared)
    @Environment(\.languageVersion) private var languageVersion

    // MARK: - Body

    public var body: some View {
        let _ = languageVersion
        Group {
            if isReady {
                contentView
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L("Loading...", defaultValue: "加载中..."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FlowOSDesign.pageBackground)
            }
        }
        .task {
            await coordinator.initialize()
            timerViewModel = TimerViewModel(coordinator: coordinator)
            isReady = true
        }
    }

    private var contentView: some View {
        TabView(selection: $selectedTab) {
            // 计时器标签页
            if let viewModel = timerViewModel {
                TimerView(viewModel: viewModel)
                    .tabItem {
                        Label(L("Timer", defaultValue: "计时器"), systemImage: "timer")
                    }
                    .tag(0)
            }

            // TodoList 标签页
            TodoListView(viewModel: coordinator.todoListViewModel)
                .tabItem {
                    Label(L("Todo", defaultValue: "待办"), systemImage: "checklist")
                }
                .tag(1)

            // 历史记录标签页
            HistoryView(
                viewModel: HistoryViewModel(sessionRepository: coordinator.sessionRepository),
                todoRepository: coordinator.todoRepository
            )
                .tabItem {
                    Label(L("History", defaultValue: "历史"), systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label(L("Settings", defaultValue: "设置"), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .background(FlowOSDesign.pageBackground)
        .sheet(isPresented: $coordinator.showSessionCompletion) {
            SessionCompletionView(
                todoViewModel: coordinator.todoListViewModel,
                sessionType: coordinator.completedSessionType
            ) { completedTaskIds, taskProgress in
                coordinator.handleTaskSelection(
                    completedTaskIds: completedTaskIds,
                    taskProgress: taskProgress
                )
            }
        }
        .onChange(of: coordinator.shouldSwitchToTimerTab) { _, newValue in
            if newValue {
                selectedTab = 0
                coordinator.shouldSwitchToTimerTab = false
            }
        }
    }

    // MARK: - Init

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
}

enum FlowOSDesign {
    #if os(macOS)
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let elevatedBackground = Color(nsColor: .textBackgroundColor)
    #else
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let panelBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedBackground = Color(uiColor: .systemBackground)
    #endif
    static let hairline = Color.secondary.opacity(0.12)

    static func sessionColor(_ type: SessionType) -> Color {
        switch type {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

struct FlowOSPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 900)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)
        }
        .background(FlowOSDesign.pageBackground)
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        28
        #endif
    }

    private var verticalPadding: CGFloat {
        #if os(iOS)
        18
        #else
        24
        #endif
    }
}

struct FlowOSPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(FlowOSDesign.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(FlowOSDesign.hairline, lineWidth: 1)
            }
    }
}

struct FlowOSMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: iconFrame, height: iconFrame)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(12)
        .background(FlowOSDesign.elevatedBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(FlowOSDesign.hairline, lineWidth: 1)
        }
    }

    private var iconSize: CGFloat {
        #if os(iOS)
        15
        #else
        16
        #endif
    }

    private var iconFrame: CGFloat {
        #if os(iOS)
        28
        #else
        30
        #endif
    }

    private var valueFontSize: CGFloat {
        #if os(iOS)
        18
        #else
        19
        #endif
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator())
}
