import Darwin
import Foundation
import IOKit

public final class HostMonitor: @unchecked Sendable {
    private var previousCPU: [CPUTicks] = []
    private var previousDisk = DiskCounters()
    private var previousNet = NetCounters()
    private var previousTimestamp = Date()
    private var cachedDisk: DiskSnapshot?
    private var cachedNetwork = NetworkSnapshot(downPerSecond: 0, upPerSecond: 0, sessionDown: 0, sessionUp: 0)
    private var sessionDown: UInt64 = 0
    private var sessionUp: UInt64 = 0
    private var lastCapacity = DiskCapacity()
    private var lastCapacityAt = Date.distantPast
    private let battery = BatteryMonitor()
    private let pCoreCount = MachineInfo.current.performanceCores

    public init() {}

    public func snapshot(diskIO: Bool, network: Bool = true) -> HostSnapshot {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(previousTimestamp), 0.2)
        previousTimestamp = now
        return HostSnapshot(
            cpu: readCPU(),
            memory: readMemory(),
            disk: readDisk(elapsed: elapsed, includeIO: diskIO),
            network: readNetwork(elapsed: elapsed, include: network),
            battery: battery.snapshot(),
            uptime: readUptime(),
            loadAverage: readLoad(),
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }

    private func readCPU() -> CPUSnapshot {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let status = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &infoArray,
            &infoCount
        )
        guard status == KERN_SUCCESS, let infoArray else {
            return CPUSnapshot(total: 0, cores: [], user: 0, system: 0, idle: 100, performance: 0, efficiency: 0)
        }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoArray), size)
        }

        var cores: [CoreLoad] = []
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        var nextPrevious: [CPUTicks] = []
        let loadInfo = infoArray.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) { $0 }

        for index in 0..<Int(cpuCount) {
            let ticks = CPUTicks(
                user: UInt64(loadInfo[index].cpu_ticks.0),
                system: UInt64(loadInfo[index].cpu_ticks.1),
                idle: UInt64(loadInfo[index].cpu_ticks.2),
                nice: UInt64(loadInfo[index].cpu_ticks.3)
            )
            nextPrevious.append(ticks)
            let previous = previousCPU.indices.contains(index) ? previousCPU[index] : ticks
            let delta = ticks.delta(from: previous)
            cores.append(CoreLoad(id: index, usage: delta.usage, isPerformance: index < pCoreCount))
            totalUser += delta.userRatio * 100
            totalSystem += delta.systemRatio * 100
            totalIdle += delta.idleRatio * 100
        }
        previousCPU = nextPrevious
        let count = max(Double(cpuCount), 1)
        let pCores = cores.filter(\.isPerformance)
        let eCores = cores.filter { !$0.isPerformance }
        return CPUSnapshot(
            total: cores.map(\.usage).reduce(0, +) / count,
            cores: cores,
            user: totalUser / count,
            system: totalSystem / count,
            idle: totalIdle / count,
            performance: average(pCores),
            efficiency: average(eCores)
        )
    }

    private func readMemory() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        let page = UInt64(getpagesize())
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        guard status == KERN_SUCCESS else {
            return MemorySnapshot(total: total, used: 0, app: 0, wired: 0, compressed: 0, cached: 0, free: total, swapUsed: 0, pressure: 0)
        }
        let free = UInt64(stats.free_count) * page
        let speculative = UInt64(stats.speculative_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let app = UInt64(stats.internal_page_count) * page
        let cached = UInt64(stats.external_page_count) * page
        let used = min(total, app + wired + compressed)
        let swap = readSwap()
        let pressure = memoryPressure(used: used, compressed: compressed, swap: swap, total: total)
        return MemorySnapshot(
            total: total,
            used: used,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free + speculative,
            swapUsed: swap,
            pressure: pressure
        )
    }

    private func readSwap() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        var mib: [Int32] = [CTL_VM, VM_SWAPUSAGE]
        guard sysctl(&mib, 2, &usage, &size, nil, 0) == 0 else { return 0 }
        return UInt64(usage.xsu_used)
    }

    private func readDisk(elapsed: TimeInterval, includeIO: Bool) -> DiskSnapshot {
        if Date().timeIntervalSince(lastCapacityAt) > 20 {
            lastCapacity = DiskCapacity.current()
            lastCapacityAt = Date()
        }
        let capacity = lastCapacity
        guard includeIO else {
            return cachedDisk ?? DiskSnapshot(
                total: capacity.total,
                used: capacity.used,
                free: capacity.free,
                readPerSecond: 0,
                writePerSecond: 0,
                volumeName: capacity.volumeName
            )
        }
        let counters = DiskCounters.current()
        let readDelta = counters.readBytes &- previousDisk.readBytes
        let writeDelta = counters.writeBytes &- previousDisk.writeBytes
        previousDisk = counters
        let snapshot = DiskSnapshot(
            total: capacity.total,
            used: capacity.used,
            free: capacity.free,
            readPerSecond: UInt64(Double(readDelta) / elapsed),
            writePerSecond: UInt64(Double(writeDelta) / elapsed),
            volumeName: capacity.volumeName
        )
        cachedDisk = snapshot
        return snapshot
    }

    private func average(_ cores: [CoreLoad]) -> Double {
        guard !cores.isEmpty else { return 0 }
        return cores.map(\.usage).reduce(0, +) / Double(cores.count)
    }

    private func memoryPressure(used: UInt64, compressed: UInt64, swap: UInt64, total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        let base = Double(used) / Double(total)
        let extra = swap > 0 ? 0.15 : Double(compressed) / Double(total) * 0.25
        return min(base + extra, 1)
    }

    private func readNetwork(elapsed: TimeInterval, include: Bool) -> NetworkSnapshot {
        guard include else { return cachedNetwork }
        let counters = NetCounters.current()
        let hasBaseline = previousNet.ibytes > 0 || previousNet.obytes > 0
        let down = counters.ibytes &- previousNet.ibytes
        let up = counters.obytes &- previousNet.obytes
        previousNet = counters
        guard hasBaseline else { return cachedNetwork }
        sessionDown &+= down
        sessionUp &+= up
        let snapshot = NetworkSnapshot(
            downPerSecond: UInt64(Double(down) / elapsed),
            upPerSecond: UInt64(Double(up) / elapsed),
            sessionDown: sessionDown,
            sessionUp: sessionUp
        )
        cachedNetwork = snapshot
        return snapshot
    }

    private func readUptime() -> TimeInterval {
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0 else { return 0 }
        return Date().timeIntervalSince1970 - Double(boot.tv_sec)
    }

    private func readLoad() -> (Double, Double, Double) {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return (0, 0, 0) }
        return (loads[0], loads[1], loads[2])
    }
}

