import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Shared data contract used by macOS and future iOS targets.
public enum FlowOSDataSchema {
    public static let currentVersion = 2
    public static let legacyVersion = 1
}

public enum FlowOSDataFile: String, CaseIterable, Sendable {
    case todos = "todos.json"
    case settings = "settings.json"
    case sessions = "sessions.jsonl"
    case activeTimer = "active_timer.json"
    case widgetData = "widget_data.json"
}

public enum FlowOSPlatform: String, Codable, Sendable {
    case macOS
    case iOS
    case other

    public static var current: FlowOSPlatform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #else
        return .other
        #endif
    }
}

public struct DeviceInfo: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String?
    public var platform: FlowOSPlatform

    public static var current: DeviceInfo {
        DeviceInfo(
            id: DeviceIdentityStore.currentDeviceID,
            name: DeviceInfo.currentDeviceName,
            platform: .current
        )
    }

    public init(id: UUID, name: String? = nil, platform: FlowOSPlatform = .current) {
        self.id = id
        self.name = name
        self.platform = platform
    }

    private static var currentDeviceName: String? {
        #if os(macOS)
        return Host.current().localizedName
        #elseif canImport(UIKit)
        return UIDevice.current.name
        #else
        return nil
        #endif
    }
}

private enum DeviceIdentityStore {
    private static let defaultsKey = "flowOSCurrentDeviceID"

    static var currentDeviceID: UUID {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: existing) {
            return id
        }

        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
        return id
    }
}

/// Per-task changes captured by a focus session.
///
/// This array shape is friendlier for cross-platform sync than a JSON object
/// keyed by UUID, while `SessionRecord.taskProgress` remains for 1.x data.
public struct SessionTaskUpdate: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID { taskId }
    public var taskId: UUID
    public var completedPercentage: Int
    public var completedAt: Date?

    public init(taskId: UUID, completedPercentage: Int, completedAt: Date? = nil) {
        self.taskId = taskId
        self.completedPercentage = max(0, min(100, completedPercentage))
        self.completedAt = completedAt
    }
}
