import SwiftUI

/// 主标签视图
public struct MainTabView: View {
    // MARK: - Properties

    @Bindable var coordinator: AppCoordinator
    @State private var selectedTab = 0
    @State private var isReady = false

    // MARK: - Body

    public var body: some View {
        Group {
            if isReady {
                contentView
            } else {
                ProgressView("加载中...")
            }
        }
        .task {
            await coordinator.initialize()
            isReady = true
        }
    }

    private var contentView: some View {
        TabView(selection: $selectedTab) {
            // 计时器标签页
            TimerView(viewModel: TimerViewModel(coordinator: coordinator))
                .tabItem {
                    Label("计时器", systemImage: "timer")
                }
                .tag(0)

            // TodoList 标签页
            TodoListView(viewModel: coordinator.todoListViewModel)
                .tabItem {
                    Label("待办", systemImage: "checklist")
                }
                .tag(1)

            // 历史记录标签页
            HistoryView(viewModel: HistoryViewModel(sessionRepository: coordinator.sessionRepository))
                .tabItem {
                    Label("历史", systemImage: "chart.bar.fill")
                }
                .tag(2)
        }
        .sheet(isPresented: $coordinator.showSessionCompletion) {
            SessionCompletionView(
                todoViewModel: coordinator.todoListViewModel
            ) { completedTaskIds, taskProgress in
                coordinator.handleTaskSelection(
                    completedTaskIds: completedTaskIds,
                    taskProgress: taskProgress
                )
            }
        }
    }

    // MARK: - Init

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator())
}