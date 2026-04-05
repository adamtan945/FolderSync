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
            VStack(spacing: 0) {
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.localizedName, systemImage: tab.icon)
                        .font(.rounded(13))
                }
                .listStyle(.sidebar)

                Divider()

                // 版本資訊 + 更新
                sidebarVersionView
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
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

    // MARK: - Sidebar 底部版本列

    @ViewBuilder
    private var sidebarVersionView: some View {
        let appState = syncManager.appState

        if appState.isDownloadingUpdate {
            // 下載中
            VStack(spacing: 6) {
                Text(l["updateDownloading"])
                    .font(.rounded(11))
                    .foregroundStyle(.secondary)
                ProgressView(value: appState.updateDownloadProgress)
                    .progressViewStyle(.linear)
                    .tint(Theme.primary)
                Text("\(Int(appState.updateDownloadProgress * 100))%")
                    .font(.mono(10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else if appState.updateAvailable {
            // 有新版本
            Button {
                Task { await syncManager.downloadAndInstallUpdate() }
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                        Text("v\(appState.latestVersion)")
                            .font(.rounded(12, weight: .medium))
                    }
                    Text(l["updateAvailableShort"])
                        .font(.rounded(10))
                }
                .foregroundStyle(Theme.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Theme.warning.opacity(0.08))
        } else {
            // 正常：版本號 + 檢查按鈕
            HStack(spacing: 6) {
                Text("v\(UpdateService.currentVersion)")
                    .font(.mono(11))
                    .foregroundStyle(.tertiary)

                Spacer()

                if appState.isCheckingUpdate {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Button {
                        Task { await syncManager.checkForUpdates() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(l["updateCheck"])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
