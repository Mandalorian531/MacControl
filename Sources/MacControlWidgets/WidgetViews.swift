import MacControlCore
import SwiftUI

struct MetricWidgetView: View {
    let metric: WidgetMetric
    let entry: SampleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: metric.symbol)
                    .foregroundStyle(tone)
                Text(metric.title)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .font(.caption)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tone)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Gauge(value: ratio) {
                Text(metric.title)
            }
            .gaugeStyle(.linearCapacity)
            .tint(tone)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var value: String {
        switch metric {
        case .cpu: Formatters.percent(entry.host.cpu.total)
        case .memory: Formatters.percent(entry.host.memory.usedRatio * 100)
        case .temperature:
            entry.thermal.soc.map(Formatters.celsius)
                ?? entry.thermal.hottest.map { Formatters.celsius($0.celsius) }
                ?? "—"
        case .fan: entry.fan.available ? Formatters.rpm(entry.fan.rpm) : "—"
        case .battery: entry.host.battery.present ? Formatters.percent(entry.host.battery.percent) : "—"
        case .disk: Formatters.percent(entry.host.disk.usedRatio * 100)
        }
    }

    private var detail: String {
        switch metric {
        case .cpu:
            return "\(L10n.pCores) \(Formatters.percent(entry.host.cpu.performance))  \(L10n.eCores) \(Formatters.percent(entry.host.cpu.efficiency))"
        case .memory:
            return "\(Formatters.bytes(entry.host.memory.used))  \(L10n.pressure) \(Formatters.percent(entry.host.memory.pressure * 100))"
        case .temperature:
            return entry.thermal.storage.map { "SSD \(Formatters.celsius($0))" } ?? ""
        case .fan:
            return entry.fan.available ? (entry.fan.isManual ? L10n.manual : L10n.auto) : L10n.noFan
        case .battery:
            if !entry.host.battery.present { return L10n.desktopMac }
            return entry.host.battery.isCharging
                ? L10n.charging
                : (entry.host.battery.isAC ? L10n.onAC : L10n.onBattery)
        case .disk:
            return "\(Formatters.bytes(entry.host.disk.free)) \(L10n.free)"
        }
    }

    private var ratio: Double {
        switch metric {
        case .cpu: min(max(entry.host.cpu.total / 100, 0), 1)
        case .memory: min(max(entry.host.memory.usedRatio, 0), 1)
        case .temperature:
            min(max((entry.thermal.soc ?? entry.thermal.hottest?.celsius ?? 0) / 100, 0), 1)
        case .fan: min(max(entry.fan.ratio, 0), 1)
        case .battery: min(max(entry.host.battery.percent / 100, 0), 1)
        case .disk: min(max(entry.host.disk.usedRatio, 0), 1)
        }
    }

    private var tone: Color {
        switch metric {
        case .cpu, .memory, .disk: WidgetTone.usage(ratio)
        case .temperature: WidgetTone.usage((entry.thermal.soc ?? entry.thermal.hottest?.celsius ?? 0) / 100)
        case .fan: entry.fan.isManual ? .orange : .accentColor
        case .battery: WidgetTone.usage(1 - ratio)
        }
    }
}

struct OverviewWidgetView: View {
    let entry: SampleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.appName)
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                overviewCell(
                    L10n.cpu,
                    Formatters.percent(entry.host.cpu.total),
                    WidgetTone.usage(entry.host.cpu.total / 100)
                )
                overviewCell(
                    L10n.memory,
                    Formatters.percent(entry.host.memory.usedRatio * 100),
                    WidgetTone.usage(entry.host.memory.usedRatio)
                )
                overviewCell(
                    L10n.temperatures,
                    entry.thermal.soc.map(Formatters.celsius)
                        ?? entry.thermal.hottest.map { Formatters.celsius($0.celsius) }
                        ?? "—",
                    WidgetTone.usage((entry.thermal.soc ?? entry.thermal.hottest?.celsius ?? 0) / 100)
                )
                overviewCell(
                    L10n.disk,
                    Formatters.percent(entry.host.disk.usedRatio * 100),
                    WidgetTone.usage(entry.host.disk.usedRatio)
                )
            }
            HStack {
                if entry.fan.available {
                    labeled(L10n.fan, Formatters.rpm(entry.fan.rpm))
                }
                if entry.host.battery.present {
                    labeled(L10n.battery, Formatters.percent(entry.host.battery.percent))
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func overviewCell(_ title: String, _ value: String, _ tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tone)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        Text("\(title) \(value)")
            .monospacedDigit()
    }
}

enum WidgetTone {
    static func usage(_ ratio: Double) -> Color {
        if ratio >= 0.90 { return .red }
        if ratio >= 0.70 { return .orange }
        return .green
    }
}
