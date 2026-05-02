import SwiftUI

/// 番茄钟完成时的任务选择视图
public struct SessionCompletionView: View {
    // MARK: - Properties

    @Bindable var todoViewModel: TodoListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTasks: Set<UUID> = []
    @State private var taskProgress: [UUID: Int] = [:]

    let onComplete: ([UUID], [UUID: Int]) -> Void

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("番茄钟完成！")
                .font(.title.bold())

            Text("完成了哪些任务？")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if todoViewModel.uncompletedTasks.isEmpty && todoViewModel.inProgressTasks.isEmpty {
                // 没有任务
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("暂无待办任务")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 40)
            } else {
                // 任务列表
                ScrollView {
                    VStack(spacing: 8) {
                        // 进行中的任务
                        if !todoViewModel.inProgressTasks.isEmpty {
                            Section("进行中") {
                                ForEach(todoViewModel.inProgressTasks) { task in
                                    TaskProgressRow(
                                        task: task,
                                        isSelected: selectedTasks.contains(task.id),
                                        progress: taskProgress[task.id] ?? task.completedPercentage,
                                        onToggle: {
                                            toggleTask(task)
                                        },
                                        onProgressChange: { newProgress in
                                            taskProgress[task.id] = newProgress
                                        }
                                    )
                                }
                            }
                        }

                        // 未开始的任务
                        if !todoViewModel.uncompletedTasks.filter({ !todoViewModel.inProgressTasks.contains($0) }).isEmpty {
                            Section("待办") {
                                ForEach(todoViewModel.uncompletedTasks.filter { !todoViewModel.inProgressTasks.contains($0) }) { task in
                                    TaskSelectionRow(
                                        task: task,
                                        isSelected: selectedTasks.contains(task.id),
                                        onToggle: {
                                            toggleTask(task)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // 按钮
            HStack(spacing: 16) {
                Button("跳过") {
                    onComplete([], [:])
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("确认") {
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
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private func toggleTask(_ task: TodoItem) {
        if selectedTasks.contains(task.id) {
            selectedTasks.remove(task.id)
            taskProgress.removeValue(forKey: task.id)
        } else {
            selectedTasks.insert(task.id)
            taskProgress[task.id] = task.completedPercentage > 0 ? task.completedPercentage : 100
        }
    }

    // MARK: - Init

    public init(todoViewModel: TodoListViewModel, onComplete: @escaping ([UUID], [UUID: Int]) -> Void) {
        self.todoViewModel = todoViewModel
        self.onComplete = onComplete
    }
}

/// 任务选择行
struct TaskSelectionRow: View {
    let task: TodoItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .gray)

                if task.priority > 0 {
                    Text(String(repeating: "!", count: task.priority))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                }

                Text(task.text)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// 任务进度行
struct TaskProgressRow: View {
    let task: TodoItem
    let isSelected: Bool
    let progress: Int
    let onToggle: () -> Void
    let onProgressChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .gray)

                    if task.priority > 0 {
                        Text(String(repeating: "!", count: task.priority))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.red)
                    }

                    Text(task.text)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(progress)%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isSelected {
                Slider(value: Binding(
                    get: { Double(progress) },
                    set: { onProgressChange(Int($0)) }
                ), in: 0...100, step: 10)
                .padding(.horizontal, 12)
            }
        }
    }
}

#Preview {
    let viewModel = TodoListViewModel(todoRepository: .shared)
    SessionCompletionView(todoViewModel: viewModel) { _, _ in }
}