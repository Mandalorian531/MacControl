import AppKit
import Foundation
import MacControlCore
import ServiceManagement

final class Preferences: ObservableObject {
    @Published var pace: RefreshPace {
        didSet { defaults.set(pace.rawValue, forKey: Keys.pace) }
    }
    @Published var hideApple: Bool {
        didSet { defaults.set(hideApple, forKey: Keys.hideApple) }
    }
    @Published var menuCPU: Bool {
        didSet { defaults.set(menuCPU, forKey: Keys.menuCPU) }
    }
    @Published var menuRAM: Bool {
        didSet { defaults.set(menuRAM, forKey: Keys.menuRAM) }
    }
    @Published var menuTemp: Bool {
        didSet { defaults.set(menuTemp, forKey: Keys.menuTemp) }
    }
    @Published var menuFan: Bool {
        didSet { defaults.set(menuFan, forKey: Keys.menuFan) }
    }
    @Published var menuBattery: Bool {
        didSet { defaults.set(menuBattery, forKey: Keys.menuBattery) }
    }
    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }
    @Published var launchAtLogin: Bool {
        didSet { setLoginItem(launchAtLogin) }
    }
    @Published var desktopWidgets: Bool {
        didSet { defaults.set(desktopWidgets, forKey: Keys.desktopWidgets) }
    }
    @Published var widgetCPU: Bool {
        didSet { defaults.set(widgetCPU, forKey: Keys.widgetCPU) }
    }
    @Published var widgetRAM: Bool {
        didSet { defaults.set(widgetRAM, forKey: Keys.widgetRAM) }
    }
    @Published var widgetTemp: Bool {
        didSet { defaults.set(widgetTemp, forKey: Keys.widgetTemp) }
    }
    @Published var widgetFan: Bool {
        didSet { defaults.set(widgetFan, forKey: Keys.widgetFan) }
    }
    @Published var widgetBattery: Bool {
        didSet { defaults.set(widgetBattery, forKey: Keys.widgetBattery) }
    }
    @Published var widgetDisk: Bool {
        didSet { defaults.set(widgetDisk, forKey: Keys.widgetDisk) }
    }
    @Published var paused = false

    private let defaults = UserDefaults.standard

    var hasActiveDesktopWidget: Bool {
        desktopWidgets && (widgetCPU || widgetRAM || widgetTemp || widgetFan || widgetBattery || widgetDisk)
    }

    init() {
        let stored = defaults.string(forKey: Keys.pace) ?? RefreshPace.balanced.rawValue
        pace = RefreshPace(rawValue: stored) ?? .balanced
        hideApple = defaults.object(forKey: Keys.hideApple) as? Bool ?? false
        menuCPU = defaults.object(forKey: Keys.menuCPU) as? Bool ?? true
        menuRAM = defaults.object(forKey: Keys.menuRAM) as? Bool ?? false
        menuTemp = defaults.object(forKey: Keys.menuTemp) as? Bool ?? true
        menuFan = defaults.object(forKey: Keys.menuFan) as? Bool ?? true
        menuBattery = defaults.object(forKey: Keys.menuBattery) as? Bool ?? true
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? false
        desktopWidgets = defaults.object(forKey: Keys.desktopWidgets) as? Bool ?? true
        widgetCPU = defaults.object(forKey: Keys.widgetCPU) as? Bool ?? true
        widgetRAM = defaults.object(forKey: Keys.widgetRAM) as? Bool ?? true
        widgetTemp = defaults.object(forKey: Keys.widgetTemp) as? Bool ?? true
        widgetFan = defaults.object(forKey: Keys.widgetFan) as? Bool ?? true
        widgetBattery = defaults.object(forKey: Keys.widgetBattery) as? Bool ?? true
        widgetDisk = defaults.object(forKey: Keys.widgetDisk) as? Bool ?? false
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func widgetFrame(_ kind: String) -> NSRect? {
        guard let raw = defaults.string(forKey: Keys.widgetFrame + kind) else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    func setWidgetFrame(_ frame: NSRect, kind: String) {
        defaults.set(
            "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)",
            forKey: Keys.widgetFrame + kind
        )
    }

    func clearWidgetFrames() {
        for kind in ["cpu", "memory", "temperature", "fan", "battery", "disk"] {
            defaults.removeObject(forKey: Keys.widgetFrame + kind)
        }
    }

    private func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private enum Keys {
    static let pace = "pace"
    static let hideApple = "hideApple"
    static let menuCPU = "menuCPU"
    static let menuRAM = "menuRAM"
    static let menuTemp = "menuTemp"
    static let menuFan = "menuFan"
    static let menuBattery = "menuBattery"
    static let alwaysOnTop = "alwaysOnTop"
    static let desktopWidgets = "desktopWidgets"
    static let widgetCPU = "widgetCPU"
    static let widgetRAM = "widgetRAM"
    static let widgetTemp = "widgetTemp"
    static let widgetFan = "widgetFan"
    static let widgetBattery = "widgetBattery"
    static let widgetDisk = "widgetDisk"
    static let widgetFrame = "widget.frame."
}
