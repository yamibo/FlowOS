import Foundation

/// TodoList ViewModel
@MainActor
@Observable
public final class TodoListViewModel {
    // MARK: - Properties

    public let todoRepository: TodoRepository

    /// Todo 项目列表
    public var items: [TodoItem] = []

    /// 当前正在编辑的项目 ID
    public var editingItemId: UUID?

    /// 新建项目的临时文本
    public var newItemText: String = ""

    /// 是否已加载
    public var isLoaded = false

    // MARK: - Init

    public init(todoRepository: TodoRepository) {
        self.todoRepository = todoRepository
    }

    // MARK: - Actions

    /// 加载数据
    public func load() {
        let list = todoRepository.load()
        items = list.items
        isLoaded = true
    }

    /// 添加新项目
    public func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        var item = TodoItem(text: text)
        item.parsePriority()

        try? todoRepository.add(item)
        items.append(item)
        newItemText = ""
    }

    /// 添加子项到指定父项
    public func addSubItem(to parentId: UUID) -> TodoItem {
        let subItem = TodoItem(text: "", parentId: parentId)
        try? todoRepository.add(subItem)
        items.append(subItem)
        return subItem
    }

    /// 开始编辑项目
    public func startEditing(_ item: TodoItem) {
        editingItemId = item.id
    }

    /// 完成编辑
    public func finishEditing(_ item: TodoItem) {
        var updated = item

        // 如果文本为空且是新建的子项，删除它
        if item.text.trimmingCharacters(in: .whitespaces).isEmpty && item.isSubItem {
            try? todoRepository.delete(item.id)
            items.removeAll { $0.id == item.id }
            editingItemId = nil
            return
        }

        updated.parsePriority()

        try? todoRepository.update(updated)
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }
        editingItemId = nil
    }

    /// 切换完成状态
    public func toggleCompleted(_ item: TodoItem) {
        var updated = item
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil

        if updated.isCompleted {
            updated.completedPercentage = 100
        } else {
            updated.completedPercentage = 0
        }

        try? todoRepository.update(updated)
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }

        // 如果是母项被取消完成，检查是否需要更新子项
        if !updated.isCompleted && !updated.isSubItem {
            uncompleteSubItems(of: updated.id)
        }

        // 检查是否需要自动完成母项
        checkParentCompletion(item: updated)
    }

    /// 设置完成百分比
    public func setCompletedPercentage(_ item: TodoItem, percentage: Int) {
        var updated = item
        updated.completedPercentage = max(0, min(100, percentage))

        if updated.completedPercentage == 100 {
            updated.isCompleted = true
            updated.completedAt = Date()
        } else {
            updated.isCompleted = false
            updated.completedAt = nil
        }

        try? todoRepository.update(updated)
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }

        // 检查是否需要自动完成母项
        checkParentCompletion(item: updated)
    }

    /// 切换置顶状态
    public func togglePinned(_ item: TodoItem) {
        var updated = item
        updated.isPinned.toggle()

        try? todoRepository.update(updated)
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }
    }

    /// 删除项目
    public func delete(_ item: TodoItem) {
        // 同时删除所有子项
        let subItemIds = items.filter { $0.parentId == item.id }.map { $0.id }
        for subId in subItemIds {
            try? todoRepository.delete(subId)
            items.removeAll { $0.id == subId }
        }

        try? todoRepository.delete(item.id)
        items.removeAll { $0.id == item.id }
    }

    // MARK: - Query

    /// 获取指定父项的子项
    public func subItems(of parentId: UUID) -> [TodoItem] {
        items.filter { $0.parentId == parentId }
    }

    /// 获取顶层项目（没有父项的）
    public var topLevelItems: [TodoItem] {
        items.filter { $0.parentId == nil }
    }

    /// 排序后的项目（分层显示，支持无限层级）
    public var sortedItems: [TodoItem] {
        var result: [TodoItem] = []

        // 获取顶层项目并排序
        let topItems = topLevelItems.sorted { a, b in
            // 完成的项目放最后
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
            }
            // 置顶优先
            if a.isPinned != b.isPinned {
                return a.isPinned
            }
            // 优先级高的在前
            if a.priority != b.priority {
                return a.priority > b.priority
            }
            // 按创建时间
            return a.createdAt < b.createdAt
        }

        // 遍历顶层项目，递归添加子项
        for topItem in topItems {
            result.append(topItem)
            addSubItemsRecursive(parentId: topItem.id, to: &result)
        }

        return result
    }

    /// 递归添加子项
    private func addSubItemsRecursive(parentId: UUID, to result: inout [TodoItem]) {
        let subs = subItems(of: parentId).sorted { $0.createdAt < $1.createdAt }
        for sub in subs {
            result.append(sub)
            addSubItemsRecursive(parentId: sub.id, to: &result)
        }
    }

    /// 获取项目的层级
    public func level(of item: TodoItem) -> Int {
        return item.level(in: items)
    }

    /// 获取未完成的任务（用于番茄钟完成时选择）
    public var uncompletedTasks: [TodoItem] {
        items.filter { !$0.isCompleted && !$0.isSubItem }
    }

    /// 获取进行中的任务（有进度但未完成）
    public var inProgressTasks: [TodoItem] {
        items.filter { !$0.isCompleted && $0.completedPercentage > 0 }
    }

    // MARK: - Private

    /// 取消子项的完成状态
    private func uncompleteSubItems(of parentId: UUID) {
        let subs = subItems(of: parentId)
        for sub in subs where sub.isCompleted {
            var updated = sub
            updated.isCompleted = false
            updated.completedAt = nil
            updated.completedPercentage = 0
            try? todoRepository.update(updated)
            if let index = items.firstIndex(where: { $0.id == updated.id }) {
                items[index] = updated
            }
        }
    }

    /// 检查是否需要自动完成母项
    private func checkParentCompletion(item: TodoItem) {
        guard let parentId = item.parentId else { return }

        let parent = items.first { $0.id == parentId }
        guard let parent = parent, !parent.isCompleted else { return }

        // 检查所有子项是否都完成了
        let subItems = self.subItems(of: parentId)
        let allCompleted = !subItems.isEmpty && subItems.allSatisfy { $0.isCompleted }

        if allCompleted {
            var updatedParent = parent
            updatedParent.isCompleted = true
            updatedParent.completedAt = Date()
            updatedParent.completedPercentage = 100
            try? todoRepository.update(updatedParent)
            if let index = items.firstIndex(where: { $0.id == updatedParent.id }) {
                items[index] = updatedParent
            }
        }
    }
}
