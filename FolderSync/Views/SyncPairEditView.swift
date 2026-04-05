import SwiftUI

// MARK: - 新增 / 編輯同步配對 Sheet

struct SyncPairEditView: View {
    @State private var pair: SyncPair
    let isNew: Bool
    let onSave: (SyncPair) -> Void
    let onCancel: () -> Void

    @State private var newExclusion: String = ""
    @State private var sourceDropHighlight = false
    @State private var destDropHighlight = false
    private var l: L10n { L10n.shared }

    init(
        existingPair: SyncPair? = nil,
        isNew: Bool,
        onSave: @escaping (SyncPair) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _pair = State(initialValue: existingPair ?? SyncPair())
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題
            HStack {
                Text(isNew ? l["editTitleNew"] : l["editTitleEdit"])
                    .font(.rounded(18, weight: .semibold))
                Spacer()
                Button(l["cancel"]) { onCancel() }
                    .keyboardShortcut(.escape)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    formSection(l["editName"]) {
                        TextField(l["editNamePlaceholder"], text: $pair.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    formSection(l["editSourcePath"]) {
                        pathPicker(
                            path: $pair.sourcePath,
                            placeholder: l["editSourcePlaceholder"],
                            isDropHighlighted: $sourceDropHighlight
                        )
                    }

                    formSection(l["editDirection"]) {
                        directionPicker
                    }

                    formSection(l["editDestPath"]) {
                        pathPicker(
                            path: $pair.destinationPath,
                            placeholder: l["editDestPlaceholder"],
                            isDropHighlighted: $destDropHighlight
                        )
                    }

                    formSection(l["editExclusions"]) {
                        exclusionEditor
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button(l["cancel"]) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(isNew ? l["editAdd"] : l["editSave"]) {
                    onSave(pair)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .frame(width: 520, height: 650)
    }

    private var isValid: Bool {
        !pair.sourcePath.isEmpty && !pair.destinationPath.isEmpty
    }

    // MARK: - 方向選取器（圖示）

    private var directionPicker: some View {
        HStack(spacing: 12) {
            ForEach(SyncDirection.allCases, id: \.self) { direction in
                directionOption(direction)
            }
        }
    }

    private func directionOption(_ direction: SyncDirection) -> some View {
        let isSelected = pair.direction == direction
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { pair.direction = direction }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: direction.symbolName)
                    .font(.system(size: 22, weight: .medium))
                Text(direction.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.primary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Theme.primary : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .foregroundStyle(isSelected ? Theme.primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 路徑選取器

    private func pathPicker(
        path: Binding<String>,
        placeholder: String,
        isDropHighlighted: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: path)
                .font(.mono(12))
                .textFieldStyle(.roundedBorder)
                .onDrop(of: [.fileURL], isTargeted: isDropHighlighted) { providers in
                    handleDrop(providers: providers, path: path)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Theme.primary.opacity(isDropHighlighted.wrappedValue ? 0.5 : 0),
                            lineWidth: 2
                        )
                )

            Button(l["editBrowse"]) {
                pickFolder(path: path)
            }
            .controlSize(.small)
        }
    }

    private func pickFolder(path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = l["editBrowse"]
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path(percentEncoded: false)
        }
    }

    private func handleDrop(providers: [NSItemProvider], path: Binding<String>) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               url.hasDirectoryPath {
                DispatchQueue.main.async {
                    path.wrappedValue = url.path(percentEncoded: false)
                }
            }
        }
        return true
    }

    // MARK: - 排除規則（預設選項 + 自訂）

    @State private var showPresets = false

    private var exclusionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 已選擇的排除項目
            if !pair.exclusions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(pair.exclusions, id: \.self) { exc in
                        HStack(spacing: 4) {
                            Text(exc).font(.mono(11))
                            Button {
                                withAnimation { pair.exclusions.removeAll { $0 == exc } }
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

            // 常見排除項目（可展開）
            DisclosureGroup(isExpanded: $showPresets) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ExclusionCategory.allCases, id: \.self) { category in
                        let presets = exclusionPresets.filter { $0.category == category }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.localizedName)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)

                            FlowLayout(spacing: 6) {
                                ForEach(presets) { preset in
                                    presetButton(preset)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text(l["editExclusionPresets"])
                    .font(.rounded(12, weight: .medium))
            }

            // 自訂輸入
            HStack {
                TextField(l["editExclusionPlaceholder"], text: $newExclusion)
                    .textFieldStyle(.roundedBorder)
                    .font(.mono(12))
                    .onSubmit { addExclusion() }

                Button(action: addExclusion) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.borderless)
                .disabled(newExclusion.isEmpty)
            }
        }
    }

    /// 預設排除項目按鈕（已加入的顯示打勾）
    private func presetButton(_ preset: ExclusionPreset) -> some View {
        let isAdded = pair.exclusions.contains(preset.pattern)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isAdded {
                    pair.exclusions.removeAll { $0 == preset.pattern }
                } else {
                    pair.exclusions.append(preset.pattern)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if isAdded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(preset.pattern)
                    .font(.mono(11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isAdded ? Theme.primary.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(isAdded ? Theme.primary : .secondary)
        }
        .buttonStyle(.plain)
        .help(preset.localizedDescription)
    }

    private func addExclusion() {
        let trimmed = newExclusion.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !pair.exclusions.contains(trimmed) else { return }
        pair.exclusions.append(trimmed)
        newExclusion = ""
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rounded(13, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}
