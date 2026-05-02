import Foundation
#if os(macOS)
import AppKit
#endif

/// 快捷键管理器
///
/// 管理全局快捷键
public final class KeyboardShortcutManager: Sendable {
    // MARK: - Singleton

    public static let shared = KeyboardShortcutManager()

    // MARK: - Properties

    private var onToggle: (@Sendable () -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// 设置切换回调
    public func setToggleHandler(_ handler: @escaping @Sendable () -> Void) {
        onToggle = handler
    }

    /// 开始监听全局快捷键
    #if os(macOS)
    public func startListening() {
        // 监听全局键盘事件
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // 监听应用内的键盘事件
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // 空格键
        if event.keyCode == 49 {
            // 检查是否在输入框中
            if let responder = NSApp.keyWindow?.firstResponder {
                if responder is NSTextView || responder is NSTextField {
                    return // 在输入框中不触发
                }
            }
            onToggle?()
        }
    }
    #else
    public func startListening() {
        // iOS 不支持全局快捷键
    }
    #endif
}