import SwiftUI

// MARK: - 同步配對列表視圖

struct SyncPairsListView: View {
    let syncManager: SyncManager

    @State private var showAddSheet = false
    @State private var editingPair: SyncPair?
    private var l: L10n { L10n.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 標題列
                HStack {
                    Text(l["syncPairsTitle"])
                        .font(.rounded(20, weight: .semibold))
                    Spacer()
                    if syncManager.appState.unisonInstalled {
                        Label(l["unisonReady"], systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                    } else {
                        Label(l["unisonMissing"], systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // 配對卡片列表
                if syncManager.appState.syncPairs.isEmpty {
                    emptyStateView
                } else {
                    ForEach(syncManager.appState.syncPairs) { pair in
                        SyncPairRow(
                            pair: pair,
                            status: syncManager.appState.status(for: pair.id),
                            lastSyncText: syncManager.appState.lastSyncText(for: pair),
                            onToggle: { syncManager.togglePair(id: pair.id) },
                            onEdit: { editingPair = pair },
                            onDelete: { syncManager.deletePair(id: pair.id) },
                            onSync: { Task { await syncManager.triggerSync(for: pair) } }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // 新增按鈕
                Button(action: { showAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text(l["syncPairsAdd"])
                    }
                    .font(.rounded(14))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .foregroundStyle(Theme.primary.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            SyncPairEditView(
                isNew: true,
                onSave: { pair in
                    syncManager.addPair(pair)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(item: $editingPair) { pair in
            SyncPairEditView(
                existingPair: pair,
                isNew: false,
                onSave: { updated in
                    syncManager.updatePair(updated)
                    editingPair = nil
                },
                onCancel: { editingPair = nil }
            )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: syncManager.appState.syncPairs)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(l["syncPairsEmpty"])
                .font(.rounded(16))
                .foregroundStyle(.secondary)
            Text(l["syncPairsEmptyHint"])
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
