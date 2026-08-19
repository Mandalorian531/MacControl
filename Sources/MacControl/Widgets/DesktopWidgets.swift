import AppKit
import CoreGraphics
import MacControlCore
import SwiftUI

enum DesktopWidgetKind: String, CaseIterable, Identifiable {
    case cpu
    case memory
    case temperature
    case fan
    case battery
    case disk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: L10n.cpu
        case .memory: L10n.memory
        case .temperature: L10n.temperatures
        case .fan: L10n.fan
        case .battery: L10n.battery
        case .disk: L10n.disk
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .temperature: "thermometer.medium"
        case .fan: "fan"
        case .battery: "battery.100"
        case .disk: "internaldrive"
        }
    }
}

@MainActor
final class DesktopWidgetController {
    private weak var model: AppModel?
    private var windows: [DesktopWidgetKind: DesktopWidgetWindow] = [:]

    func attach(_ model: AppModel) {
        self.model = model
        sync()
    }

    func sync() {
        guard let model else { return }
        for kind in DesktopWidgetKind.allCases {
            if isEnabled(kind, model: model) {
                show(kind, model: model)
            } else {
                hide(kind)
            }
        }
    }

    func resetPositions() {
        model?.preferences.clearWidgetFrames()
        for (kind, window) in windows {
            window.setFrame(Self.defaultFrame(kind), display: true)
            model?.preferences.setWidgetFrame(window.frame, kind: kind.rawValue)
        }
    }

    func hide(_ kind: DesktopWidgetKind) {
        windows[kind]?.orderOut(nil)
        windows[kind]?.close()
        windows[kind] = nil
    }

    private func isEnabled(_ kind: DesktopWidgetKind, model: AppModel) -> Bool {
        let prefs = model.preferences
        guard prefs.desktopWidgets else { return false }
        switch kind {
        case .cpu: return prefs.widgetCPU
        case .memory: return prefs.widgetRAM
        case .temperature: return prefs.widgetTemp
        case .fan: return prefs.widgetFan && model.fan.available
        case .battery: return prefs.widgetBattery && model.host.battery.present
        case .disk: return prefs.widgetDisk
        }
    }

    private func show(_ kind: DesktopWidgetKind, model: AppModel) {
        if let existing = windows[kind] {
            existing.orderFrontRegardless()
            return
        }
        let window = DesktopWidgetWindow(kind: kind)
        window.setFrame(storedFrame(kind) ?? Self.defaultFrame(kind), display: true)
        let host = NSHostingView(rootView: DesktopWidgetView(model: model, kind: kind))
        host.frame = NSRect(origin: .zero, size: window.frame.size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.onMoved = { [weak self, weak window] in
            guard let window else { return }
            self?.model?.preferences.setWidgetFrame(window.frame, kind: kind.rawValue)
        }
        window.orderFrontRegardless()
        windows[kind] = window
    }

    private func storedFrame(_ kind: DesktopWidgetKind) -> NSRect? {
        guard var frame = model?.preferences.widgetFrame(kind.rawValue) else { return nil }
        let screens = NSScreen.screens.map(\.visibleFrame)
        let visible = screens.contains { $0.intersects(frame) }
        if !visible {
            return nil
        }
        frame.size = NSSize(width: Layout.widgetWidth, height: Layout.widgetHeight)
        return frame
    }

    static func defaultFrame(_ kind: DesktopWidgetKind) -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let index = DesktopWidgetKind.allCases.firstIndex(of: kind) ?? 0
        let x = screen.maxX - Layout.widgetWidth - 24
        let y = screen.maxY - Layout.widgetHeight - 24 - CGFloat(index) * (Layout.widgetHeight + 10)
        return NSRect(x: x, y: y, width: Layout.widgetWidth, height: Layout.widgetHeight)
    }
}

private final class DesktopWidgetWindow: NSPanel {
    var onMoved: (() -> Void)?

    convenience init(kind: DesktopWidgetKind) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: Layout.widgetWidth, height: Layout.widgetHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        identifier = NSUserInterfaceItemIdentifier("widget.\(kind.rawValue)")
        isFloatingPanel = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        appearance = nil
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(moved),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @objc private func moved() {
        onMoved?()
    }
}

struct DesktopWidgetView: View {
    @ObservedObject var model: AppModel
    let kind: DesktopWidgetKind

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(TypeScale.caption)
                    .foregroundStyle(tone)
                Text(kind.title)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            Text(value)
                .font(TypeScale.headline)
                .foregroundStyle(tone)
                .monospacedDigit()
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail)
                    .font(TypeScale.micro)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            UsageBar(ratio: ratio, tone: tone)
        }
        .padding(Spacing.sm)
        .frame(width: Layout.widgetWidth, height: Layout.widgetHeight, alignment: .topLeading)
        .background(Palette.widgetCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.widgetStroke, lineWidth: 1)
        )
        .onTapGesture(count: 2) {
            model.showMainWindow()
        }
        .contextMenu {
            Button(L10n.hideWidget) { model.hideDesktopWidget(kind) }
            Button(L10n.openWindow) { model.showMainWindow() }
        }
    }

    private var value: String {
        switch kind {
        case .cpu: Formatters.percent(model.host.cpu.total)
        case .memory: Formatters.percent(model.host.memory.usedRatio * 100)
        case .temperature: Formatters.celsius(model.thermal.soc ?? model.thermal.hottest?.celsius ?? 0)
        case .fan: model.fan.available ? Formatters.rpm(model.fan.rpm) : "—"
        case .battery: Formatters.percent(model.host.battery.percent)
        case .disk: Formatters.percent(model.host.disk.usedRatio * 100)
        }
    }

    private var detail: String {
        switch kind {
        case .cpu:
            "\(L10n.pCores) \(Formatters.percent(model.host.cpu.performance))  \(L10n.eCores) \(Formatters.percent(model.host.cpu.efficiency))"
        case .memory:
            "\(Formatters.bytes(model.host.memory.used))  \(L10n.pressure) \(Formatters.percent(model.host.memory.pressure * 100))"
        case .temperature:
            model.thermal.storage.map { "SSD \(Formatters.celsius($0))" } ?? ""
        case .fan:
            model.fan.isManual ? L10n.manual : L10n.auto
        case .battery:
            model.host.battery.isCharging ? L10n.charging : (model.host.battery.isAC ? L10n.onAC : L10n.onBattery)
        case .disk:
            "\(Formatters.bytes(model.host.disk.free)) \(L10n.free)"
        }
    }

    private var ratio: Double {
        switch kind {
        case .cpu: min(model.host.cpu.total / 100, 1)
        case .memory: model.host.memory.usedRatio
        case .temperature: min((model.thermal.soc ?? model.thermal.hottest?.celsius ?? 0) / 100, 1)
        case .fan: model.fan.ratio
        case .battery: model.host.battery.percent / 100
        case .disk: model.host.disk.usedRatio
        }
    }

    private var tone: Color {
        switch kind {
        case .cpu: UsageTone(ratio: ratio).color
        case .memory: UsageTone(ratio: ratio).color
        case .temperature: TemperatureTone.color(celsius: (model.thermal.soc ?? model.thermal.hottest?.celsius ?? 0))
        case .fan: model.fan.isManual ? Palette.warning : Palette.accent
        case .battery: UsageTone(ratio: 1 - ratio, warnAt: 0.70, criticalAt: 0.90).color
        case .disk: UsageTone(ratio: ratio).color
        }
    }
}
