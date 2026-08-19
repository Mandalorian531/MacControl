import Foundation

public enum FanApplyResult: Sendable {
    case applied
    case needsPrivilege
    case failed(String)
}

public final class FanController: @unchecked Sendable {
    private let smc = SMCClient()

    public init() {}

    public func snapshot() -> FanSnapshot {
        smc.readFan()
    }

    public func apply(_ command: FanCommand) -> FanApplyResult {
        do {
            try smc.apply(command)
            return .applied
        } catch let error as SMCError {
            if PrivilegeHelper.isDaemonReachable() {
                return sendToDaemon(command)
            }
            switch error {
            case .writeRejected, .callFailed, .openFailed, .serviceMissing:
                return .needsPrivilege
            case .keyMissing:
                return .failed(String(describing: error))
            }
        } catch {
            if PrivilegeHelper.isDaemonReachable() {
                return sendToDaemon(command)
            }
            return .failed(String(describing: error))
        }
    }

    public func authorizeAndApply(_ command: FanCommand) -> FanApplyResult {
        if PrivilegeHelper.isDaemonReachable() {
            return sendToDaemon(command)
        }
        guard PrivilegeHelper.installDaemon() else {
            return .failed(L10n.helperFailed)
        }
        return sendToDaemon(command)
    }

    private func sendToDaemon(_ command: FanCommand) -> FanApplyResult {
        let line: String
        switch command {
        case .auto:
            line = "auto"
        case .manual(let rpm):
            line = "manual \(rpm)"
        }
        guard let reply = PrivilegeHelper.send(line) else {
            return .failed(L10n.helperFailed)
        }
        return reply.hasPrefix("ok") ? .applied : .failed(reply)
    }
}
