import Foundation

/// Todo 仓库
///
/// 管理 Todo 列表的持久化
public final class TodoRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = TodoRepository()

    // MARK: - Properties

    private let fileURL: URL
    private var cachedList: TodoList?
    private let lock = NSLock()

    // MARK: - Init

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            self.fileURL = DataFolderManager.appDataURL.appendingPathComponent("todos.json")
        }
    }

    // MARK: - Public API

    /// 加载 Todo 列表
    public func load() -> TodoList {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedList {
            return cached
        }

        do {
            try DataFolderManager.ensureDirectoriesExist()
            if let list = try JSONFileStore.read(TodoList.self, from: fileURL) {
                cachedList = list
                return list
            }
        } catch {
            // 读取失败，返回空列表
        }

        let emptyList = TodoList()
        cachedList = emptyList
        return emptyList
    }

    /// 保存 Todo 列表
    public func save(_ list: TodoList) throws {
        lock.lock()
        defer { lock.unlock() }

        try DataFolderManager.ensureDirectoriesExist()

        var updated = list
        updated.updatedAt = Date()

        try JSONFileStore.write(updated, to: fileURL)
        cachedList = updated
    }

    /// 添加 Todo 项
    public func add(_ item: TodoItem) throws {
        var list = load()
        list.items.append(item)
        try save(list)
    }

    /// 更新 Todo 项
    public func update(_ item: TodoItem) throws {
        var list = load()
        if let index = list.items.firstIndex(where: { $0.id == item.id }) {
            list.items[index] = item
            try save(list)
        }
    }

    /// 删除 Todo 项
    public func delete(_ id: UUID) throws {
        var list = load()
        list.items.removeAll { $0.id == id }
        try save(list)
    }

    /// 清除缓存
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedList = nil
    }
}
