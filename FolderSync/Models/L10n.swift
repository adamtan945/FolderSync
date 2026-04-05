import SwiftUI

// MARK: - 已發現的語系資訊

/// 從 JSON 檔動態載入的語系描述
struct DiscoveredLanguage: Identifiable, Hashable {
    let id: String          // 檔名去掉 .json，如 "zh-TW"
    let displayName: String // JSON 內的 languageName，如 "繁體中文"
}

// MARK: - 在地化字串管理（動態 JSON 驅動）

/// 掃描 Locales 資料夾自動載入所有 *.json 語系檔
@Observable
final class L10n: @unchecked Sendable {
    static let shared = L10n()

    /// 當前語系 ID（如 "zh-TW"）
    var language: String = "zh-TW" {
        didSet {
            UserDefaults.standard.set(language, forKey: "appLanguage")
            currentStrings = Self.loadJSON(at: localesDir, filename: language)
        }
    }

    /// 所有已發現的語系
    var availableLanguages: [DiscoveredLanguage] = []

    /// 當前語系字串
    private var currentStrings: [String: String] = [:]
    /// 備用語系（en-US）
    private var fallbackStrings: [String: String] = [:]
    /// Locales 資料夾路徑
    private let localesDir: URL

    private init() {
        localesDir = Self.findLocalesDir()
        fallbackStrings = Self.loadJSON(at: localesDir, filename: "en-US")

        if let saved = UserDefaults.standard.string(forKey: "appLanguage") {
            language = saved
        }
        currentStrings = Self.loadJSON(at: localesDir, filename: language)
        scanLanguages()
    }

    /// 以字串 key 取得在地化文字
    subscript(_ key: String) -> String {
        currentStrings[key] ?? fallbackStrings[key] ?? key
    }

    // MARK: - 掃描語系檔

    /// 重新掃描 Locales 資料夾，載入所有可用語系
    func scanLanguages() {
        let fm = FileManager.default
        var discovered: [DiscoveredLanguage] = []

        guard let files = try? fm.contentsOfDirectory(at: localesDir, includingPropertiesForKeys: nil) else {
            logWarn("[L10n] 無法列出 Locales 目錄: \(localesDir.path)")
            return
        }

        for file in files where file.pathExtension == "json" {
            let langId = file.deletingPathExtension().lastPathComponent
            let dict = Self.loadJSON(at: localesDir, filename: langId)
            let displayName = dict["languageName"] ?? langId
            discovered.append(DiscoveredLanguage(id: langId, displayName: displayName))
        }

        // 按 displayName 排序，但保持目前語系在前
        discovered.sort { a, b in
            if a.id == language { return true }
            if b.id == language { return false }
            return a.displayName < b.displayName
        }

        availableLanguages = discovered

        // 驗證當前語系仍存在，否則 fallback 到第一個
        if !discovered.contains(where: { $0.id == language }), let first = discovered.first {
            language = first.id
        }
    }

    // MARK: - 內部工具

    /// 從指定目錄載入 {filename}.json
    private static func loadJSON(at dir: URL, filename: String) -> [String: String] {
        let url = dir.appendingPathComponent("\(filename).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            logWarn("[L10n] 找不到語系檔: \(url.path)")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            logError("[L10n] JSON 解析失敗 (\(filename).json): \(error.localizedDescription)")
            return [:]
        }
    }

    /// 尋找 Resources/Locales 資料夾位置
    private static func findLocalesDir() -> URL {
        // Bundle.main（.app bundle）
        if let url = Bundle.main.url(forResource: "Locales", withExtension: nil, subdirectory: "Resources") {
            return url
        }

        // SPM executable：從 executable 位置反推原始碼目錄
        // .build/arm64-apple-macosx/debug/FolderSync → 往上 4 層到專案根
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            .resolvingSymlinksInPath()
        let candidates = [
            // swift run: .build/arm64-apple-macosx/debug/FolderSync
            execURL.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("FolderSync/Resources/Locales"),
            // 同層
            execURL.deletingLastPathComponent()
                .appendingPathComponent("Resources/Locales"),
            // 往上 3 層
            execURL.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("FolderSync/Resources/Locales"),
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        // 最終 fallback
        logWarn("[L10n] 找不到 Locales 目錄，使用空字串")
        return URL(fileURLWithPath: "/tmp")
    }
}

// MARK: - 常用排除項目預設集

struct ExclusionPreset: Identifiable {
    let id = UUID()
    let pattern: String
    let descriptionKey: String  // L10n key
    let category: ExclusionCategory

    var localizedDescription: String {
        L10n.shared[descriptionKey]
    }
}

enum ExclusionCategory: String, CaseIterable {
    case system
    case development
    case media
    case versionControl

    var localizedName: String {
        switch self {
        case .system: return L10n.shared["categorySystem"]
        case .development: return L10n.shared["categoryDevelopment"]
        case .media: return L10n.shared["categoryTempLogs"]
        case .versionControl: return L10n.shared["categoryVersionControl"]
        }
    }
}

let exclusionPresets: [ExclusionPreset] = [
    .init(pattern: ".DS_Store", descriptionKey: "excDSStore", category: .system),
    .init(pattern: "*.icloud", descriptionKey: "excICloud", category: .system),
    .init(pattern: "Thumbs.db", descriptionKey: "excThumbs", category: .system),
    .init(pattern: ".Spotlight-V100", descriptionKey: "excSpotlight", category: .system),
    .init(pattern: ".Trashes", descriptionKey: "excTrashes", category: .system),

    .init(pattern: "node_modules", descriptionKey: "excNodeModules", category: .development),
    .init(pattern: ".build", descriptionKey: "excSwiftBuild", category: .development),
    .init(pattern: "__pycache__", descriptionKey: "excPycache", category: .development),
    .init(pattern: "*.pyc", descriptionKey: "excPyc", category: .development),
    .init(pattern: ".venv", descriptionKey: "excVenv", category: .development),
    .init(pattern: "target", descriptionKey: "excTarget", category: .development),

    .init(pattern: "*.tmp", descriptionKey: "excTmp", category: .media),
    .init(pattern: "*.log", descriptionKey: "excLog", category: .media),
    .init(pattern: "*.swp", descriptionKey: "excSwp", category: .media),

    .init(pattern: ".git", descriptionKey: "excGit", category: .versionControl),
    .init(pattern: ".svn", descriptionKey: "excSvn", category: .versionControl),
]
