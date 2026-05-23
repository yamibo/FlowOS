import Foundation
import AppKit

/// 目录授权管理器
///
/// 使用 NSOpenPanel 让用户选择授权目录，并保存访问权限
public final class DirectoryAuthorizationManager: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = DirectoryAuthorizationManager()

    // MARK: - Properties

    private let lock = NSLock()
    private let defaultsKey = "authorizedDirectoryBookmark"

    /// 已授权的目录 URL
    private var authorizedDirectory: URL?

    /// 安全访问的书签数据
    private var securityBookmark: Data?

    // MARK: - Init

    public init() {
        loadBookmark()
    }

    // MARK: - Public API

    /// 检查是否有已授权的目录
    public var hasAuthorizedDirectory: Bool {
        authorizedDirectory != nil
    }

    /// 获取已授权的目录
    public var authorizedDirectoryURL: URL? {
        authorizedDirectory
    }

    /// 请求用户授权目录
    /// - Returns: 用户选择的目录 URL，如果用户取消则返回 nil
    @discardableResult
    public func requestAuthorization() async -> URL? {
        guard let url = await selectDirectory() else {
            return nil
        }

        do {
            try authorizeDirectory(url)
            return url
        } catch {
            logPrint("[DirectoryAuthorizationManager] Failed to authorize directory: \(error)")
            return nil
        }
    }

    /// 选择目录但不保存授权，用于切换目录前执行迁移检查
    public func selectDirectory() async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.title = L("Select Data Storage Directory", defaultValue: "选择数据存储目录")
                panel.message = L("Please select a directory to store FlowOSApple data. We recommend choosing a folder in iCloud Drive for multi-device sync.", defaultValue: "请选择一个目录来存储 FlowOSApple 的数据。推荐选择 iCloud Drive 中的文件夹以实现多设备同步。")
                panel.prompt = L("Select", defaultValue: "选择")
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.allowsMultipleSelection = false
                panel.directoryURL = self.defaultDirectorySuggestion()

                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    /// 确保目录已授权，如果没有则请求授权
    public func ensureAuthorized() async -> URL? {
        if let existing = authorizedDirectory {
            return existing
        }
        return await requestAuthorization()
    }

    /// 保存目录授权
    public func authorizeDirectory(_ url: URL) throws {
        try saveBookmark(for: url)
    }

    /// 清除授权
    public func clearAuthorization() {
        lock.lock()
        defer { lock.unlock() }

        authorizedDirectory = nil
        securityBookmark = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    // MARK: - Private

    /// 建议的默认目录（iCloud Drive）
    private func defaultDirectorySuggestion() -> URL? {
        let iCloudDrive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")

        if FileManager.default.fileExists(atPath: iCloudDrive.path) {
            return iCloudDrive.appendingPathComponent("FlowOSApple")
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// 保存安全书签
    private func saveBookmark(for url: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        do {
            // 创建安全范围书签（包含读写权限）
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            securityBookmark = bookmark
            authorizedDirectory = url

            // 保存到 UserDefaults
            UserDefaults.standard.set(bookmark, forKey: defaultsKey)

            // 开始访问安全范围
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            throw error
        }
    }

    /// 从 UserDefaults 加载书签
    private func loadBookmark() {
        lock.lock()
        defer { lock.unlock() }

        guard let bookmark = UserDefaults.standard.data(forKey: defaultsKey) else {
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // 书签已过期，需要重新授权
                securityBookmark = nil
                authorizedDirectory = nil
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                securityBookmark = bookmark
                authorizedDirectory = url
                _ = url.startAccessingSecurityScopedResource()
            }
        } catch {
            print("加载书签失败: \(error)")
        }
    }

    /// 停止访问安全范围
    public func stopAccessing() {
        lock.lock()
        defer { lock.unlock() }

        if let url = authorizedDirectory {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
