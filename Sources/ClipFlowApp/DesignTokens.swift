import SwiftUI

// MARK: - Spacing

enum ClipFlowSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
    static let panelPadding: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let inputPaddingH: CGFloat = 14
    static let inputPaddingV: CGFloat = 11
}

// MARK: - Corner Radius

enum ClipFlowRadius {
    static let panel: CGFloat = 28
    static let overlay: CGFloat = 26
    static let hudPanel: CGFloat = 24
    static let card: CGFloat = 20
    static let menuHeader: CGFloat = 20
    static let innerCard: CGFloat = 18
    static let input: CGFloat = 16
    static let menuRow: CGFloat = 16
    static let button: CGFloat = 15
    static let menuButton: CGFloat = 14
    static let hudButton: CGFloat = 13
    static let badge: CGFloat = 12
    static let icon: CGFloat = 12
    static let smallIcon: CGFloat = 9
}

// MARK: - Typography

enum ClipFlowTypography {
    static let heroTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let overlayTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let menuTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let settingsTitle = Font.system(size: 16, weight: .semibold)
    static let blockTitle = Font.system(size: 15, weight: .semibold)
    static let cardTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .medium)
    static let bodyBold = Font.system(size: 13, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)
    static let captionBold = Font.system(size: 12, weight: .semibold)
    static let captionCode = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let smallCaption = Font.system(size: 11, weight: .medium)
    static let smallCaptionBold = Font.system(size: 11, weight: .semibold)
    static let badge = Font.system(size: 10, weight: .bold)
    static let tinyBadge = Font.system(size: 9, weight: .bold)

    static let metricValue = Font.system(size: 24, weight: .bold, design: .rounded)
    static let overviewValue = Font.system(size: 22, weight: .bold, design: .rounded)
    static let statValue = Font.system(size: 18, weight: .bold, design: .rounded)
    static let cardSnippet = Font.system(size: 16, weight: .bold, design: .rounded)
    static let hudSnippet = Font.system(size: 13, weight: .bold, design: .rounded)
    static let hudLabel = Font.system(size: 13, weight: .bold, design: .rounded)
}

// MARK: - Palette

struct ClipFlowPalette {
    let backgroundStart: Color
    let backgroundMiddle: Color
    let backgroundEnd: Color
    let orbA: Color
    let orbB: Color
    let border: Color
    let shadow: Color
    let softFill: Color
    let inputFill: Color
    let primaryButtonFill: Color
    let secondaryButtonFill: Color

    static func resolve(for colorScheme: ColorScheme) -> ClipFlowPalette {
        if colorScheme == .dark {
            return ClipFlowPalette(
                backgroundStart: Color(red: 0.09, green: 0.10, blue: 0.14),
                backgroundMiddle: Color(red: 0.12, green: 0.14, blue: 0.18),
                backgroundEnd: Color(red: 0.09, green: 0.12, blue: 0.16),
                orbA: Color(red: 0.83, green: 0.55, blue: 0.28).opacity(0.28),
                orbB: Color(red: 0.25, green: 0.58, blue: 0.88).opacity(0.24),
                border: Color.white.opacity(0.10),
                shadow: Color.black.opacity(0.34),
                softFill: Color(red: 0.13, green: 0.15, blue: 0.20),
                inputFill: Color(red: 0.17, green: 0.19, blue: 0.25),
                primaryButtonFill: Color(red: 0.30, green: 0.59, blue: 0.92),
                secondaryButtonFill: Color(red: 0.20, green: 0.22, blue: 0.28)
            )
        }

        return ClipFlowPalette(
            backgroundStart: Color(red: 0.95, green: 0.95, blue: 0.96),
            backgroundMiddle: Color(red: 0.95, green: 0.95, blue: 0.96),
            backgroundEnd: Color(red: 0.95, green: 0.95, blue: 0.96),
            orbA: Color.clear,
            orbB: Color.clear,
            border: Color.black.opacity(0.08),
            shadow: Color.black.opacity(0.10),
            softFill: Color.white,
            inputFill: Color(red: 0.93, green: 0.93, blue: 0.94),
            primaryButtonFill: Color(red: 0.30, green: 0.59, blue: 0.92),
            secondaryButtonFill: Color(red: 0.90, green: 0.90, blue: 0.93)
        )
    }
}
