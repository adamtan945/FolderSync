import SwiftUI
import ServiceManagement

// MARK: - 一般設定視圖

struct GeneralSettingsView: View {
    let syncManager: SyncManager
    private var l: L10n { L10n.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(l["generalTitle"])
                    .font(.rounded(20, weight: .semibold))
                    .padding(.top, 16)

                // 語言設定（最上方）
                settingsCard(l["generalLanguage"]) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l["generalLanguage"])
                                .font(.rounded(13))
                            Text(l["generalLanguageDesc"])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // 語言選取器（動態掃描）
                        Picker("", selection: Binding(
                            get: { L10n.shared.language },
                            set: { L10n.shared.language = $0 }
                        )) {
                            ForEach(L10n.shared.availableLanguages) { lang in
                                Text(lang.displayName).tag(lang.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()

                        // 重新掃描語系檔按鈕
                        Button {
                            L10n.shared.scanLanguages()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(l.language == "zh-TW" ? "重新載入語系檔" : "Reload language files")
                    }
                }

                // 啟動設定
                settingsCard(l["generalStartup"]) {
                    Toggle(isOn: Binding(
                        get: { syncManager.appState.launchAtLogin },
                        set: { syncManager.setLaunchAtLogin($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l["generalLaunchAtLogin"])
                                .font(.rounded(13))
                            Text(l["generalLaunchAtLoginDesc"])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                // Unison 設定
                settingsCard(l["generalUnison"]) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if syncManager.appState.unisonInstalled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.success)
                                Text(l["generalUnisonInstalled"])
                                    .font(.rounded(13))
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.error)
                                Text(l["generalUnisonNotInstalled"])
                                    .font(.rounded(13))
                            }
                            Spacer()
                            Button(l["generalUnisonRecheck"]) {
                                syncManager.checkUnisonInstalled()
                            }
                            .controlSize(.small)
                        }

                        HStack {
                            Text(l["generalUnisonPath"])
                                .font(.rounded(13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                            TextField("unison", text: Binding(
                                get: { syncManager.appState.unisonPath },
                                set: { syncManager.appState.unisonPath = $0 }
                            ))
                            .font(.mono(12))
                            .textFieldStyle(.roundedBorder)
                        }

                        if !syncManager.appState.unisonInstalled {
                            installHint
                        }
                    }
                }

                // 全域排除規則
                settingsCard(l["generalExclusions"]) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l["generalExclusionsDesc"])
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        globalExclusionEditor
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 安裝提示

    private var installHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l["generalUnisonInstallHint"])
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("brew install unison")
                    .font(.mono(13))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.textBackgroundColor))
                    )

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew install unison", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.warning.opacity(0.08))
        )
    }

    // MARK: - 全域排除編輯器

    @State private var newGlobalExclusion = ""

    private var globalExclusionEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !syncManager.appState.globalExclusions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(syncManager.appState.globalExclusions, id: \.self) { exc in
                        HStack(spacing: 4) {
                            Text(exc).font(.mono(11))
                            Button {
                                syncManager.appState.globalExclusions.removeAll { $0 == exc }
                                syncManager.appState.saveToDisk()
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.primary.opacity(0.12)))
                        .foregroundStyle(Theme.primary)
                    }
                }
            }

            HStack {
                TextField(l["generalExclusionsPlaceholder"], text: $newGlobalExclusion)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))
                    .onSubmit { addGlobalExclusion() }

                Button(action: addGlobalExclusion) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.primary)
                }
                .buttonStyle(.borderless)
                .disabled(newGlobalExclusion.isEmpty)
            }
        }
    }

    private func addGlobalExclusion() {
        let trimmed = newGlobalExclusion.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !syncManager.appState.globalExclusions.contains(trimmed) else { return }
        syncManager.appState.globalExclusions.append(trimmed)
        syncManager.appState.saveToDisk()
        newGlobalExclusion = ""
    }

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
