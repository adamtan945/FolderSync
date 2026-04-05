import SwiftUI
import UniformTypeIdentifiers

// MARK: - 匯出 / 匯入設定視圖

struct BackupSettingsView: View {
    let syncManager: SyncManager
    @Binding var toastMessage: String?
    @Binding var toastIsError: Bool
    private var l: L10n { L10n.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(l["tabBackup"])
                    .font(.rounded(20, weight: .semibold))
                    .padding(.top, 16)

                // 匯出設定
                settingsCard(l["generalExport"]) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l["generalExportDesc"])
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            exportSettings()
                        } label: {
                            Label(l["generalExport"], systemImage: "square.and.arrow.up")
                                .font(.rounded(13))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                // 匯入設定
                settingsCard(l["generalImport"]) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l["generalImportDesc"])
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            importSettings()
                        } label: {
                            Label(l["generalImport"], systemImage: "square.and.arrow.down")
                                .font(.rounded(13))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 匯出

    private func exportSettings() {
        let panel = NSSavePanel()
        let dateStr: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        panel.nameFieldStringValue = "foldersync_\(dateStr).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let config = AppConfig(
            syncPairs: syncManager.appState.syncPairs,
            launchAtLogin: syncManager.appState.launchAtLogin,
            unisonPath: syncManager.appState.unisonPath,
            globalExclusions: syncManager.appState.globalExclusions,
            language: L10n.shared.language
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            try data.write(to: url, options: .atomic)
            showToast(l["generalExportSuccess"], isError: false)
        } catch {
            showToast(l["generalExportFail"], isError: true)
        }
    }

    // MARK: - 匯入

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(AppConfig.self, from: data)

            syncManager.appState.syncPairs = config.syncPairs
            syncManager.appState.launchAtLogin = config.launchAtLogin
            syncManager.appState.unisonPath = config.unisonPath
            syncManager.appState.globalExclusions = config.globalExclusions
            L10n.shared.language = config.language
            syncManager.appState.saveToDisk()

            showToast(l["generalImportSuccess"], isError: false)
        } catch {
            showToast(l["generalImportFail"], isError: true)
        }
    }

    private func showToast(_ msg: String, isError: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            toastMessage = msg
            toastIsError = isError
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.3)) { toastMessage = nil }
        }
    }

    // MARK: - 卡片容器

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.rounded(14, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}
