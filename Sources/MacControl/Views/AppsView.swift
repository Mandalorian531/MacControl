import AppKit
import MacControlCore
import SwiftUI

struct AppsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            table
            leftovers
            actions
        }
        .padding(Spacing.lg)
        .confirmationDialog(L10n.confirmUninstall, isPresented: Binding(
            get: { model.pendingUninstall != nil },
            set: { if !$0 { model.pendingUninstall = nil } }
        )) {
            Button(L10n.uninstall, role: .destructive) {
                model.uninstallSelected()
                model.pendingUninstall = nil
            }
            Button(L10n.cancel, role: .cancel) { model.pendingUninstall = nil }
        }
        .confirmationDialog(L10n.confirmResidues, isPresented: $model.pendingResidues) {
            Button(L10n.removeResidues, role: .destructive) {
                model.removeResiduesOnly()
                model.pendingResidues = false
            }
            Button(L10n.cancel, role: .cancel) { model.pendingResidues = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(L10n.apps)
                    .font(TypeScale.display)
                Spacer()
                Text("\(model.filteredApps.count)")
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                TextField(L10n.search, text: $model.appQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Toggle(L10n.hideSystem, isOn: $model.hideSystemApps)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                Button(L10n.verify) {
                    model.refreshApps()
                }
            }
            Text(L10n.leftoversHint)
                .font(TypeScale.caption)
                .foregroundStyle(Palette.muted)
        }
    }

    private var table: some View {
        Table(model.filteredApps, selection: $model.selectedAppID) {
            TableColumn(L10n.name) { app in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                            .font(TypeScale.body)
                            .lineLimit(1)
                        Text(app.bundleID)
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 180, ideal: 260)
            TableColumn(L10n.version) { app in
                Text(app.version.isEmpty ? "—" : app.version)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
            }
            .width(70)
            TableColumn(L10n.size) { app in
                Text(Formatters.bytes(app.size))
                    .font(TypeScale.body)
                    .monospacedDigit()
            }
            .width(80)
            TableColumn(L10n.signature) { app in
                Text(app.signature.title)
                    .font(TypeScale.caption)
                    .foregroundStyle(signatureColor(app.signature))
            }
            .width(80)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let app = model.installedApps.first(where: { ids.contains($0.id) }) {
                Button(L10n.reveal) { model.revealApp(app) }
                if !app.isSystem {
                    Button(L10n.uninstall) { model.pendingUninstall = app }
                }
            }
        }
    }

    private var leftovers: some View {
        Panel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(L10n.leftovers)
                        .font(TypeScale.headline)
                    Spacer()
                    if model.residuesLoading {
                        Text(L10n.scanning)
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                    } else if model.leftoverSize > 0 {
                        Text(Formatters.bytes(model.leftoverSize))
                            .font(TypeScale.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                    }
                }
                if model.selectedApp != nil {
                    if model.residues.isEmpty, !model.residuesLoading {
                        Text(L10n.noResidues)
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                    } else {
                        ForEach(model.residues.prefix(12)) { item in
                            HStack {
                                Text(item.kind.title)
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 88, alignment: .leading)
                                Text(item.path)
                                    .font(TypeScale.caption)
                                    .lineLimit(1)
                                    .help(item.path)
                                Spacer()
                                Text(Formatters.bytes(item.size))
                                    .font(TypeScale.caption)
                                    .monospacedDigit()
                            }
                            .onTapGesture(count: 2) {
                                model.revealResidue(item)
                            }
                        }
                    }
                } else {
                    Text(L10n.selectApp)
                        .font(TypeScale.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            if let app = model.selectedApp {
                Button(L10n.reveal) { model.revealApp(app) }
                Button(L10n.removeResidues) {
                    model.pendingResidues = true
                }
                .disabled(model.residues.filter { $0.kind != .application }.isEmpty)
                Button(L10n.uninstall, role: .destructive) {
                    model.pendingUninstall = app
                }
                .disabled(app.isSystem)
            }
            Spacer()
            if let status = model.janitorStatus {
                Text(status)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.success)
            }
        }
    }

    private func signatureColor(_ status: SignatureStatus) -> Color {
        switch status {
        case .valid: Palette.success
        case .invalid: Palette.danger
        case .unsigned: Palette.warning
        case .unknown: Palette.muted
        }
    }
}
