import SwiftUI

// MARK: - 應用程式全域狀態

/// 可觀察的全域狀態，驅動所有 UI 更新
@Observable
@MainActor
final class AppState {
    /// 所有同���配對
    var syncPairs: [SyncPair] = []

    /// 每個配對的即時狀態
    var pairStatuses: [UUID: SyncStatus] = [:]

    /// 同步日誌
    var logEntries: [SyncLogEntry] = []

    /// 全域暫停開關
    var isGloballyPaused: Bool = false

    /// 是否開機自動啟動
    var launchAtLogin: Bool = false

    /// unison 執行檔路徑
    var unisonPath: String = AppConfig.defaultUnisonPath

    /// 全域排除規則
    var globalExclusions: [String] = []

    /// 是否顯示設定視窗
    var showSettings: Bool = false

    /// 是否顯示首次啟動引導
    var showOnboarding: Bool = false

    /// unison 是否已安裝
    var unisonInstalled: Bool = false

    // MARK: - 更新狀態

    /// 是否有新版本可用
    var updateAvailable: Bool = false

    /// 最新版本號
    var latestVersion: String = ""

    /// 最新版 DMG 下載 URL
    var latestDownloadURL: URL?

    /// 下載進度（0~1）
    var updateDownloadProgress: Double = 0

    /// 是否正在下載更新
    var isDownloadingUpdate: Bool = false

    /// 是否正在檢查更新
    var isCheckingUpdate: Bool = false

    /// 更新錯誤訊息
    var updateError: String?

    // MARK: - 計算屬性

    /// 整體狀態（用於 Menu Bar 圖示）
    var overallStatus: SyncStatus {
        let activeStatuses = syncPairs
            .filter(\.isEnabled)
            .compactMap { pairStatuses[$0.id] }

        // 優先顯示錯誤
        if activeStatuses.contains(where: {
            if case .error = $0 { return true }
            return false
        }) {
            return .error("部分配對同步失敗")
        }

        // 有任一在同步中
        if activeStatuses.contains(.syncing) {
            return .syncing
        }

        // 全域暫停
        if isGloballyPaused {
            return .paused
        }

        return .watching
    }

    // MARK: - 狀態查詢

    /// 取得特定配對的狀態
    func status(for pairId: UUID) -> SyncStatus {
        pairStatuses[pairId] ?? .idle
    }

    /// 取得特定配對距上次同步的相對時間文字
    func lastSyncText(for pair: SyncPair) -> String {
        guard let date = pair.lastSyncDate else { return L10n.shared["statusNeverSynced"] }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }

    // MARK: - 設定同步

    /// 從持久化載入設定
    func loadFromDisk() {
        let config = PersistenceService.loadConfig()
        syncPairs = config.syncPairs
        launchAtLogin = config.launchAtLogin
        unisonPath = config.unisonPath
        globalExclusions = config.globalExclusions
        logEntries = PersistenceService.loadLogs()

        // 初始化所有配對狀態
        for pair in syncPairs {
            pairStatuses[pair.id] = pair.isEnabled ? .idle : .paused
        }
    }

    /// 儲存設定到磁碟
    func saveToDisk() {
        let config = AppConfig(
            syncPairs: syncPairs,
            launchAtLogin: launchAtLogin,
            unisonPath: unisonPath,
            globalExclusions: globalExclusions,
            language: L10n.shared.language
        )
        do {
            try PersistenceService.saveConfig(config)
        } catch {
            logError("[AppState] 儲存設定失敗: \(error.localizedDescription)")
        }
    }
}
