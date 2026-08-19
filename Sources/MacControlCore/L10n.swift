import Foundation

public enum L10n {
    private static var isFrench: Bool {
        Locale.current.language.languageCode?.identifier == "fr"
    }

    private static func pick(fr: String, en: String) -> String {
        isFrench ? fr : en
    }

    public static let appName = "MacControl"
    public static let dashboard = pick(fr: "Vue d’ensemble", en: "Overview")
    public static let temperatures = pick(fr: "Températures", en: "Temperatures")
    public static let fan = pick(fr: "Ventilateur", en: "Fan")
    public static let processes = pick(fr: "Processus", en: "Processes")
    public static let cpu = "CPU"
    public static let memory = pick(fr: "Mémoire", en: "Memory")
    public static let disk = pick(fr: "Disque", en: "Disk")
    public static let network = pick(fr: "Réseau", en: "Network")
    public static let cores = pick(fr: "Cœurs", en: "Cores")
    public static let used = pick(fr: "Utilisée", en: "Used")
    public static let free = pick(fr: "Libre", en: "Free")
    public static let cached = pick(fr: "Cache", en: "Cached")
    public static let wired = pick(fr: "Filaire", en: "Wired")
    public static let compressed = pick(fr: "Compressée", en: "Compressed")
    public static let swap = "Swap"
    public static let read = pick(fr: "Lecture", en: "Read")
    public static let write = pick(fr: "Écriture", en: "Write")
    public static let download = pick(fr: "Réception", en: "Download")
    public static let upload = pick(fr: "Envoi", en: "Upload")
    public static let soc = "SoC"
    public static let storage = pick(fr: "Stockage", en: "Storage")
    public static let board = pick(fr: "Carte", en: "Board")
    public static let other = pick(fr: "Autres", en: "Other")
    public static let hottest = pick(fr: "Point le plus chaud", en: "Hottest")
    public static let thermalState = pick(fr: "État thermique", en: "Thermal state")
    public static let nominal = pick(fr: "Nominal", en: "Nominal")
    public static let fair = pick(fr: "Élevé", en: "Fair")
    public static let serious = pick(fr: "Sérieux", en: "Serious")
    public static let critical = pick(fr: "Critique", en: "Critical")
    public static let fanSpeed = pick(fr: "Vitesse", en: "Speed")
    public static let target = pick(fr: "Cible", en: "Target")
    public static let auto = pick(fr: "Automatique", en: "Automatic")
    public static let manual = pick(fr: "Manuel", en: "Manual")
    public static let apply = pick(fr: "Appliquer", en: "Apply")
    public static let authorize = pick(fr: "Autoriser le contrôle", en: "Allow control")
    public static let restoreAuto = pick(fr: "Revenir en auto", en: "Return to auto")
    public static let fanHint = pick(
        fr: "Le firmware règle les ventilos tout seul. Le mode manuel écrit dans le SMC et demande un mot de passe admin. Un régime trop bas fait monter le SoC, surtout sur un portable.",
        en: "Firmware runs the fans on its own. Manual mode writes to the SMC and needs an admin password. Too low a speed cooks the SoC, especially on a laptop."
    )
    public static let fanless = pick(
        fr: "Ce Mac n’a pas de ventilateur. La dissipation est passive.",
        en: "This Mac has no fan. Cooling is passive."
    )
    public static let fans = pick(fr: "Ventilateurs", en: "Fans")
    public static let battery = pick(fr: "Batterie", en: "Battery")
    public static let charging = pick(fr: "En charge", en: "Charging")
    public static let onAC = pick(fr: "Secteur", en: "Power adapter")
    public static let onBattery = pick(fr: "Sur batterie", en: "On battery")
    public static let cycles = pick(fr: "Cycles", en: "Cycles")
    public static let health = pick(fr: "Santé", en: "Health")
    public static let gpu = "GPU"
    public static let showBattery = pick(fr: "Afficher la batterie", en: "Show battery")
    public static let model = pick(fr: "Modèle", en: "Model")
    public static let macBookAir = "MacBook Air"
    public static let macBookPro = "MacBook Pro"
    public static let macMini = "Mac mini"
    public static let macStudio = "Mac Studio"
    public static let iMac = "iMac"
    public static let macPro = "Mac Pro"
    public static let appleSilicon = "Apple Silicon"
    public static let fanNeedsAdmin = pick(
        fr: "macOS refuse l’écriture SMC depuis l’app. Autorise un helper admin une fois, puis le curseur agit directement.",
        en: "macOS blocked the SMC write from the app. Authorize an admin helper once, then the slider talks to it directly."
    )
    public static let search = pick(fr: "Rechercher", en: "Search")
    public static let name = pick(fr: "Nom", en: "Name")
    public static let pid = "PID"
    public static let cpuShort = "CPU"
    public static let ramShort = "RAM"
    public static let threads = pick(fr: "Threads", en: "Threads")
    public static let quitProcess = pick(fr: "Quitter", en: "Quit")
    public static let forceQuit = pick(fr: "Forcer à quitter", en: "Force quit")
    public static let confirmQuit = pick(fr: "Quitter ce processus ?", en: "Quit this process?")
    public static let confirmForce = pick(
        fr: "Forcer à quitter ce processus ?",
        en: "Force quit this process?"
    )
    public static let cancel = pick(fr: "Annuler", en: "Cancel")
    public static let topProcesses = pick(fr: "Plus gourmands", en: "Top processes")
    public static let uptime = pick(fr: "Allumé depuis", en: "Up for")
    public static let load = pick(fr: "Charge", en: "Load")
    public static let noFan = pick(fr: "Aucun ventilateur exposé par le SMC.", en: "No fan exposed by the SMC.")
    public static let helperReady = pick(fr: "Helper admin actif", en: "Admin helper active")
    public static let helperFailed = pick(
        fr: "Impossible d’installer le helper. Le mot de passe a peut‑être été annulé.",
        en: "Could not install the helper. The password prompt may have been cancelled."
    )
    public static let sensors = pick(fr: "Capteurs", en: "Sensors")
    public static let refresh = pick(fr: "Rafraîchir", en: "Refresh")
    public static let settings = pick(fr: "Réglages", en: "Settings")
    public static let pause = pick(fr: "Pause", en: "Pause")
    public static let resume = pick(fr: "Reprendre", en: "Resume")
    public static let interval = pick(fr: "Intervalle", en: "Interval")
    public static let eco = pick(fr: "Économe", en: "Low impact")
    public static let balanced = pick(fr: "Équilibré", en: "Balanced")
    public static let fast = pick(fr: "Rapide", en: "Fast")
    public static let launchAtLogin = pick(fr: "Ouvrir à la connexion", en: "Open at login")
    public static let alwaysOnTop = pick(fr: "Toujours au-dessus", en: "Always on top")
    public static let hideApple = pick(fr: "Masquer les process Apple", en: "Hide Apple processes")
    public static let menuBar = pick(fr: "Barre de menu", en: "Menu bar")
    public static let showCPU = pick(fr: "Afficher le CPU", en: "Show CPU")
    public static let showRAM = pick(fr: "Afficher la RAM", en: "Show RAM")
    public static let showTemp = pick(fr: "Afficher la température", en: "Show temperature")
    public static let showFan = pick(fr: "Afficher le ventilateur", en: "Show fan")
    public static let pCores = pick(fr: "Cœurs P", en: "P cores")
    public static let eCores = pick(fr: "Cœurs E", en: "E cores")
    public static let pressure = pick(fr: "Pression", en: "Pressure")
    public static let peak = pick(fr: "Pic", en: "Peak")
    public static let copyPath = pick(fr: "Copier le chemin", en: "Copy path")
    public static let reveal = pick(fr: "Afficher dans le Finder", en: "Reveal in Finder")
    public static let copySnapshot = pick(fr: "Copier un instantané", en: "Copy snapshot")
    public static let processCount = pick(fr: "processus", en: "processes")
    public static let paused = pick(fr: "En pause", en: "Paused")
    public static let openWindow = pick(fr: "Ouvrir la fenêtre", en: "Open window")
    public static let quitApp = pick(fr: "Quitter MacControl", en: "Quit MacControl")
    public static let samplingHint = pick(
        fr: "L’app échantillonne hors du thread UI. Fenêtre cachée ou couverte : 3 s, sans liste process ni I/O disque.",
        en: "Sampling runs off the UI thread. Hidden or covered window: 3 s, no process list or disk I/O."
    )
    public static let resetPeaks = pick(fr: "Réinitialiser les pics", en: "Reset peaks")
    public static let activityMonitor = pick(fr: "Moniteur d’activité", en: "Activity Monitor")
    public static let about = pick(fr: "À propos", en: "About")
    public static let userCPU = pick(fr: "User", en: "User")
    public static let systemCPU = pick(fr: "Système", en: "System")
    public static let session = pick(fr: "Session", en: "Session")
    public static let selfUsage = pick(fr: "MacControl", en: "MacControl")
    public static let load15 = pick(fr: "Charge 1 / 5 / 15", en: "Load 1 / 5 / 15")
    public static let path = pick(fr: "Chemin", en: "Path")
    public static let idle = pick(fr: "Inactif", en: "Idle")
}

