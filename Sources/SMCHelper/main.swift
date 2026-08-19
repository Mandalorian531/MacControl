import Darwin
import Foundation
import MacControlCore

@main
struct SMCHelperMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            fputs("usage: smc-helper read|auto|manual <rpm>|daemon|install-daemon\n", stderr)
            exit(2)
        }

        switch command {
        case "read":
            let fan = SMCClient().readFan()
            if fan.units.isEmpty {
                print(fan.message ?? "no-fan")
            } else {
                for unit in fan.units {
                    print("fan\(unit.id) name=\(unit.name) rpm=\(Int(unit.rpm)) min=\(Int(unit.minRPM)) max=\(Int(unit.maxRPM)) target=\(Int(unit.targetRPM)) mode=\(unit.mode)")
                }
            }
        case "auto":
            apply(.auto)
        case "manual":
            guard let rpm = args.dropFirst().first.flatMap(Int.init) else {
                fputs("manual needs an rpm\n", stderr)
                exit(2)
            }
            apply(.manual(rpm: rpm))
        case "daemon":
            runDaemon()
        case "install-daemon":
            installDaemon()
        default:
            fputs("unknown command \(command)\n", stderr)
            exit(2)
        }
    }

    static func apply(_ command: FanCommand) {
        do {
            try SMCClient().apply(command)
            print("ok")
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func runDaemon() {
        unlink(PrivilegeHelper.socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { exit(1) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = PrivilegeHelper.socketPath.withCString { path in
            withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 104) { raw in
                    strncpy(raw, path, 103)
                }
            }
        }
        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                bind(fd, raw, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(fd, 4) == 0 else { exit(1) }
        chmod(PrivilegeHelper.socketPath, 0o666)

        let client = SMCClient()
        while true {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { continue }
            var buffer = [CChar](repeating: 0, count: 256)
            let received = recv(clientFD, &buffer, buffer.count - 1, 0)
            guard received > 0 else {
                close(clientFD)
                continue
            }
            let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
            let line = String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reply = handle(line, client: client)
            _ = reply.withCString { Darwin.send(clientFD, $0, strlen($0), 0) }
            close(clientFD)
        }
    }

    static func handle(_ line: String, client: SMCClient) -> String {
        let parts = line.split(separator: " ").map(String.init)
        do {
            switch parts.first {
            case "ping":
                return "ok"
            case "auto":
                try client.apply(.auto)
                return "ok"
            case "manual":
                guard let rpm = parts.dropFirst().first.flatMap(Int.init) else {
                    return "error bad-rpm"
                }
                try client.apply(.manual(rpm: rpm))
                return "ok"
            default:
                return "error unknown"
            }
        } catch {
            return "error \(error)"
        }
    }

    static func installDaemon() {
        let source = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let dest = URL(fileURLWithPath: "/usr/local/libexec/maccontrol-smc")
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            fputs("copy failed: \(error)\n", stderr)
            exit(1)
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(PrivilegeHelper.label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(dest.path)</string>
                <string>daemon</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
        </dict>
        </plist>
        """
        let plistURL = URL(fileURLWithPath: "/Library/LaunchDaemons/\(PrivilegeHelper.label).plist")
        do {
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("plist failed: \(error)\n", stderr)
            exit(1)
        }

        _ = bootout()
        let load = Process()
        load.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        load.arguments = ["bootstrap", "system", plistURL.path]
        try? load.run()
        load.waitUntilExit()
        if load.terminationStatus != 0 {
            fputs("launchctl bootstrap failed\n", stderr)
            exit(1)
        }
        print("ok")
    }

    static func bootout() -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "system/\(PrivilegeHelper.label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
