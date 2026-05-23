import Foundation

/// iCloud Drive 同步管理器
///
/// 使用用户授权的目录同步数据
/// 在沙盒模式下，需要用户通过 NSOpenPanel 授权目录
public final class iCloudDriveSyncManager: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = iCloudDriveSyncManager()

    // MARK: - Properties

    private let lock = NSLock()
    private let fileManager = FileManager.default
    private let authManager = DirectoryAuthorizationManager.shared

    /// App 数据目录（从授权管理器获取）
    public var appDataDirectory: URL? {
        authManager.authorizedDirectoryURL
    }

    /// Todo 文件 URL
    public var todoFileURL: URL? {
        appDataDirectory?.appendingPathComponent("todos.json")
    }

    /// Settings 文件 URL
    public var settingsFileURL: URL? {
        appDataDirectory?.appendingPathComponent("settings.json")
    }

    /// Sessions 文件 URL
    public var sessionsFileURL: URL? {
        appDataDirectory?.appendingPathComponent("sessions.jsonl")
    }

    /// 外部变更回调
    public var onExternalChange: (() -> Void)?

    // MARK: - Init

    public init() {
        setupDirectoryWatcher()
    }

    // MARK: - Public API

    /// 检查是否有授权目录
    public var isICloudDriveAvailable: Bool {
        authManager.hasAuthorizedDirectory
    }

    /// 请求用户授权目录
    public func requestAuthorization() async -> URL? {
        await authManager.requestAuthorization()
    }

    /// 更改数据目录，并将旧目录中缺失的数据文件迁移到新目录
    public func changeDataDirectory() async throws -> DirectoryChangeResult? {
        let oldDirectory = appDataDirectory
        guard let newDirectory = await authManager.selectDirectory() else {
            return nil
        }

        let result = try migrateDataFiles(from: oldDirectory, to: newDirectory)
        try authManager.authorizeDirectory(newDirectory)
        SettingsRepository.shared.clearCache()
        TodoRepository.shared.clearCache()
        NotificationCenter.default.post(name: .dataDirectoryDidChange, object: result)
        return result
    }

    /// 确保目录已授权
    public func ensureAuthorized() async -> URL? {
        await authManager.ensureAuthorized()
    }

    /// 确保数据目录存在
    public func ensureDirectoryExists() throws {
        guard let dir = appDataDirectory else {
            throw iCloudDriveSyncError.iCloudDriveNotAvailable
        }

        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func migrateDataFiles(from oldDirectory: URL?, to newDirectory: URL) throws -> DirectoryChangeResult {
        let source = oldDirectory?.standardizedFileURL
        let destination = newDirectory.standardizedFileURL

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        guard source != destination else {
            return DirectoryChangeResult(directory: destination, copiedFiles: [], keptExistingFiles: [], skippedFiles: [])
        }

        let dataFileNames = ["todos.json", "settings.json", "sessions.jsonl"]
        var copied: [String] = []
        var keptExisting: [String] = []
        var skipped: [String] = []

        for fileName in dataFileNames {
            guard let sourceURL = source?.appendingPathComponent(fileName),
                  fileManager.fileExists(atPath: sourceURL.path) else {
                skipped.append(fileName)
                continue
            }

            let destinationURL = destination.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                keptExisting.append(fileName)
                continue
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            copied.append(fileName)
        }

        return DirectoryChangeResult(
            directory: destination,
            copiedFiles: copied,
            keptExistingFiles: keptExisting,
            skippedFiles: skipped
        )
    }

    /// 写入数据到文件
    public func write<T: Codable>(_ data: T, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        try ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url, options: .atomic)
    }

    /// 从文件读取数据
    public func read<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            return nil
        }
    }

    /// 追加 Session 记录到 JSONL 文件
    public func appendSession(_ record: SessionRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        try ensureDirectoryExists()

        guard let url = sessionsFileURL else {
            throw iCloudDriveSyncError.iCloudDriveNotAvailable
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(record)
        guard let line = String(data: jsonData, encoding: .utf8) else {
            throw iCloudDriveSyncError.encodingFailed
        }

        if !fileManager.fileExists(atPath: url.path) {
            try (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        } else {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            if let appendData = (line + "\n").data(using: .utf8) {
                try fileHandle.write(contentsOf: appendData)
            }
        }
    }

    /// 读取所有 Session 记录
    public func loadAllSessions() -> [SessionRecord] {
        lock.lock()
        defer { lock.unlock() }

        guard let url = sessionsFileURL,
              fileManager.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return lines.compactMap { line -> SessionRecord? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(SessionRecord.self, from: data)
            }
        } catch {
            return []
        }
    }

    /// 获取最后同步时间（通过文件修改时间）
    public func getLastSyncTime(for url: URL) -> Date? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            return attrs[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    // MARK: - Directory Watcher

    private func setupDirectoryWatcher() {
        guard let dir = appDataDirectory else { return }

        // 使用 DispatchSource 监听目录变更
        let descriptor = open(dir.path, O_EVTONLY)
        if descriptor < 0 { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onExternalChange?()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
    }
}

// MARK: - Errors

public enum iCloudDriveSyncError: LocalizedError {
    case iCloudDriveNotAvailable
    case encodingFailed
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .iCloudDriveNotAvailable:
            return L("Data directory is not authorized", defaultValue: "数据目录未授权")
        case .encodingFailed:
            return L("Encoding failed", defaultValue: "编码失败")
        case .fileNotFound:
            return L("File not found", defaultValue: "文件不存在")
        }
    }
}

public struct DirectoryChangeResult: Sendable {
    public let directory: URL
    public let copiedFiles: [String]
    public let keptExistingFiles: [String]
    public let skippedFiles: [String]

    public var didCopyFiles: Bool {
        !copiedFiles.isEmpty
    }

    public var didKeepExistingFiles: Bool {
        !keptExistingFiles.isEmpty
    }
}

extension Notification.Name {
    public static let dataDirectoryDidChange = Notification.Name("dataDirectoryDidChange")
}
