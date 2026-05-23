import Foundation

/// Todo 仓库
///
/// 管理 Todo 列表的持久化，支持 iCloud Drive 同步
public final class TodoRepository: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = TodoRepository()

    // MARK: - Properties

    private let fileURL: URL
    private var cachedList: TodoList?
    private let lock = NSLock()
    private let iCloudSync = iCloudDriveSyncManager.shared

    /// 已完成任务保留天数
    public var completedTaskRetentionDays: Int = 30

    // MARK: - Init

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            self.fileURL = DataFolderManager.appDataURL.appendingPathComponent("todos.json")
        }

        // 监听 iCloud Drive 外部变更
        iCloudSync.onExternalChange = { [weak self] in
            self?.handleExternalChange()
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

        // 优先从 iCloud Drive 加载
        if let iCloudURL = iCloudSync.todoFileURL,
           let iCloudList = iCloudSync.read(TodoList.self, from: iCloudURL) {
            cachedList = iCloudList
            return iCloudList
        }

        // 回退到本地文件
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

        // 清理超过保留天数的已完成任务
        var updated = list
        updated.items = filterExpiredCompletedItems(updated.items)
        updated.updatedAt = Date()

        // 保存到本地
        try JSONFileStore.write(updated, to: fileURL)
        cachedList = updated

        // 同步到 iCloud Drive
        if let iCloudURL = iCloudSync.todoFileURL {
            try? iCloudSync.write(updated, to: iCloudURL)
        }
    }

    /// 过滤过期的已完成任务
    private func filterExpiredCompletedItems(_ items: [TodoItem]) -> [TodoItem] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -completedTaskRetentionDays, to: Date())!

        return items.filter { item in
            // 未完成的任务保留
            if !item.isCompleted { return true }

            // 已完成但没有完成时间的任务保留
            guard let completedAt = item.completedAt else { return true }

            // 完成时间在保留期内则保留
            return completedAt > cutoffDate
        }
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

    /// 处理 iCloud Drive 外部变更
    private func handleExternalChange() {
        lock.lock()
        defer { lock.unlock() }

        // 从 iCloud Drive 重新加载
        if let iCloudURL = iCloudSync.todoFileURL,
           let iCloudList = iCloudSync.read(TodoList.self, from: iCloudURL) {
            cachedList = iCloudList

            // 同时更新本地文件
            try? JSONFileStore.write(iCloudList, to: fileURL)
        }
    }
}