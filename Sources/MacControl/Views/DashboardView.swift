import MacControlCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    cpuCard
                    memoryCard
                    if model.host.battery.present {
                        batteryCard
                    }
                    diskCard
                    networkCard
                    tempCard
                    if model.fan.available || model.machine.family.isLaptop {
                        fanCard
                    }
                }
                topProcesses
            }
            .padding(Spacing.lg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.dashboard)
                    .font(TypeScale.display)
                Spacer()
                Button(model.preferences.paused ? L10n.resume : L10n.pause) {
                    model.togglePause()
                }
                .controlSize(.small)
                Button(L10n.copySnapshot) {
                    model.copySnapshot()
                }
                .controlSize(.small)
                Button(L10n.resetPeaks) {
                    model.resetPeaks()
                }
                .controlSize(.small)
            }
            Text("\(model.machine.hostname) · \(model.machine.productLine) · \(model.machine.coreSummary) · \(Formatters.bytes(model.machine.memory))")
                .font(TypeScale.caption)
                .foregroundStyle(Palette.muted)
            HStack(spacing: Spacing.md) {
                Text("\(L10n.uptime) \(Formatters.duration(model.host.uptime))")
                Text("\(L10n.load15) \(loadText)")
                Text("\(L10n.thermalState) \(thermalLabel(model.host.thermalState))")
                    .foregroundStyle(thermalColor(model.host.thermalState))
                if model.preferences.paused {
                    Text(L10n.paused)
                        .foregroundStyle(Palette.warning)
                }
            }
            .font(TypeScale.caption)
            .foregroundStyle(Palette.muted)
        }
    }

    private var cpuCard: some View {
        MetricCard(
            title: L10n.cpu,
            value: Formatters.percent(model.host.cpu.total),
            detail: "\(L10n.pCores) \(Formatters.percent(model.host.cpu.performance))   \(L10n.eCores) \(Formatters.percent(model.host.cpu.efficiency))   \(L10n.peak) \(Formatters.percent(model.peakCPU))",
            tone: UsageTone(ratio: model.host.cpu.total / 100).color,
            symbol: "cpu"
        ) {
            Sparkline(values: model.history.cpu, tone: Palette.accent)
            HStack(spacing: 3) {
                ForEach(model.host.cpu.cores) { core in
                    UsageBar(
                        ratio: core.usage / 100,
                        tone: core.isPerformance ? Palette.performance : Palette.efficiency
                    )
                }
            }
            MetricStats(items: [
                (L10n.userCPU, Formatters.percent(model.host.cpu.user)),
                (L10n.systemCPU, Formatters.percent(model.host.cpu.system)),
                (L10n.idle, Formatters.percent(model.host.cpu.idle)),
                (L10n.peak, Formatters.percent(model.peakCPU))
            ])
        }
    }

    private var memoryCard: some View {
        let memory = model.host.memory
        return MetricCard(
            title: L10n.memory,
            value: Formatters.percent(memory.usedRatio * 100),
            detail: "\(Formatters.bytes(memory.used)) / \(Formatters.bytes(memory.total))   \(L10n.pressure) \(Formatters.percent(memory.pressure * 100))",
            tone: UsageTone(ratio: memory.usedRatio).color,
            symbol: "memorychip"
        ) {
            Sparkline(values: model.history.memory, tone: UsageTone(ratio: memory.usedRatio).color)
            UsageBar(ratio: memory.usedRatio, tone: UsageTone(ratio: memory.usedRatio).color)
            MetricStats(items: [
                (L10n.used, Formatters.bytes(memory.app)),
                (L10n.wired, Formatters.bytes(memory.wired)),
                (L10n.compressed, Formatters.bytes(memory.compressed)),
                memory.swapUsed > 0
                    ? (L10n.swap, Formatters.bytes(memory.swapUsed))
                    : (L10n.cached, Formatters.bytes(memory.cached))
            ])
        }
    }

    private var diskCard: some View {
        let disk = model.host.disk
        return MetricCard(
            title: disk.volumeName.isEmpty ? L10n.disk : disk.volumeName,
            value: Formatters.percent(disk.usedRatio * 100),
            detail: "\(Formatters.bytes(disk.free)) \(L10n.free.lowercased())   \(Formatters.bytes(disk.used)) / \(Formatters.bytes(disk.total))",
            tone: UsageTone(ratio: disk.usedRatio, warnAt: 0.85, criticalAt: 0.95).color,
            symbol: "internaldrive"
        ) {
            Sparkline(
                values: model.history.disk,
                tone: UsageTone(ratio: disk.usedRatio, warnAt: 0.85, criticalAt: 0.95).color
            )
            UsageBar(
                ratio: disk.usedRatio,
                tone: UsageTone(ratio: disk.usedRatio, warnAt: 0.85, criticalAt: 0.95).color
            )
            MetricStats(items: [
                (L10n.read, Formatters.bytesPerSecond(disk.readPerSecond)),
                (L10n.write, Formatters.bytesPerSecond(disk.writePerSecond)),
                (L10n.used, Formatters.bytes(disk.used)),
                (L10n.free, Formatters.bytes(disk.free))
            ])
        }
    }

    private var networkCard: some View {
        MetricCard(
            title: L10n.network,
            value: Formatters.bytesPerSecond(model.host.network.downPerSecond),
            detail: "\(L10n.upload) \(Formatters.bytesPerSecond(model.host.network.upPerSecond))",
            tone: Palette.accent,
            symbol: "network"
        ) {
            Sparkline(values: model.history.network, tone: Palette.accent)
            UsageBar(
                ratio: min(Double(model.host.network.downPerSecond + model.host.network.upPerSecond) / 2_000_000, 1),
                tone: Palette.accent
            )
            MetricStats(items: [
                (L10n.download, Formatters.bytesPerSecond(model.host.network.downPerSecond)),
                (L10n.upload, Formatters.bytesPerSecond(model.host.network.upPerSecond)),
                ("↓ \(L10n.session)", Formatters.bytes(model.host.network.sessionDown)),
                ("↑ \(L10n.session)", Formatters.bytes(model.host.network.sessionUp))
            ])
        }
    }

    private var tempCard: some View {
        let value = model.thermal.soc ?? model.thermal.hottest?.celsius ?? 0
        return MetricCard(
            title: L10n.soc,
            value: Formatters.celsius(value),
            detail: "SSD \(Formatters.celsius1(model.thermal.storage ?? 0))   GPU \(Formatters.celsius1(model.thermal.gpu ?? 0))   \(L10n.peak) \(Formatters.celsius(model.peakTemp))",
            tone: TemperatureTone.color(celsius: value),
            symbol: "thermometer.medium"
        ) {
            Sparkline(values: model.history.temperature, tone: TemperatureTone.color(celsius: value))
            UsageBar(ratio: min(value / 100, 1), tone: TemperatureTone.color(celsius: value))
            MetricStats(items: [
                (L10n.storage, Formatters.celsius1(model.thermal.storage ?? 0)),
                (L10n.gpu, Formatters.celsius1(model.thermal.gpu ?? 0)),
                (L10n.hottest, Formatters.celsius1(model.thermal.hottest?.celsius ?? value)),
                (L10n.peak, Formatters.celsius(model.peakTemp))
            ])
        }
    }

    private var fanCard: some View {
        MetricCard(
            title: L10n.fan,
            value: model.fan.available ? Formatters.rpm(model.fan.rpm) : "—",
            detail: model.fan.available
                ? "\(model.fan.units.count) · \(model.fan.isManual ? L10n.manual : L10n.auto)   \(L10n.peak) \(Formatters.rpm(model.peakFan))"
                : model.fan.message,
            tone: UsageTone(ratio: model.fan.ratio, warnAt: 0.75, criticalAt: 0.92).color,
            symbol: "fan"
        ) {
            Sparkline(values: model.history.fan, tone: Palette.accent)
            UsageBar(ratio: model.fan.ratio, tone: Palette.accent)
            MetricStats(items: fanStats)
        }
    }

    private var fanStats: [(String, String)] {
        if model.fan.units.count > 1 {
            return model.fan.units.prefix(4).map { ($0.name, Formatters.rpm($0.rpm)) }
        }
        return [
            (L10n.target, Formatters.rpm(model.fan.targetRPM)),
            (model.fan.isManual ? L10n.manual : L10n.auto, Formatters.rpm(model.peakFan))
        ]
    }

    private var batteryCard: some View {
        let battery = model.host.battery
        let detail = battery.isCharging ? L10n.charging : (battery.isAC ? L10n.onAC : L10n.onBattery)
        return MetricCard(
            title: L10n.battery,
            value: Formatters.percent(battery.percent),
            detail: [
                detail,
                battery.cycleCount > 0 ? "\(L10n.cycles) \(battery.cycleCount)" : nil,
                battery.minutesRemaining > 0 ? Formatters.minutes(battery.minutesRemaining) : nil
            ].compactMap { $0 }.joined(separator: "   "),
            tone: UsageTone(ratio: 1 - battery.percent / 100, warnAt: 0.80, criticalAt: 0.92).color,
            symbol: battery.isCharging ? "battery.100.bolt" : "battery.100"
        ) {
            Sparkline(values: [battery.percent], tone: UsageTone(ratio: 1 - battery.percent / 100, warnAt: 0.80, criticalAt: 0.92).color)
            UsageBar(
                ratio: battery.percent / 100,
                tone: UsageTone(ratio: 1 - battery.percent / 100, warnAt: 0.80, criticalAt: 0.92).color
            )
            MetricStats(items: [
                (battery.isCharging ? L10n.charging : (battery.isAC ? L10n.onAC : L10n.onBattery), Formatters.minutes(battery.minutesRemaining)),
                (L10n.cycles, battery.cycleCount > 0 ? "\(battery.cycleCount)" : "—"),
                (L10n.health, battery.health > 0 ? Formatters.percent(battery.health * 100) : "—"),
                (L10n.peak, Formatters.percent(battery.percent))
            ])
        }
    }

    private var topProcesses: some View {
        Panel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(L10n.topProcesses)
                        .font(TypeScale.headline)
                    Spacer()
                    if model.processCount > 0 {
                        Text("\(model.processCount) \(L10n.processCount)")
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                    }
                }
                ForEach(model.topProcesses) { process in
                    HStack {
                        Image(nsImage: ProcessMonitor.icon(for: process.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(process.name)
                            .font(TypeScale.body)
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.percent1(process.cpu))
                            .font(TypeScale.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                        Text(Formatters.bytes(process.memory))
                            .font(TypeScale.caption)
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                    }
                    .help(process.path)
                }
            }
        }
    }

    private var loadText: String {
        let load = model.host.loadAverage
        return String(format: "%.2f  %.2f  %.2f", load.0, load.1, load.2)
    }

}
