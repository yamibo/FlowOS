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
        // 初始化时立即加载数据
        load()
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
        // 设置 order 为当前最大值 + 1
        let maxOrder = topLevelItems.map { $0.order }.max() ?? -1
        item.order = maxOrder + 1

        try? todoRepository.add(item)
        items.append(item)
        newItemText = ""
    }

    /// 添加子项到指定父项
    public func addSubItem(to parentId: UUID) -> TodoItem {
        // 获取同级子项目的最大 order 值
        let siblings = subItems(of: parentId)
        let maxOrder = siblings.map { $0.order }.max() ?? -1

        var subItem = TodoItem(text: "", parentId: parentId)
        subItem.order = maxOrder + 1

        try? todoRepository.add(subItem)
        items.append(subItem)
        return subItem
    }

    /// 添加一个空的顶层项目，用于连续录入
    public func addEmptyTopLevelItem() -> TodoItem {
        let maxOrder = topLevelItems.map { $0.order }.max() ?? -1

        var item = TodoItem(text: "")
        item.order = maxOrder + 1

        try? todoRepository.add(item)
        items.append(item)
        return item
    }

    /// 将子项目提升到上一级（成为父项目的同级项目）
    public func promoteItem(_ item: TodoItem) -> TodoItem {
        guard let currentParentId = item.parentId else { return item }

        // 找到当前父项目
        guard let currentParent = items.first(where: { $0.id == currentParentId }) else { return item }

        var promoted = item
        touch(&promoted)
        promoted.parentId = currentParent.parentId  // 设置为祖父项目（可能为 nil，成为顶层项目）

        // 设置新的 order 值
        if let newParentId = currentParent.parentId {
            // 成为祖父项目的子项目
            let newSiblings = subItems(of: newParentId)
            promoted.order = (newSiblings.map { $0.order }.max() ?? -1) + 1
        } else {
            // 成为顶层项目
            promoted.order = (topLevelItems.map { $0.order }.max() ?? -1) + 1
        }

        // 更新仓库
        try? todoRepository.update(promoted)
        if let index = items.firstIndex(where: { $0.id == promoted.id }) {
            items[index] = promoted
        }

        return promoted
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
        touch(&updated)

        try? todoRepository.update(updated)
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }
        editingItemId = nil
    }

    /// 切换完成状态
    public func toggleCompleted(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            logPrint("[TodoListViewModel] Item not found: \(item.id)")
            return
        }

        var updated = items[index]
        touch(&updated)
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil

        if updated.isCompleted {
            updated.completedPercentage = 100
        } else {
            updated.completedPercentage = 0
        }

        // 直接更新数组中的元素
        items[index] = updated
        logPrint("[TodoListViewModel] Updated item at index \(index), isCompleted: \(updated.isCompleted)")

        // 保存到仓库
        try? todoRepository.update(updated)

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
        touch(&updated)
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
        touch(&updated)
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

    /// 移动项目到指定位置
    /// - Parameters:
    ///   - source: 源索引集
    ///   - destination: 目标位置
    ///   - sortedItems: 当前显示的排序后列表
    public func moveItems(from source: IndexSet, to destination: Int, sortedItems: [TodoItem]) {
        guard let firstIndex = source.first, firstIndex < sortedItems.count else { return }

        let movedItem = sortedItems[firstIndex]

        if movedItem.isSubItem {
            // 子项目：只能在同一父项目下的同级项目中移动
            moveSubItem(movedItem, from: source, to: destination, sortedItems: sortedItems)
        } else {
            // 顶层项目：移动时带上所有子项目
            moveTopItem(movedItem, from: source, to: destination, sortedItems: sortedItems)
        }

        saveAllItems()
    }

    /// 移动子项目（只能在同级中移动）
    private func moveSubItem(_ item: TodoItem, from source: IndexSet, to destination: Int, sortedItems: [TodoItem]) {
        guard let parentId = item.parentId else { return }

        // 获取同一父项目下的所有子项目（同级）
        let siblings = subItems(of: parentId).sorted { $0.order < $1.order }

        // 获取要移动的子项目
        var movedItems: [TodoItem] = []
        for index in source {
            guard index < sortedItems.count else { continue }
            let sourceItem = sortedItems[index]
            // 确保是同一父项目的子项目
            if sourceItem.parentId == parentId {
                movedItems.append(sourceItem)
            }
        }

        guard !movedItems.isEmpty else { return }

        // 从 siblings 中移除要移动的项目
        var remainingSiblings = siblings.filter { sibling in
            !movedItems.contains { $0.id == sibling.id }
        }

        // 计算在 siblings 中的目标位置
        // 需要将 sortedItems 中的 destination 转换为 siblings 中的位置
        let destItem = destination < sortedItems.count ? sortedItems[destination] : nil
        var siblingDestination: Int

        if let destItem = destItem, destItem.parentId == parentId {
            // 目标位置是同级项目，找到它在 siblings 中的位置
            siblingDestination = remainingSiblings.firstIndex(where: { $0.id == destItem.id }) ?? remainingSiblings.count
        } else {
            // 目标位置不在同级中，放到末尾或开头
            if destination > source.first! {
                siblingDestination = remainingSiblings.count
            } else {
                siblingDestination = 0
            }
        }

        // 在目标位置插入
        for (offset, movedItem) in movedItems.enumerated() {
            let insertIndex = min(siblingDestination + offset, remainingSiblings.count)
            remainingSiblings.insert(movedItem, at: insertIndex)
        }

        // 更新 order 值
        for (index, sibling) in remainingSiblings.enumerated() {
            var updated = sibling
            touch(&updated)
            updated.order = index
            try? todoRepository.update(updated)
            if let itemIndex = items.firstIndex(where: { $0.id == updated.id }) {
                items[itemIndex] = updated
            }
        }
    }

    /// 移动顶层项目（带上所有子项目）
    private func moveTopItem(_ item: TodoItem, from source: IndexSet, to destination: Int, sortedItems: [TodoItem]) {
        // 获取所有顶层项目
        let topItems = topLevelItems.sorted { $0.order < $1.order }

        // 获取要移动的顶层项目
        var movedTopItems: [TodoItem] = []
        for index in source {
            guard index < sortedItems.count else { continue }
            let sourceItem = sortedItems[index]
            // 确保是顶层项目
            if !sourceItem.isSubItem {
                movedTopItems.append(sourceItem)
            }
        }

        guard !movedTopItems.isEmpty else { return }

        // 从 topItems 中移除要移动的项目
        var remainingTopItems = topItems.filter { topItem in
            !movedTopItems.contains { $0.id == topItem.id }
        }

        // 计算在 topItems 中的目标位置
        let destItem = destination < sortedItems.count ? sortedItems[destination] : nil
        var topDestination: Int

        if let destItem = destItem, !destItem.isSubItem {
            // 目标位置是顶层项目
            topDestination = remainingTopItems.firstIndex(where: { $0.id == destItem.id }) ?? remainingTopItems.count
        } else {
            // 目标位置是子项目，找到其父项目
            if let destItem = destItem, let parentId = destItem.parentId {
                // 找到父项目在 remainingTopItems 中的位置，插入到父项目之后
                if let parentIndex = remainingTopItems.firstIndex(where: { $0.id == parentId }) {
                    topDestination = parentIndex + 1
                } else {
                    topDestination = remainingTopItems.count
                }
            } else if destination >= sortedItems.count {
                topDestination = remainingTopItems.count
            } else {
                topDestination = 0
            }
        }

        // 在目标位置插入
        for (offset, movedItem) in movedTopItems.enumerated() {
            let insertIndex = min(topDestination + offset, remainingTopItems.count)
            remainingTopItems.insert(movedItem, at: insertIndex)
        }

        // 更新顶层项目的 order 值
        for (index, topItem) in remainingTopItems.enumerated() {
            var updated = topItem
            touch(&updated)
            updated.order = index
            try? todoRepository.update(updated)
            if let itemIndex = items.firstIndex(where: { $0.id == updated.id }) {
                items[itemIndex] = updated
            }
        }
    }

    /// 保存所有项目
    private func saveAllItems() {
        let list = TodoList(items: items, updatedAt: Date())
        try? todoRepository.save(list)
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

    /// 排序后的项目（分层显示，支持用户自定义排序）
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
            // 用户自定义顺序（order 小的在前）
            if a.order != b.order {
                return a.order < b.order
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
        let subs = subItems(of: parentId).sorted { $0.order < $1.order }
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
    /// 包含所有未完成的任务，按层级显示
    public var uncompletedTasks: [TodoItem] {
        items.filter { !$0.isCompleted }
    }

    /// 获取未完成的顶层任务（用于番茄钟完成时选择）
    public var uncompletedTopLevelTasks: [TodoItem] {
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
            touch(&updated)
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
            touch(&updatedParent)
            updatedParent.isCompleted = true
            updatedParent.completedAt = Date()
            updatedParent.completedPercentage = 100
            try? todoRepository.update(updatedParent)
            if let index = items.firstIndex(where: { $0.id == updatedParent.id }) {
                items[index] = updatedParent
            }
        }
    }

    private func touch(_ item: inout TodoItem) {
        item.schemaVersion = FlowOSDataSchema.currentVersion
        item.updatedAt = Date()
        item.sourceDevice = .current
    }
}
