import SwiftUI

// MARK: - Menu Bar 下拉選單

/// Menu Bar 點擊後顯示的選單內容
struct MenuBarView: View {
    let appState: AppState
    let onSyncAll: () -> Void
    let onTogglePause: () -> Void
    let onSyncPair: (SyncPair) -> Void
    let onUpdate: () -> Void

    @Environment(\.openWindow) private var openWindow
    private var l: L10n { L10n.shared }

    var body: some View {
        // 狀態標題
        Button {} label: {
            HStack(spacing: 6) {
                Text("FolderSync")
                    .font(.rounded(13, weight: .semibold))
                Spacer()
                Circle()
                    .fill(Theme.color(for: appState.overallStatus))
                    .frame(width: 8, height: 8)
                Text(appState.overallStatus.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(true)

        // 更新狀態提示
        if appState.isDownloadingUpdate {
            Button {} label: {
                Label(
                    "\(l["updateDownloading"]) \(Int(appState.updateDownloadProgress * 100))%",
                    systemImage: "arrow.down.circle"
                )
            }
            .disabled(true)
        } else if appState.updateAvailable {
            // 自動更新失敗時可手動重試
            Button {
                onUpdate()
            } label: {
                Label(
                    l["updateAvailable"].replacingOccurrences(of: "{version}", with: appState.latestVersion),
                    systemImage: "arrow.up.circle.fill"
                )
            }
        }

        Divider()

        // 同步配對列表
        if appState.syncPairs.isEmpty {
            Text(l["menuNoSyncPairs"])
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        } else {
            ForEach(appState.syncPairs) { pair in
                MenuBarPairRow(
                    pair: pair,
                    status: appState.status(for: pair.id),
                    lastSyncText: appState.lastSyncText(for: pair),
                    onSync: { onSyncPair(pair) }
                )
            }
        }

        Divider()

        // 動作按鈕
        Button {
            onSyncAll()
        } label: {
            Label(l["menuSyncAll"], systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(appState.syncPairs.isEmpty)

        Button {
            onTogglePause()
        } label: {
            if appState.isGloballyPaused {
                Label(l["menuResumeAll"], systemImage: "play.circle")
            } else {
                Label(l["menuPauseAll"], systemImage: "pause.circle")
            }
        }

        Divider()

        Button {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label(l["menuSettings"], systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label(l["menuQuit"], systemImage: "xmark.circle")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Menu Bar 配對行

private struct MenuBarPairRow: View {
    let pair: SyncPair
    let status: SyncStatus
    let lastSyncText: String
    let onSync: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onSync) {
            HStack(spacing: 8) {
                Image(systemName: pair.direction.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(pair.name.isEmpty ? pair.shortSourcePath : pair.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer()

                switch status {
                case .syncing, .error, .paused:
                    Text(status.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.color(for: status), in: Capsule())
                default:
                    Text(lastSyncText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}
