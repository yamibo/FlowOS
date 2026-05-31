import Foundation

/// Todo 项
public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var text: String
    public var isCompleted: Bool
    public var isPinned: Bool
    public var priority: Int  // 0 = 无优先级, 1-3 = 优先级
    public var parentId: UUID?  // 父项 ID，用于子项
    public var createdAt: Date
    public var updatedAt: Date?
    public var completedAt: Date?
    public var completedPercentage: Int  // 完成百分比 0-100
    public var order: Int  // 用户自定义排序顺序
    public var note: String  // 备注
    public var sourceDevice: DeviceInfo?

    public init(
        schemaVersion: Int = FlowOSDataSchema.currentVersion,
        id: UUID = UUID(),
        text: String = "",
        isCompleted: Bool = false,
        isPinned: Bool = false,
        priority: Int = 0,
        parentId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        completedPercentage: Int = 0,
        order: Int = 0,
        note: String = "",
        sourceDevice: DeviceInfo? = .current
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.priority = priority
        self.parentId = parentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.completedPercentage = completedPercentage
        self.order = order
        self.note = note
        self.sourceDevice = sourceDevice
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case text
        case isCompleted
        case isPinned
        case priority
        case parentId
        case createdAt
        case updatedAt
        case completedAt
        case completedPercentage
        case order
        case note
        case sourceDevice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? FlowOSDataSchema.legacyVersion
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        priority = try container.decode(Int.self, forKey: .priority)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        completedPercentage = try container.decode(Int.self, forKey: .completedPercentage)
        order = try container.decode(Int.self, forKey: .order)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        sourceDevice = try container.decodeIfPresent(DeviceInfo.self, forKey: .sourceDevice)
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
public struct TodoList: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var items: [TodoItem]
    public var createdAt: Date?
    public var updatedAt: Date?
    public var sourceDevice: DeviceInfo?

    public init(
        schemaVersion: Int = FlowOSDataSchema.currentVersion,
        items: [TodoItem] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        sourceDevice: DeviceInfo? = .current
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceDevice = sourceDevice
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case items
        case createdAt
        case updatedAt
        case sourceDevice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? FlowOSDataSchema.legacyVersion
        items = try container.decode([TodoItem].self, forKey: .items)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        sourceDevice = try container.decodeIfPresent(DeviceInfo.self, forKey: .sourceDevice)
    }
}
