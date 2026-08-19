import Darwin
import Foundation
import IOKit

public enum MachineFamily: String, Sendable {
    case macBookAir
    case macBookPro
    case macMini
    case macStudio
    case iMac
    case macPro
    case unknown

    public var title: String {
        switch self {
        case .macBookAir: L10n.macBookAir
        case .macBookPro: L10n.macBookPro
        case .macMini: L10n.macMini
        case .macStudio: L10n.macStudio
        case .iMac: L10n.iMac
        case .macPro: L10n.macPro
        case .unknown: L10n.appleSilicon
        }
    }

    public var isLaptop: Bool {
        self == .macBookAir || self == .macBookPro
    }
}

public struct MachineInfo: Sendable {
    public var chip: String
    public var modelID: String
    public var family: MachineFamily
    public var performanceCores: Int
    public var efficiencyCores: Int
    public var memory: UInt64
    public var osVersion: String
    public var hostname: String
    public var isAppleSilicon: Bool

    public var coreSummary: String {
        if efficiencyCores > 0 {
            return "\(performanceCores)P + \(efficiencyCores)E"
        }
        return "\(performanceCores + efficiencyCores)"
    }

    public var productLine: String {
        "\(family.title) · \(chip)"
    }

    public static let current = MachineInfo.read()

    private static func read() -> MachineInfo {
        let modelID = sysctlString("hw.model") ?? platformString("model") ?? "Mac"
        let product = platformString("product-name") ?? platformString("marketing-name") ?? ""
        let chip = sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        let levels = sysctlInt("hw.nperflevels") ?? 2
        let performance = sysctlInt("hw.perflevel0.physicalcpu") ?? sysctlInt("hw.physicalcpu") ?? 0
        var efficiency = 0
        if levels > 1 {
            for level in 1..<levels {
                efficiency += sysctlInt("hw.perflevel\(level).physicalcpu") ?? 0
            }
        }
        return MachineInfo(
            chip: chip,
            modelID: modelID,
            family: family(modelID: modelID, product: product, chip: chip),
            performanceCores: performance,
            efficiencyCores: efficiency,
            memory: UInt64(ProcessInfo.processInfo.physicalMemory),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hostname: sysctlString("kern.hostname") ?? Host.current().localizedName ?? "Mac",
            isAppleSilicon: sysctlInt("hw.optional.arm64") == 1
        )
    }

    private static func family(modelID: String, product: String, chip: String) -> MachineFamily {
        let blob = "\(modelID) \(product) \(chip)".lowercased()
        if modelID.hasPrefix("MacBookAir") || blob.contains("macbook air") { return .macBookAir }
        if modelID.hasPrefix("MacBookPro") || blob.contains("macbook pro") { return .macBookPro }
        if modelID.hasPrefix("Macmini") || blob.contains("mac mini") { return .macMini }
        if blob.contains("mac studio") || studioIDs.contains(modelID) { return .macStudio }
        if modelID.hasPrefix("iMac") || blob.contains("imac") { return .iMac }
        if modelID.hasPrefix("MacPro") || blob.contains("mac pro") { return .macPro }
        if miniIDs.contains(modelID) { return .macMini }
        if iMacIDs.contains(modelID) { return .iMac }
        if airIDs.contains(modelID) { return .macBookAir }
        if proIDs.contains(modelID) { return .macBookPro }
        return .unknown
    }

    private static let miniIDs: Set<String> = [
        "Mac14,3", "Mac14,12", "Mac16,10", "Mac16,11"
    ]
    private static let studioIDs: Set<String> = [
        "Mac13,1", "Mac13,2", "Mac14,13", "Mac14,14"
    ]
    private static let iMacIDs: Set<String> = [
        "Mac15,4", "Mac15,5", "Mac16,2", "Mac16,3"
    ]
    private static let airIDs: Set<String> = [
        "Mac14,2", "Mac14,15", "Mac15,12", "Mac15,13", "Mac16,6", "Mac16,7", "Mac16,12", "Mac16,13"
    ]
    private static let proIDs: Set<String> = [
        "Mac14,5", "Mac14,6", "Mac14,7", "Mac14,9", "Mac14,10",
        "Mac15,3", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11",
        "Mac16,1", "Mac16,5", "Mac16,8"
    ]

    private static func platformString(_ key: String) -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }
        if let text = raw as? String {
            return text.trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
        }
        if let data = raw as? Data {
            return String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
        }
        return nil
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        if let end = buffer.firstIndex(of: 0) {
            return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return String(decoding: buffer.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.stride
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}
