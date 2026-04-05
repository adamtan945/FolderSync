import SwiftUI

// MARK: - FolderSync 設計系統

/// 配色系統：Refined Utility 精緻工具風
enum Theme {
    // 語義色
    static let primary = Color(hex: 0x4F46E5)       // 靛藍 — 主要操作、同步中
    static let success = Color(hex: 0x059669)        // 翡翠 — 成功、健康
    static let warning = Color(hex: 0xD97706)        // 琥珀 — 衝突、注意
    static let error = Color(hex: 0xE11D48)          // 玫紅 — 失敗

    /// 根據 SyncStatus 取得對應色彩
    static func color(for status: SyncStatus) -> Color {
        switch status {
        case .idle, .watching: return success
        case .syncing: return primary
        case .error: return error
        case .paused: return .secondary
        }
    }

    /// Menu Bar 圖示名稱
    static func menuBarSymbol(for status: SyncStatus) -> String {
        switch status {
        case .idle, .watching: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle"
        }
    }
}

// MARK: - Color Hex 擴充

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - 字型擴充

extension Font {
    /// SF Pro Rounded — 標題用
    static func rounded(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// SF Mono — 路徑顯示用
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
