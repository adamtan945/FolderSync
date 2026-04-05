import SwiftUI

// MARK: - 同步日誌視圖

struct SyncLogView: View {
    let logEntries: [SyncLogEntry]
    let onClearLogs: () -> Void

    @State private var searchText = ""
    @State private var showErrorsOnly = false
    private var l: L10n { L10n.shared }

    private var filteredEntries: [SyncLogEntry] {
        var entries = logEntries.reversed() as [SyncLogEntry]
        if showErrorsOnly {
            entries = entries.filter(\.isError)
        }
        if !searchText.isEmpty {
            entries = entries.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.pairName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return Array(entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                Text(l["logTitle"])
                    .font(.rounded(20, weight: .semibold))
                Spacer()
                Toggle(isOn: $showErrorsOnly) {
                    Label(l["logErrorsOnly"], systemImage: "exclamationmark.triangle")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .controlSize(.small)

                Button(l["logClearAll"], action: onClearLogs)
                    .controlSize(.small)
                    .disabled(logEntries.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // 搜尋列
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField(l["logSearch"], text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(logEntries.isEmpty ? l["logEmpty"] : l["logNoMatch"])
                        .font(.rounded(14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            logRow(entry)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func logRow(_ entry: SyncLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing) {
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.mono(10))
                    .foregroundStyle(.tertiary)
                Text(entry.timestamp, format: .dateTime.month().day())
                    .font(.mono(9))
                    .foregroundStyle(.quaternary)
            }
            .frame(width: 65, alignment: .trailing)

            Rectangle()
                .fill(entry.isError ? Theme.error : Theme.success)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.pairName)
                        .font(.rounded(12, weight: .medium))
                    if entry.filesChanged > 0 {
                        Text("\(entry.filesChanged) \(l["logFiles"])")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.secondary.opacity(0.12)))
                    }
                }
                Text(entry.message)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isError ? Theme.error : .secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}
