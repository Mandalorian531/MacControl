import MacControlCore
import SwiftUI

struct FanView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.fan)
                        .font(TypeScale.display)
                    Spacer()
                    if model.peakFan > 0 {
                        Text("\(L10n.peak) \(Formatters.rpm(model.peakFan))")
                            .font(TypeScale.caption)
                            .foregroundStyle(Palette.muted)
                    }
                }
                if model.fan.available {
                    if model.fan.units.count > 1 {
                        multiGauges
                    }
                    gauge
                    controls
                    Text(L10n.fanHint)
                        .font(TypeScale.caption)
                        .foregroundStyle(Palette.muted)
                    if let status = model.fanStatus {
                        Text(status)
                            .font(TypeScale.caption)
                            .foregroundStyle(status == L10n.helperReady ? Palette.success : Palette.warning)
                    }
                    if model.fanStatus == L10n.fanNeedsAdmin {
                        Button(L10n.authorize) {
                            model.authorizeControl()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text(model.fan.message ?? L10n.noFan)
                        .font(TypeScale.body)
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var multiGauges: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(model.fan.units.count) \(L10n.fans.lowercased())")
                .font(TypeScale.headline)
            ForEach(model.fan.units) { unit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(unit.name)
                            .font(TypeScale.body)
                        Spacer()
                        Text(Formatters.rpm(unit.rpm))
                            .font(TypeScale.body)
                            .monospacedDigit()
                    }
                    UsageBar(ratio: unit.ratio, tone: Palette.accent)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }

    private var gauge: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.fanSpeed)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                Text(Formatters.rpm(model.fan.rpm))
                    .font(TypeScale.display)
                    .monospacedDigit()
                Sparkline(values: model.history.fan, tone: Palette.accent)
                UsageBar(ratio: model.fan.ratio, tone: Palette.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.target)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.muted)
                Text(Formatters.rpm(model.fanTarget))
                    .font(TypeScale.display)
                    .monospacedDigit()
                Text(model.fanManual ? L10n.manual : L10n.auto)
                    .font(TypeScale.caption)
                    .foregroundStyle(model.fanManual ? Palette.warning : Palette.success)
                UsageBar(
                    ratio: {
                        let span = max(model.fan.maxRPM - model.fan.minRPM, 1)
                        return min(max((model.fanTarget - model.fan.minRPM) / span, 0), 1)
                    }(),
                    tone: model.fanManual ? Palette.warning : Palette.accent
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: Layout.cardMinHeight, alignment: .top)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Toggle(L10n.manual, isOn: Binding(
                get: { model.fanManual },
                set: { model.setManual($0) }
            ))
            .toggleStyle(.switch)
            Slider(
                value: Binding(
                    get: { model.fanTarget },
                    set: { model.scheduleFanTarget($0) }
                ),
                in: model.fan.minRPM...max(model.fan.maxRPM, model.fan.minRPM + 1),
                step: 50
            )
            .disabled(!model.fanManual)
            HStack {
                Text(Formatters.rpm(model.fan.minRPM))
                Spacer()
                Text(Formatters.rpm(model.fan.maxRPM))
            }
            .font(TypeScale.caption)
            .foregroundStyle(Palette.muted)
            if model.fanManual {
                Button(L10n.restoreAuto) {
                    model.setManual(false)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }
}