public enum RefreshPace: String, CaseIterable, Identifiable, Sendable {
    case eco
    case balanced
    case fast

    public var id: String { rawValue }

    public var seconds: Double {
        switch self {
        case .eco: 3
        case .balanced: 2
        case .fast: 1
        }
    }

    public var title: String {
        switch self {
        case .eco: L10n.eco
        case .balanced: L10n.balanced
        case .fast: L10n.fast
        }
    }
}

public enum Formatters {
    public static func percent(_ value: Double) -> String {
        String(format: "%.0f %%", value)
    }

    public static func percent1(_ value: Double) -> String {
        String(format: "%.1f %%", value)
    }

    public static func celsius(_ value: Double) -> String {
        String(format: "%.0f °C", value)
    }

    public static func celsius1(_ value: Double) -> String {
        String(format: "%.1f °C", value)
    }

    public static func rpm(_ value: Double) -> String {
        let unit = Locale.current.language.languageCode?.identifier == "fr" ? "tr/min" : "rpm"
        return "\(Int(value.rounded())) \(unit)"
    }

    public static func bytes(_ value: UInt64) -> String {
        let units = ["o", "Ko", "Mo", "Go", "To"]
        var size = Double(value)
        var unit = 0
        while size >= 1024, unit < units.count - 1 {
            size /= 1024
            unit += 1
        }
        let format = unit == 0 ? "%.0f %@" : (size >= 10 ? "%.0f %@" : "%.1f %@")
        return String(format: format, locale: Locale.current, size, units[unit])
    }

    public static func bytesPerSecond(_ value: UInt64) -> String {
        "\(bytes(value))/s"
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return "\(days) j \(hours) h"
        }
        if hours > 0 {
            return "\(hours) h \(minutes) min"
        }
        return "\(minutes) min"
    }

    public static func minutes(_ value: Int) -> String {
        guard value > 0 else { return "—" }
        let hours = value / 60
        let minutes = value % 60
        if hours > 0 {
            return "\(hours) h \(minutes) min"
        }
        return "\(minutes) min"
    }
}
