import SwiftUI

/// TodoList 视图
public struct TodoListView: View {
    // MARK: - Properties

    @Bindable var viewModel: TodoListViewModel
    @FocusState private var focusedField: UUID?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // 输入框
            inputField

            Divider()

            // Todo 列表
            todoList
        }
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Subviews

    private var inputField: some View {
        HStack(spacing: 12) {
            // 空白的圆圈占位
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                .frame(width: 20, height: 20)

            // 输入框
            TextField("添加新任务...", text: $viewModel.newItemText)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.addItem()
                }
                .onKeyPress(.tab) {
                    // Tab 键：创建任务并立即创建子任务
                    createTaskWithSubItem()
                    return .handled
                }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
    }

    private func createTaskWithSubItem() {
        let text = viewModel.newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // 创建主任务
        var mainItem = TodoItem(text: text)
        mainItem.parsePriority()
        try? viewModel.todoRepository.add(mainItem)
        viewModel.items.append(mainItem)

        // 清空输入框
        viewModel.newItemText = ""

        // 创建子任务并进入编辑
        let subItem = viewModel.addSubItem(to: mainItem.id)
        viewModel.startEditing(subItem)
        focusedField = subItem.id
    }

    private var todoList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.sortedItems) { item in
                    TodoItemRow(
                        item: item,
                        viewModel: viewModel,
                        focusedField: $focusedField
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Init

    public init(viewModel: TodoListViewModel) {
        self.viewModel = viewModel
    }
}

/// Todo 项行视图
struct TodoItemRow: View {
    let item: TodoItem
    @Bindable var viewModel: TodoListViewModel
    @FocusState.Binding var focusedField: UUID?

    @State private var editText: String = ""
    @State private var isCreatingSubItem = false

    var body: some View {
        HStack(spacing: 12) {
            // 缩进（根据层级缩进）
            let itemLevel = viewModel.level(of: item)
            ForEach(0..<itemLevel, id: \.self) { _ in
                Text("    ")
                    .foregroundStyle(.secondary)
            }

            // 完成状态圆圈 - 点击切换完成
            Button {
                viewModel.toggleCompleted(item)
            } label: {
                Circle()
                    .stroke(item.isCompleted ? Color.green : Color.gray.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if item.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                        } else if item.completedPercentage > 0 {
                            Text("\(item.completedPercentage)%")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
            }
            .buttonStyle(.plain)

            // 优先级标记
            if item.priority > 0 {
                Text(item.priorityMarker)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
            }

            // 文本内容 - 点击直接编辑
            if viewModel.editingItemId == item.id {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: item.id)
                    .onSubmit {
                        if !isCreatingSubItem {
                            finishEditing()
                        }
                    }
                    .onAppear {
                        editText = item.text
                    }
                    .onKeyPress(.tab) {
                        // Tab 键：保存当前项并创建下一级子任务
                        createNextLevelSubItem()
                        return .handled
                    }
                    .onChange(of: focusedField) { oldValue, newValue in
                        if oldValue == item.id && newValue != item.id && !isCreatingSubItem {
                            finishEditing()
                        }
                        isCreatingSubItem = false
                    }
            } else {
                Text(item.displayText)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.startEditing(item)
                        editText = item.text
                        focusedField = item.id
                    }
            }

            Spacer()

            // 置顶按钮（只有顶层项目显示）
            if viewModel.level(of: item) == 0 {
                Button {
                    viewModel.togglePinned(item)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundStyle(item.isPinned ? .orange : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .opacity(item.isCompleted ? 0.3 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(item.isPinned ? Color.orange.opacity(0.1) : Color.clear)
        .contextMenu {
            Button("编辑") {
                viewModel.startEditing(item)
                editText = item.text
                focusedField = item.id
            }

            Button("添加子项") {
                createSubItem()
            }

            Button(item.isPinned ? "取消置顶" : "置顶") {
                viewModel.togglePinned(item)
            }

            Divider()

            Button("删除", role: .destructive) {
                viewModel.delete(item)
            }
        }
    }

    private func finishEditing() {
        var updated = item
        updated.text = editText
        viewModel.finishEditing(updated)
    }

    private func createNextLevelSubItem() {
        // 保存当前项
        var updated = item
        updated.text = editText
        try? viewModel.todoRepository.update(updated)
        if let index = viewModel.items.firstIndex(where: { $0.id == updated.id }) {
            viewModel.items[index] = updated
        }

        // 标记正在创建子项
        isCreatingSubItem = true

        // 创建下一级子任务
        let subItem = viewModel.addSubItem(to: item.id)
        viewModel.startEditing(subItem)
        editText = ""
        focusedField = subItem.id
    }

    private func createSubItem() {
        isCreatingSubItem = true
        let subItem = viewModel.addSubItem(to: item.id)
        viewModel.startEditing(subItem)
        editText = ""
        focusedField = subItem.id
    }
}

#Preview {
    let viewModel = TodoListViewModel(todoRepository: .shared)
    TodoListView(viewModel: viewModel)
        .frame(width: 400, height: 500)
}