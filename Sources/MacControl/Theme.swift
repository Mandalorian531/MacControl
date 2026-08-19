import SwiftUI

enum Palette {
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let accentForeground = Color(red: 0.99, green: 0.99, blue: 0.99)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.50)
    static let warning = Color(red: 0.96, green: 0.75, blue: 0.18)
    static let danger = Color(red: 0.91, green: 0.35, blue: 0.29)
    static let muted = Color.secondary
    static let card = Color.primary.opacity(0.045)
    static let stroke = Color.primary.opacity(0.06)
    static let performance = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let efficiency = Color(red: 0.42, green: 0.72, blue: 0.86)
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
