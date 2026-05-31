import SwiftUI

/// TodoList 视图
public struct TodoListView: View {
    // MARK: - Properties

    @Bindable var viewModel: TodoListViewModel
    @FocusState private var focusedField: UUID?
    @State private var collapsedParents: Set<UUID> = []
    @Environment(\.languageVersion) private var languageVersion

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Tasks", defaultValue: "任务"))
                    .font(.title2.bold())
                Text(L("Plan your focus work and break tasks into clear steps.", defaultValue: "规划专注任务，并拆成清晰步骤。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            inputField
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(FlowOSDesign.hairline, lineWidth: 1)
                }
            .padding(.horizontal, 24)

            todoList
        }
        .background(FlowOSDesign.pageBackground)
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Subviews

    private var inputField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            TextField(L("Add new task...", defaultValue: "添加新任务..."), text: $viewModel.newItemText)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.addItem()
                }
                .onKeyPress(.tab) {
                    createTaskWithSubItem()
                    return .handled
                }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(FlowOSDesign.panelBackground)
    }

    private func createTaskWithSubItem() {
        let text = viewModel.newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        var mainItem = TodoItem(text: text)
        mainItem.parsePriority()
        try? viewModel.todoRepository.add(mainItem)
        viewModel.items.append(mainItem)

        viewModel.newItemText = ""

        let subItem = viewModel.addSubItem(to: mainItem.id)
        viewModel.startEditing(subItem)
        focusedField = subItem.id
    }

    /// 过滤后的排序列表（折叠的父项不显示子项）
    private var filteredSortedItems: [TodoItem] {
        viewModel.sortedItems.filter { item in
            if !item.isSubItem { return true }
            guard let parentId = item.parentId else { return true }
            return isAncestorExpanded(item, parentId: parentId)
        }
    }

    private func isAncestorExpanded(_ item: TodoItem, parentId: UUID) -> Bool {
        if collapsedParents.contains(parentId) {
            return false
        }
        if let parent = viewModel.items.first(where: { $0.id == parentId }),
           let grandParentId = parent.parentId {
            return isAncestorExpanded(parent, parentId: grandParentId)
        }
        return true
    }

    private var todoList: some View {
        Group {
            if filteredSortedItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checklist.unchecked")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(L("No tasks yet", defaultValue: "暂无任务"))
                        .font(.headline)
                    Text(L("Add a task above to plan your next focus session.", defaultValue: "在上方添加任务，规划下一次专注。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredSortedItems) { item in
                        TodoItemRow(
                            itemId: item.id,
                            viewModel: viewModel,
                            focusedField: $focusedField,
                            collapsedParents: $collapsedParents
                        )
                        .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let item = viewModel.items.first(where: { $0.id == item.id }) {
                                    viewModel.delete(item)
                                }
                            } label: {
                                Label(L("Delete", defaultValue: "删除"), systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveItems(from: source, to: destination, sortedItems: viewModel.sortedItems)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    // MARK: - Init

    public init(viewModel: TodoListViewModel) {
        self.viewModel = viewModel
    }
}

/// Todo 项行视图
struct TodoItemRow: View {
    let itemId: UUID
    @Bindable var viewModel: TodoListViewModel
    @FocusState.Binding var focusedField: UUID?
    @Binding var collapsedParents: Set<UUID>

    @State private var editText: String = ""
    @State private var isCreatingSubItem = false
    @State private var isHovered = false
    @State private var showDetail = false

    private var item: TodoItem {
        viewModel.items.first { $0.id == itemId } ?? TodoItem(text: "")
    }

    private var hasSubItems: Bool {
        !viewModel.subItems(of: item.id).isEmpty
    }

    private var isCollapsed: Bool {
        collapsedParents.contains(item.id)
    }

    private var itemLevel: Int {
        viewModel.level(of: item)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            hierarchyGuide

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 28)
                    .help(L("Drag to reorder", defaultValue: "拖动排序"))
                    .opacity(isHovered ? 1 : 0.45)

                disclosureControl

                completionButton
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 5) {
                    if viewModel.editingItemId == item.id {
                        TextField("", text: $editText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...3)
                            .font(.system(size: 14, weight: .medium))
                            .focused($focusedField, equals: item.id)
                            .onSubmit {
                                if !isCreatingSubItem {
                                    createSiblingItem()
                                }
                            }
                            .onAppear {
                                editText = item.text
                            }
                            .onChange(of: editText) { _, newValue in
                                handleInlineReturn(in: newValue)
                            }
                            .onKeyPress(phases: .down) { keyPress in
                                guard keyPress.key == .tab else { return .ignored }

                                if keyPress.modifiers.contains(.shift) {
                                    if item.isSubItem {
                                        promoteToParentLevel()
                                        return .handled
                                    }
                                    return .ignored
                                } else {
                                    createNextLevelSubItem()
                                    return .handled
                                }
                            }
                            .onChange(of: focusedField) { oldValue, newValue in
                                if oldValue == item.id && newValue != item.id {
                                    if !isCreatingSubItem {
                                        finishEditing()
                                    }
                                    DispatchQueue.main.async {
                                        isCreatingSubItem = false
                                    }
                                }
                            }
                    } else {
                        Text(item.displayText.isEmpty ? L("Untitled task", defaultValue: "未命名任务") : item.displayText)
                            .font(.system(size: 14, weight: item.isSubItem ? .regular : .medium))
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .strikethrough(item.isCompleted)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.startEditing(item)
                                editText = item.text
                                focusedField = item.id
                            }
                            .onKeyPress(phases: .down) { keyPress in
                                guard keyPress.key == .tab && keyPress.modifiers.contains(.shift) else { return .ignored }
                                if item.isSubItem {
                                    viewModel.startEditing(item)
                                    editText = item.text
                                    focusedField = item.id
                                    promoteToParentLevel()
                                    return .handled
                                }
                                return .ignored
                            }
                    }

                    HStack(spacing: 8) {
                        if shouldShowStatusPill {
                            statusPill
                        }

                        if item.priority > 0 {
                            Label(priorityLabel, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(priorityColor)
                        }

                        if item.isPinned {
                            Label(L("Pinned", defaultValue: "已置顶"), systemImage: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        if hasSubItems {
                            Text("\(viewModel.subItems(of: item.id).count) \(L("subtasks", defaultValue: "个子项"))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if !firstNoteLine.isEmpty {
                            Label(firstNoteLine, systemImage: "note.text")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showDetail = true
                } label: {
                    Image(systemName: item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "info.circle" : "note.text")
                        .font(.system(size: 14))
                        .foregroundStyle(item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Task Details", defaultValue: "任务详情"))

                if itemLevel == 0 {
                    Button {
                        viewModel.togglePinned(item)
                    } label: {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 14))
                            .foregroundStyle(item.isPinned ? .orange : .gray.opacity(0.5))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .opacity(item.isCompleted ? 0.3 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(rowBackground)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor.opacity(item.priority > 0 ? 0.95 : 0))
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(isHovered ? 0.22 : 0.08), lineWidth: 1)
        }
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        .contextMenu {
            Button(L("Edit", defaultValue: "编辑")) {
                viewModel.startEditing(item)
                editText = item.text
                focusedField = item.id
            }

            Button(L("Task Details", defaultValue: "任务详情")) {
                showDetail = true
            }

            Button(L("Add Sub-item", defaultValue: "添加子项")) {
                createSubItem()
            }

            if hasSubItems {
                Button(isCollapsed ? L("Expand Sub-items", defaultValue: "展开子项") : L("Collapse Sub-items", defaultValue: "折叠子项")) {
                    toggleCollapsed()
                }
            }

            Button(item.isPinned ? L("Unpin", defaultValue: "取消置顶") : L("Pin", defaultValue: "置顶")) {
                viewModel.togglePinned(item)
            }

            Divider()

            Button(L("Delete", defaultValue: "删除"), role: .destructive) {
                viewModel.delete(item)
            }
        }
        .sheet(isPresented: $showDetail) {
            TodoDetailView(itemId: item.id, viewModel: viewModel)
        }
    }

    private var hierarchyGuide: some View {
        ZStack(alignment: .topLeading) {
            if itemLevel > 0 {
                ForEach(0..<itemLevel, id: \.self) { level in
                    Capsule()
                        .fill(level == itemLevel - 1 ? Color.secondary.opacity(0.22) : Color.secondary.opacity(0.10))
                        .frame(width: 2, height: 34)
                        .padding(.top, 15)
                        .padding(.leading, CGFloat(level) * 28 + 13)
                }
            }
        }
        .frame(width: CGFloat(itemLevel) * 28)
        .frame(maxHeight: .infinity)
    }

    private var disclosureControl: some View {
        Group {
            if hasSubItems {
                Button {
                    toggleCollapsed()
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? L("Expand Sub-items", defaultValue: "展开子项") : L("Collapse Sub-items", defaultValue: "折叠子项"))
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var completionButton: some View {
        Circle()
            .stroke(item.isCompleted ? Color.green : statusColor.opacity(0.65), lineWidth: 1.6)
            .background {
                Circle()
                    .fill(item.isCompleted ? Color.green.opacity(0.16) : statusColor.opacity(item.completedPercentage > 0 ? 0.12 : 0))
            }
            .frame(width: 22, height: 22)
            .overlay {
                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                } else if item.completedPercentage > 0 {
                    Text("\(item.completedPercentage)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(statusColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                logPrint("[TodoItemRow] Circle tapped for item: \(item.id)")
                viewModel.toggleCompleted(item)
            }
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var rowBackground: Color {
        if item.isCompleted {
            return FlowOSDesign.panelBackground.opacity(0.55)
        }
        if item.isPinned {
            return Color.orange.opacity(isHovered ? 0.16 : 0.10)
        }
        if item.priority > 0 {
            return priorityColor.opacity(isHovered ? 0.12 : 0.07)
        }
        return FlowOSDesign.panelBackground.opacity(isHovered ? 0.95 : 0.72)
    }

    private var statusText: String {
        if item.isCompleted {
            return L("Completed", defaultValue: "已完成")
        }
        if item.completedPercentage > 0 {
            return "\(L("In Progress", defaultValue: "进行中")) \(item.completedPercentage)%"
        }
        return L("Pending", defaultValue: "待办")
    }

    private var shouldShowStatusPill: Bool {
        item.isCompleted || item.completedPercentage > 0
    }

    private var statusColor: Color {
        if item.isCompleted {
            return .green
        }
        if item.completedPercentage > 0 {
            return .orange
        }
        return .secondary
    }

    private var priorityColor: Color {
        switch item.priority {
        case 3:
            return .red
        case 2:
            return .orange
        case 1:
            return .yellow
        default:
            return .clear
        }
    }

    private var priorityLabel: String {
        String(format: L("Priority %d", defaultValue: "优先级 %d"), item.priority)
    }

    private var firstNoteLine: String {
        item.note
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func toggleCollapsed() {
        withAnimation {
            if collapsedParents.contains(item.id) {
                collapsedParents.remove(item.id)
            } else {
                collapsedParents.insert(item.id)
            }
        }
    }

    private func finishEditing() {
        var updated = item
        updated.text = editText
        viewModel.finishEditing(updated)
    }

    private func handleInlineReturn(in text: String) {
        guard text.contains(where: \.isNewline), !isCreatingSubItem else { return }
        editText = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        createSiblingItem()
    }

    private func createNextLevelSubItem() {
        var updated = item
        updated.text = editText
        try? viewModel.todoRepository.update(updated)
        if let index = viewModel.items.firstIndex(where: { $0.id == updated.id }) {
            viewModel.items[index] = updated
        }

        isCreatingSubItem = true
        collapsedParents.remove(item.id)

        let subItem = viewModel.addSubItem(to: item.id)
        viewModel.startEditing(subItem)
        editText = ""

        DispatchQueue.main.async {
            focusedField = subItem.id
        }
    }

    private func createSiblingItem() {
        guard !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            finishEditing()
            return
        }

        var updated = item
        updated.text = editText
        try? viewModel.todoRepository.update(updated)
        if let index = viewModel.items.firstIndex(where: { $0.id == updated.id }) {
            viewModel.items[index] = updated
        }

        isCreatingSubItem = true

        let siblingItem: TodoItem
        if let parentId = item.parentId {
            siblingItem = viewModel.addSubItem(to: parentId)
        } else {
            siblingItem = viewModel.addEmptyTopLevelItem()
        }
        viewModel.startEditing(siblingItem)
        editText = ""

        DispatchQueue.main.async {
            focusedField = siblingItem.id
        }
    }

    private func promoteToParentLevel() {
        var updated = item
        updated.text = editText

        let promotedItem = viewModel.promoteItem(updated)

        viewModel.startEditing(promotedItem)
        editText = promotedItem.text
        focusedField = promotedItem.id
    }

    private func createSubItem() {
        isCreatingSubItem = true
        collapsedParents.remove(item.id)

        let subItem = viewModel.addSubItem(to: item.id)
        viewModel.startEditing(subItem)
        editText = ""

        DispatchQueue.main.async {
            focusedField = subItem.id
        }
    }
}

struct TodoDetailView: View {
    let itemId: UUID
    @Bindable var viewModel: TodoListViewModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var titleText = ""
    @State private var noteText = ""

    private var item: TodoItem? {
        viewModel.items.first { $0.id == itemId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L("Task Details", defaultValue: "任务详情"))
                    .font(.title3.bold())
                Spacer()
                Button {
                    save()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Title", defaultValue: "标题"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(L("Untitled task", defaultValue: "未命名任务"), text: $titleText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Notes", defaultValue: "备注"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $noteText)
                    .font(.body)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(FlowOSDesign.elevatedBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(FlowOSDesign.hairline, lineWidth: 1)
                    }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: modalWidth, height: modalHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, modalOuterPadding)
        .background(FlowOSDesign.panelBackground)
        .onAppear {
            titleText = item?.text ?? ""
            noteText = item?.note ?? ""
        }
        .onDisappear {
            save()
        }
    }

    private func save() {
        guard var updated = item else { return }
        updated.text = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.finishEditing(updated)
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
        360
        #endif
    }

    private var modalOuterPadding: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? 16 : 24
        #else
        0
        #endif
    }
}

#Preview {
    let viewModel = TodoListViewModel(todoRepository: .shared)
    TodoListView(viewModel: viewModel)
        .frame(width: 400, height: 500)
}
