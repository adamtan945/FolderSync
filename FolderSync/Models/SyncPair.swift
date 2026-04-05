import Foundation

// MARK: - 同步方向

/// 同步方向列舉
enum SyncDirection: String, Codable, CaseIterable, Sendable {
    case oneWay = "oneWay"             // 單向：來源 → 目的
    case bidirectional = "bidirectional" // 雙向同步

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .oneWay: return l["directionOneWay"]
        case .bidirectional: return l["directionBidirectional"]
        }
    }

    var symbolName: String {
        switch self {
        case .oneWay: return "arrow.right"
        case .bidirectional: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - 同步配對資料模型

/// 一組同步配對：來源路徑 ↔ 目的路徑
struct SyncPair: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var sourcePath: String
    var destinationPath: String
    var direction: SyncDirection
    var isEnabled: Bool
    var exclusions: [String]
    var lastSyncDate: Date?

    /// 所有排除規則（直接使用使用者選擇的項目）
    var allExclusions: [String] {
        exclusions
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        sourcePath: String = "",
        destinationPath: String = "",
        direction: SyncDirection = .bidirectional,
        isEnabled: Bool = true,
        exclusions: [String] = [],
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.direction = direction
        self.isEnabled = isEnabled
        self.exclusions = exclusions
        self.lastSyncDate = lastSyncDate
    }

    /// 來源路徑的縮短顯示（truncate middle）
    var shortSourcePath: String {
        Self.truncateMiddle(sourcePath)
    }

    /// 目的路徑的縮短顯示
    var shortDestinationPath: String {
        Self.truncateMiddle(destinationPath)
    }

    /// 將過長路徑截斷為中間省略格式
    private static func truncateMiddle(_ path: String, maxLength: Int = 45) -> String {
        guard path.count > maxLength else { return path }
        let components = path.split(separator: "/")
        guard components.count > 3 else { return path }
        let first = components.prefix(2).joined(separator: "/")
        let last = components.suffix(2).joined(separator: "/")
        return "/\(first)/.../\(last)"
    }
}
