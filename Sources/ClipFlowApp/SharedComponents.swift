import AppKit
import SwiftUI

// MARK: - App Background

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = colorScheme == .light
            ? Color(red: 0.94, green: 0.94, blue: 0.95)
            : Color(red: 0.11, green: 0.12, blue: 0.16)
        color.ignoresSafeArea()
    }
}

// MARK: - Frosted Panel

struct FrostedPanel<Content: View>: View {
    let palette: ClipFlowPalette
    @ViewBuilder var content: Content

    init(palette: ClipFlowPalette, @ViewBuilder content: () -> Content) {
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        content
            .padding(ClipFlowSpacing.panelPadding)
            .background(
                RoundedRectangle(cornerRadius: ClipFlowRadius.panel, style: .continuous)
                    .fill(palette.softFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClipFlowRadius.panel, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: palette.shadow, radius: 28, x: 0, y: 18)
    }
}

// MARK: - Clip Thumbnail View

struct ClipThumbnailView: View {
    let image: NSImage?
    let isRevealed: Bool
    let privacyColor: Color
    let item: ClipboardItem
    let height: CGFloat
    var cornerRadius: CGFloat = 20
    var showsDimensionLabel: Bool = true
    var contentMode: ContentMode = .fill
    var insetPreview: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.10))

            previewContent

            if showsDimensionLabel, let dimension = item.imageDimensionText {
                Text(dimension)
                    .font(ClipFlowTypography.smallCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    )
                    .padding(ClipFlowSpacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var previewContent: some View {
        if !isRevealed {
            previewPlaceholder(
                title: "图片预览已隐藏",
                icon: "lock.fill",
                tint: privacyColor
            )
        } else if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(insetPreview ? ClipFlowSpacing.sm : 0)
        } else {
            previewPlaceholder(
                title: "图片不可用",
                icon: "photo.badge.exclamationmark",
                tint: ClipCategory.protected.tint
            )
        }
    }

    private func previewPlaceholder(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(ClipFlowTypography.bodyBold)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.16), Color.black.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Clipboard Card (Library)

struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let displayedSnippet: String
    let palette: ClipFlowPalette
    let imagePreview: NSImage?
    let isRevealed: Bool

    var body: some View {
        let tint = item.kind.tint

        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                    HStack(spacing: 7) {
                        Text(item.sourceApp)
                            .font(ClipFlowTypography.smallCaptionBold)
                            .foregroundStyle(Color.secondary)

                        KindBadge(kind: item.kind, tint: tint)

                        if item.pinned {
                            SmallBadge(title: "已置顶", tint: ClipCategory.quickPaste.tint)
                        }
                    }

                    Text(item.isImage ? item.title : displayedSnippet)
                        .font(ClipFlowTypography.cardSnippet)
                        .lineLimit(item.isImage ? 1 : 3)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(item.timeLabel)
                        .font(ClipFlowTypography.smallCaptionBold)
                        .foregroundStyle(Color.secondary)

                    SmallBadge(title: item.privacy.label, tint: item.privacy.color)
                }
            }

            if item.isImage {
                ClipThumbnailView(
                    image: imagePreview,
                    isRevealed: isRevealed,
                    privacyColor: item.privacy.color,
                    item: item,
                    height: 156,
                    cornerRadius: ClipFlowRadius.innerCard,
                    showsDimensionLabel: false,
                    contentMode: .fit,
                    insetPreview: true
                )
            } else {
                Text(item.title)
                    .font(ClipFlowTypography.captionBold)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 7) {
                ForEach(item.labels.prefix(4), id: \.self) { label in
                    Text(label)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.softFill)
                        )
                }

                Spacer()

                Label("粘贴", systemImage: "arrowshape.turn.up.right.fill")
                    .font(ClipFlowTypography.smallCaptionBold)
                    .foregroundStyle(tint)
            }
        }
        .padding(ClipFlowSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .fill(isSelected ? tint.opacity(0.12) : palette.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.4) : palette.border.opacity(0.65), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 0.996 : 1)
        .animation(ClipFlowMotion.selection, value: isSelected)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ClipCategory
    let count: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: ClipFlowSpacing.sm) {
            HStack {
                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? category.tint : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, ClipFlowSpacing.xs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? category.tint.opacity(0.18) : Color.primary.opacity(0.055))
                    )
            }
            .frame(maxWidth: .infinity)

            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [category.tint.opacity(isSelected ? 0.24 : 0.14), category.tint.opacity(isSelected ? 0.12 : 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)

                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(category.tint)
            }

            Text(category.title)
                .font(ClipFlowTypography.captionBold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ClipFlowSpacing.sm)
        .padding(.vertical, ClipFlowSpacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                .fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [category.tint.opacity(0.14), category.tint.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.primary.opacity(0.035))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                .stroke(isSelected ? category.tint.opacity(0.34) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 0.995 : 1)
        .animation(ClipFlowMotion.selection, value: isSelected)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let metric: FlowMetric
    let palette: ClipFlowPalette

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(metric.tint.opacity(0.14))
                    .frame(width: 32, height: 32)

                Image(systemName: metric.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(metric.tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(ClipFlowTypography.captionBold)
                    .lineLimit(1)

                Text(metric.detail)
                    .font(ClipFlowTypography.badge)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(metric.value)
                .font(ClipFlowTypography.metricValue)
                .foregroundStyle(metric.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .fill(palette.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .stroke(palette.border.opacity(0.55), lineWidth: 1)
        )
    }
}

// MARK: - Header Overview Card

struct HeaderOverviewCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Spacer()

                Text(value)
                    .font(ClipFlowTypography.overviewValue)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                Text(title)
                    .font(ClipFlowTypography.bodyBold)
                Text(detail)
                    .font(ClipFlowTypography.smallCaption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
        }
        .padding(ClipFlowSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.card, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Badges & Pills

struct KindBadge: View {
    let kind: ClipboardKind
    let tint: Color

    var body: some View {
        Text(kind.label)
            .font(ClipFlowTypography.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, ClipFlowSpacing.sm)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

struct SmallBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(ClipFlowTypography.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, ClipFlowSpacing.sm)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

struct HeroSignalPill: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: ClipFlowSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(ClipFlowTypography.smallCaptionBold)
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, ClipFlowSpacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

struct FlexiblePillRow: View {
    let items: [String]
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ClipFlowSpacing.sm) {
                rowContent
            }
            VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(ClipFlowTypography.captionBold)
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }
}

// MARK: - Privacy Fact Row

struct PrivacyFactRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .font(ClipFlowTypography.body)
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(ClipFlowTypography.captionBold)
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }
}

// MARK: - Detail Action Label

struct DetailActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: ClipFlowSpacing.sm) {
            Image(systemName: icon)
            Text(title)
        }
        .font(ClipFlowTypography.bodyBold)
        .foregroundStyle(tint)
        .padding(.horizontal, ClipFlowSpacing.md)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

