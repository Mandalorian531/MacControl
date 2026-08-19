import Foundation

public enum JunkRisk: Int, Comparable, Sendable {
    case safe = 0
    case caution = 1
    case critical = 2

    public static func < (lhs: JunkRisk, rhs: JunkRisk) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .safe: ""
        case .caution: L10n.junkRiskCaution
        case .critical: L10n.junkRiskCritical
        }
    }
}

public enum JunkKind: String, CaseIterable, Sendable {
    case userCache
    case browser
    case logs
    case developer
    case hidden
    case temporary
    case backup
    case trash

    public var title: String {
        switch self {
        case .userCache: L10n.junkKindCache
        case .browser: L10n.junkKindBrowser
        case .logs: L10n.junkKindLogs
        case .developer: L10n.junkKindDeveloper
        case .hidden: L10n.junkKindHidden
        case .temporary: L10n.junkKindTemporary
        case .backup: L10n.junkKindBackup
        case .trash: L10n.junkKindTrash
        }
    }

    public var summary: String {
        switch self {
        case .userCache: L10n.junkSummaryCache
        case .browser: L10n.junkSummaryBrowser
        case .logs: L10n.junkSummaryLogs
        case .developer: L10n.junkSummaryDeveloper
        case .hidden: L10n.junkSummaryHidden
        case .temporary: L10n.junkSummaryTemporary
        case .backup: L10n.junkSummaryBackup
        case .trash: L10n.junkSummaryTrash
        }
    }
}

public struct JunkNode: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var kind: JunkKind
    public var size: UInt64
    public var fileCount: Int
    public var isDirectory: Bool
    public var isHidden: Bool
    public var recommended: Bool
    public var risk: JunkRisk

    public init(
        path: String,
        name: String,
        kind: JunkKind,
        size: UInt64,
        fileCount: Int,
        isDirectory: Bool,
        isHidden: Bool,
        recommended: Bool,
        risk: JunkRisk
    ) {
        self.path = path
        self.name = name
        self.kind = kind
        self.size = size
        self.fileCount = fileCount
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.recommended = recommended
        self.risk = risk
    }
}

public struct JunkCategory: Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: JunkKind
    public var items: [JunkNode]

    public var size: UInt64 { items.reduce(0) { $0 + $1.size } }
    public var fileCount: Int { items.reduce(0) { $0 + $1.fileCount } }

    public init(kind: JunkKind, items: [JunkNode]) {
        self.kind = kind
        self.items = items
    }
}

public struct JunkListing: Sendable {
    public var items: [JunkNode]
    public var truncated: Bool
    public var totalCount: Int

    public init(items: [JunkNode], truncated: Bool, totalCount: Int) {
        self.items = items
        self.truncated = truncated
        self.totalCount = totalCount
    }
}