private struct CPUTicks {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    func delta(from previous: CPUTicks) -> CPUDelta {
        let user = Double((user &- previous.user) + (nice &- previous.nice))
        let system = Double(system &- previous.system)
        let idle = Double(idle &- previous.idle)
        let total = max(user + system + idle, 1)
        return CPUDelta(
            usage: (user + system) / total * 100,
            userRatio: user / total,
            systemRatio: system / total,
            idleRatio: idle / total
        )
    }
}

private struct CPUDelta {
    var usage: Double
    var userRatio: Double
    var systemRatio: Double
    var idleRatio: Double
}

private struct DiskCapacity {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var free: UInt64 = 0
    var volumeName = "/"

    static func current() -> DiskCapacity {
        var stats = statfs()
        guard statfs("/", &stats) == 0 else { return DiskCapacity() }
        let total = UInt64(stats.f_blocks) * UInt64(stats.f_bsize)
        let free = UInt64(stats.f_bavail) * UInt64(stats.f_bsize)
        let name = (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? "/"
        return DiskCapacity(
            total: total,
            used: total > free ? total - free : 0,
            free: free,
            volumeName: name
        )
    }
}

private struct DiskCounters {
    var readBytes: UInt64 = 0
    var writeBytes: UInt64 = 0

    static func current() -> DiskCounters {
        var counters = DiskCounters()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBlockStorageDriver"),
            &iterator
        ) == KERN_SUCCESS else {
            return counters
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                counters.readBytes &+= (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                counters.writeBytes &+= (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return counters
    }
}

private struct NetCounters {
    var ibytes: UInt64 = 0
    var obytes: UInt64 = 0

    static func current() -> NetCounters {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else {
            return NetCounters()
        }
        defer { freeifaddrs(addrs) }
        var counters = NetCounters()
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = current {
            let name = String(cString: pointer.pointee.ifa_name)
            if name != "lo0", let data = pointer.pointee.ifa_data {
                let network = data.assumingMemoryBound(to: if_data.self).pointee
                counters.ibytes &+= UInt64(network.ifi_ibytes)
                counters.obytes &+= UInt64(network.ifi_obytes)
            }
            current = pointer.pointee.ifa_next
        }
        return counters
    }
}
