import Combine
import MacControlCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case temperatures
    case fan
    case processes
    case apps
    case cleanup
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: L10n.dashboard
        case .temperatures: L10n.temperatures
        case .fan: L10n.fan
        case .processes: L10n.processes
        case .apps: L10n.apps
        case .cleanup: L10n.cleanup
        case .settings: L10n.settings
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .temperatures: "thermometer.medium"
        case .fan: "fan"
        case .processes: "list.bullet.rectangle"
        case .apps: "app.badge.checkmark"
        case .cleanup: "trash"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.section) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 220)
            .listStyle(.sidebar)
            .listItemTint(Palette.accent)
            .safeAreaInset(edge: .bottom) {
                sidebarFooter
            }
        } detail: {
            switch model.section {
            case .dashboard:
                DashboardView(model: model)
            case .temperatures:
                TemperaturesView(model: model)
            case .fan:
                FanView(model: model)
            case .processes:
                ProcessesView(model: model)
            case .apps:
                AppsView(model: model)
            case .cleanup:
                CleanupView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .navigationTitle(model.section.title)
        .background(Palette.background)
        .background(WindowVisibility(onChange: model.setWindowVisible))
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.machine.family.title)
            Text(model.machine.chip)
            Text(model.machine.coreSummary)
            Text("\(Formatters.percent1(model.selfUsage.cpu)) · \(Formatters.bytes(model.selfUsage.memory))")
                .help(L10n.selfUsage)
            if model.preferences.paused {
                Text(L10n.paused)
                    .foregroundStyle(Palette.warning)
            }
        }
        .font(TypeScale.caption)
        .foregroundStyle(Palette.muted)
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.menuBarText)
            .monospacedDigit()
    }
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(L10n.openWindow) { showMain() }
        Button(model.preferences.paused ? L10n.resume : L10n.pause) {
            model.togglePause()
        }
        Divider()
        Button(L10n.dashboard) { openSection(.dashboard) }
        Button(L10n.temperatures) { openSection(.temperatures) }
        Button(L10n.fan) { openSection(.fan) }
        Button(L10n.processes) { openSection(.processes) }
        Button(L10n.apps) { openSection(.apps) }
        Button(L10n.cleanup) { openSection(.cleanup) }
        Button(L10n.settings) { openSection(.settings) }
        Divider()
        Button(L10n.quitApp) {
            NSApp.terminate(nil)
        }
    }

    private func openSection(_ section: AppSection) {
        model.section = section
        showMain()
    }

    private func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == L10n.appName }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        AppModel.applyAlwaysOnTop(model.preferences.alwaysOnTop)
    }
}

private struct WindowVisibility: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        VisibilityView(onChange: onChange)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? VisibilityView {
            view.onChange = onChange
        }
    }
}

private final class VisibilityView: NSView {
    var onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        publish()
        guard let window else { return }
        let names: [Notification.Name] = [
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didChangeOcclusionStateNotification
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowChanged),
                name: name,
                object: window
            )
        }
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        publish()
    }

    override func viewDidHide() {
        super.viewDidHide()
        publish()
    }

    @objc private func windowChanged(_ notification: Notification) {
        publish()
    }

    private func publish() {
        let visible = window?.isVisible == true
            && window?.isMiniaturized == false
            && window?.occlusionState.contains(.visible) == true
        onChange(visible)
    }
}
