import Foundation

/// JSON 文件存储
///
/// 通用的 JSON 文件读写工具
public enum JSONFileStore {
    /// 读取 JSON 文件
    public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    /// 写入 JSON 文件
    public static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    /// 删除文件
    public static func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

/// JSONL 文件存储（JSON Lines 格式）
///
/// 每行一个 JSON 对象，适合追加写入
public enum JSONLFileStore {
    /// 读取所有记录
    public static func readAll<T: Decodable>(_ type: T.Type, from url: URL) throws -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try lines.compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try decoder.decode(T.self, from: data)
        }
    }

    /// 追加一条记录
    public static func append<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var data = try encoder.encode(value)
        data.append(contentsOf: [0x0A]) // 换行符

        // 如果文件不存在，创建新文件
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url)
        } else {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }

    /// 删除文件
    public static func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
