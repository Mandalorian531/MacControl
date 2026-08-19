import AppKit
import Combine
import Foundation
import MacControlCore
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var host: HostSnapshot
    @Published var thermal: ThermalSnapshot
    @Published var fan: FanSnapshot
    @Published var processes: [ProcessSnapshot] = []
    @Published var topProcesses: [ProcessSnapshot] = []
    @Published var processCount = 0
    @Published var processQuery = ""
    @Published var processSort = ProcessSort.cpu
    @Published var fanManual = false
    @Published var fanTarget: Double = 1500
    @Published var fanStatus: String?
    @Published var helperReady = false
    @Published var section: AppSection = .dashboard
    @Published var selectedProcessID: ProcessSnapshot.ID?
    @Published var pendingQuit: ProcessSnapshot?
    @Published var pendingForce: ProcessSnapshot?
    @Published var history = HistoryStore()
    @Published var menuBarText = "MacControl"
    @Published var peakCPU: Double = 0
    @Published var peakTemp: Double = 0
    @Published var peakFan: Double = 0
    @Published var selfUsage = SelfSnapshot(cpu: 0, memory: 0)
    @Published var windowVisible = true
    @Published var preferences = Preferences()
    @Published var installedApps: [InstalledApp] = []
    @Published var appQuery = ""
    @Published var hideSystemApps = true
    @Published var selectedAppID: String?
    @Published var residues: [ResidueItem] = []
    @Published var residuesLoading = false
    @Published var pendingUninstall: InstalledApp?
    @Published var pendingResidues = false
    @Published var janitorStatus: String?
    @Published var junkCategories: [JunkCategory] = []
    @Published var junkQuery = ""
    @Published var junkLoading = false
    @Published var selectedJunk: Set<String> = []
    @Published var expandedJunk: Set<String> = []
    @Published var expandedCategories: Set<String> = []
    @Published var junkChildren: [String: JunkListing] = [:]
    @Published var junkLoadingPaths: Set<String> = []
    @Published var pendingJunkTrash = false
    @Published var pendingEmptyTrash = false
    @Published var junkStatus: String?
    @Published var lastFreedSize: UInt64 = 0

    let machine = MachineInfo.current

    private let sampler = MetricsSampler()
    private let janitor = AppJanitor()
    private let junkScanner = JunkScanner()
    private let queue = DispatchQueue(label: "com.cgs.maccontrol.sample", qos: .utility)
    private let janitorQueue = DispatchQueue(label: "com.cgs.maccontrol.janitor", qos: .utility)
    private let live = LiveConfig()
    private var timer: DispatchSourceTimer?
    private var lastWidgetReload = Date.distantPast
    private var fanWriteTask: Task<Void, Never>?
    private var lastMenu = ""
    private var cancellables = Set<AnyCancellable>()

    enum ProcessSort {
        case cpu
        case memory
        case name
    }

    var filteredProcesses: [ProcessSnapshot] {
        let query = processQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var rows = processes
        if preferences.hideApple {
            rows = rows.filter { !$0.isApple }
        }
        if !query.isEmpty {
            rows = rows.filter {
                $0.name.localizedCaseInsensitiveContains(query) || String($0.pid).contains(query)
            }
        }
        switch processSort {
        case .cpu: return rows.sorted { $0.cpu > $1.cpu }
        case .memory: return rows.sorted { $0.memory > $1.memory }
        case .name: return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var filteredApps: [InstalledApp] {
        var rows = installedApps
        if hideSystemApps {
            rows = rows.filter { !$0.isSystem }
        }
        let query = appQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            rows = rows.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
            }
        }
        return rows
    }

    var selectedApp: InstalledApp? {
        guard let selectedAppID else { return nil }
        return installedApps.first { $0.id == selectedAppID }
    }

    var leftoverSize: UInt64 {
        residues.filter { $0.kind != .application }.map(\.size).reduce(0, +)
    }

    var filteredJunkCategories: [JunkCategory] {
        let query = junkQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return junkCategories }
        return junkCategories.compactMap { category in
            let items = category.items.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.path.localizedCaseInsensitiveContains(query)
            }
            guard !items.isEmpty else { return nil }
            return JunkCategory(kind: category.kind, items: items)
        }
    }

    var junkTotalSize: UInt64 {
        junkCategories.reduce(0) { $0 + $1.size }
    }

    var junkFileCount: Int {
        junkCategories.reduce(0) { $0 + $1.fileCount }
    }

    var junkCriticalSize: UInt64 {
        junkCategories.flatMap(\.items).filter { $0.risk == .critical }.map(\.size).reduce(0, +)
    }

    var selectedJunkSize: UInt64 {
        junkScanner.compactSelection(selectedJunk).reduce(0) { $0 + junkSize(for: $1) }
    }

    var selectedJunkCount: Int {
        junkScanner.compactSelection(selectedJunk).count
    }

    var selectedJunkRisk: JunkRisk {
        var highest = JunkRisk.safe
        for item in junkCategories.flatMap(\.items) where isJunkSelected(item.path) {
            highest = max(highest, item.risk)
        }
        for item in junkChildren.values.flatMap(\.items) where isJunkSelected(item.path) {
            highest = max(highest, item.risk)
        }
        return highest
    }

    var hasTrashItems: Bool {
        junkCategories.contains { $0.kind == .trash && !$0.items.isEmpty }
    }

    func isJunkSelected(_ path: String) -> Bool {
        if selectedJunk.contains(path) { return true }
        return selectedJunk.contains { path.hasPrefix($0 + "/") }
    }

    func isJunkSelectionLocked(_ path: String) -> Bool {
        selectedJunk.contains { path != $0 && path.hasPrefix($0 + "/") }
    }

    func setJunkSelected(_ path: String, _ on: Bool) {
        if on {
            selectedJunk.insert(path)
            selectedJunk = selectedJunk.filter { $0 == path || !$0.hasPrefix(path + "/") }
        } else {
            selectedJunk.remove(path)
        }
    }

    func setJunkExpanded(_ path: String, _ on: Bool, node: JunkNode) {
        if on {
            expandedJunk.insert(path)
            loadJunkChildren(node)
        } else {
            expandedJunk.remove(path)
        }
    }

    func selectRecommendedJunk() {
        selectedJunk = Set(
            junkCategories.flatMap(\.items).filter { $0.recommended && $0.kind != .trash }.map(\.path)
        )
    }

    func clearJunkSelection() {
        selectedJunk = []
    }

    func toggleJunkCategory(_ category: JunkCategory, _ on: Bool) {
        let paths = category.items.filter { $0.kind != .trash && $0.risk != .critical }.map(\.path)
        if on {
            selectedJunk.formUnion(paths)
        } else {
            selectedJunk.subtract(Set(paths))
        }
    }

    init() {
        let first = sampler.sample(
            SampleRequest(processes: .none, fullSensors: false, diskIO: false, fan: true, thermal: true, network: false)
        )
        host = first.host
        thermal = first.thermal
        fan = first.fan
        selfUsage = first.selfUsage
        fanManual = fan.isManual
        fanTarget = fan.targetRPM > 0 ? fan.targetRPM : max(fan.minRPM, 1500)
        live.menuTemp = preferences.menuTemp
        live.menuFan = preferences.menuFan
        preferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        preferences.$alwaysOnTop
            .dropFirst()
            .sink { enabled in AppModel.applyAlwaysOnTop(enabled) }
            .store(in: &cancellables)
        preferences.$pace
            .dropFirst()
            .sink { [weak self] _ in self?.restartTimer() }
            .store(in: &cancellables)
        preferences.$paused
            .sink { [live] paused in live.paused = paused }
            .store(in: &cancellables)
        preferences.$menuTemp
            .sink { [live] value in live.menuTemp = value }
            .store(in: &cancellables)
        preferences.$menuFan
            .sink { [live] value in live.menuFan = value }
            .store(in: &cancellables)
        $section
            .sink { [weak self, live] section in
                live.section = section
                if section == .apps {
                    self?.refreshApps(force: false)
                }
                if section == .cleanup {
                    self?.scanJunkIfNeeded()
                }
            }
            .store(in: &cancellables)
        $selectedAppID
            .sink { [weak self] id in self?.loadResidues(id) }
            .store(in: &cancellables)
    }

    func refreshApps(force: Bool = true) {
        if !force, !installedApps.isEmpty { return }
        janitorQueue.async { [weak self, janitor] in
            let rows = janitor.listApps()
            DispatchQueue.main.async {
                self?.installedApps = rows
            }
        }
    }

    func uninstallSelected() {
        guard let app = selectedApp else { return }
        if app.isSelf {
            janitorStatus = L10n.cannotUninstallSelf
            return
        }
        guard !app.isSystem else {
            janitorStatus = L10n.cannotUninstallSystem
            return
        }
        let paths = residues.map(\.path)
        trash(paths)
    }

    func removeResiduesOnly() {
        let paths = residues.filter { $0.kind != .application }.map(\.path)
        trash(paths)
    }

    func revealApp(_ app: InstalledApp) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
    }

    func revealResidue(_ item: ResidueItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }

    func scanJunkIfNeeded() {
        guard junkCategories.isEmpty, !junkLoading else { return }
        scanJunk()
    }

    func scanJunk() {
        junkLoading = true
        junkStatus = nil
        janitorQueue.async { [weak self, junkScanner] in
            let categories = junkScanner.scan()
            DispatchQueue.main.async {
                self?.junkCategories = categories
                self?.junkChildren = [:]
                self?.expandedJunk = []
                self?.expandedCategories = []
                self?.junkLoading = false
                self?.selectRecommendedJunk()
            }
        }
    }

    func loadJunkChildren(_ node: JunkNode) {
        guard node.isDirectory, junkChildren[node.path] == nil else { return }
        junkLoadingPaths.insert(node.path)
        janitorQueue.async { [weak self, junkScanner] in
            let listing = junkScanner.listChildren(of: node)
            DispatchQueue.main.async {
                self?.junkChildren[node.path] = listing
                self?.junkLoadingPaths.remove(node.path)
            }
        }
    }

    func revealJunk(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func requestJunkTrash() {
        if selectedJunkRisk == .critical {
            confirmUltraSensitiveTrash()
            return
        }
        pendingJunkTrash = true
    }

    func trashSelectedJunk() {
        trashSelectedJunk(allowUltraSensitive: selectedJunkRisk == .critical)
    }

    private func confirmUltraSensitiveTrash() {
        let first = NSAlert()
        first.alertStyle = .critical
        first.messageText = L10n.ultraAlertTitle
        first.informativeText = L10n.ultraAlertBody
        first.addButton(withTitle: L10n.cancel)
        first.addButton(withTitle: L10n.ultraAlertContinue)
        first.buttons.last?.hasDestructiveAction = true
        guard first.runModal() == .alertSecondButtonReturn else { return }

        let labels = ultraSensitiveLabels()
        let second = NSAlert()
        second.alertStyle = .critical
        second.messageText = L10n.ultraAlertTitle2
        second.informativeText = L10n.ultraAlertBody2 + labels.joined(separator: "\n")
        second.addButton(withTitle: L10n.cancel)
        second.addButton(withTitle: L10n.ultraAlertConfirm)
        second.buttons.last?.hasDestructiveAction = true
        guard second.runModal() == .alertSecondButtonReturn else { return }
        trashSelectedJunk(allowUltraSensitive: true)
    }

    private func ultraSensitiveLabels() -> [String] {
        let rows = junkCategories.flatMap(\.items) + junkChildren.values.flatMap(\.items)
        return rows.filter { $0.risk == .critical && isJunkSelected($0.path) }
            .map { "• \($0.name)  \(Formatters.bytes($0.size))" }
    }

    private func trashSelectedJunk(allowUltraSensitive: Bool) {
        let paths = junkScanner.allowedTrashPaths(
            junkScanner.compactSelection(selectedJunk),
            allowUltraSensitive: allowUltraSensitive
        )
        guard !paths.isEmpty else { return }
        let freed = paths.reduce(0) { $0 + junkSize(for: $1) }
        janitorQueue.async { [weak self, janitor] in
            do {
                try janitor.moveToTrash(paths)
                DispatchQueue.main.async {
                    self?.lastFreedSize = freed
                    self?.junkStatus = L10n.trashDone
                    self?.selectedJunk = []
                    self?.scanJunk()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.junkStatus = String(describing: error)
                }
            }
        }
    }

    func emptyUserTrash() {
        let freed = junkCategories.first(where: { $0.kind == .trash })?.size ?? 0
        janitorQueue.async { [weak self, janitor] in
            do {
                try janitor.emptyTrash()
                DispatchQueue.main.async {
                    if freed > 0 { self?.lastFreedSize = freed }
                    self?.junkStatus = L10n.trashDone
                    self?.scanJunk()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.junkStatus = String(describing: error)
                }
            }
        }
    }

    private func junkSize(for path: String) -> UInt64 {
        if let item = junkCategories.flatMap(\.items).first(where: { $0.path == path }) {
            return item.size
        }
        for listing in junkChildren.values {
            if let item = listing.items.first(where: { $0.path == path }) {
                return item.size
            }
        }
        return 0
    }

    private func loadResidues(_ id: String?) {
        residues = []
        guard let app = installedApps.first(where: { $0.id == id }) else {
            residuesLoading = false
            return
        }
        residuesLoading = true
        janitorQueue.async { [weak self, janitor] in
            let items = janitor.residues(for: app)
            DispatchQueue.main.async {
                guard self?.selectedAppID == id else { return }
                self?.residues = items
                self?.residuesLoading = false
            }
        }
    }

    private func trash(_ paths: [String]) {
        guard !paths.isEmpty else { return }
        janitorQueue.async { [weak self, janitor] in
            do {
                try janitor.moveToTrash(paths)
                DispatchQueue.main.async {
                    self?.janitorStatus = L10n.trashDone
                    self?.residues = []
                    self?.selectedAppID = nil
                    self?.refreshApps()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.janitorStatus = String(describing: error)
                }
            }
        }
    }

    func start() {
        guard timer == nil else { return }
        restartTimer()
        NSApplication.shared.appearance = nil
        Self.applyAlwaysOnTop(preferences.alwaysOnTop)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == L10n.appName }) {
            window.makeKeyAndOrderFront(nil)
        }
        Self.applyAlwaysOnTop(preferences.alwaysOnTop)
    }

    func setWindowVisible(_ visible: Bool) {
        windowVisible = visible
        live.visible = visible
    }

    func resetPeaks() {
        peakCPU = host.cpu.total
        peakTemp = thermal.soc ?? thermal.hottest?.celsius ?? 0
        peakFan = fan.rpm
    }

    func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }

    func togglePause() {
        preferences.paused.toggle()
        live.paused = preferences.paused
        lastMenu = ""
        menuBarText = menuText()
    }

    func restartTimer() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + preferences.pace.seconds, repeating: preferences.pace.seconds)
        timer.setEventHandler { [weak self, live, sampler] in
            guard !live.paused else { return }
            let ticks = live.bump()
            let visible = live.visible
            if !visible, !ticks.isMultiple(of: 2) { return }
            let section = live.section
            let onDash = section == .dashboard
            let request = SampleRequest(
                processes: LiveConfig.processDepth(visible: visible, section: section, ticks: ticks),
                fullSensors: visible && section == .temperatures,
                diskIO: visible && onDash && ticks.isMultiple(of: 3),
                fan: (visible && (onDash || section == .fan)) || live.menuFan,
                thermal: (visible && (onDash || section == .temperatures)) || live.menuTemp,
                network: visible && onDash
            )
            let bundle = sampler.sample(request)
            DispatchQueue.main.async {
                self?.apply(bundle)
            }
        }
        timer.resume()
        self.timer = timer
    }

    func setManual(_ enabled: Bool) {
        fanManual = enabled
        if enabled {
            applyFan(.manual(rpm: Int(fanTarget)))
        } else {
            applyFan(.auto)
        }
    }

    func scheduleFanTarget(_ value: Double) {
        fanTarget = value
        fanWriteTask?.cancel()
        fanWriteTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            self?.applyFan(.manual(rpm: Int(value)))
        }
    }

    func authorizeControl() {
        let command: FanCommand = fanManual ? .manual(rpm: Int(fanTarget)) : .auto
        switch sampler.authorizeFan(command) {
        case .applied:
            helperReady = true
            fanStatus = L10n.helperReady
        case .needsPrivilege:
            fanStatus = L10n.fanNeedsAdmin
        case .failed(let message):
            fanStatus = message
        }
    }

    func quitProcess(_ process: ProcessSnapshot, force: Bool) {
        _ = sampler.terminate(pid: process.pid, force: force)
    }

    func copyPath(_ process: ProcessSnapshot) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(process.path.isEmpty ? process.name : process.path, forType: .string)
    }

    func reveal(_ process: ProcessSnapshot) {
        guard !process.path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: process.path)])
    }

    func copySnapshot() {
        let load = host.loadAverage
        let text = """
        \(machine.hostname)  \(machine.productLine)  \(machine.modelID)  \(machine.coreSummary)  \(Formatters.bytes(machine.memory))
        \(machine.osVersion)
        CPU \(Formatters.percent1(host.cpu.total))  P \(Formatters.percent(host.cpu.performance))  E \(Formatters.percent(host.cpu.efficiency))  user \(Formatters.percent(host.cpu.user))  sys \(Formatters.percent(host.cpu.system))
        load \(String(format: "%.2f  %.2f  %.2f", load.0, load.1, load.2))
        RAM \(Formatters.percent(host.memory.usedRatio * 100))  \(Formatters.bytes(host.memory.used))  \(L10n.pressure) \(Formatters.percent(host.memory.pressure * 100))
        SoC \(Formatters.celsius1(thermal.soc ?? 0))  SSD \(Formatters.celsius1(thermal.storage ?? 0))  GPU \(Formatters.celsius1(thermal.gpu ?? 0))
        \(fan.units.map { "\($0.name) \(Formatters.rpm($0.rpm))" }.joined(separator: "  "))
        \(host.battery.present ? "\(L10n.battery) \(Formatters.percent(host.battery.percent))" : "")
        \(L10n.uptime) \(Formatters.duration(host.uptime))
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func apply(_ bundle: SampleBundle) {
        host = bundle.host
        thermal = bundle.thermal
        fan = bundle.fan
        selfUsage = bundle.selfUsage
        processCount = bundle.processCount == 0 ? processCount : bundle.processCount
        if !bundle.processes.isEmpty {
            if section == .processes {
                processes = bundle.processes
            }
            topProcesses = Array(bundle.processes.prefix(8))
        }
        let temp = thermal.soc ?? thermal.hottest?.celsius ?? 0
        peakCPU = max(peakCPU, host.cpu.total)
        peakTemp = max(peakTemp, temp)
        peakFan = max(peakFan, fan.rpm)
        if windowVisible, section == .dashboard {
            var next = history
            next.push(
                cpu: host.cpu.total,
                memory: host.memory.usedRatio * 100,
                temperature: temp,
                network: Double(host.network.downPerSecond + host.network.upPerSecond),
                fan: fan.rpm,
                disk: host.disk.usedRatio * 100
            )
            history = next
        }
        if !fanManual {
            fanTarget = fan.targetRPM > 0 ? fan.targetRPM : fan.rpm
        }
        let nextMenu = menuText()
        if nextMenu != lastMenu {
            lastMenu = nextMenu
            menuBarText = nextMenu
        }
        reloadWidgetsIfNeeded()
    }

    private func reloadWidgetsIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastWidgetReload) >= 30 else { return }
        lastWidgetReload = now
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func menuText() -> String {
        if preferences.paused { return L10n.paused }
        var parts: [String] = []
        if preferences.menuCPU { parts.append(Formatters.percent(host.cpu.total)) }
        if preferences.menuRAM { parts.append(Formatters.percent(host.memory.usedRatio * 100)) }
        if preferences.menuTemp {
            parts.append(Formatters.celsius(thermal.soc ?? thermal.hottest?.celsius ?? 0))
        }
        if preferences.menuFan, fan.available { parts.append("\(Int(fan.rpm))") }
        if preferences.menuBattery, host.battery.present {
            parts.append(Formatters.percent(host.battery.percent))
        }
        return parts.isEmpty ? L10n.appName : parts.joined(separator: "  ")
    }

    private func applyFan(_ command: FanCommand) {
        switch sampler.applyFan(command) {
        case .applied:
            fanStatus = nil
            fan = sampler.readFan()
        case .needsPrivilege:
            fanStatus = L10n.fanNeedsAdmin
        case .failed(let message):
            fanStatus = message
        }
    }

    static func applyAlwaysOnTop(_ enabled: Bool) {
        let app = NSApplication.shared
        for window in app.windows where window.identifier?.rawValue == "main" || window.title == L10n.appName {
            window.appearance = nil
            window.level = enabled ? .floating : .normal
        }
    }
}

private final class LiveConfig: @unchecked Sendable {
    var paused = false
    var visible = true
    var menuTemp = true
    var menuFan = true
    var section: AppSection = .dashboard
    private var ticks = 0
    private let lock = NSLock()

    func bump() -> Int {
        lock.lock()
        ticks += 1
        let value = ticks
        lock.unlock()
        return value
    }

    static func processDepth(visible: Bool, section: AppSection, ticks: Int) -> ProcessDepth {
        guard visible else { return .none }
        switch section {
        case .processes: return .all
        case .dashboard: return ticks.isMultiple(of: 3) ? .top(8) : .none
        default: return .none
        }
    }
}
