import Foundation

private let flowOSLogURL: URL = {
    let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
    let url = baseURL.appendingPathComponent("FlowOS.log")
    FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
    return url
}()

func logPrint(_ message: String) {
    print(message)
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logLine = "[\(timestamp)] \(message)\n"
    guard let data = logLine.data(using: .utf8) else { return }

    if let fileHandle = try? FileHandle(forWritingTo: flowOSLogURL) {
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        try? fileHandle.close()
    } else {
        try? data.write(to: flowOSLogURL)
    }
}

func logFilePath() -> String {
    flowOSLogURL.path
}
