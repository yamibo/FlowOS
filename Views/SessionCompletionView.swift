import SwiftUI

/// 番茄钟完成时的任务选择视图
public struct SessionCompletionView: View {
    // MARK: - Properties

    @Bindable var todoViewModel: TodoListViewModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var selectedTasks: Set<UUID> = []
    @State private var taskProgress: [UUID: Int] = [:]
    @State private var expandedParents: Set<UUID> = []

    let sessionType: SessionType
    let onComplete: ([UUID], [UUID: Int]) -> Void

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 58, height: 58)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text(titleText)
                    .font(.title2.bold())

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 18)

            if sessionType == .focus && !todoViewModel.uncompletedTasks.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(unstartedTopLevelTasks) { task in
                            SessionTaskRow(
                                task: task,
                                level: 0,
                                todoViewModel: todoViewModel,
                                selectedTasks: $selectedTasks,
                                taskProgress: $taskProgress,
                                expandedParents: $expandedParents
                            )
                        }
                    }
                    .padding(16)
                }
                .background(FlowOSDesign.pageBackground)
            } else {
                VStack(spacing: 12) {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            }

            Divider()

            HStack(spacing: 16) {
                Button(L("Skip", defaultValue: "跳过")) {
                    onComplete([], [:])
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(L("Confirm", defaultValue: "确认")) {
                    let progress = selectedTasks.reduce(into: [UUID: Int]()) { result, taskId in
                        if let p = taskProgress[taskId] {
                            result[taskId] = p
                        } else {
                            result[taskId] = 100
                        }
                    }
                    onComplete(Array(selectedTasks), progress)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .background(FlowOSDesign.panelBackground)
        .frame(width: modalWidth, height: modalHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, modalOuterPadding)
        .onAppear {
            // 默认展开所有有子项的父项
            for task in todoViewModel.uncompletedTasks {
                if !todoViewModel.subItems(of: task.id).filter({ !$0.isCompleted }).isEmpty {
                    expandedParents.insert(task.id)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var unstartedTopLevelTasks: [TodoItem] {
        todoViewModel.uncompletedTopLevelTasks
    }

    private var titleText: String {
        switch sessionType {
        case .focus: return L("Pomodoro Complete!", defaultValue: "番茄钟完成！")
        case .shortBreak: return L("Short Break Over", defaultValue: "短休息结束")
        case .longBreak: return L("Long Break Over", defaultValue: "长休息结束")
        }
    }

    private var subtitleText: String {
        switch sessionType {
        case .focus: return L("Which tasks did you complete?", defaultValue: "完成了哪些任务？")
        case .shortBreak, .longBreak: return L("Break is over, ready to focus", defaultValue: "休息时间已结束，准备继续专注")
        }
    }

    private var iconName: String {
        switch sessionType {
        case .focus: return "checkmark.circle.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.fill"
        }
    }

    private var iconColor: Color {
        switch sessionType {
        case .focus: return .green
        case .shortBreak: return .blue
        case .longBreak: return .purple
        }
    }

    private var emptyMessage: String {
        switch sessionType {
        case .focus: return L("No pending tasks", defaultValue: "暂无待办任务")
        case .shortBreak, .longBreak: return L("Take a break and relax", defaultValue: "休息一下，放松身心")
        }
    }

    private var modalWidth: CGFloat? {
        #if os(iOS)
        nil
        #else
        460
        #endif
    }

    private var modalHeight: CGFloat? {
        #if os(iOS)
        nil
        #else
        560
        #endif
    }

    private var modalOuterPadding: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? 16 : 24
        #else
        0
        #endif
    }

    // MARK: - Init

    public init(todoViewModel: TodoListViewModel, sessionType: SessionType = .focus, onComplete: @escaping ([UUID], [UUID: Int]) -> Void) {
        self.todoViewModel = todoViewModel
        self.sessionType = sessionType
        self.onComplete = onComplete
    }
}

/// 任务行视图（用于 SessionCompletionView）
struct SessionTaskRow: View {
    let task: TodoItem
    let level: Int
    @Bindable var todoViewModel: TodoListViewModel
    @Binding var selectedTasks: Set<UUID>
    @Binding var taskProgress: [UUID: Int]
    @Binding var expandedParents: Set<UUID>

    private var hasSubItems: Bool {
        !todoViewModel.subItems(of: task.id).filter { !$0.isCompleted }.isEmpty
    }

    private var isSelected: Bool {
        selectedTasks.contains(task.id)
    }

    private var isExpanded: Bool {
        expandedParents.contains(task.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 展开/折叠按钮
                if hasSubItems {
                    Button {
                        withAnimation {
                            if expandedParents.contains(task.id) {
                                expandedParents.remove(task.id)
                            } else {
                                expandedParents.insert(task.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 16)
                }

                // 选择复选框
                Button {
                    toggleTask()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)

                // 任务文本
                Text(task.displayText)
                    .font(.system(size: 13, weight: task.isSubItem ? .regular : .medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 进度滑块（选中时显示）
                if isSelected {
                    Slider(
                        value: Binding(
                            get: { Double(taskProgress[task.id] ?? 100) },
                            set: { taskProgress[task.id] = Int($0) }
                        ),
                        in: 0...100,
                        step: 10
                    )
                    .frame(width: 100)

                    Text("\(taskProgress[task.id] ?? 100)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                } else if task.completedPercentage > 0 {
                    Text("\(task.completedPercentage)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .padding(.leading, CGFloat(level) * 20)
            .background(isSelected ? Color.green.opacity(0.10) : FlowOSDesign.elevatedBackground.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.green.opacity(0.35) : FlowOSDesign.hairline, lineWidth: 1)
            }

            // 子任务
            if isExpanded {
                let subTasks = todoViewModel.subItems(of: task.id).filter { !$0.isCompleted }
                ForEach(subTasks) { subTask in
                    SessionTaskRow(
                        task: subTask,
                        level: level + 1,
                        todoViewModel: todoViewModel,
                        selectedTasks: $selectedTasks,
                        taskProgress: $taskProgress,
                        expandedParents: $expandedParents
                    )
                    .padding(.top, 6)
                }
            }
        }
    }

    private func toggleTask() {
        if selectedTasks.contains(task.id) {
            selectedTasks.remove(task.id)
            taskProgress.removeValue(forKey: task.id)
        } else {
            selectedTasks.insert(task.id)
            taskProgress[task.id] = task.completedPercentage > 0 ? task.completedPercentage : 100
        }
    }
}

#Preview {
    let viewModel = TodoListViewModel(todoRepository: .shared)
    SessionCompletionView(todoViewModel: viewModel) { _, _ in }
}
