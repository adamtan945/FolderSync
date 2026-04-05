import SwiftUI

// MARK: - FolderSync 應用程式進入點

/// App Delegate：在 App 啟動後設定 activation policy
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隱藏 Dock 圖示（純 Menu Bar App）
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct FolderSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var syncManager = SyncManager()

    var body: some Scene {
        // Menu Bar 常駐圖示
        MenuBarExtra {
            MenuBarView(
                appState: syncManager.appState,
                onSyncAll: { Task { await syncManager.syncAllNow() } },
                onTogglePause: { syncManager.toggleGlobalPause() },
                onSyncPair: { pair in Task { await syncManager.triggerSync(for: pair) } }
            )
        } label: {
            MenuBarIcon(status: syncManager.appState.overallStatus)
        }
        .menuBarExtraStyle(.menu)

        // 設定視窗
        Window("FolderSync 設定", id: "settings") {
            SettingsView(syncManager: syncManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 750, height: 550)
        .windowResizability(.contentSize)
    }
}

// MARK: - Menu Bar 圖示（含動畫）

/// Menu Bar 上的狀態圖示
struct MenuBarIcon: View {
    let status: SyncStatus
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: Theme.menuBarSymbol(for: status))
            .rotationEffect(.degrees(status == .syncing ? rotation : 0))
            .onChange(of: status) { _, newValue in
                if newValue == .syncing {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                } else {
                    rotation = 0
                }
            }
    }
}
