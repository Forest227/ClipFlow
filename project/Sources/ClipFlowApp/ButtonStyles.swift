import SwiftUI

// MARK: - Unified Button Style

enum ClipFlowButtonSize {
    case regular
    case compact
    case dense
}

struct ClipFlowButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary
    var size: ClipFlowButtonSize = .regular

    private var fontSize: CGFloat {
        switch size {
        case .regular: 13
        case .compact: 12
        case .dense: 12
        }
    }

    private var paddingH: CGFloat {
        switch size {
        case .regular: 14
        case .compact: 12
        case .dense: 13
        }
    }

    private var paddingV: CGFloat {
        switch size {
        case .regular: 10
        case .compact: 8
        case .dense: 8
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .regular: ClipFlowRadius.button
        case .compact: ClipFlowRadius.hudButton
        case .dense: ClipFlowRadius.hudButton
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .animation(ClipFlowMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Menu Button Styles

enum MenuButtonLayout {
    case compact
    case footer
    case tile
    case row
}

struct MenuActionButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary
    var layout: MenuButtonLayout = .compact

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .modifier(MenuButtonLayoutModifier(layout: layout, fill: fill, isPressed: configuration.isPressed))
            .animation(ClipFlowMotion.press, value: configuration.isPressed)
    }
}

private struct MenuButtonLayoutModifier: ViewModifier {
    let layout: MenuButtonLayout
    let fill: Color
    let isPressed: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    func body(content: Content) -> some View {
        switch layout {
        case .compact:
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .scaleEffect(isPressed ? 0.985 : 1)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .fill(fill.opacity(isPressed ? 0.78 : 1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

        case .footer:
            content
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .scaleEffect(isPressed ? 0.985 : 1)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .fill(fill.opacity(isPressed ? 0.78 : 1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

        case .tile:
            content
                .padding(ClipFlowSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(isPressed ? 0.988 : 1)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                        .fill(fill.opacity(isPressed ? 0.78 : 1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

        case .row:
            content
                .padding(10)
                .scaleEffect(isPressed ? 0.988 : 1)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                        .fill(Color.primary.opacity(isPressed ? 0.09 : 0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
    }
}
