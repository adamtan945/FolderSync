import Foundation

// MARK: - Unison 同步引擎服務

/// 包裝 unison CLI，負責組裝指令、執行同步、解析輸出
actor UnisonService {
    /// 檢查 unison 是否已安裝
    static func isInstalled(at path: String = AppConfig.defaultUnisonPath) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    /// 執行同步
    func sync(pair: SyncPair, unisonPath: String, globalExclusions: [String]) async throws -> SyncResult {
        let args = buildArguments(for: pair, globalExclusions: globalExclusions)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: unisonPath)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let result = parseOutput(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )

        // 後處理：重命名衝突檔為 {name}.conflict.{ext}
        if !result.conflictFiles.isEmpty {
            renameConflictFiles(in: pair.destinationPath, conflicts: result.conflictFiles)
            if pair.direction == .bidirectional {
                renameConflictFiles(in: pair.sourcePath, conflicts: result.conflictFiles)
            }
        }

        return result
    }

    // MARK: - 組裝 unison 指令參數

    /// 根據 SyncPair 設定組裝 unison CLI 參數
    func buildArguments(for pair: SyncPair, globalExclusions: [String]) -> [String] {
        var args: [String] = []

        // 兩個根路徑
        args.append(pair.sourcePath)
        args.append(pair.destinationPath)

        // 自動模式（非互動）
        args.append(contentsOf: ["-batch", "-auto"])

        // 同步方向
        switch pair.direction {
        case .bidirectional:
            args.append(contentsOf: ["-prefer", "newer"])
            args.append("-copyonconflict")
        case .oneWay:
            args.append(contentsOf: ["-force", pair.sourcePath])
        }

        // 時間戳與權限
        args.append("-times")
        args.append(contentsOf: ["-perms", "0"])

        // 快速檢查（用修改時間而非內容 hash）
        args.append(contentsOf: ["-fastcheck", "true"])

        // 重試
        args.append(contentsOf: ["-retry", "3"])

        // 排除規則：預設 + 自訂 + 全域
        let allExclusions = pair.allExclusions + globalExclusions
        for exclusion in allExclusions {
            if exclusion.contains("/") {
                // 包含路徑分隔符，用 Path 匹配
                args.append(contentsOf: ["-ignore", "Path \(exclusion)"])
            } else {
                // 純名稱匹配
                args.append(contentsOf: ["-ignore", "Name \(exclusion)"])
            }
        }

        return args
    }

    // MARK: - 解析 unison 輸出

    /// 解析 unison 的 stdout/stderr 和 exit code
    func parseOutput(stdout: String, stderr: String, exitCode: Int32) -> SyncResult {
        var filesChanged = 0
        var conflictFiles: [String] = []

        // 計算同步的檔案數
        // unison 輸出格式：  <---- filename  或  ----> filename  或  <-?-> filename（衝突）
        let lines = stdout.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("<----") || trimmed.contains("---->") || trimmed.contains("<--->") {
                filesChanged += 1
            }
            // 衝突檔偵測
            if trimmed.contains("<-?->") || trimmed.contains("conflict") {
                // 提取檔名
                let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }
                if let filename = parts.last?.trimmingCharacters(in: .whitespaces) {
                    conflictFiles.append(filename)
                }
            }
        }

        let success: Bool
        let message: String

        switch exitCode {
        case 0:
            success = true
            message = filesChanged > 0 ? "同步完成，\(filesChanged) 個檔案已更新" : "已是最新狀態"
        case 1:
            // exit code 1 = 部分檔案被跳過（衝突等）
            success = true
            message = "同步完成，部分檔案有衝突（\(conflictFiles.count) 個）"
        case 2:
            success = false
            message = "同步失敗：連線錯誤或路徑不存在"
        case 3:
            success = false
            message = "同步中止：使用者取消或嚴重錯誤"
        default:
            success = false
            let errorDetail = stderr.isEmpty ? stdout : stderr
            let firstLine = errorDetail.components(separatedBy: .newlines).first ?? "未知錯誤"
            message = "同步失敗 (exit \(exitCode)): \(firstLine)"
        }

        return SyncResult(
            success: success,
            filesChanged: filesChanged,
            message: message,
            conflictFiles: conflictFiles
        )
    }

    // MARK: - 衝突檔重命名

    /// 將 unison 產生的衝突備份檔重命名為 {name}.conflict.{ext}
    private func renameConflictFiles(in directory: String, conflicts: [String]) {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: directory)

        // unison 的 copyonconflict 備份格式通常是 .unison.tmp 結尾
        guard let enumerator = fm.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            // 偵測 unison 衝突備份檔
            if name.contains(".unison.tmp") {
                let original = name.replacingOccurrences(of: ".unison.tmp", with: "")
                let ext = (original as NSString).pathExtension
                let base = (original as NSString).deletingPathExtension

                let newName: String
                if ext.isEmpty {
                    newName = "\(base).conflict"
                } else {
                    newName = "\(base).conflict.\(ext)"
                }

                let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
                do {
                    // 若目標已存在則先移除
                    if fm.fileExists(atPath: newURL.path) {
                        try fm.removeItem(at: newURL)
                    }
                    try fm.moveItem(at: url, to: newURL)
                } catch {
                    print("[UnisonService] 衝突檔重命名失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}
