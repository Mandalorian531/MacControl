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
    public static let authorize = pick(fr: "Autoriser", en: "Allow")
    public static let restoreAuto = pick(fr: "Revenir en auto", en: "Return to auto")
    public static let fanHint = pick(
        fr: "Le Mac règle le ventilateur tout seul. Le mode manuel demande un mot de passe administrateur. Évitez une vitesse trop basse, surtout sur un portable.",
        en: "The Mac runs the fan on its own. Manual mode needs an administrator password. Avoid a very low speed, especially on a laptop."
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
        fr: "macOS demande une autorisation pour régler le ventilateur.",
        en: "macOS needs permission before the fan can be set."
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
    public static let helperReady = pick(fr: "Contrôle autorisé", en: "Control allowed")
    public static let helperFailed = pick(
        fr: "Impossible d’installer le helper. Le mot de passe a peut‑être été annulé.",
        en: "Could not install the helper. The password prompt may have been cancelled."
    )
    public static let sensors = pick(fr: "Capteurs", en: "Sensors")
    public static let refresh = pick(fr: "Rafraîchir", en: "Refresh")
    public static let settings = pick(fr: "Réglages", en: "Settings")
    public static let pause = pick(fr: "Pause", en: "Pause")
    public static let resume = pick(fr: "Reprendre", en: "Resume")
    public static let interval = pick(fr: "Actualisation", en: "Refresh rate")
    public static let eco = pick(fr: "Économe", en: "Low impact")
    public static let balanced = pick(fr: "Équilibré", en: "Balanced")
    public static let fast = pick(fr: "Rapide", en: "Fast")
    public static let launchAtLogin = pick(fr: "Ouvrir à la connexion", en: "Open at login")
    public static let alwaysOnTop = pick(fr: "Toujours au-dessus", en: "Always on top")
    public static let hideApple = pick(fr: "Masquer les processus Apple", en: "Hide Apple processes")
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
    public static let copySnapshot = pick(fr: "Copier l’état", en: "Copy status")
    public static let processCount = pick(fr: "processus", en: "processes")
    public static let paused = pick(fr: "En pause", en: "Paused")
    public static let openWindow = pick(fr: "Ouvrir la fenêtre", en: "Open window")
    public static let quitApp = pick(fr: "Quitter MacControl", en: "Quit MacControl")
    public static let samplingHint = pick(
        fr: "Quand la fenêtre est cachée, MacControl se met en veille pour limiter l’usage du processeur.",
        en: "When the window is hidden, MacControl idles to keep CPU use down."
    )
    public static let resetPeaks = pick(fr: "Réinitialiser les pics", en: "Reset peaks")
    public static let activityMonitor = pick(fr: "Moniteur d’activité", en: "Activity Monitor")
    public static let about = pick(fr: "À propos", en: "About")
    public static let privacy = pick(fr: "Confidentialité", en: "Privacy")
    public static let privacyNote = pick(
        fr: "Rien ne quitte cet ordinateur. Pas de compte, pas de télémétrie. Les mesures restent locales. Le réglage du ventilateur et l’envoi à la Corbeille demandent une confirmation.",
        en: "Nothing leaves this Mac. No account, no telemetry. Metrics stay local. Fan control and Trash actions wait for confirmation."
    )
    public static let userCPU = pick(fr: "User", en: "User")
    public static let systemCPU = pick(fr: "Système", en: "System")
    public static let session = pick(fr: "Session", en: "Session")
    public static let selfUsage = pick(fr: "MacControl", en: "MacControl")
    public static let load15 = pick(fr: "Charge 1 / 5 / 15", en: "Load 1 / 5 / 15")
    public static let path = pick(fr: "Chemin", en: "Path")
    public static let idle = pick(fr: "Inactif", en: "Idle")
    public static let apps = pick(fr: "Apps", en: "Apps")
    public static let leftovers = pick(fr: "Fichiers restants", en: "Leftover files")
    public static let uninstall = pick(fr: "Désinstaller", en: "Uninstall")
    public static let removeResidues = pick(fr: "Supprimer les fichiers restants", en: "Remove leftover files")
    public static let verify = pick(fr: "Actualiser", en: "Refresh")
    public static let signature = pick(fr: "Signature", en: "Signature")
    public static let signedOK = pick(fr: "Valide", en: "Valid")
    public static let unsigned = pick(fr: "Non signée", en: "Unsigned")
    public static let signatureInvalid = pick(fr: "Invalide", en: "Invalid")
    public static let hideSystem = pick(fr: "Masquer les apps système", en: "Hide system apps")
    public static let version = pick(fr: "Version", en: "Version")
    public static let size = pick(fr: "Taille", en: "Size")
    public static let confirmUninstall = pick(
        fr: "Mettre cette application et ses fichiers restants à la Corbeille ?",
        en: "Move this app and its leftover files to the Trash?"
    )
    public static let confirmResidues = pick(
        fr: "Mettre ces fichiers restants à la Corbeille ?",
        en: "Move these leftover files to the Trash?"
    )
    public static let leftoversHint = pick(
        fr: "Sélectionnez une application pour voir ses fichiers restants. Tout va à la Corbeille. Les applications Apple restent protégées.",
        en: "Select an app to see leftover files. Everything goes to Trash. Apple apps stay protected."
    )
    public static let cannotUninstallSystem = pick(
        fr: "Cette application système ne se désinstalle pas d’ici.",
        en: "This system app cannot be uninstalled here."
    )
    public static let cannotUninstallSelf = pick(
        fr: "MacControl ne peut pas se désinstaller lui-même.",
        en: "MacControl cannot uninstall itself."
    )
    public static let residueKindApp = pick(fr: "Application", en: "Application")
    public static let residueKindSupport = pick(fr: "Support", en: "Support")
    public static let residueKindPrefs = pick(fr: "Préférences", en: "Preferences")
    public static let residueKindCache = pick(fr: "Cache", en: "Cache")
    public static let residueKindLogs = pick(fr: "Journaux", en: "Logs")
    public static let residueKindContainer = pick(fr: "Conteneur", en: "Container")
    public static let residueKindAgent = pick(fr: "Agent", en: "Agent")
    public static let residueKindState = pick(fr: "État", en: "State")
    public static let trashDone = pick(fr: "Envoyé à la Corbeille", en: "Moved to Trash")
    public static let noResidues = pick(fr: "Aucun fichier restant.", en: "No leftover files.")
    public static let scanning = pick(fr: "Analyse…", en: "Scanning…")
    public static let selectApp = pick(fr: "Sélectionnez une application pour voir ses fichiers restants.", en: "Select an app to see leftover files.")
    public static let cleanup = pick(fr: "Nettoyage", en: "Cleanup")
    public static let cleanupHint = pick(
        fr: "Cochez ce que vous voulez retirer, puis envoyez-le à la Corbeille. Vous pourrez encore le récupérer ensuite.",
        en: "Tick what you want to remove, then move it to Trash. You can still restore it later."
    )
    public static let scanJunk = pick(fr: "Analyser", en: "Scan")
    public static let selectRecommended = pick(fr: "Recommandé", en: "Recommended")
    public static let selectNone = pick(fr: "Tout décocher", en: "Clear selection")
    public static let moveToTrash = pick(fr: "Mettre à la Corbeille", en: "Move to Trash")
    public static let confirmJunk = pick(
        fr: "Mettre la sélection à la Corbeille ?",
        en: "Move the selection to the Trash?"
    )
    public static let confirmJunkBackup = pick(
        fr: "La sélection contient des sauvegardes iPhone / iPad. Continuer vers la Corbeille ?",
        en: "The selection includes iPhone / iPad backups. Move them to the Trash?"
    )
    public static let confirmJunkCritical = pick(
        fr: "Critique : la sélection contient des sauvegardes iPhone / iPad ou des archives Xcode. Les mettre à la Corbeille peut faire perdre des données difficiles à retrouver. Continuer ?",
        en: "Critical: the selection includes iPhone / iPad backups or Xcode archives. Moving them to Trash can lose data that is hard to replace. Continue?"
    )
    public static let confirmJunkCaution = pick(
        fr: "Attention : la sélection contient des caches système ou des fichiers de développement. Des apps peuvent se reconnecter ou retélécharger des données. Continuer ?",
        en: "Caution: the selection includes system caches or developer files. Apps may sign in again or download data again. Continue?"
    )
    public static let junkRiskCaution = pick(fr: "attention", en: "caution")
    public static let junkRiskCritical = pick(fr: "critique", en: "critical")
    public static let selectedCriticalHint = pick(
        fr: "Éléments critiques cochés. Vérifiez avant d’envoyer à la Corbeille.",
        en: "Critical items are ticked. Check them before moving to Trash."
    )
    public static let selectedCautionHint = pick(
        fr: "Certains éléments cochés peuvent faire reconnecter des apps.",
        en: "Some ticked items may make apps sign in again."
    )
    public static let emptyTrash = pick(fr: "Vider la Corbeille", en: "Empty Trash")
    public static let confirmEmptyTrash = pick(
        fr: "Vider la Corbeille définitivement ? Ce n’est pas annulable.",
        en: "Empty the Trash permanently? This cannot be undone."
    )
    public static let junkKindCache = pick(fr: "Caches des applications", en: "App caches")
    public static let junkKindBrowser = pick(fr: "Navigateurs", en: "Browsers")
    public static let junkKindLogs = pick(fr: "Journaux", en: "Logs")
    public static let junkKindDeveloper = pick(fr: "Outils de développement", en: "Developer tools")
    public static let junkKindHidden = pick(fr: "Fichiers cachés", en: "Hidden files")
    public static let junkKindTemporary = pick(fr: "Fichiers temporaires", en: "Temporary files")
    public static let junkKindBackup = pick(fr: "Sauvegardes iPhone et iPad", en: "iPhone and iPad backups")
    public static let junkKindTrash = pick(fr: "Corbeille", en: "Trash")
    public static let junkSummaryCache = pick(fr: "Fichiers temporaires des applications, régénérés au besoin.", en: "App cache files. They come back if needed.")
    public static let junkSummaryBrowser = pick(fr: "Cache Safari, Chrome et les autres navigateurs.", en: "Safari, Chrome, and other browser caches.")
    public static let junkSummaryLogs = pick(fr: "Journaux d’applications. Sans effet sur vos documents.", en: "App logs. Your documents stay untouched.")
    public static let junkSummaryDeveloper = pick(fr: "DerivedData, Homebrew, npm et caches similaires.", en: "DerivedData, Homebrew, npm, and similar caches.")
    public static let junkSummaryHidden = pick(fr: "Fichiers .DS_Store et assimilés dans vos dossiers.", en: ".DS_Store and similar files in your folders.")
    public static let junkSummaryTemporary = pick(fr: "Fichiers de travail déjà destinés à disparaître.", en: "Working files that were already meant to go.")
    public static let junkSummaryBackup = pick(fr: "Sauvegardes d’appareils iOS. Décochez si vous en avez encore besoin.", en: "iOS device backups. Untick if you still need them.")
    public static let junkSummaryTrash = pick(fr: "Déjà dans la Corbeille. Vider les efface définitivement.", en: "Already in Trash. Emptying deletes them for good.")
    public static let hiddenBadge = pick(fr: "caché", en: "hidden")
    public static let filesCount = pick(fr: "fichiers", en: "files")
    public static let truncated = pick(fr: "liste partielle", en: "partial list")
    public static let noJunk = pick(
        fr: "Aucun fichier inutile trouvé. Si la liste est vide à tort, autorisez l’accès aux dossiers dans Réglages système.",
        en: "No junk files found. If this looks wrong, allow folder access in System Settings."
    )
    public static let selected = pick(fr: "Sélection", en: "Selected")
    public static let expandFolder = pick(fr: "Voir le contenu", en: "Show contents")
    public static let showDetails = pick(fr: "Voir les fichiers", en: "Show files")
    public static let hideDetails = pick(fr: "Masquer", en: "Hide")
    public static let scanningJunk = pick(fr: "Recherche des fichiers inutiles…", en: "Looking for junk files…")
    public static let foundSpace = pick(fr: "Espace récupérable", en: "Reclaimable space")
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
