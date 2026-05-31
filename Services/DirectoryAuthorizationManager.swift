import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

/// 目录授权管理器
///
/// 使用 NSOpenPanel 让用户选择授权目录，并保存访问权限
public final class DirectoryAuthorizationManager: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = DirectoryAuthorizationManager()

    // MARK: - Properties

    private let lock = NSLock()
    private let defaultsKey = "authorizedDirectoryBookmark"
    private let defaultsURLKey = "authorizedDirectoryURL"
    #if os(iOS)
    private static var activeDocumentPickerDelegate: IOSDirectoryPickerDelegate?
    #endif

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
        #if os(iOS)
        if let authorizedDirectory {
            _ = authorizedDirectory.startAccessingSecurityScopedResource()
        }
        #endif
        return authorizedDirectory
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
        #if os(macOS)
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
        #elseif os(iOS)
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let presenter = Self.topViewController() else {
                    continuation.resume(returning: nil)
                    return
                }

                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
                let delegate = IOSDirectoryPickerDelegate { url in
                    Self.activeDocumentPickerDelegate = nil
                    continuation.resume(returning: url)
                }
                Self.activeDocumentPickerDelegate = delegate
                picker.delegate = delegate
                picker.allowsMultipleSelection = false
                presenter.present(picker, animated: true)
            }
        }
        #else
        return nil
        #endif
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
        UserDefaults.standard.removeObject(forKey: defaultsURLKey)
    }

    // MARK: - Private

    /// 建议的默认目录（iCloud Drive）
    private func defaultDirectorySuggestion() -> URL? {
        #if os(macOS)
        let iCloudDrive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")

        if FileManager.default.fileExists(atPath: iCloudDrive.path) {
            return iCloudDrive.appendingPathComponent("FlowOSApple")
        }

        return FileManager.default.homeDirectoryForCurrentUser
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #endif
    }

    /// 保存安全书签
    private func saveBookmark(for url: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        #if os(macOS)
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
        #else
        _ = url.startAccessingSecurityScopedResource()
        try validateWritableDirectory(url)

        let bookmark = try? url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        securityBookmark = bookmark
        authorizedDirectory = url
        UserDefaults.standard.set(url.absoluteString, forKey: defaultsURLKey)
        if let bookmark {
            UserDefaults.standard.set(bookmark, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            logPrint("[DirectoryAuthorizationManager] iOS bookmark creation failed; using session URL fallback.")
        }
        #endif
    }

    /// 从 UserDefaults 加载书签
    private func loadBookmark() {
        lock.lock()
        defer { lock.unlock() }

        #if os(macOS)
        do {
            guard let bookmark = UserDefaults.standard.data(forKey: defaultsKey) else {
                return
            }
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
        #else
        if let bookmark = UserDefaults.standard.data(forKey: defaultsKey) {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    securityBookmark = nil
                    authorizedDirectory = nil
                    UserDefaults.standard.removeObject(forKey: defaultsKey)
                } else {
                    securityBookmark = bookmark
                    authorizedDirectory = url
                    _ = url.startAccessingSecurityScopedResource()
                    return
                }
            } catch {
                logPrint("[DirectoryAuthorizationManager] Failed to load bookmark: \(error)")
            }
        }

        if let urlString = UserDefaults.standard.string(forKey: defaultsURLKey),
           let url = URL(string: urlString) {
            authorizedDirectory = url
            _ = url.startAccessingSecurityScopedResource()
        }
        #endif
    }

    /// 停止访问安全范围
    public func stopAccessing() {
        lock.lock()
        defer { lock.unlock() }

        if let url = authorizedDirectory {
            url.stopAccessingSecurityScopedResource()
        }
    }

    #if os(iOS)
    private func validateWritableDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            _ = try url.resourceValues(forKeys: [.isDirectoryKey])
        }

        let testURL = url.appendingPathComponent(".flowos-access-test")
        let data = Data("ok".utf8)
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: testURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                try? FileManager.default.removeItem(at: coordinatedURL)
            } catch {
                writeError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let writeError {
            throw writeError
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }

        if let tab = controller as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }

        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }

        return controller
    }
    #endif
}

#if os(iOS)
private final class IOSDirectoryPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
#endif