// MARK: - Preview Panel

struct PreviewPanel: View {
    let item: ClipboardItem
    let displayedText: String
    let palette: ClipFlowPalette
    let imagePreview: NSImage?
    let isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            HStack {
                Text(item.sourceApp)
                    .font(ClipFlowTypography.captionBold)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(item.timeLabel)
                    .font(ClipFlowTypography.captionBold)
                    .foregroundStyle(Color.secondary)
            }

            if item.isImage {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                    ClipThumbnailView(
                        image: imagePreview,
                        isRevealed: isRevealed,
                        privacyColor: item.privacy.color,
                        item: item,
                        height: 260,
                        cornerRadius: 22,
                        contentMode: .fit,
                        insetPreview: true
                    )

                    Text(displayedText)
                        .font(ClipFlowTypography.body)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ClipFlowSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                        .fill(palette.softFill)
                )
            } else {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                    Text(displayedText)
                        .font(.system(size: item.kind == .code ? 12 : 14, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ClipFlowSpacing.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                .fill(palette.softFill)
                        )

                    if let linkURL = item.primaryURL {
                        Button {
                            NSWorkspace.shared.open(linkURL)
                        } label: {
                            Label("访问链接", systemImage: "arrow.up.forward.app")
                                .font(ClipFlowTypography.bodyBold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClipFlowButtonStyle(fill: ClipCategory.links.tint.opacity(0.14), foreground: ClipCategory.links.tint))
                    }
                }
            }
        }
    }
}

// MARK: - Empty State Components

struct EmptyStateCard: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(ClipFlowTypography.cardTitle)

            Text(detail)
                .font(ClipFlowTypography.smallCaption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClipFlowSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct EmptyStateBadge: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: ClipFlowSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ClipCategory.quickPaste.tint)
                .frame(width: 16, height: 16)
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ClipCategory.quickPaste.tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClipFlowTypography.captionBold)
                Text(detail)
                    .font(ClipFlowTypography.badge)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, ClipFlowSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct StepRow: View {
    let index: String
    let text: String

    var body: some View {
        HStack(spacing: ClipFlowSpacing.sm) {
            Text(index)
                .font(ClipFlowTypography.smallCaptionBold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(ClipCategory.quickPaste.tint)
                )

            Text(text)
                .font(ClipFlowTypography.caption)
                .foregroundStyle(Color.secondary)
        }
    }
}

struct InfoStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
            Text(title)
                .font(ClipFlowTypography.smallCaption)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(ClipFlowTypography.statValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Header Badge

struct HeaderBadge: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClipFlowTypography.captionBold)
                Text(detail)
                    .font(ClipFlowTypography.smallCaption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, ClipFlowSpacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.input, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
    }
}

// MARK: - Privacy Rule Row

struct PrivacyRuleRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ClipCategory.protected.tint)
                .frame(width: 18, height: 18)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                        .fill(ClipCategory.protected.tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                Text(title)
                    .font(ClipFlowTypography.bodyBold)
                Text(detail)
                    .font(ClipFlowTypography.caption)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
