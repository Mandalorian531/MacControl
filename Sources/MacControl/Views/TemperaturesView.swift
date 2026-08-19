import MacControlCore
import SwiftUI

struct TemperaturesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(L10n.temperatures)
                    .font(TypeScale.display)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.md),
                        GridItem(.flexible(), spacing: Spacing.md),
                        GridItem(.flexible(), spacing: Spacing.md),
                        GridItem(.flexible(), spacing: Spacing.md)
                    ],
                    spacing: Spacing.md
                ) {
                    summary(L10n.soc, model.thermal.soc)
                    summary(L10n.storage, model.thermal.storage)
                    summary(L10n.gpu, model.thermal.gpu)
                    summary(L10n.hottest, model.thermal.hottest?.celsius)
                }
                ForEach(SensorGroup.allCases) { group in
                    let sensors = model.thermal.sensors.filter { $0.group == group }
                    if !sensors.isEmpty {
                        groupSection(group, sensors)
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func summary(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(TypeScale.caption)
                .foregroundStyle(Palette.muted)
            Text(value.map(Formatters.celsius1) ?? "—")
                .font(TypeScale.title)
                .foregroundStyle(TemperatureTone.color(celsius: value ?? 0))
                .monospacedDigit()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(TemperatureTone.color(celsius: value ?? 0))
                .frame(width: 3)
                .padding(.vertical, 12)
                .padding(.leading, 1)
        }
    }

    private func groupSection(_ group: SensorGroup, _ sensors: [TemperatureSensor]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(group.title)
                .font(TypeScale.headline)
            ForEach(sensors) { sensor in
                HStack {
                    Text(sensor.name)
                        .font(TypeScale.body)
                        .lineLimit(1)
                    Spacer()
                    Text(Formatters.celsius1(sensor.celsius))
                        .font(TypeScale.body)
                        .monospacedDigit()
                        .foregroundStyle(TemperatureTone.color(celsius: sensor.celsius))
                        .frame(width: 56, alignment: .trailing)
                    UsageBar(
                        ratio: min(sensor.celsius / 100, 1),
                        tone: TemperatureTone.color(celsius: sensor.celsius)
                    )
                    .frame(width: 120)
                }
            }
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }
}
