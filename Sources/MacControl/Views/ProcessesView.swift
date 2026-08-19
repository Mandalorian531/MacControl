import MacControlCore
import SwiftUI

struct ProcessesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(L10n.processes)
                    .font(TypeScale.display)
                Spacer()
                Text("\(model.filteredProcesses.count) \(L10n.processCount)")
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                TextField(L10n.search, text: $model.processQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Toggle(L10n.hideApple, isOn: $model.preferences.hideApple)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            table
            actions
        }
        .padding(Spacing.lg)
        .confirmationDialog(L10n.confirmQuit, isPresented: Binding(
            get: { model.pendingQuit != nil },
            set: { if !$0 { model.pendingQuit = nil } }
        )) {
            Button(L10n.quitProcess, role: .destructive) {
                if let pendingQuit = model.pendingQuit {
                    model.quitProcess(pendingQuit, force: false)
                }
                model.pendingQuit = nil
            }
            Button(L10n.cancel, role: .cancel) { model.pendingQuit = nil }
        }
        .confirmationDialog(L10n.confirmForce, isPresented: Binding(
            get: { model.pendingForce != nil },
            set: { if !$0 { model.pendingForce = nil } }
        )) {
            Button(L10n.forceQuit, role: .destructive) {
                if let pendingForce = model.pendingForce {
                    model.quitProcess(pendingForce, force: true)
                }
                model.pendingForce = nil
            }
            Button(L10n.cancel, role: .cancel) { model.pendingForce = nil }
        }
    }

    private var table: some View {
        Table(model.filteredProcesses, selection: $model.selectedProcessID) {
            TableColumn(L10n.name) { process in
                HStack(spacing: 8) {
                    Image(nsImage: ProcessMonitor.icon(for: process.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(process.name)
                        .font(TypeScale.body)
                        .lineLimit(1)
                        .help(process.path.isEmpty ? process.name : process.path)
                }
            }
            .width(min: 180, ideal: 260)
            TableColumn(L10n.pid) { process in
                Text("\(process.pid)")
                    .font(TypeScale.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
            }
            .width(60)
            TableColumn(L10n.cpuShort) { process in
                Text(Formatters.percent1(process.cpu))
                    .font(TypeScale.body)
                    .monospacedDigit()
                    .foregroundStyle(UsageTone(ratio: process.cpu / 100, warnAt: 0.4, criticalAt: 0.8).color)
            }
            .width(70)
            TableColumn(L10n.ramShort) { process in
                Text(Formatters.bytes(process.memory))
                    .font(TypeScale.body)
                    .monospacedDigit()
            }
            .width(80)
            TableColumn(L10n.threads) { process in
                Text("\(process.threadCount)")
                    .font(TypeScale.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
            }
            .width(70)
        }
        .contextMenu(forSelectionType: ProcessSnapshot.ID.self) { ids in
            if let process = selected(from: ids) {
                Button(L10n.copyPath) { model.copyPath(process) }
                Button(L10n.reveal) { model.reveal(process) }
                Divider()
                Button(L10n.quitProcess) { model.pendingQuit = process }
                Button(L10n.forceQuit) { model.pendingForce = process }
            }
        }
    }

    private var actions: some View {
        HStack {
            Picker(L10n.cpuShort, selection: $model.processSort) {
                Text(L10n.cpuShort).tag(AppModel.ProcessSort.cpu)
                Text(L10n.ramShort).tag(AppModel.ProcessSort.memory)
                Text(L10n.name).tag(AppModel.ProcessSort.name)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            Button(L10n.activityMonitor) {
                model.openActivityMonitor()
            }
            Spacer()
            if let process = selectedProcess {
                Button(L10n.copyPath) { model.copyPath(process) }
                Button(L10n.reveal) { model.reveal(process) }
                Button(L10n.quitProcess) { model.pendingQuit = process }
                Button(L10n.forceQuit, role: .destructive) { model.pendingForce = process }
            }
        }
    }

    private var selectedProcess: ProcessSnapshot? {
        guard let id = model.selectedProcessID else { return nil }
        return model.filteredProcesses.first { $0.id == id }
    }

    private func selected(from ids: Set<ProcessSnapshot.ID>) -> ProcessSnapshot? {
        guard let id = ids.first else { return nil }
        return model.filteredProcesses.first { $0.id == id }
    }
}
