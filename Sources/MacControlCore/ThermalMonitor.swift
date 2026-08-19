import CoreFoundation
import Foundation
import IOKit

public final class ThermalMonitor: @unchecked Sendable {
    private var client: IOHIDEventSystemClientRef?
    private var services: [CachedSensor] = []
    private let lock = NSLock()

    public init() {}

    public func snapshot(detail: Bool) -> ThermalSnapshot {
        lock.lock()
        defer { lock.unlock() }
        ensureClient()
        var sensors: [TemperatureSensor] = []
        if detail {
            sensors.reserveCapacity(services.count)
        }
        var hottest: TemperatureSensor?
        var soc: Double?
        var storage: Double?
        var gpu: Double?
        for item in services {
            guard let event = IOHIDServiceClientCopyEvent(item.service, Int64(kIOHIDEventTypeTemperature), 0, 0) else {
                continue
            }
            let celsius = IOHIDEventGetFloatValue(event, IOHIDEventField(kIOHIDEventTypeTemperature << 16))
            guard celsius.isFinite, celsius > 1, celsius < 120 else { continue }
            let sensor = TemperatureSensor(id: item.id, name: item.name, celsius: celsius, group: item.group)
            if hottest == nil || celsius > (hottest?.celsius ?? 0) {
                hottest = sensor
            }
            switch item.group {
            case .soc: soc = max(soc ?? celsius, celsius)
            case .storage: storage = max(storage ?? celsius, celsius)
            case .gpu: gpu = max(gpu ?? celsius, celsius)
            default: break
            }
            if detail {
                sensors.append(sensor)
            }
        }
        if detail {
            sensors.sort { $0.celsius > $1.celsius }
        }
        return ThermalSnapshot(sensors: sensors, hottest: hottest, soc: soc, storage: storage, gpu: gpu)
    }

    private func ensureClient() {
        if client != nil { return }
        guard let created = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return }
        client = created
        let matching: NSDictionary = [
            "PrimaryUsagePage": 0xFF00,
            "PrimaryUsage": 5
        ]
        IOHIDEventSystemClientSetMatching(created, matching)
        guard let copied = IOHIDEventSystemClientCopyServices(created) as? [AnyObject] else { return }
        services = copied.enumerated().compactMap { index, service in
            let product = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String ?? "Sensor"
            if product.localizedCaseInsensitiveContains("tcal") { return nil }
            return CachedSensor(
                service: service,
                id: "\(product)#\(index)",
                name: Self.displayName(product),
                group: Self.group(for: product)
            )
        }
    }

    private static func group(for product: String) -> SensorGroup {
        let name = product.lowercased()
        if name.contains("nand") || name.contains("ssd") || name.contains("storage") { return .storage }
        if name.contains("gpu") || name.contains("gfx") { return .gpu }
        if name.contains("battery") || name.contains("gas") || name.contains("ggbat") { return .battery }
        if name.contains("pmu2") && name.contains("tdie") { return .pmu2 }
        if name.contains("tdie") || name.contains("soc") || name.contains("cpu") || name.contains("die") {
            return .soc
        }
        if name.contains("tdev") || name.contains("skin") || name.contains("palm") || name.contains("ambient") {
            return .board
        }
        return .other
    }

    private static func displayName(_ product: String) -> String {
        if product.localizedCaseInsensitiveContains("NAND") {
            return "SSD"
        }
        return product
            .replacingOccurrences(of: "PMU2 ", with: "PMU 2 ")
            .replacingOccurrences(of: "tdie", with: "die ")
            .replacingOccurrences(of: "tdev", with: "board ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

private struct CachedSensor {
    var service: AnyObject
    var id: String
    var name: String
    var group: SensorGroup
}

private let kIOHIDEventTypeTemperature = 15

private typealias IOHIDEventSystemClientRef = CFTypeRef
private typealias IOHIDServiceClientRef = CFTypeRef
private typealias IOHIDEventRef = CFTypeRef
private typealias IOHIDEventField = UInt32

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClientRef?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: IOHIDEventSystemClientRef, _ matching: CFDictionary?)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: IOHIDEventSystemClientRef) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: IOHIDServiceClientRef, _ key: CFString) -> AnyObject?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(
    _ service: IOHIDServiceClientRef,
    _ type: Int64,
    _ options: Int32,
    _ timeout: Int32
) -> IOHIDEventRef?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: IOHIDEventRef, _ field: IOHIDEventField) -> Double