public final class JunkScanner: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let home: URL

    public init() {
        home = FileManager.default.homeDirectoryForCurrentUser
    }

    public func scan() -> [JunkCategory] {
        var claimed = Set<String>()
        let budget = MeasureBudget()
        let developerRoots = collect(roots: developerRoots(), kind: .developer, claimed: &claimed, budget: budget)
        let cacheHome = collect(
            directory: home.appendingPathComponent(".cache"),
            kind: .developer,
            claimed: &claimed,
            defaultRecommended: true,
            budget: budget
        )
        let browsers = collect(roots: browserRoots(), kind: .browser, claimed: &claimed, budget: budget)
        let caches = collect(directory: library("Caches"), kind: .userCache, claimed: &claimed, defaultRecommended: true, budget: budget)
        let logs = collect(directory: library("Logs"), kind: .logs, claimed: &claimed, defaultRecommended: true, budget: budget)
        let http = collect(directory: library("HTTPStorages"), kind: .userCache, claimed: &claimed, defaultRecommended: true, budget: budget)
        let hidden = hiddenJunk()
        let temporary = collect(
            directory: fileManager.temporaryDirectory,
            kind: .temporary,
            claimed: &claimed,
            defaultRecommended: true,
            budget: budget
        )
        let backups = collect(roots: backupRoots(), kind: .backup, claimed: &claimed, budget: budget)
        let trash = collect(
            directory: home.appendingPathComponent(".Trash"),
            kind: .trash,
            claimed: &claimed,
            defaultRecommended: false,
            budget: budget
        )

        return [
            JunkCategory(kind: .userCache, items: merge(caches, http)),
            JunkCategory(kind: .browser, items: browsers),
            JunkCategory(kind: .logs, items: logs),
            JunkCategory(kind: .developer, items: merge(developerRoots, cacheHome)),
            JunkCategory(kind: .hidden, items: hidden),
            JunkCategory(kind: .temporary, items: temporary),
            JunkCategory(kind: .backup, items: backups),
            JunkCategory(kind: .trash, items: trash)
        ].filter { !$0.items.isEmpty }
    }

    public func listChildren(of node: JunkNode, limit: Int = 200) -> JunkListing {
        listFolder(URL(fileURLWithPath: node.path), kind: node.kind, recommended: node.recommended, limit: limit)
    }

    public func compactSelection(_ paths: Set<String>) -> [String] {
        let sorted = paths.sorted()
        var kept: [String] = []
        for path in sorted {
            if kept.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                continue
            }
            kept.append(path)
        }
        return kept
    }

    public func allowedTrashPaths(_ paths: [String]) -> [String] {
        paths.filter { PathGuard.isSafeToTrashJunk(URL(fileURLWithPath: $0), home: home, temporary: fileManager.temporaryDirectory) }
    }

    private func collect(roots: [(URL, Bool)], kind: JunkKind, claimed: inout Set<String>, budget: MeasureBudget) -> [JunkNode] {
        var items: [JunkNode] = []
        for (url, recommended) in roots {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            if isProtected(url.path) || PathGuard.shouldSkipListing(url) { continue }
            claimed.insert(url.path)
            items.append(makeNode(url, kind: kind, recommended: recommended, measureDeep: true, budget: budget))
        }
        return items.sorted(by: Self.bySize)
    }

    private func collect(
        directory: URL,
        kind: JunkKind,
        claimed: inout Set<String>,
        defaultRecommended: Bool,
        budget: MeasureBudget
    ) -> [JunkNode] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey],
            options: []
        ) else { return [] }
        var items: [JunkNode] = []
        for child in children {
            if claimed.contains(child.path) { continue }
            if isProtected(child.path) || PathGuard.shouldSkipListing(child) { continue }
            if child.lastPathComponent == ".DS_Store" { continue }
            let recommended = defaultRecommended && kind != .trash && kind != .backup
            items.append(makeNode(child, kind: kind, recommended: recommended, measureDeep: true, budget: budget))
        }
        return items.sorted(by: Self.bySize)
    }

    private func hiddenJunk() -> [JunkNode] {
        let folders = ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music"]
        var items: [JunkNode] = []
        for folder in folders {
            let root = home.appendingPathComponent(folder)
            items.append(contentsOf: findHidden(in: root, depth: 0, maxDepth: 2))
            if items.count >= 400 { break }
        }
        return items.sorted(by: Self.bySize)
    }

    private func findHidden(in root: URL, depth: Int, maxDepth: Int) -> [JunkNode] {
        guard depth <= maxDepth, !isProtected(root.path) else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else { return [] }
        if depth >= 1, children.count > 80 { return [] }
        var found: [JunkNode] = []
        for child in children {
            if found.count >= 400 { break }
            let name = child.lastPathComponent
            if isHiddenJunkName(name) {
                found.append(makeNode(child, kind: .hidden, recommended: true, measureDeep: false, budget: nil))
                continue
            }
            if name.hasPrefix(".") || PathGuard.skipHiddenFolder(name) { continue }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
            if values?.isSymbolicLink == true || values?.isPackage == true { continue }
            if values?.isDirectory == true {
                found.append(contentsOf: findHidden(in: child, depth: depth + 1, maxDepth: maxDepth))
            }
        }
        return found
    }

    private func listFolder(_ url: URL, kind: JunkKind, recommended: Bool, limit: Int) -> JunkListing {
        guard let children = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: []
        ) else {
            return JunkListing(items: [], truncated: false, totalCount: 0)
        }
        let visible = children.filter { !isProtected($0.path) && !PathGuard.shouldSkipListing($0) }
        let truncated = visible.count > limit
        let slice = truncated ? Array(visible.prefix(limit)) : visible
        let items = slice.map { makeNode($0, kind: kind, recommended: recommended, measureDeep: false, budget: nil) }
            .sorted(by: Self.bySize)
        return JunkListing(items: items, truncated: truncated, totalCount: visible.count)
    }

    private func makeNode(
        _ url: URL,
        kind: JunkKind,
        recommended: Bool,
        measureDeep: Bool,
        budget: MeasureBudget?
    ) -> JunkNode {
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .isRegularFileKey,
            .fileAllocatedSizeKey, .totalFileAllocatedSizeKey
        ])
        let symlink = values?.isSymbolicLink == true
        let directory = values?.isDirectory == true && !symlink
        let stats: (UInt64, Int)
        if directory {
            stats = measureDeep ? measure(url, budget: budget) : (UInt64(values?.totalFileAllocatedSize ?? 0), 1)
        } else {
            stats = (UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0), 1)
        }
        let name = url.lastPathComponent
        let classified = PathGuard.classify(path: url.path, name: name, kind: kind, recommended: recommended)
        return JunkNode(
            path: url.path,
            name: name,
            kind: kind,
            size: stats.0,
            fileCount: stats.1,
            isDirectory: directory,
            isHidden: name.hasPrefix(".") || values?.isHidden == true,
            recommended: classified.recommended,
            risk: classified.risk
        )
    }

    private func measure(_ url: URL, budget: MeasureBudget?) -> (UInt64, Int) {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsPackageDescendants]
        ) else { return (0, 0) }
        var size: UInt64 = 0
        var count = 0
        for case let child as URL in enumerator {
            if count >= 2_500 || budget?.exhausted == true {
                enumerator.skipDescendants()
                break
            }
            let values = try? child.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey
            ])
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values?.isRegularFile == true {
                count += 1
                budget?.consume()
                size += UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            }
        }
        return (size, max(count, 1))
    }

    private func library(_ folder: String) -> URL {
        home.appendingPathComponent("Library").appendingPathComponent(folder)
    }

    private func developerRoots() -> [(URL, Bool)] {
        let developer = home.appendingPathComponent("Library/Developer")
        return [
            (developer.appendingPathComponent("Xcode/DerivedData"), true),
            (developer.appendingPathComponent("Xcode/iOS DeviceSupport"), false),
            (developer.appendingPathComponent("Xcode/watchOS DeviceSupport"), false),
            (developer.appendingPathComponent("Xcode/Archives"), false),
            (developer.appendingPathComponent("CoreSimulator/Caches"), true),
            (library("Caches").appendingPathComponent("org.swift.swiftpm"), true),
            (library("Caches").appendingPathComponent("Homebrew"), true),
            (library("Caches").appendingPathComponent("pip"), true),
            (library("Caches").appendingPathComponent("Yarn"), true),
            (library("Caches").appendingPathComponent("CocoaPods"), true),
            (home.appendingPathComponent(".npm/_cacache"), true),
            (home.appendingPathComponent(".npm/_logs"), true),
            (home.appendingPathComponent(".gradle/caches"), true),
            (home.appendingPathComponent(".cargo/registry/cache"), true),
            (URL(fileURLWithPath: "/opt/homebrew/var/homebrew/cache"), true)
        ]
    }

    private func browserRoots() -> [(URL, Bool)] {
        let caches = library("Caches")
        let names = [
            "com.apple.Safari",
            "com.apple.Safari.SafeBrowsing",
            "com.apple.Safari.WebApp",
            "Google",
            "Chromium",
            "BraveSoftware",
            "com.brave.Browser",
            "Microsoft Edge",
            "Firefox",
            "org.mozilla.firefox",
            "com.operasoftware.Opera",
            "company.thebrowser.Browser",
            "com.kagi.orion",
            "Vivaldi"
        ]
        return names.map { (caches.appendingPathComponent($0), true) }
    }

    private func backupRoots() -> [(URL, Bool)] {
        [
            (home.appendingPathComponent("Library/Application Support/MobileSync/Backup"), false)
        ]
    }

    private func merge(_ lists: [JunkNode]...) -> [JunkNode] {
        var seen = Set<String>()
        var items: [JunkNode] = []
        for list in lists {
            for item in list where seen.insert(item.path).inserted {
                items.append(item)
            }
        }
        return items.sorted(by: Self.bySize)
    }

    private static func bySize(_ lhs: JunkNode, _ rhs: JunkNode) -> Bool {
        if lhs.size == rhs.size {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.size > rhs.size
    }

    private func isHiddenJunkName(_ name: String) -> Bool {
        name == ".DS_Store" || name.hasPrefix("._")
    }

    private func isProtected(_ path: String) -> Bool {
        PathGuard.isProtected(path, home: home.path)
    }
}

