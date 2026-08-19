import AppKit
import Darwin
import Foundation
import UniformTypeIdentifiers

public final class ProcessMonitor: @unchecked Sendable {
    private var previousCPU: [Int32: UInt64] = [:]
    private var previousDate = Date()
    private var previousSelfCPU: UInt64 = 0
    private var previousSelfDate = Date()
    private var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    private var nameBuffer = [CChar](repeating: 0, count: 256)
    nonisolated(unsafe) private static let icons = NSCache<NSString, NSImage>()

    public init() {
        Self.icons.countLimit = 64
    }

    public func snapshot(depth: ProcessDepth) -> (rows: [ProcessSnapshot], count: Int) {
        guard case .none = depth else {
            return collect(depth: depth)
        }
        return ([], 0)
    }

    private func collect(depth: ProcessDepth) -> (rows: [ProcessSnapshot], count: Int) {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(previousDate), 0.2)
        previousDate = now

        let pids = listedPIDs()
        var nextCPU: [Int32: UInt64] = [:]
        var rows: [ProcessSnapshot] = []
        rows.reserveCapacity(min(pids.count, 256))

        for pid in pids where pid > 0 {
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let rawName = cString(nameBuffer)
            guard !rawName.isEmpty else { continue }

            var info = proc_taskinfo()
            let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.stride))
            guard size == MemoryLayout<proc_taskinfo>.stride else { continue }

            let totalTicks = info.pti_total_user + info.pti_total_system
            nextCPU[pid] = totalTicks
            let previous = previousCPU[pid] ?? totalTicks
            let cpu = max(Double(totalTicks &- previous) / 1_000_000_000 / elapsed * 100, 0)
            rows.append(
                ProcessSnapshot(
                    pid: pid,
                    name: rawName,
                    path: "",
                    cpu: cpu,
                    memory: info.pti_resident_size,
                    threadCount: info.pti_threadnum,
                    isApple: false
                )
            )
        }
        previousCPU = nextCPU
        rows.sort { $0.cpu > $1.cpu }

        let limit: Int?
        switch depth {
        case .none: limit = 0
        case .top(let count): limit = count
        case .all: limit = nil
        }
        let sliced = limit.map { Array(rows.prefix($0)) } ?? rows
        let resolved = sliced.map { row in
            let pathLength = proc_pidpath(row.pid, &pathBuffer, UInt32(MAXPATHLEN))
            let path = pathLength > 0 ? cString(pathBuffer) : ""
            return ProcessSnapshot(
                pid: row.pid,
                name: Self.displayName(path: path, fallback: row.name),
                path: path,
                cpu: row.cpu,
                memory: row.memory,
                threadCount: row.threadCount,
                isApple: Self.isApple(path: path, name: row.name)
            )
        }
        return (resolved, rows.count)
    }

    public func selfUsage() -> SelfSnapshot {
        let pid = ProcessInfo.processInfo.processIdentifier
        var info = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.stride))
        guard size == MemoryLayout<proc_taskinfo>.stride else {
            return SelfSnapshot(cpu: 0, memory: 0)
        }
        let now = Date()
        let elapsed = max(now.timeIntervalSince(previousSelfDate), 0.2)
        let total = info.pti_total_user + info.pti_total_system
        let cpu: Double
        if previousSelfCPU == 0 {
            cpu = 0
        } else {
            cpu = max(Double(total &- previousSelfCPU) / 1_000_000_000 / elapsed * 100, 0)
        }
        previousSelfCPU = total
        previousSelfDate = now
        return SelfSnapshot(cpu: cpu, memory: info.pti_resident_size)
    }

    public func terminate(pid: Int32, force: Bool) -> Bool {
        kill(pid, force ? SIGKILL : SIGTERM) == 0
    }

    public static func icon(for path: String) -> NSImage {
        let key = (path.isEmpty ? "exec" : path) as NSString
        if let cached = icons.object(forKey: key) {
            return cached
        }
        let image: NSImage
        if path.isEmpty {
            image = NSWorkspace.shared.icon(for: .unixExecutable)
        } else if let app = path.components(separatedBy: ".app").first, path.contains(".app") {
            image = NSWorkspace.shared.icon(forFile: app + ".app")
        } else {
            image = NSWorkspace.shared.icon(forFile: path)
        }
        image.size = NSSize(width: 16, height: 16)
        icons.setObject(image, forKey: key)
        return image
    }

    private func listedPIDs() -> [Int32] {
        let capacity = 4096
        var pids = [Int32](repeating: 0, count: capacity)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.stride * capacity))
        guard bytes > 0 else { return [] }
        return Array(pids.prefix(Int(bytes) / MemoryLayout<pid_t>.stride))
    }

    private func cString(_ buffer: [CChar]) -> String {
        buffer.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return "" }
            return String(cString: base)
        }
    }

    private static func displayName(path: String, fallback: String) -> String {
        if let range = path.range(of: ".app/") {
            let prefix = String(path[..<range.lowerBound])
            if let bundle = prefix.split(separator: "/").last {
                return String(bundle)
            }
        }
        if let last = path.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }
        return fallback
    }

    private static func isApple(path: String, name: String) -> Bool {
        path.hasPrefix("/System/")
            || path.hasPrefix("/usr/")
            || path.contains("/Library/Apple/")
            || name == "kernel_task"
            || name == "launchd"
            || name.hasPrefix("com.apple.")
    }
}
