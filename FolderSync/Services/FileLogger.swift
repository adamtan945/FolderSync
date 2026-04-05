import Foundation

// MARK: - 檔案日誌服務

/// 將執行日誌寫入 ~/Library/Application Support/FolderSync/Logs/{YYYY-MM-DD-HH}.log
/// 用於偵錯和追蹤同步行為
final class FileLogger: Sendable {
    static let shared = FileLogger()

    private let logsDir: URL = PersistenceService.appSupportDir.appendingPathComponent("Logs", isDirectory: true)
    private let queue = DispatchQueue(label: "com.foldersync.filelogger")

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH"
        f.timeZone = .current
        return f
    }()

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.timeZone = .current
        return f
    }()

    /// 日誌保留天數
    private let retentionDays = 30

    private init() {
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        cleanOldLogs()
    }

    /// 刪除超過保留天數的日誌檔
    private func cleanOldLogs() {
        queue.async { [self] in
            let fm = FileManager.default
            let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

            guard let files = try? fm.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }

            for file in files where file.pathExtension == "log" {
                if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let created = attrs.creationDate,
                   created < cutoff {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }

    /// 寫入一行日誌
    func log(_ message: String, level: Level = .info) {
        let now = Date()
        let timestamp = timestampFormatter.string(from: now)
        let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

        // 同時輸出到 stdout
        print(message)

        queue.async { [self] in
            let filename = dateFormatter.string(from: now) + ".log"
            let fileURL = logsDir.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(Data(line.utf8))
                    handle.closeFile()
                }
            } else {
                try? Data(line.utf8).write(to: fileURL, options: .atomic)
            }
        }
    }

    /// 日誌等級
    enum Level: String, Sendable {
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }
}

// MARK: - 全域快捷函式

/// 寫入 info 日誌
func logInfo(_ message: String) {
    FileLogger.shared.log(message, level: .info)
}

/// 寫入 warn 日誌
func logWarn(_ message: String) {
    FileLogger.shared.log(message, level: .warn)
}

/// 寫入 error 日誌
func logError(_ message: String) {
    FileLogger.shared.log(message, level: .error)
}
