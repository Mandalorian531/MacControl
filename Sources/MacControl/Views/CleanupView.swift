import AppKit
import MacControlCore
import SwiftUI

struct CleanupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            content
            actions
        }
        .padding(Spacing.lg)
        .confirmationDialog(junkConfirmTitle, isPresented: $model.pendingJunkTrash) {
            Button(L10n.moveToTrash, role: .destructive) {
                model.trashSelectedJunk()
                model.pendingJunkTrash = false
            }
            Button(L10n.cancel, role: .cancel) { model.pendingJunkTrash = false }
        }
        .confirmationDialog(L10n.confirmEmptyTrash, isPresented: $model.pendingEmptyTrash) {
            Button(L10n.emptyTrash, role: .destructive) {
                model.emptyUserTrash()
                model.pendingEmptyTrash = false
            }
            Button(L10n.cancel, role: .cancel) { model.pendingEmptyTrash = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.cleanup)
                    .font(TypeScale.display)
                Spacer()
                if model.junkTotalSize > 0 {
                    Text("\(L10n.foundSpace) \(Formatters.bytes(model.junkTotalSize))")
                        .font(TypeScale.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.muted)
                }
                Button(model.junkCategories.isEmpty ? L10n.scanJunk : L10n.refresh) {
                    model.scanJunk()
                }
                .disabled(model.junkLoading)
            }
            Text(L10n.cleanupHint)
                .font(TypeScale.caption)
                .foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.junkLoading && model.junkCategories.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Text(L10n.scanningJunk)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if model.filteredJunkCategories.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Text(L10n.noJunk)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button(L10n.scanJunk) { model.scanJunk() }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(model.filteredJunkCategories) { category in
                        categoryCard(category)
                    }
                }
            }
        }
    }

    private func categoryCard(_ category: JunkCategory) -> some View {
        let expanded = model.expandedCategories.contains(category.id)
        return Panel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    if category.kind != .trash {
                        Toggle("", isOn: Binding(
                            get: { categorySelected(category) },
                            set: { model.toggleJunkCategory(category, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .padding(.top, 2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(category.kind.title)
                                .font(TypeScale.headline)
                            if let risk = categoryRisk(category) {
                                Text(risk.title)
                                    .font(TypeScale.micro)
                                    .foregroundStyle(risk == .critical ? Palette.danger : Palette.warning)
                            }
                        }
                        Text(category.kind.summary)
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Formatters.bytes(category.size))
                            .font(TypeScale.headline)
                            .monospacedDigit()
                        Text("\(category.fileCount) \(L10n.filesCount)")
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    if category.kind == .trash {
                        Button(L10n.emptyTrash, role: .destructive) {
                            model.pendingEmptyTrash = true
                        }
                        .controlSize(.small)
                    }
                }
                Button {
                    if expanded {
                        model.expandedCategories.remove(category.id)
                    } else {
                        model.expandedCategories.insert(category.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(TypeScale.micro)
                        Text(expanded ? L10n.hideDetails : L10n.showDetails)
                            .font(TypeScale.caption)
                    }
                    .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                if expanded {
                    ForEach(category.items) { node in
                        JunkNodeRow(model: model, node: node, depth: 0)
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            if model.selectedJunkRisk == .critical {
                Text(L10n.selectedCriticalHint)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.danger)
            } else if model.selectedJunkRisk == .caution {
                Text(L10n.selectedCautionHint)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.warning)
            } else if model.selectedJunkSize > 0 {
                Text("\(L10n.selected) · \(Formatters.bytes(model.selectedJunkSize))")
                    .font(TypeScale.body)
                    .monospacedDigit()
            }
            Spacer()
            if let status = model.junkStatus {
                Text(status)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.success)
            }
            Button(L10n.moveToTrash) {
                model.pendingJunkTrash = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selectedJunk.isEmpty)
        }
    }

    private var junkConfirmTitle: String {
        switch model.selectedJunkRisk {
        case .critical: L10n.confirmJunkCritical
        case .caution: L10n.confirmJunkCaution
        case .safe: L10n.confirmJunk
        }
    }

    private func categorySelected(_ category: JunkCategory) -> Bool {
        let rows = category.items.filter { $0.kind != .trash && $0.risk != .critical }
        guard !rows.isEmpty else { return false }
        return rows.allSatisfy { model.selectedJunk.contains($0.path) }
    }

    private func categoryRisk(_ category: JunkCategory) -> JunkRisk? {
        let highest = category.items.map(\.risk).max() ?? .safe
        return highest == .safe ? nil : highest
    }
}

struct JunkNodeRow: View {
    @ObservedObject var model: AppModel
    let node: JunkNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row
            if node.isDirectory, model.expandedJunk.contains(node.path) {
                children
            }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            if node.kind != .trash {
                Toggle("", isOn: Binding(
                    get: { model.isJunkSelected(node.path) },
                    set: { model.setJunkSelected(node.path, $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(model.isJunkSelectionLocked(node.path))
            }
            if node.isDirectory, depth < 10 {
                Button {
                    model.setJunkExpanded(node.path, !model.expandedJunk.contains(node.path), node: node)
                } label: {
                    Image(systemName: model.expandedJunk.contains(node.path) ? "chevron.down" : "chevron.right")
                        .font(TypeScale.micro)
                        .foregroundStyle(Palette.muted)
                        .frame(width: 10)
                }
                .buttonStyle(.plain)
                .help(L10n.expandFolder)
            } else {
                Color.clear.frame(width: 10)
            }
            Text(node.name)
                .font(TypeScale.body)
                .lineLimit(1)
                .help(node.path)
            if node.risk != .safe {
                Text(node.risk.title)
                    .font(TypeScale.micro)
                    .foregroundStyle(node.risk == .critical ? Palette.danger : Palette.warning)
            } else if node.isHidden {
                Text(L10n.hiddenBadge)
                    .font(TypeScale.micro)
                    .foregroundStyle(Palette.warning)
            }
            Spacer()
            Text(Formatters.bytes(node.size))
                .font(TypeScale.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
        }
        .padding(.leading, CGFloat(depth) * 14)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.revealJunk(node.path)
        }
        .contextMenu {
            Button(L10n.reveal) { model.revealJunk(node.path) }
        }
    }

    private var children: some View {
        Group {
            if model.junkLoadingPaths.contains(node.path) {
                Text(L10n.scanning)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, CGFloat(depth + 1) * 14 + 36)
            } else if let listing = model.junkChildren[node.path] {
                ForEach(listing.items) { child in
                    JunkNodeRow(model: model, node: child, depth: depth + 1)
                }
                if listing.truncated {
                    Text("\(L10n.truncated) · \(listing.totalCount) \(L10n.filesCount)")
                        .font(TypeScale.caption)
                        .foregroundStyle(Palette.muted)
                        .padding(.leading, CGFloat(depth + 1) * 14 + 36)
                }
            }
        }
    }
}
