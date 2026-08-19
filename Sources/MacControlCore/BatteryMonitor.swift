import Foundation
import IOKit
import IOKit.ps

public final class BatteryMonitor: @unchecked Sendable {
    private var lastExtra = BatterySnapshot.missing
    private var lastExtraAt = Date.distantPast

    public init() {}

    public func snapshot() -> BatterySnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .missing
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .missing
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = description[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }
            let current = double(description[kIOPSCurrentCapacityKey])
            let capacity = Swift.max(double(description[kIOPSMaxCapacityKey]), 1)
            let extra = extraInfo()
            var minutes = int(description[kIOPSTimeToEmptyKey])
            if minutes < 0 {
                minutes = int(description[kIOPSTimeToFullChargeKey])
            }
            return BatterySnapshot(
                present: true,
                percent: min(Swift.max(current / capacity * 100, 0), 100),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isAC: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
                minutesRemaining: minutes,
                cycleCount: extra.cycleCount,
                health: extra.health
            )
        }
        return .missing
    }

    private func extraInfo() -> BatterySnapshot {
        if Date().timeIntervalSince(lastExtraAt) < 30 {
            return lastExtra
        }
        lastExtraAt = Date()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return lastExtra
        }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return lastExtra }
        defer { IOObjectRelease(service) }
        let cycles = intProperty(service, "CycleCount")
        let design = doubleProperty(service, "DesignCapacity")
        let rawMax = doubleProperty(service, "AppleRawMaxCapacity")
        let health = design > 0 ? min(max(rawMax / design, 0), 1.2) : 0
        lastExtra = BatterySnapshot(
            present: true,
            percent: 0,
            isCharging: false,
            isAC: true,
            minutesRemaining: -1,
            cycleCount: cycles,
            health: health
        )
        return lastExtra
    }

    private func double(_ value: Any?) -> Double {
        (value as? NSNumber)?.doubleValue ?? 0
    }

    private func int(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? -1
    }

    private func intProperty(_ service: io_registry_entry_t, _ key: String) -> Int {
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return 0
        }
        return raw.intValue
    }

    private func doubleProperty(_ service: io_registry_entry_t, _ key: String) -> Double {
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return 0
        }
        return raw.doubleValue
    }
}
