import Foundation

// MARK: - 同步狀態

/// 單一配對的同步狀態
enum SyncStatus: Equatable, Sendable {
    case idle                // 閒置
    case watching            // 監控中，等待變更
    case syncing             // 同步進行中
    case error(String)       // 同步失敗，附帶錯誤訊息
    case paused              // 使用者手動暫停

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .idle: return l["statusIdle"]
        case .watching: return l["statusWatching"]
        case .syncing: return l["statusSyncing"]
        case .error: return l["statusError"]
        case .paused: return l["statusPaused"]
        }
    }

    /// Menu Bar 與列表用的 SF Symbol 圖示
    var symbolName: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .watching: return "eye.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    /// 狀態對應的語義色名稱
    var colorName: String {
        switch self {
        case .idle, .watching: return "statusSuccess"
        case .syncing: return "statusPrimary"
        case .error: return "statusError"
        case .paused: return "statusSecondary"
        }
    }
}

// MARK: - 同步日誌條目

/// 記錄每次同步操作的結果
struct SyncLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let pairId: UUID
    let pairName: String
    let timestamp: Date
    let message: String
    let isError: Bool
    let filesChanged: Int

    init(
        id: UUID = UUID(),
        pairId: UUID,
        pairName: String,
        timestamp: Date = Date(),
        message: String,
        isError: Bool = false,
        filesChanged: Int = 0
    ) {
        self.id = id
        self.pairId = pairId
        self.pairName = pairName
        self.timestamp = timestamp
        self.message = message
        self.isError = isError
        self.filesChanged = filesChanged
    }
}

// MARK: - 同步結果

/// unison 同步執行結果
struct SyncResult: Sendable {
    let success: Bool
    let filesChanged: Int
    let message: String
    let conflictFiles: [String]
}
