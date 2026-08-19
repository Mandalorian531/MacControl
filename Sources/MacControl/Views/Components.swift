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

struct UsageBar: View {
    let ratio: Double
    var tone: Color = Palette.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
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
