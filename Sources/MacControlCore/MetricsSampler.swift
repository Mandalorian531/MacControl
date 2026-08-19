import Foundation

public final class MetricsSampler: @unchecked Sendable {
    private let host = HostMonitor()
    private let thermal = ThermalMonitor()
    private let processes = ProcessMonitor()
    private let fans = FanController()
    private var lastThermal = ThermalSnapshot.empty
    private var lastFan = FanSnapshot.empty

    public init() {}

    public func sample(_ request: SampleRequest) -> SampleBundle {
        let processResult = processes.snapshot(depth: request.processes)
        if request.thermal {
            lastThermal = thermal.snapshot(detail: request.fullSensors)
        }
        if request.fan {
            lastFan = fans.snapshot()
        }
        return SampleBundle(
            host: host.snapshot(diskIO: request.diskIO, network: request.network),
            thermal: lastThermal,
            fan: lastFan,
            processes: processResult.rows,
            processCount: processResult.count,
            selfUsage: processes.selfUsage()
        )
    }

    public func terminate(pid: Int32, force: Bool) -> Bool {
        processes.terminate(pid: pid, force: force)
    }

    public func applyFan(_ command: FanCommand) -> FanApplyResult {
        fans.apply(command)
    }

    public func authorizeFan(_ command: FanCommand) -> FanApplyResult {
        fans.authorizeAndApply(command)
    }

    public func readFan() -> FanSnapshot {
        fans.snapshot()
    }
}
