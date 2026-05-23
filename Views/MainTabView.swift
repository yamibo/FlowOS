import SwiftUI

/// 主标签视图
public struct MainTabView: View {
    // MARK: - Properties

    @Bindable var coordinator: AppCoordinator
    @State private var selectedTab = 0
    @State private var isReady = false
    @State private var timerViewModel: TimerViewModel?
    @Environment(\.languageVersion) private var languageVersion

    // MARK: - Body

    public var body: some View {
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
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let elevatedBackground = Color(nsColor: .textBackgroundColor)
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
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
        .background(FlowOSDesign.pageBackground)
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
}

#Preview {
    MainTabView(coordinator: AppCoordinator())
}