private final class MeasureBudget {
    private var remaining = 20_000

    var exhausted: Bool { remaining <= 0 }

    func consume() {
        if remaining > 0 { remaining -= 1 }
    }
}

enum PathGuard {
    private static let skippedNames: Set<String> = [
        "CloudKit",
        "com.apple.bird",
        "com.apple.accountsd",
        "com.apple.AddressBook",
        "com.apple.HomeKit",
        "com.apple.Passwords",
        "com.apple.identityservicesd",
        "com.apple.suggestd",
        "FamilyCircle"
    ]

    static func skipHiddenFolder(_ name: String) -> Bool {
        name == "node_modules"
            || name == ".git"
            || name == "DerivedData"
            || name == "Pods"
            || name == "build"
            || name == ".build"
            || name == "Library"
            || name == "Applications"
    }

    static func shouldSkipListing(_ url: URL) -> Bool {
        skippedNames.contains(url.lastPathComponent)
    }

    static func classify(path: String, name: String, kind: JunkKind, recommended: Bool) -> (risk: JunkRisk, recommended: Bool) {
        if kind == .backup || path.contains("/MobileSync/Backup") || path.contains("/Xcode/Archives") {
            return (.critical, false)
        }
        if kind == .trash {
            return (.safe, false)
        }
        if name == "DiagnosticReports" || path.contains("DeviceSupport") {
            return (.caution, false)
        }
        if kind == .userCache, name.hasPrefix("com.apple.") || name == "CloudKit" {
            return (.caution, false)
        }
        return (.safe, recommended && kind != .backup)
    }

