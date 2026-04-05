import SwiftUI

// MARK: - 同步配對卡片

struct SyncPairRow: View {
    let pair: SyncPair
    let status: SyncStatus
    let lastSyncText: String
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSync: () -> Void

    @State private var showDeleteConfirm = false
    @State private var completionBounce = false
    private var l: L10n { L10n.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題列
            HStack {
                statusDot
                Text(pair.name.isEmpty ? l["syncPairUntitled"] : pair.name)
                    .font(.rounded(15, weight: .semibold))
                Spacer()
                statusBadge
                Toggle("", isOn: Binding(
                    get: { pair.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // 路徑區塊
            HStack(alignment: .center, spacing: 12) {
                pathLabel(pair.shortSourcePath, icon: "folder.fill")
                directionArrow
                pathLabel(pair.shortDestinationPath, icon: "folder.fill")
            }

            // 底部
            HStack {
                Label(pair.direction.displayName, systemImage: pair.direction.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·").foregroundStyle(.tertiary)

                Text("\(l["syncPairLastSync"])：\(lastSyncText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !pair.exclusions.isEmpty {
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(l["syncPairExclusions"]) \(pair.exclusions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    actionButton(
                        icon: "arrow.triangle.2.circlepath",
                        color: Theme.primary,
                        action: onSync
                    )
                    .disabled(status == .syncing)

                    actionButton(
                        icon: "pencil",
                        color: .secondary,
                        action: onEdit
                    )

                    actionButton(
                        icon: "trash",
                        color: Theme.error,
                        action: { showDeleteConfirm = true }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Theme.color(for: status).opacity(status == .syncing ? 0.4 : 0),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 20)
        .alert(l["syncPairDeleteTitle"], isPresented: $showDeleteConfirm) {
            Button(l["cancel"], role: .cancel) {}
            Button(l["syncPairDeleteConfirm"], role: .destructive) { onDelete() }
        } message: {
            Text(l["syncPairDeleteMessage"])
        }
    }

    // MARK: - 子元件

    private var statusDot: some View {
        Circle()
            .fill(Theme.color(for: status))
            .frame(width: 8, height: 8)
            .scaleEffect(completionBounce ? 1.5 : 1.0)
            .opacity(status == .syncing ? 0.6 : 1.0)
            .animation(
                status == .syncing
                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .spring(response: 0.3, dampingFraction: 0.5),
                value: status
            )
            .onChange(of: status) { oldValue, newValue in
                if oldValue == .syncing && (newValue == .idle || newValue == .watching) {
                    completionBounce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        completionBounce = false
                    }
                }
            }
    }

    private var statusBadge: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(Theme.color(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.color(for: status).opacity(0.12)))
    }

    @State private var arrowRotation: Double = 0

    private var directionArrow: some View {
        Image(systemName: pair.direction.symbolName)
            .font(.title3)
            .foregroundStyle(Theme.color(for: status))
            .rotationEffect(.degrees(arrowRotation))
            .onChange(of: status) { _, newValue in
                if newValue == .syncing {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        arrowRotation = 360
                    }
                } else {
                    withAnimation(.default) { arrowRotation = 0 }
                }
            }
    }

    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func pathLabel(_ path: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
            Text(path)
                .font(.mono(11))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
