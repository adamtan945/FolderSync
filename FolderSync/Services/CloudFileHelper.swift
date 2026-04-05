import Foundation

// MARK: - 雲端佔位檔輔助服務

/// 統一處理所有 FileProvider 雲端儲存的佔位檔下載（iCloud、Google Drive、Dropbox、OneDrive 等）。
/// 使用 macOS 原生 ubiquitous item API，不依賴特定供應商工具。
enum CloudFileHelper {
    /// 雲端路徑特徵字串
    private static let cloudPathPatterns = [
        "/Library/Mobile Documents/",   // iCloud（沙盒路徑）
        "com~apple~CloudDocs",          // iCloud（容器識別）
        "/Library/CloudStorage/"         // Google Drive、Dropbox、OneDrive 等
    ]

    /// 快速判斷是否為雲端管理的路徑
    static func isCloudPath(_ path: String) -> Bool {
        cloudPathPatterns.contains { path.contains($0) }
    }

    /// 下載指定目錄中所有未下載的雲端檔案
    ///
    /// 掃描目錄內的所有檔案，找出 ubiquitousItemDownloadingStatus 不是 .current 的項目，
    /// 以及 iCloud 特有的 .icloud stub 檔，統一觸發下載。
    static func downloadPlaceholders(at directoryPath: String, timeout: TimeInterval = 60) async throws {
        // 快速路徑：非雲端目錄直接跳過
        guard isCloudPath(directoryPath) else { return }

        let notDownloaded = findNotDownloaded(in: directoryPath)
        guard !notDownloaded.isEmpty else { return }

        print("[CloudFileHelper] 發現 \(notDownloaded.count) 個未下載的雲端檔案，開始下載...")

        // 對每個檔案觸發下載
        let fm = FileManager.default
        for url in notDownloaded {
            do {
                try fm.startDownloadingUbiquitousItem(at: url)
            } catch {
                print("[CloudFileHelper] 無法觸發下載 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // 等待下載完成
        try await waitForDownloads(urls: notDownloaded, timeout: timeout)
    }

    /// 掃描目錄中未完整下載的雲端檔案
    static func findNotDownloaded(in directoryPath: String) -> [URL] {
        let fm = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)
        var results: [URL] = []

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // iCloud stub 檔是隱藏檔（.xxx.icloud），需要額外掃描
        let icloudStubs = findICloudStubs(in: directoryPath)
        results.append(contentsOf: icloudStubs)

        while let itemURL = enumerator.nextObject() as? URL {
            do {
                let values = try itemURL.resourceValues(forKeys: [
                    .isUbiquitousItemKey,
                    .ubiquitousItemDownloadingStatusKey
                ])

                guard values.isUbiquitousItem == true else { continue }

                if let status = values.ubiquitousItemDownloadingStatus,
                   status != .current {
                    results.append(itemURL)
                }
            } catch {
                // 無法讀取資源值，跳過
                continue
            }
        }

        return results
    }

    /// 掃描 iCloud 特有的 .icloud stub 檔
    private static func findICloudStubs(in directoryPath: String) -> [URL] {
        let fm = FileManager.default
        var stubs: [URL] = []

        guard let enumerator = fm.enumerator(atPath: directoryPath) else { return [] }

        while let relativePath = enumerator.nextObject() as? String {
            let filename = (relativePath as NSString).lastPathComponent
            if filename.hasPrefix(".") && filename.hasSuffix(".icloud") {
                let fullPath = (directoryPath as NSString).appendingPathComponent(relativePath)
                stubs.append(URL(fileURLWithPath: fullPath))
            }
        }

        return stubs
    }

    /// 輪詢等待所有檔案下載完成
    private static func waitForDownloads(urls: [URL], timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var remaining = Set(urls)

        while Date() < deadline && !remaining.isEmpty {
            var completed: Set<URL> = []

            for url in remaining {
                // iCloud stub 檔：檢查是否已消失（表示已下載為實體檔案）
                let filename = url.lastPathComponent
                if filename.hasPrefix(".") && filename.hasSuffix(".icloud") {
                    if !FileManager.default.fileExists(atPath: url.path) {
                        completed.insert(url)
                    }
                    continue
                }

                // 一般雲端檔案：檢查下載狀態
                do {
                    let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if values.ubiquitousItemDownloadingStatus == .current {
                        completed.insert(url)
                    }
                } catch {
                    completed.insert(url) // 無法查詢，視為完成避免卡住
                }
            }

            remaining.subtract(completed)

            if remaining.isEmpty {
                print("[CloudFileHelper] 所有雲端檔案已下載完成")
                return
            }

            try await Task.sleep(for: .seconds(1))
        }

        if !remaining.isEmpty {
            print("[CloudFileHelper] 警告：\(remaining.count) 個檔案下載逾時，繼續同步")
        }
    }
}