    static func isProtected(_ path: String, home: String) -> Bool {
        if path == "/" || path == home || path == home + "/Library" { return true }
        if path.hasPrefix("/System") || path.hasPrefix("/usr") || path.hasPrefix("/bin") || path.hasPrefix("/sbin") {
            return true
        }
        let markers = [
            "/Library/Keychains",
            "/Library/Mail",
            "/Library/Messages",
            "/Library/Accounts",
            "/Library/Cookies",
            "/Library/Safari",
            "/Library/Suggestions",
            "/Library/IdentityServices",
            "/Library/Mobile Documents",
            "/Library/CloudStorage",
            "/Library/Photos",
            "/Library/Notes",
            "/Library/Calendars",
            "/Library/Reminders",
            "/Library/HomeKit",
            "/Library/Passwords",
            "/Library/Group Containers/group.com.apple",
            "/.ssh",
            "/.gnupg",
            "/.aws",
            "/.kube"
        ]
        if markers.contains(where: { path.contains($0) }) { return true }
        if skippedNames.contains(where: { path.hasSuffix("/" + $0) || path.contains("/" + $0 + "/") }) {
            return true
        }
        return false
    }

    static func isSafeToTrash(_ url: URL, home: URL, temporary: URL) -> Bool {
        let path = url.path
        let homePath = home.path
        if isProtected(path, home: homePath) { return false }
        if path.hasPrefix("/Library"), !path.hasPrefix("/Library/Application Support") {
            return false
        }
        if path.hasPrefix("/Applications") { return true }
        if path.hasPrefix(homePath + "/Applications") { return true }
        if path.hasPrefix(homePath + "/Library") { return true }
        return false
    }

    static func isSafeToTrashJunk(_ url: URL, home: URL, temporary: URL) -> Bool {
        let path = url.path
        let homePath = home.path
        if isProtected(path, home: homePath) { return false }
        let allowed = [
            homePath + "/Library/Caches",
            homePath + "/Library/Logs",
            homePath + "/Library/HTTPStorages",
            homePath + "/Library/Developer/Xcode/DerivedData",
            homePath + "/Library/Developer/Xcode/iOS DeviceSupport",
            homePath + "/Library/Developer/Xcode/watchOS DeviceSupport",
            homePath + "/Library/Developer/Xcode/Archives",
            homePath + "/Library/Developer/CoreSimulator/Caches",
            homePath + "/Library/Application Support/MobileSync/Backup",
            homePath + "/.npm/_cacache",
            homePath + "/.npm/_logs",
            homePath + "/.cache",
            homePath + "/.gradle/caches",
            homePath + "/.cargo/registry/cache",
            "/opt/homebrew/var/homebrew",
            temporary.path
        ]
        if allowed.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        if path.hasPrefix(homePath + "/.Trash") { return true }
        let name = url.lastPathComponent
        if name == ".DS_Store" || name.hasPrefix("._") {
            let folders = ["/Desktop/", "/Documents/", "/Downloads/", "/Pictures/", "/Movies/", "/Music/"]
            return folders.contains(where: { path.hasPrefix(homePath + $0) })
        }
        return false
    }
}
