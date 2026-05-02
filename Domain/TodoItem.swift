import Foundation

/// Todo 项
public struct TodoItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var text: String
    public var isCompleted: Bool
    public var isPinned: Bool
    public var priority: Int  // 0 = 无优先级, 1-3 = 优先级
    public var parentId: UUID?  // 父项 ID，用于子项
    public var createdAt: Date
    public var completedAt: Date?
    public var completedPercentage: Int  // 完成百分比 0-100

    public init(
        id: UUID = UUID(),
        text: String = "",
        isCompleted: Bool = false,
        isPinned: Bool = false,
        priority: Int = 0,
        parentId: UUID? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        completedPercentage: Int = 0
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.priority = priority
        self.parentId = parentId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.completedPercentage = completedPercentage
    }

    /// 是否是子项
    public var isSubItem: Bool {
        parentId != nil
    }

    /// 计算层级（需要传入所有 items）
    public func level(in items: [TodoItem]) -> Int {
        var currentLevel = 0
        var currentParentId = parentId

        while let parentId = currentParentId {
            currentLevel += 1
            if let parent = items.first(where: { $0.id == parentId }) {
                currentParentId = parent.parentId
            } else {
                break
            }
        }

        return currentLevel
    }

    /// 解析文本中的优先级标记（!或！开头）
    public mutating func parsePriority() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // 计算开头的感叹号数量（支持中英文感叹号）
        var count = 0
        for char in trimmed {
            if char == "!" || char == "！" {
                count += 1
            } else {
                break
            }
        }

        if count > 0 {
            priority = min(count, 3)  // 最多3级优先级
            // 移除感叹号，保留后面的文本
            let index = trimmed.index(trimmed.startIndex, offsetBy: count)
            text = String(trimmed[index...]).trimmingCharacters(in: .whitespaces)
        }
    }

    /// 显示文本（不含优先级标记）
    public var displayText: String {
        text
    }

    /// 优先级标记显示
    public var priorityMarker: String {
        if priority == 0 { return "" }
        return String(repeating: "!", count: priority)
    }
}

/// Todo 列表
public struct TodoList: Codable, Equatable {
    public var items: [TodoItem]
    public var updatedAt: Date?

    public init(items: [TodoItem] = [], updatedAt: Date? = nil) {
        self.items = items
        self.updatedAt = updatedAt
    }
}
