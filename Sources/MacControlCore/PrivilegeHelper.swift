import Darwin
import Foundation

public enum PrivilegeHelper {
    public static let socketPath = "/tmp/com.cgs.maccontrol.smc.sock"
    public static let label = "com.cgs.maccontrol.smc"

    public static func helperURL() -> URL? {
        if let bundled = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("smc-helper"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        let neighbors = [
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("smc-helper"),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent("smc-helper")
        ]
        for url in neighbors.compactMap({ $0 }) where FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
        return nil
    }

    public static func isDaemonReachable() -> Bool {
        send("ping") == "ok"
    }

    public static func send(_ line: String) -> String? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketPath
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 104) { raw in
                _ = path.withCString { strncpy(raw, $0, 103) }
            }
        }

        let connected = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                connect(fd, raw, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return nil }

        let payload = line + "\n"
        _ = payload.withCString { Darwin.send(fd, $0, strlen($0), 0) }
        var buffer = [CChar](repeating: 0, count: 256)
        let received = recv(fd, &buffer, buffer.count - 1, 0)
        guard received > 0 else { return nil }
        let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func installDaemon() -> Bool {
        guard let helper = helperURL() else { return false }
        let script = """
        do shell script "\(escaped(helper.path)) install-daemon" with administrator privileges
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 && isDaemonReachable()
        } catch {
            return false
        }
    }

    private static func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
