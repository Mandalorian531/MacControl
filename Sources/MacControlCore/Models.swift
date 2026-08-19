import Foundation

public struct CoreLoad: Identifiable, Sendable {
    public var id: Int
    public var usage: Double
    public var isPerformance: Bool
}

public struct CPUSnapshot: Sendable {
    public var total: Double
    public var cores: [CoreLoad]
    public var user: Double
    public var system: Double
    public var idle: Double
    public var performance: Double
    public var efficiency: Double
}

public struct MemorySnapshot: Sendable {
    public var total: UInt64
    public var used: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64
    public var free: UInt64
    public var swapUsed: UInt64
    public var pressure: Double

    public var usedRatio: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
}

public struct DiskSnapshot: Sendable {
    public var total: UInt64
    public var used: UInt64
    public var free: UInt64
    public var readPerSecond: UInt64
    public var writePerSecond: UInt64
    public var volumeName: String

    public var usedRatio: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
}

public struct NetworkSnapshot: Sendable {
    public var downPerSecond: UInt64
    public var upPerSecond: UInt64
    public var sessionDown: UInt64
    public var sessionUp: UInt64
}

public struct SelfSnapshot: Sendable {
    public var cpu: Double
    public var memory: UInt64

    public init(cpu: Double, memory: UInt64) {
        self.cpu = cpu
        self.memory = memory
    }
}

public struct BatterySnapshot: Sendable {
    public var present: Bool
    public var percent: Double
    public var isCharging: Bool
    public var isAC: Bool
    public var minutesRemaining: Int
    public var cycleCount: Int
    public var health: Double

    public static let missing = BatterySnapshot(
        present: false,
        percent: 0,
        isCharging: false,
        isAC: true,
        minutesRemaining: -1,
        cycleCount: 0,
        health: 0
    )
}

public struct HostSnapshot: Sendable {
    public var cpu: CPUSnapshot
    public var memory: MemorySnapshot
    public var disk: DiskSnapshot
    public var network: NetworkSnapshot
    public var battery: BatterySnapshot
    public var uptime: TimeInterval
    public var loadAverage: (Double, Double, Double)
    public var thermalState: ProcessInfo.ThermalState
}

public enum SensorGroup: String, Sendable, CaseIterable, Identifiable {
    case soc
    case gpu
    case pmu2
    case board
    case storage
    case battery
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .soc: L10n.soc
        case .gpu: L10n.gpu
        case .pmu2: "PMU 2"
        case .board: L10n.board
        case .storage: L10n.storage
        case .battery: L10n.battery
        case .other: L10n.other
        }
    }
}

public struct TemperatureSensor: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var celsius: Double
    public var group: SensorGroup
}

public struct ThermalSnapshot: Sendable {
    public var sensors: [TemperatureSensor]
    public var hottest: TemperatureSensor?
    public var soc: Double?
    public var storage: Double?
    public var gpu: Double?

    public static let empty = ThermalSnapshot(sensors: [], hottest: nil, soc: nil, storage: nil, gpu: nil)
}

public struct FanUnit: Identifiable, Sendable {
    public var id: Int
    public var name: String
    public var rpm: Double
    public var minRPM: Double
    public var maxRPM: Double
    public var targetRPM: Double
    public var mode: UInt8

    public var isManual: Bool { mode == 1 }

    public var ratio: Double {
        let span = max(maxRPM - minRPM, 1)
        return min(max((rpm - minRPM) / span, 0), 1)
    }
}

public struct FanSnapshot: Sendable {
    public var units: [FanUnit]
    public var message: String?

    public static let empty = FanSnapshot(units: [], message: nil)

    public var available: Bool { !units.isEmpty }
    public var rpm: Double { units.map(\.rpm).max() ?? 0 }
    public var minRPM: Double { units.map(\.minRPM).min() ?? 0 }
    public var maxRPM: Double { units.map(\.maxRPM).max() ?? 1 }
    public var targetRPM: Double { units.map(\.targetRPM).max() ?? 0 }
    public var mode: UInt8 { units.contains(where: \.isManual) ? 1 : 0 }
    public var isManual: Bool { mode == 1 }

    public var ratio: Double {
        let span = max(maxRPM - minRPM, 1)
        return min(max((rpm - minRPM) / span, 0), 1)
    }
}

public struct ProcessSnapshot: Identifiable, Sendable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    public var path: String
    public var cpu: Double
    public var memory: UInt64
    public var threadCount: Int32
    public var isApple: Bool
}

public enum ProcessDepth: Sendable {
    case none
    case top(Int)
    case all
}

public struct SampleRequest: Sendable {
    public var processes: ProcessDepth
    public var fullSensors: Bool
    public var diskIO: Bool
    public var fan: Bool
    public var thermal: Bool
    public var network: Bool

    public init(
        processes: ProcessDepth,
        fullSensors: Bool,
        diskIO: Bool,
        fan: Bool,
        thermal: Bool = true,
        network: Bool = true
    ) {
        self.processes = processes
        self.fullSensors = fullSensors
        self.diskIO = diskIO
        self.fan = fan
        self.thermal = thermal
        self.network = network
    }
}

public struct SampleBundle: Sendable {
    public var host: HostSnapshot
    public var thermal: ThermalSnapshot
    public var fan: FanSnapshot
    public var processes: [ProcessSnapshot]
    public var processCount: Int
    public var selfUsage: SelfSnapshot
}

public enum FanCommand: Sendable {
    case auto
    case manual(rpm: Int)
}
