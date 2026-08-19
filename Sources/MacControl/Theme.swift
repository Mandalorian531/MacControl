import AppKit
import SwiftUI

enum Palette {
    static let accent = Token.color(light: Token.accent, dark: Token.accentDark)
    static let accentForeground = Token.color(light: Token.onAccent, dark: Token.onAccent)
    static let success = Token.color(light: Token.success, dark: Token.successDark)
    static let warning = Token.color(light: Token.warning, dark: Token.warningDark)
    static let danger = Token.color(light: Token.danger, dark: Token.dangerDark)
    static let muted = Color(nsColor: .secondaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Token.color(light: Token.cardLight, dark: Token.cardDark)
    static let stroke = Token.color(light: Token.strokeLight, dark: Token.strokeDark)
    static let track = Token.color(light: Token.trackLight, dark: Token.trackDark)
    static let widgetCard = Token.color(light: Token.widgetCardLight, dark: Token.widgetCardDark)
    static let widgetStroke = Token.color(light: Token.widgetStrokeLight, dark: Token.widgetStrokeDark)
    static let performance = accent
    static let efficiency = Token.color(light: Token.efficiency, dark: Token.efficiencyDark)
}

private enum Token {
    static let accent = RGBA(0.23, 0.51, 0.96)
    static let accentDark = RGBA(0.38, 0.62, 1.00)
    static let onAccent = RGBA(0.99, 0.99, 0.99)
    static let success = RGBA(0.20, 0.78, 0.50)
    static let successDark = RGBA(0.34, 0.82, 0.56)
    static let warning = RGBA(0.96, 0.75, 0.18)
    static let warningDark = RGBA(0.96, 0.78, 0.36)
    static let danger = RGBA(0.91, 0.35, 0.29)
    static let dangerDark = RGBA(0.95, 0.44, 0.38)
    static let efficiency = RGBA(0.42, 0.72, 0.86)
    static let efficiencyDark = RGBA(0.52, 0.78, 0.90)
    static let cardLight = RGBA(0, 0, 0, 0.045)
    static let cardDark = RGBA(1, 1, 1, 0.08)
    static let strokeLight = RGBA(0, 0, 0, 0.06)
    static let strokeDark = RGBA(1, 1, 1, 0.12)
    static let trackLight = RGBA(0, 0, 0, 0.08)
    static let trackDark = RGBA(1, 1, 1, 0.14)
    static let widgetCardLight = RGBA(1, 1, 1, 0.78)
    static let widgetCardDark = RGBA(0.11, 0.12, 0.14, 0.82)
    static let widgetStrokeLight = RGBA(0, 0, 0, 0.10)
    static let widgetStrokeDark = RGBA(1, 1, 1, 0.16)

    static func color(light: RGBA, dark: RGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let useDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = useDark ? dark : light
            return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
    }
}

private struct RGBA {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

enum TypeScale {
    static let display: Font = .system(size: 28, weight: .semibold, design: .rounded)
    static let title: Font = .system(size: 20, weight: .semibold, design: .default)
    static let headline: Font = .system(size: 15, weight: .semibold, design: .default)
    static let body: Font = .system(size: 13, weight: .regular, design: .default)
    static let caption: Font = .system(size: 11, weight: .regular, design: .default)
    static let micro: Font = .system(size: 10, weight: .medium, design: .default)
}

enum Spacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

enum Layout {
    static let cardMinHeight: CGFloat = 176
    static let sparklineHeight: CGFloat = 28
    static let coreRowHeight: CGFloat = 22
    static let widgetWidth: CGFloat = 176
    static let widgetHeight: CGFloat = 96
}

enum UsageTone {
    case calm
    case warn
    case critical

    init(ratio: Double, warnAt: Double = 0.70, criticalAt: Double = 0.90) {
        if ratio >= criticalAt {
            self = .critical
        } else if ratio >= warnAt {
            self = .warn
        } else {
            self = .calm
        }
    }

    var color: Color {
        switch self {
        case .calm: Palette.success
        case .warn: Palette.warning
        case .critical: Palette.danger
        }
    }
}

enum TemperatureTone {
    static func color(celsius: Double) -> Color {
        UsageTone(ratio: celsius / 100, warnAt: 0.75, criticalAt: 0.90).color
    }
}
