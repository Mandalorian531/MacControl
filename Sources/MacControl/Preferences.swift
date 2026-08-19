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
    @Published var paused = false

    private let defaults = UserDefaults.standard

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
        launchAtLogin = SMAppService.mainApp.status == .enabled
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
}
