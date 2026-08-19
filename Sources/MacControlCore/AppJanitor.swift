import Foundation
import Security

public enum SignatureStatus: String, Sendable {
    case valid
    case invalid
    case unsigned
    case unknown

    public var title: String {
        switch self {
        case .valid: L10n.signedOK
        case .invalid: L10n.signatureInvalid
        case .unsigned: L10n.unsigned
        case .unknown: "—"
        }
    }
}

public enum ResidueKind: String, Sendable {
    case application
    case support
    case preferences
    case cache
    case logs
    case container
    case launchAgent
    case savedState
    case other

    public var title: String {
        switch self {
        case .application: L10n.residueKindApp
        case .support: L10n.residueKindSupport
        case .preferences: L10n.residueKindPrefs
        case .cache: L10n.residueKindCache
        case .logs: L10n.residueKindLogs
        case .container: L10n.residueKindContainer
        case .launchAgent: L10n.residueKindAgent
        case .savedState: L10n.residueKindState
        case .other: L10n.other
        }
    }
}

public struct InstalledApp: Identifiable, Sendable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var bundleID: String
    public var version: String
    public var size: UInt64
    public var signature: SignatureStatus
    public var isSystem: Bool
    public var isSelf: Bool
}

public struct ResidueItem: Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var kind: ResidueKind
    public var size: UInt64
}

public final class AppJanitor: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let home: URL

    public init() {
        home = FileManager.default.homeDirectoryForCurrentUser
    }

    public func listApps() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications")
        ]
        var rows: [InstalledApp] = []
        for root in roots {
            guard let items = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for item in items where item.pathExtension == "app" {
                if let app = inspect(item) {
                    rows.append(app)
                }
            }
        }
        return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func residues(for app: InstalledApp) -> [ResidueItem] {
        var items: [ResidueItem] = []
        if fileManager.fileExists(atPath: app.path) {
            items.append(
                ResidueItem(path: app.path, kind: .application, size: allocatedSize(URL(fileURLWithPath: app.path)))
            )
        }
        items.append(contentsOf: scanLibrary(bundleID: app.bundleID, name: app.name))
        var seen = Set<String>()
        return items.filter { seen.insert($0.path).inserted }
            .sorted { $0.size > $1.size }
    }

    public func moveToTrash(_ paths: [String]) throws {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard isSafeToTrash(url) else { continue }
            var resulting: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resulting)
        }
    }

    public func emptyTrash() throws {
        let trash = home.appendingPathComponent(".Trash")
        guard let children = try? fileManager.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return }
        for child in children {
            try fileManager.removeItem(at: child)
        }
    }

    private func inspect(_ url: URL) -> InstalledApp? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = info["CFBundleIdentifier"] as? String ?? ""
        let version = (info["CFBundleShortVersionString"] as? String) ?? ""
        let system = url.path.hasPrefix("/System/") || bundleID.hasPrefix("com.apple.")
        return InstalledApp(
            name: name,
            path: url.path,
            bundleID: bundleID,
            version: version,
            size: allocatedSize(url),
            signature: verify(url),
            isSystem: system,
            isSelf: bundleID == "com.cgs.maccontrol"
        )
    }

    private func verify(_ url: URL) -> SignatureStatus {
        var staticCode: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
        guard created == errSecSuccess, let staticCode else { return .unknown }
        let status = SecStaticCodeCheckValidity(staticCode, [], nil)
        if status == errSecSuccess { return .valid }
        if status == -67062 { return .unsigned }
        return .invalid
    }

    private func scanLibrary(bundleID: String, name: String) -> [ResidueItem] {
        let library = home.appendingPathComponent("Library")
        let roots: [(String, ResidueKind)] = [
            ("Application Support", .support),
            ("Preferences", .preferences),
            ("Preferences/ByHost", .preferences),
            ("Caches", .cache),
            ("Logs", .logs),
            ("Saved Application State", .savedState),
            ("Containers", .container),
            ("Group Containers", .container),
            ("HTTPStorages", .cache),
            ("WebKit", .cache),
            ("Cookies", .preferences),
            ("Application Scripts", .support),
            ("LaunchAgents", .launchAgent)
        ]
        var found: [ResidueItem] = []
        for (folder, kind) in roots {
            let directory = library.appendingPathComponent(folder)
            guard let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children where matches(child, bundleID: bundleID, name: name) {
                found.append(ResidueItem(path: child.path, kind: kind, size: allocatedSize(child)))
            }
        }
        return found
    }

    private func matches(_ url: URL, bundleID: String, name: String) -> Bool {
        let last = url.lastPathComponent
        if last.hasPrefix(".") { return false }
        if last.hasPrefix("com.apple.") { return false }
        if !bundleID.isEmpty, !bundleID.hasPrefix("com.apple.") {
            if last == bundleID
                || last.hasPrefix(bundleID + ".")
                || last.hasPrefix(bundleID + "+")
                || last == "\(bundleID).plist"
                || last == "\(bundleID).savedState"
                || last == "\(bundleID).binarycookies"
            {
                return true
            }
        }
        guard name.count >= 6 else { return false }
        let needle = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let hay = last.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return hay == needle
            || hay == "\(needle).plist"
            || hay == "\(needle).savedState"
    }

    private func allocatedSize(_ url: URL) -> UInt64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            if let total = values.totalFileAllocatedSize { return UInt64(total) }
            if values.isDirectory != true, let file = values.fileAllocatedSize { return UInt64(file) }
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: UInt64 = 0
        var count = 0
        for case let child as URL in enumerator {
            count += 1
            if count > 400 { break }
            if let size = try? child.resourceValues(forKeys: [.fileAllocatedSizeKey]).fileAllocatedSize {
                total += UInt64(size)
            }
        }
        return total
    }

    private func isSafeToTrash(_ url: URL) -> Bool {
        PathGuard.isSafeToTrash(url, home: home, temporary: fileManager.temporaryDirectory)
    }
}
