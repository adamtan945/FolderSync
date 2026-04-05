import Foundation

// MARK: - 持久化設定結構

/// App 設定的頂層容器
struct AppConfig: Codable {
    var syncPairs: [SyncPair]
    var launchAtLogin: Bool
    var unisonPath: String
    var globalExclusions: [String]
    var language: String

    static let defaultUnisonPath = "/opt/homebrew/bin/unison"

    init(
        syncPairs: [SyncPair] = [],
        launchAtLogin: Bool = false,
        unisonPath: String = defaultUnisonPath,
        globalExclusions: [String] = [],
        language: String = "zh-TW"
    ) {
        self.syncPairs = syncPairs
        self.launchAtLogin = launchAtLogin
        self.unisonPath = unisonPath
        self.globalExclusions = globalExclusions
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncPairs = try container.decode([SyncPair].self, forKey: .syncPairs)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        unisonPath = try container.decode(String.self, forKey: .unisonPath)
        globalExclusions = try container.decode([String].self, forKey: .globalExclusions)
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "zh-TW"
    }
}

// MARK: - 持久化服務

/// 負責 config.json 與 logs.json 的讀寫
final class PersistenceService: Sendable {
    /// Application Support 下的 FolderSync 目錄
    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("FolderSync", isDirectory: true)
    }()

    private static let configFile = appSupportDir.appendingPathComponent("config.json")
    private static let logsFile = appSupportDir.appendingPathComponent("logs.json")

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - 目錄初始化

    /// 確保 Application Support/FolderSync 目錄存在
    static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: appSupportDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 設定讀寫

    /// 載入設定檔，若不存在則回傳預設值
    static func loadConfig() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return AppConfig()
        }
        do {
            let data = try Data(contentsOf: configFile)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("[PersistenceService] 設定檔讀取失敗: \(error.localizedDescription)")
            return AppConfig()
        }
    }

    /// 儲存設定檔
    static func saveConfig(_ config: AppConfig) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(config)
        try data.write(to: configFile, options: .atomic)
    }

    // MARK: - 日誌讀寫

    /// 載入同��日誌
    static func loadLogs() -> [SyncLogEntry] {
        guard FileManager.default.fileExists(atPath: logsFile.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: logsFile)
            return try decoder.decode([SyncLogEntry].self, from: data)
        } catch {
            print("[PersistenceService] 日誌讀取失敗: \(error.localizedDescription)")
            return []
        }
    }

    /// 新增日誌條目，保留最近 500 筆
    static func appendLog(_ entry: SyncLogEntry) throws {
        try ensureDirectoryExists()
        var logs = loadLogs()
        logs.append(entry)
        // 只保留最近 500 筆
        if logs.count > 500 {
            logs = Array(logs.suffix(500))
        }
        let data = try encoder.encode(logs)
        try data.write(to: logsFile, options: .atomic)
    }

    /// 清空��誌
    static func clearLogs() throws {
        try ensureDirectoryExists()
        let data = try encoder.encode([SyncLogEntry]())
        try data.write(to: logsFile, options: .atomic)
    }
}
