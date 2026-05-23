import SwiftUI

// MARK: - Language Version Environment Key

struct LanguageVersionKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var languageVersion: Int {
        get { self[LanguageVersionKey.self] }
        set { self[LanguageVersionKey.self] = newValue }
    }
}

// MARK: - LanguageManager

@MainActor
@Observable
public final class LanguageManager {
    public static let shared = LanguageManager()

    @ObservationIgnored
    @AppStorage("appLanguage") private var storedLanguage: String = "zh-Hans"

    public var currentLanguage: String {
        didSet {
            storedLanguage = currentLanguage
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            invalidateStringsCache()
            languageVersion += 1
        }
    }

    public var languageVersion: Int = 0

    public var currentLocale: Locale {
        Locale(identifier: currentLanguage)
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"
        currentLanguage = saved
    }
}

// MARK: - Thread-safe localization lookup

private func currentAppLanguage() -> String {
    UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"
}

private var stringsCache: [String: [String: String]] = [:]
private let stringsCacheLock = NSLock()

func invalidateStringsCache() {
    stringsCacheLock.lock()
    stringsCache.removeAll()
    stringsCacheLock.unlock()
}

/// 直接从 Bundle 中查找 .lproj 目录并解析 Localizable.strings
private func getStringsTable(for language: String) -> [String: String]? {
    stringsCacheLock.lock()
    defer { stringsCacheLock.unlock() }

    if let cached = stringsCache[language] {
        return cached
    }

    let bundle = Bundle.main
    var url: URL?

    // 方式1: 使用 Bundle 的 localization API
    if let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language) {
        url = URL(fileURLWithPath: path)
    }

    // 方式2: 直接查找 .lproj 子目录
    if url == nil {
        if let resourcePath = bundle.resourcePath {
            let directPath = (resourcePath as NSString).appendingPathComponent("\(language).lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: directPath) {
                url = URL(fileURLWithPath: directPath)
            }
        }
    }

    // 方式3: 在 bundle 内搜索所有 .lproj 目录
    if url == nil {
        if let urls = bundle.urls(forResourcesWithExtension: "strings", subdirectory: "\(language).lproj") {
            url = urls.first { $0.lastPathComponent == "Localizable.strings" }
        }
    }

    guard let url = url,
          let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
    else {
        return nil
    }

    stringsCache[language] = plist
    return plist
}

/// 全局本地化函数
public func L(_ key: String, defaultValue: String) -> String {
    let lang = currentAppLanguage()
    if let table = getStringsTable(for: lang), let value = table[key] {
        return value
    }
    return defaultValue
}
