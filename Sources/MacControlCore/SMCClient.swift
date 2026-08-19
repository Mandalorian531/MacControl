import Darwin
import Foundation
import IOKit

public enum SMCError: Error, Sendable {
    case serviceMissing
    case openFailed
    case callFailed(kern_return_t)
    case keyMissing(String)
    case writeRejected
}

public struct SMCValue: Sendable {
    public var bytes: [UInt8]
    public var type: String
    public var size: UInt32

    public var ui8: UInt8? { bytes.first }
    public var ui32: UInt32? {
        guard bytes.count >= 4 else { return nil }
        return bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }
    }

    public var floatLE: Float? {
        guard bytes.count >= 4 else { return nil }
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
    }

    public var text: String? {
        let cleaned = bytes.filter { $0 >= 32 && $0 < 127 }
        guard !cleaned.isEmpty else { return nil }
        return String(bytes: cleaned, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var number: Double? {
        switch type.trimmingCharacters(in: .whitespaces) {
        case "flt":
            return floatLE.map(Double.init)
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4
        case "ui8":
            return bytes.first.map(Double.init)
        case "ui16", "flag":
            guard bytes.count >= 2 else { return bytes.first.map(Double.init) }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            return ui32.map(Double.init)
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        default:
            if let float = floatLE, float.isFinite, float > 0, float < 20_000 { return Double(float) }
            if bytes.count >= 2 {
                let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
                let fpe = Double(raw) / 4
                if fpe > 200, fpe < 12_000 { return fpe }
            }
            return bytes.first.map(Double.init)
        }
    }

    public static func encode(_ value: Double, type: String) -> [UInt8] {
        switch type.trimmingCharacters(in: .whitespaces) {
        case "flt":
            var number = Float(value)
            return withUnsafeBytes(of: &number) { Array($0) }
        case "fpe2":
            let raw = UInt16(clamping: Int((value * 4).rounded()))
            return [UInt8(raw >> 8), UInt8(raw & 0xFF)]
        case "ui8", "flag":
            return [UInt8(clamping: Int(value.rounded()))]
        case "ui16":
            let raw = UInt16(clamping: Int(value.rounded()))
            return [UInt8(raw >> 8), UInt8(raw & 0xFF)]
        default:
            var number = Float(value)
            return withUnsafeBytes(of: &number) { Array($0) }
        }
    }
}

public final class SMCClient: @unchecked Sendable {
    private var connection: io_connect_t = 0
    private let lock = NSLock()

    public init() {}

    deinit {
        close()
    }

    public func open() throws {
        lock.lock()
        defer { lock.unlock() }
        if connection != 0 { return }
        for name in ["AppleSMCKeysEndpoint", "AppleSMC"] {
            if let opened = Self.openService(name) {
                connection = opened
                return
            }
        }
        throw SMCError.serviceMissing
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    public func read(_ key: String) throws -> SMCValue {
        try open()
        lock.lock()
        defer { lock.unlock() }

        var infoIn = SMCParamStruct()
        var infoOut = SMCParamStruct()
        infoIn.key = key.smcKey
        infoIn.data8 = SMCCommand.readKeyInfo.rawValue
        let infoStatus = Self.call(connection, input: &infoIn, output: &infoOut)
        guard infoStatus == KERN_SUCCESS else { throw SMCError.callFailed(infoStatus) }
        guard infoOut.result == 0, infoOut.keyInfo.dataSize > 0 else {
            throw SMCError.keyMissing(key)
        }

        var readIn = SMCParamStruct()
        var readOut = SMCParamStruct()
        readIn.key = key.smcKey
        readIn.keyInfo = infoOut.keyInfo
        readIn.data8 = SMCCommand.readBytes.rawValue
        let readStatus = Self.call(connection, input: &readIn, output: &readOut)
        guard readStatus == KERN_SUCCESS else { throw SMCError.callFailed(readStatus) }
        guard readOut.result == 0 else { throw SMCError.keyMissing(key) }

        let size = Int(infoOut.keyInfo.dataSize)
        let bytes = withUnsafeBytes(of: readOut.bytes) { Array($0.prefix(size)) }
        return SMCValue(bytes: bytes, type: infoOut.keyInfo.dataType.fourCC, size: infoOut.keyInfo.dataSize)
    }

    public func write(_ key: String, bytes: [UInt8]) throws {
        try open()
        lock.lock()
        defer { lock.unlock() }

        var infoIn = SMCParamStruct()
        var infoOut = SMCParamStruct()
        infoIn.key = key.smcKey
        infoIn.data8 = SMCCommand.readKeyInfo.rawValue
        let infoStatus = Self.call(connection, input: &infoIn, output: &infoOut)
        guard infoStatus == KERN_SUCCESS else { throw SMCError.callFailed(infoStatus) }
        guard infoOut.result == 0, infoOut.keyInfo.dataSize > 0 else {
            throw SMCError.keyMissing(key)
        }

        var writeIn = SMCParamStruct()
        var writeOut = SMCParamStruct()
        writeIn.key = key.smcKey
        writeIn.keyInfo = infoOut.keyInfo
        writeIn.data8 = SMCCommand.writeBytes.rawValue
        writeIn.setBytes(bytes)
        let writeStatus = Self.call(connection, input: &writeIn, output: &writeOut)
        guard writeStatus == KERN_SUCCESS else { throw SMCError.callFailed(writeStatus) }
        guard writeOut.result == 0 else { throw SMCError.writeRejected }
    }

    public func writeFloat(_ key: String, _ value: Float) throws {
        try writeNumeric(key, Double(value))
    }

    public func writeUInt8(_ key: String, _ value: UInt8) throws {
        try writeNumeric(key, Double(value))
    }

    public func writeNumeric(_ key: String, _ value: Double) throws {
        let info = try read(key)
        try write(key, bytes: SMCValue.encode(value, type: info.type))
    }

    public func readFan() -> FanSnapshot {
        do {
            let count = Int(try read("FNum").number ?? 0)
            guard count > 0 else {
                let message = MachineInfo.current.family == .macBookAir ? L10n.fanless : L10n.noFan
                return FanSnapshot(units: [], message: message)
            }
            let forced = forcedMask()
            let units = (0..<min(count, 8)).compactMap { index -> FanUnit? in
                readUnit(index: index, forced: forced)
            }
            if units.isEmpty {
                return FanSnapshot(units: [], message: L10n.noFan)
            }
            return FanSnapshot(units: units, message: nil)
        } catch {
            return FanSnapshot(units: [], message: L10n.noFan)
        }
    }

    public func apply(_ command: FanCommand) throws {
        let snapshot = readFan()
        guard !snapshot.units.isEmpty else { throw SMCError.keyMissing("FNum") }
        switch command {
        case .auto:
            for unit in snapshot.units {
                try setMode(index: unit.id, manual: false)
            }
            try setForceMask(0)
        case .manual(let rpm):
            var mask = 0
            for unit in snapshot.units {
                let clamped = min(max(Double(rpm), unit.minRPM), unit.maxRPM)
                try setMode(index: unit.id, manual: true)
                try writeTarget(index: unit.id, rpm: clamped)
                mask |= 1 << unit.id
            }
            try setForceMask(mask)
        }
    }

    private func readUnit(index: Int, forced: Int) -> FanUnit? {
        guard let rpm = (try? read(key("F", index, "Ac")))?.number, rpm.isFinite else {
            return nil
        }
        let minRPM = (try? read(key("F", index, "Mn")))?.number ?? 800
        let maxRPM = (try? read(key("F", index, "Mx")))?.number ?? max(minRPM + 1, 6000)
        let target = (try? read(key("F", index, "Tg")))?.number
            ?? (try? read(key("F", index, "Mt")))?.number
            ?? rpm
        let modeValue = (try? read(key("F", index, "Md")))?.number
        let mode: UInt8
        if let modeValue {
            mode = modeValue > 0 ? 1 : 0
        } else {
            mode = (forced & (1 << index)) != 0 ? 1 : 0
        }
        let name = (try? read(key("F", index, "ID")))?.text
        return FanUnit(
            id: index,
            name: name?.isEmpty == false ? name! : "\(L10n.fan) \(index + 1)",
            rpm: rpm,
            minRPM: minRPM,
            maxRPM: max(maxRPM, minRPM + 1),
            targetRPM: target,
            mode: mode
        )
    }

    private func setMode(index: Int, manual: Bool) throws {
        let name = key("F", index, "Md")
        if (try? read(name)) != nil {
            try writeNumeric(name, manual ? 1 : 0)
        }
    }

    private func writeTarget(index: Int, rpm: Double) throws {
        if (try? read(key("F", index, "Tg"))) != nil {
            try writeNumeric(key("F", index, "Tg"), rpm)
            return
        }
        if (try? read(key("F", index, "Mt"))) != nil {
            try writeNumeric(key("F", index, "Mt"), rpm)
        }
    }

    private func forcedMask() -> Int {
        Int((try? read("FS!"))?.number ?? 0)
    }

    private func setForceMask(_ mask: Int) throws {
        guard (try? read("FS!")) != nil else { return }
        try writeNumeric("FS!", Double(mask))
    }

    private func key(_ prefix: String, _ index: Int, _ suffix: String) -> String {
        "\(prefix)\(index)\(suffix)"
    }

    private static func openService(_ name: String) -> io_connect_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(name), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        let device = IOIteratorNext(iterator)
        guard device != 0 else { return nil }
        defer { IOObjectRelease(device) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(device, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            return nil
        }
        return connection
    }

    private static func call(
        _ connection: io_connect_t,
        input: inout SMCParamStruct,
        output: inout SMCParamStruct
    ) -> kern_return_t {
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        return withUnsafePointer(to: &input) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(connection, 2, inputPointer, inputSize, outputPointer, &outputSize)
            }
        }
    }
}

private enum SMCCommand: UInt8 {
    case writeBytes = 6
    case readBytes = 5
    case readKeyInfo = 9
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = (
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
    )

    mutating func setBytes(_ data: [UInt8]) {
        withUnsafeMutableBytes(of: &bytes) { buffer in
            for (index, byte) in data.prefix(32).enumerated() {
                buffer[index] = byte
            }
        }
    }
}

private extension String {
    var smcKey: UInt32 {
        utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }
    }
}

private extension UInt32 {
    var fourCC: String {
        let bytes = [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF)
        ]
        return String(bytes: bytes.filter { $0 != 0 }, encoding: .macOSRoman) ?? ""
    }
}
