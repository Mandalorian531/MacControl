import MacControlCore
import SwiftUI

struct MetricCard<Content: View>: View {
    let title: String
    let value: String
    let detail: String?
    let tone: Color
    var symbol: String = "circle"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: symbol)
                    .font(TypeScale.caption)
                    .foregroundStyle(tone)
                    .frame(width: 16)
                Text(title)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(value)
                    .font(TypeScale.headline)
                    .foregroundStyle(tone)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Text(detail ?? " ")
                .font(TypeScale.caption)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minHeight: Layout.cardMinHeight)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tone)
                .frame(width: 3)
                .padding(.vertical, 12)
                .padding(.leading, 1)
        }
    }
}

struct MetricStats: View {
    let items: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Text(item.0)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(item.1)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .font(TypeScale.caption)
        .frame(minHeight: 34, alignment: .top)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var tone: Color = Palette.accent
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(TypeScale.micro)
                        .foregroundStyle(tone)
                }
                Text(title)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Text(value)
                .font(TypeScale.headline)
                .foregroundStyle(tone)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let detail {
                Text(detail)
                    .font(TypeScale.micro)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(Palette.track, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ShareBar: View {
    let slices: [(ratio: Double, tone: Color)]

    var body: some View {
        let visible = slices.filter { $0.ratio > 0 }
        let total = visible.reduce(0.0) { $0 + $1.ratio }
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                HStack(spacing: 2) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, slice in
                        let share = total > 0 ? slice.ratio / total : 0
                        let gutter = CGFloat(max(visible.count - 1, 0)) * 2
                        Capsule()
                            .fill(slice.tone)
                            .frame(width: max(4, (geo.size.width - gutter) * share))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 10)
        .clipped()
    }
}

struct UsageBar: View {
    let ratio: Double
    var tone: Color = Palette.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                Capsule()
                    .fill(tone)
                    .frame(width: max(4, geo.size.width * min(max(ratio, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

struct Sparkline: View {
    let values: [Double]
    var tone: Color = Palette.accent

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxValue = max(values.max() ?? 1, 1)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height - (size.height * CGFloat(value / maxValue))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(tone), lineWidth: 1.5)
        }
        .frame(height: Layout.sparklineHeight)
    }
}

struct HistoryStore {
    private(set) var cpu: [Double] = []
    private(set) var memory: [Double] = []
    private(set) var temperature: [Double] = []
    private(set) var network: [Double] = []
    private(set) var fan: [Double] = []
    private(set) var disk: [Double] = []

    mutating func push(cpu: Double, memory: Double, temperature: Double, network: Double, fan: Double, disk: Double) {
        self.cpu.append(cpu)
        self.memory.append(memory)
        self.temperature.append(temperature)
        self.network.append(network)
        self.fan.append(fan)
        self.disk.append(disk)
        if self.cpu.count > 32 {
            self.cpu.removeFirst()
            self.memory.removeFirst()
            self.temperature.removeFirst()
            self.network.removeFirst()
            self.fan.removeFirst()
            self.disk.removeFirst()
        }
    }
}

func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: L10n.nominal
    case .fair: L10n.fair
    case .serious: L10n.serious
    case .critical: L10n.critical
    @unknown default: L10n.nominal
    }
}

func thermalColor(_ state: ProcessInfo.ThermalState) -> Color {
    switch state {
    case .nominal: Palette.success
    case .fair: Palette.warning
    case .serious, .critical: Palette.danger
    @unknown default: Palette.success
    }
}

func junkKindTone(_ kind: JunkKind) -> Color {
    switch kind {
    case .userCache: Palette.accent
    case .browser: Palette.efficiency
    case .logs: Palette.muted
    case .developer: Palette.success
    case .hidden: Palette.warning
    case .temporary: Palette.efficiency
    case .backup: Palette.danger
    case .trash: Palette.muted
    }
}
