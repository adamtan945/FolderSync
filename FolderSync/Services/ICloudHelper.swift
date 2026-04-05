import Foundation

// MARK: - iCloud 輔助服務

/// 處理 iCloud 佔位檔（.icloud）的下載與偵測
enum ICloudHelper {
    /// iCloud 路徑特徵字串
    private static let icloudPathPatterns = [
        "/Library/Mobile Documents/",
        "com~apple~CloudDocs"
    ]

    /// 判斷是否為 iCloud 管理的路徑
    static func isICloudPath(_ path: String) -> Bool {
        icloudPathPatterns.contains { path.contains($0) }
    }

    /// 下載指定目錄中所有 iCloud 佔位檔
    ///
    /// iCloud 卸載檔案時會把 `foo.txt` 替換為 `.foo.txt.icloud`（plist stub）。
    /// 用 `brctl download` 強制下載實體檔案，避免 unison 誤判為刪除。
    static func downloadPlaceholders(at directoryPath: String) async throws {
        let placeholders = findPlaceholders(in: directoryPath)
        guard !placeholders.isEmpty else { return }

        print("[ICloudHelper] 發現 \(placeholders.count) 個 iCloud 佔位檔，開始下載...")

        // 對整個目錄執行 brctl download（比逐檔快）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
        process.arguments = ["download", directoryPath]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "未知錯誤"
            print("[ICloudHelper] brctl download 失敗: \(error)")
        }

        // 等待 iCloud 下載完成（最多等 30 秒）
        try await waitForDownloads(in: directoryPath, timeout: 30)
    }

    /// 掃描目錄中的 .icloud 佔位檔
    static func findPlaceholders(in directoryPath: String) -> [String] {
        let fm = FileManager.default
        var placeholders: [String] = []

        guard let enumerator = fm.enumerator(
            atPath: directoryPath
        ) else { return [] }

        while let relativePath = enumerator.nextObject() as? String {
            if relativePath.hasSuffix(".icloud") && (relativePath as NSString).lastPathComponent.hasPrefix(".") {
                placeholders.append(relativePath)
            }
        }

        return placeholders
    }

    /// 等待佔位檔消失（代表下載完成）
    private static func waitForDownloads(in directoryPath: String, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let remaining = findPlaceholders(in: directoryPath)
            if remaining.isEmpty {
                print("[ICloudHelper] 所有佔位檔已下載完成")
                return
            }
            try await Task.sleep(for: .seconds(1))
        }

        let remaining = findPlaceholders(in: directoryPath)
        if !remaining.isEmpty {
            print("[ICloudHelper] 警告：\(remaining.count) 個佔位檔下載逾時")
        }
    }
}
