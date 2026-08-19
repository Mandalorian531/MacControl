import MacControlCore
import SwiftUI
import WidgetKit

@main
struct MacControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        OverviewWidget()
        CPUWidget()
        MemoryWidget()
        TemperatureWidget()
        FanWidget()
        BatteryWidget()
        DiskWidget()
    }
}

enum WidgetMetric: String, CaseIterable {
    case cpu
    case memory
    case temperature
    case fan
    case battery
    case disk

    var widgetKind: String { "com.cgs.maccontrol.\(rawValue)" }

    var title: String {
        switch self {
        case .cpu: L10n.cpu
        case .memory: L10n.memory
        case .temperature: L10n.temperatures
        case .fan: L10n.fan
        case .battery: L10n.battery
        case .disk: L10n.disk
        }
    }

    var summary: String {
        switch self {
        case .cpu: L10n.widgetCPUHint
        case .memory: L10n.widgetRAMHint
        case .temperature: L10n.widgetTempHint
        case .fan: L10n.widgetFanHint
        case .battery: L10n.widgetBatteryHint
        case .disk: L10n.widgetDiskHint
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .temperature: "thermometer.medium"
        case .fan: "fan"
        case .battery: "battery.100"
        case .disk: "internaldrive"
        }
    }
}

struct SampleEntry: TimelineEntry {
    let date: Date
    let host: HostSnapshot
    let thermal: ThermalSnapshot
    let fan: FanSnapshot

    static var placeholder: SampleEntry {
        let empty = MetricsSampler().sample(
            SampleRequest(processes: .none, fullSensors: false, diskIO: false, fan: false, thermal: false, network: false)
        )
        return SampleEntry(date: Date(), host: empty.host, thermal: .empty, fan: .empty)
    }
}

enum WidgetSampler {
    static let shared = MetricsSampler()
    private static let request = SampleRequest(
        processes: .none,
        fullSensors: false,
        diskIO: false,
        fan: true,
        thermal: true,
        network: false
    )

    static func capture(accurateCPU: Bool) -> SampleEntry {
        if accurateCPU {
            _ = shared.sample(request)
            Thread.sleep(forTimeInterval: 0.28)
        }
        let bundle = shared.sample(request)
        return SampleEntry(date: Date(), host: bundle.host, thermal: bundle.thermal, fan: bundle.fan)
    }
}

struct SampleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SampleEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SampleEntry) -> Void) {
        completion(WidgetSampler.capture(accurateCPU: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SampleEntry>) -> Void) {
        let entry = WidgetSampler.capture(accurateCPU: true)
        let next = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CPUWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.cpu) }
}

struct MemoryWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.memory) }
}

struct TemperatureWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.temperature) }
}

struct FanWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.fan) }
}

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.battery) }
}

struct DiskWidget: Widget {
    var body: some WidgetConfiguration { metricConfiguration(.disk) }
}

@MainActor
func metricConfiguration(_ metric: WidgetMetric) -> some WidgetConfiguration {
    StaticConfiguration(kind: metric.widgetKind, provider: SampleProvider()) { entry in
        MetricWidgetView(metric: metric, entry: entry)
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "maccontrol://open"))
    }
    .configurationDisplayName(metric.title)
    .description(metric.summary)
    .supportedFamilies([.systemSmall, .systemMedium])
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.cgs.maccontrol.overview", provider: SampleProvider()) { entry in
            OverviewWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "maccontrol://open"))
        }
        .configurationDisplayName(L10n.dashboard)
        .description(L10n.widgetOverviewHint)
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
