import MacControlCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(L10n.interval) {
                Picker(L10n.interval, selection: $model.preferences.pace) {
                    ForEach(RefreshPace.allCases) { pace in
                        Text("\(pace.title) · \(String(format: "%.0f s", pace.seconds))").tag(pace)
                    }
                }
                .pickerStyle(.inline)
                Toggle(L10n.pause, isOn: $model.preferences.paused)
                Text(L10n.samplingHint)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
            }
            Section(L10n.menuBar) {
                Toggle(L10n.showCPU, isOn: $model.preferences.menuCPU)
                Toggle(L10n.showRAM, isOn: $model.preferences.menuRAM)
                Toggle(L10n.showTemp, isOn: $model.preferences.menuTemp)
                Toggle(L10n.showFan, isOn: $model.preferences.menuFan)
                if model.host.battery.present {
                    Toggle(L10n.showBattery, isOn: $model.preferences.menuBattery)
                }
            }
            Section(L10n.processes) {
                Toggle(L10n.hideApple, isOn: $model.preferences.hideApple)
                Button(L10n.activityMonitor) {
                    model.openActivityMonitor()
                }
            }
            Section(L10n.appName) {
                Toggle(L10n.alwaysOnTop, isOn: $model.preferences.alwaysOnTop)
                Toggle(L10n.launchAtLogin, isOn: $model.preferences.launchAtLogin)
                Button(L10n.resetPeaks) {
                    model.resetPeaks()
                }
            }
            Section(L10n.privacy) {
                Text(L10n.privacyNote)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
            }
            Section(L10n.about) {
                LabeledContent(L10n.name, value: model.machine.hostname)
                LabeledContent(L10n.model, value: "\(model.machine.family.title) · \(model.machine.modelID)")
                LabeledContent(L10n.soc, value: "\(model.machine.chip) · \(model.machine.coreSummary)")
                LabeledContent(L10n.memory, value: Formatters.bytes(model.machine.memory))
                LabeledContent("macOS", value: model.machine.osVersion)
                LabeledContent(
                    L10n.selfUsage,
                    value: "\(Formatters.percent1(model.selfUsage.cpu)) · \(Formatters.bytes(model.selfUsage.memory))"
                )
            }
        }
        .formStyle(.grouped)
        .padding(.top, Spacing.sm)
    }
}
