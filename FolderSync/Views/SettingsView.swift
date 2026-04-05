import SwiftUI

// MARK: - 設定視窗主視圖（Sidebar 導航）

struct SettingsView: View {
    let syncManager: SyncManager

    @State private var selectedTab: SettingsTab = .pairs
    @State private var toastMessage: String?
    @State private var toastIsError = false
    private var l: L10n { L10n.shared }

    enum SettingsTab: String, CaseIterable {
        case pairs
        case log
        case general
        case backup

        var icon: String {
            switch self {
            case .pairs: return "folder.badge.gearshape"
            case .log: return "doc.text"
            case .general: return "gearshape"
            case .backup: return "square.and.arrow.up.on.square"
            }
        }

        var localizedName: String {
            let l = L10n.shared
            switch self {
            case .pairs: return l["tabSyncPairs"]
            case .log: return l["tabLog"]
            case .general: return l["tabGeneral"]
            case .backup: return l["tabBackup"]
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.localizedName, systemImage: tab.icon)
                    .font(.rounded(13))
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case .pairs:
                    SyncPairsListView(syncManager: syncManager)
                case .log:
                    SyncLogView(
                        logEntries: syncManager.appState.logEntries,
                        onClearLogs: { syncManager.clearLogs() }
                    )
                case .general:
                    GeneralSettingsView(syncManager: syncManager)
                case .backup:
                    BackupSettingsView(
                        syncManager: syncManager,
                        toastMessage: $toastMessage,
                        toastIsError: $toastIsError
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            if let msg = toastMessage {
                HStack(spacing: 6) {
                    Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text(msg)
                        .font(.rounded(12))
                }
                .foregroundStyle(toastIsError ? Theme.error : Theme.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((toastIsError ? Theme.error : Theme.success).opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder((toastIsError ? Theme.error : Theme.success).opacity(0.2), lineWidth: 0.5)
                )
                .padding(.top, 8)
                .padding(.trailing, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation { toastMessage = nil }
        }
        .onAppear {
            syncManager.checkUnisonInstalled()
        }
    }
}
