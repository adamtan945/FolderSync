import SwiftUI
import ServiceManagement

// MARK: - 同步管理器

/// 統籌 FileWatcher、ICloudHelper、UnisonService 的核心管理器
@Observable
@MainActor
final class SyncManager {
    let appState = AppState()

    private let unisonService = UnisonService()
    private let updateService = UpdateService()
    private var watchers: [UUID: FileWatcherService] = [:]
    private var syncLocks: Set<UUID> = [] // 防止同一配對並行同步

    // MARK: - 初始化

    init() {
        appState.loadFromDisk()
        checkUnisonInstalled()

        // 啟動所有已啟用配對的監控
        Task {
            startAllWatchers()
            // 啟動時執行一次完整同步
            await syncAllNow()
        }

        // 啟動時檢查是否有新版（僅提示，不自動安裝）
        Task {
            await checkForUpdates()
        }
    }

    // MARK: - Unison 檢查

    /// 檢查 unison 是否已安裝
    func checkUnisonInstalled() {
        appState.unisonInstalled = UnisonService.isInstalled(at: appState.unisonPath)
    }

    // MARK: - 同步配對 CRUD

    /// 新增同步配對
    func addPair(_ pair: SyncPair) {
        appState.syncPairs.append(pair)
        appState.pairStatuses[pair.id] = pair.isEnabled ? .idle : .paused
        appState.saveToDisk()

        if pair.isEnabled {
            startWatcher(for: pair)
            Task { await triggerSync(for: pair) }
        }
    }

    /// 更新同步配對
    func updatePair(_ updated: SyncPair) {
        guard let index = appState.syncPairs.firstIndex(where: { $0.id == updated.id }) else { return }

        // 先停止舊的 watcher
        stopWatcher(for: updated.id)

        appState.syncPairs[index] = updated
        appState.saveToDisk()

        // 重新啟動 watcher
        if updated.isEnabled && !appState.isGloballyPaused {
            startWatcher(for: updated)
        }
    }

    /// 刪除同步配對
    func deletePair(id: UUID) {
        stopWatcher(for: id)
        appState.syncPairs.removeAll { $0.id == id }
        appState.pairStatuses.removeValue(forKey: id)
        appState.saveToDisk()
    }

    /// 切換配對啟用/停用
    func togglePair(id: UUID) {
        guard let index = appState.syncPairs.firstIndex(where: { $0.id == id }) else { return }
        appState.syncPairs[index].isEnabled.toggle()
        let pair = appState.syncPairs[index]

        if pair.isEnabled {
            appState.pairStatuses[pair.id] = .idle
            startWatcher(for: pair)
        } else {
            stopWatcher(for: pair.id)
            appState.pairStatuses[pair.id] = .paused
        }
        appState.saveToDisk()
    }

    // MARK: - 全域控制

    /// 切換全域暫停
    func toggleGlobalPause() {
        appState.isGloballyPaused.toggle()

        if appState.isGloballyPaused {
            stopAllWatchers()
            for pair in appState.syncPairs where pair.isEnabled {
                appState.pairStatuses[pair.id] = .paused
            }
        } else {
            startAllWatchers()
            for pair in appState.syncPairs where pair.isEnabled {
                appState.pairStatuses[pair.id] = .watching
            }
        }
    }

    /// 立即同步所有已啟用的配對
    func syncAllNow() async {
        let enabledPairs = appState.syncPairs.filter(\.isEnabled)
        // 並行同步所有配對
        await withTaskGroup(of: Void.self) { group in
            for pair in enabledPairs {
                group.addTask { [self] in
                    await self.triggerSync(for: pair)
                }
            }
        }
    }

    /// 觸發單一配對的同步
    func triggerSync(for pair: SyncPair) async {
        // 防止同一配對並行同步
        guard !syncLocks.contains(pair.id) else {
            print("[SyncManager] 配對「\(pair.name)」正在同步中，跳過")
            return
        }

        guard appState.unisonInstalled else {
            appState.pairStatuses[pair.id] = .error("unison 未安裝")
            return
        }

        // 驗證路徑存在
        let fm = FileManager.default
        guard fm.fileExists(atPath: pair.sourcePath) else {
            appState.pairStatuses[pair.id] = .error("來源路徑不存在")
            appendLog(pair: pair, message: "來源路徑不存在: \(pair.sourcePath)", isError: true)
            return
        }

        // 目的路徑不存在則建立
        if !fm.fileExists(atPath: pair.destinationPath) {
            do {
                try fm.createDirectory(atPath: pair.destinationPath, withIntermediateDirectories: true)
            } catch {
                appState.pairStatuses[pair.id] = .error("無法建立目的路徑")
                appendLog(pair: pair, message: "無法建立目的路徑: \(error.localizedDescription)", isError: true)
                return
            }
        }

        // 開始同步
        syncLocks.insert(pair.id)
        appState.pairStatuses[pair.id] = .syncing

        do {
            // iCloud 佔位檔處理
            if ICloudHelper.isICloudPath(pair.sourcePath) {
                try await ICloudHelper.downloadPlaceholders(at: pair.sourcePath)
            }
            if ICloudHelper.isICloudPath(pair.destinationPath) {
                try await ICloudHelper.downloadPlaceholders(at: pair.destinationPath)
            }

            // 執行 unison 同步
            let result = try await unisonService.sync(
                pair: pair,
                unisonPath: appState.unisonPath,
                globalExclusions: appState.globalExclusions
            )

            // 更新狀態
            if result.success {
                appState.pairStatuses[pair.id] = .watching
                // 更新上次同步時間
                if let index = appState.syncPairs.firstIndex(where: { $0.id == pair.id }) {
                    appState.syncPairs[index].lastSyncDate = Date()
                }
            } else {
                appState.pairStatuses[pair.id] = .error(result.message)
            }

            appendLog(
                pair: pair,
                message: result.message,
                isError: !result.success,
                filesChanged: result.filesChanged
            )
        } catch {
            appState.pairStatuses[pair.id] = .error(error.localizedDescription)
            appendLog(pair: pair, message: "同步例外: \(error.localizedDescription)", isError: true)
        }

        syncLocks.remove(pair.id)
        appState.saveToDisk()
    }

