import Foundation
import UserNotifications

/// 通知服务
///
/// 负责发送本地通知
public final class NotificationService: Sendable {
    // MARK: - Singleton

    public static let shared = NotificationService()

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// 请求通知权限
    public func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await center.requestAuthorization(options: options)
        } catch {
            return false
        }
    }

    /// 检查授权状态
    public func checkAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// 发送 Session 完成通知
    public func sendSessionCompleteNotification(sessionType: SessionType) async {
        guard await checkAuthorization() else { return }

        let title: String
        let body: String

        switch sessionType {
        case .focus:
            title = "专注完成！"
            body = "休息一下吧"
        case .shortBreak:
            title = "短休息结束"
            body = "准备好继续专注了吗？"
        case .longBreak:
            title = "长休息结束"
            body = "新的周期开始了"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    /// 发送自定义通知
    public func sendNotification(title: String, body: String) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    /// 清除所有通知
    public func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
    }
}