    // MARK: - 日誌

    /// 新增日誌條目
    func appendLog(pair: SyncPair, message: String, isError: Bool = false, filesChanged: Int = 0) {
        let entry = SyncLogEntry(
            pairId: pair.id,
            pairName: pair.name.isEmpty ? pair.shortSourcePath : pair.name,
            message: message,
            isError: isError,
            filesChanged: filesChanged
        )
        appState.logEntries.append(entry)

        // 保留最近 500 筆
        if appState.logEntries.count > 500 {
            appState.logEntries = Array(appState.logEntries.suffix(500))
        }

        // 非同步寫入磁碟
        Task.detached {
            try? PersistenceService.appendLog(entry)
        }
    }

    /// 清除所有日誌
    func clearLogs() {
        appState.logEntries = []
        Task.detached {
            try? PersistenceService.clearLogs()
        }
    }

    // MARK: - 登入啟動

    /// 設定是否開機自動啟動
    func setLaunchAtLogin(_ enabled: Bool) {
        appState.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[SyncManager] 登入啟動設定失敗: \(error.localizedDescription)")
        }
        appState.saveToDisk()
    }

    // MARK: - 自動更新

    /// 檢查是否有新版本
    func checkForUpdates() async {
        appState.isCheckingUpdate = true
        appState.updateError = nil

        do {
            if let update = try await updateService.checkForUpdate() {
                appState.updateAvailable = true
                appState.latestVersion = update.version
                appState.latestDownloadURL = update.downloadURL
            } else {
                appState.updateAvailable = false
            }
        } catch {
            print("[SyncManager] 檢查更新失敗: \(error.localizedDescription)")
            appState.updateError = error.localizedDescription
        }

        appState.isCheckingUpdate = false
    }

    /// 檢查更新，有新版則自動下載安裝
    func checkAndAutoUpdate() async {
        await checkForUpdates()
        if appState.updateAvailable {
            await downloadAndInstallUpdate()
        }
    }

    /// 下載並安裝更新
    func downloadAndInstallUpdate() async {
        guard let url = appState.latestDownloadURL else { return }

        appState.isDownloadingUpdate = true
        appState.updateDownloadProgress = 0
        appState.updateError = nil

        do {
            let dmgPath = try await updateService.downloadUpdate(url: url) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.appState.updateDownloadProgress = progress
                }
            }

            appState.updateDownloadProgress = 1.0
            try await updateService.installUpdate(dmgPath: dmgPath)
        } catch {
            appState.isDownloadingUpdate = false
            appState.updateError = error.localizedDescription
            print("[SyncManager] 更新失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - FileWatcher 管理

    /// 啟動所有已啟用配對的監控
    private func startAllWatchers() {
        for pair in appState.syncPairs where pair.isEnabled && !appState.isGloballyPaused {
            startWatcher(for: pair)
        }
    }

    /// 停止所有監控
    private func stopAllWatchers() {
        for (_, watcher) in watchers {
            watcher.stopWatching()
        }
        watchers.removeAll()
    }

    /// 啟動單一配對的 FSEvents 監控
    private func startWatcher(for pair: SyncPair) {
        stopWatcher(for: pair.id)

        // 監控的路徑：來源 + 目的（雙向時兩邊都監控）
        var pathsToWatch = [pair.sourcePath]
        if pair.direction == .bidirectional {
            pathsToWatch.append(pair.destinationPath)
        }

        let watcher = FileWatcherService(paths: pathsToWatch) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.triggerSync(for: pair)
            }
        }

        watcher.startWatching()
        watchers[pair.id] = watcher
        appState.pairStatuses[pair.id] = .watching
    }

    /// 停止單一配對的監控
    private func stopWatcher(for pairId: UUID) {
        watchers[pairId]?.stopWatching()
        watchers.removeValue(forKey: pairId)
    }
}
