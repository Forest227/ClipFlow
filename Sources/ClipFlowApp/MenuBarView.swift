import AppKit
import SwiftUI

// MARK: - Menu Bar View (Status Bar Popover)

struct MenuBarView: View {
    @ObservedObject var store: ClipFlowStore
    @State private var inspectingItemID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let recentItems = Array(store.recentItems.prefix(50))
        ZStack {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                MenuPanelHeader(store: store)

                if recentItems.isEmpty {
                    Text("先去其他应用复制文字或图片，这里会立刻出现最近条目。")
                        .font(ClipFlowTypography.caption)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, ClipFlowSpacing.xs)
                } else {
                    VStack(spacing: ClipFlowSpacing.sm) {
                        HStack {
                            Text("最近内容")
                                .font(ClipFlowTypography.captionBold)
                            Spacer()
                            Text(store.menuQuickPasteModeEnabled ? "左键复制，双击快贴，右键查看详情" : "左键复制，右键查看详情")
                                .font(ClipFlowTypography.smallCaption)
                                .foregroundStyle(Color.secondary)
                        }

                        ScrollView {
                            LazyVStack(spacing: ClipFlowSpacing.sm) {
                                ForEach(recentItems) { item in
                                    InteractiveCard(
                                        rootView: AnyView(
                                            MenuRecentClipRow(item: item, snippet: store.displaySnippet(for: item), store: store)
                                                .padding(10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                                                        .fill(isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.04))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                                                        .stroke(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                                                )
                                        ),
                                        onPrimary: {
                                            ClipFlowRuntime.shared.copyToClipboard(item)
                                        },
                                        onDoubleTap: store.menuQuickPasteModeEnabled ? {
                                            ClipFlowRuntime.shared.paste(item)
                                        } : nil,
                                        onSecondary: {
                                            toggleMenuInspector(for: item)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 392)
                    }
                }

                HStack(spacing: ClipFlowSpacing.sm) {
                    Button {
                        AppNavigationCenter.shared.openLibraryKeepingPopover?()
                    } label: {
                        MenuCompactActionLabel(
                            title: "主窗口",
                            icon: "rectangle.on.rectangle",
                            tint: ClipCategory.all.tint
                        )
                    }
                    .buttonStyle(MenuActionButtonStyle(fill: Color.primary.opacity(0.055), layout: .compact))

                    Button {
                        store.toggleMenuQuickPasteMode()
                    } label: {
                        MenuCompactActionLabel(
                            title: "快贴",
                            icon: "cursorarrow.click.2",
                            tint: store.menuQuickPasteModeEnabled ? ClipCategory.quickPaste.tint : ClipCategory.all.tint
                        )
                    }
                    .buttonStyle(
                        MenuActionButtonStyle(
                            fill: store.menuQuickPasteModeEnabled ? ClipCategory.quickPaste.tint.opacity(0.14) : Color.primary.opacity(0.055),
                            foreground: store.menuQuickPasteModeEnabled ? ClipCategory.quickPaste.tint : Color.primary,
                            layout: .compact
                        )
                    )

                    Button {
                        store.capturePaused.toggle()
                    } label: {
                        MenuCompactActionLabel(
                            title: store.capturePaused ? "恢复" : "暂停",
                            icon: store.capturePaused ? "play.fill" : "pause.fill",
                            tint: store.capturePaused ? ClipCategory.protected.tint : ClipCategory.all.tint
                        )
                    }
                    .buttonStyle(
                        MenuActionButtonStyle(
                            fill: store.capturePaused ? ClipCategory.protected.tint.opacity(0.14) : Color.primary.opacity(0.055),
                            foreground: store.capturePaused ? ClipCategory.protected.tint : Color.primary,
                            layout: .compact
                        )
                    )

                    Button {
                        AppNavigationCenter.shared.openSettingsKeepingPopover?()
                    } label: {
                        MenuCompactActionLabel(
                            title: "设置",
                            icon: "gearshape",
                            tint: ClipCategory.links.tint
                        )
                    }
                    .buttonStyle(MenuActionButtonStyle(fill: Color.primary.opacity(0.055), layout: .compact))
                }

                Divider()
                    .overlay(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))

                HStack(spacing: ClipFlowSpacing.sm) {
                    Button("清空") {
                        store.clearHistory()
                    }
                    .buttonStyle(MenuActionButtonStyle(fill: Color.red.opacity(0.10), foreground: Color.red, layout: .footer))

                    Button("重启") {
                        ClipFlowRuntime.shared.restartApplication()
                    }
                    .buttonStyle(MenuActionButtonStyle(fill: ClipCategory.quickPaste.tint.opacity(0.12), foreground: ClipCategory.quickPaste.tint, layout: .footer))

                    Button("退出") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(MenuActionButtonStyle(fill: Color.red.opacity(0.15), foreground: Color.red, layout: .footer))
                }
            }
            .blur(radius: inspectingItem == nil ? 0 : ClipFlowMotion.backgroundDefocusRadius)

            if let inspectingItem {
                HUDInspectorOverlay(
                    item: inspectingItem,
                    store: store,
                    onClose: {
                        withAnimation(ClipFlowMotion.overlay) {
                            inspectingItemID = nil
                        }
                    },
                    onPaste: {
                        withAnimation(ClipFlowMotion.overlay) {
                            inspectingItemID = nil
                        }
                        ClipFlowRuntime.shared.paste(inspectingItem)
                    }
                )
                .transition(ClipFlowMotion.overlayTransition)
            }
        }
        .padding(ClipFlowSpacing.cardPadding)
        .frame(width: 320)
    }

    private var inspectingItem: ClipboardItem? {
        guard let inspectingItemID else { return nil }
        return store.item(withID: inspectingItemID)
    }

    private func toggleMenuInspector(for item: ClipboardItem) {
        withAnimation(ClipFlowMotion.overlay) {
            inspectingItemID = inspectingItemID == item.id ? nil : item.id
        }
    }
}

// MARK: - Menu Panel Header

struct MenuPanelHeader: View {
    @ObservedObject var store: ClipFlowStore
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.cardPadding) {
            HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ClipCategory.quickPaste.tint, ClipCategory.links.tint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "paperclip.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                    Text("ClipFlow 剪流")
                        .font(ClipFlowTypography.menuTitle)

                    Text(store.statusSummary)
                        .font(ClipFlowTypography.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: ClipFlowSpacing.sm)

                SmallBadge(
                    title: store.capturePaused ? "已暂停" : "运行中",
                    tint: store.capturePaused ? ClipCategory.protected.tint : Color.green
                )
            }

            HStack(spacing: ClipFlowSpacing.sm) {
                MenuStatPill(title: "历史", value: "\(store.items.count)", icon: "square.3.layers.3d.top.filled", tint: ClipCategory.all.tint)
                MenuStatPill(title: "隐私", value: "\(store.protectedCount)", icon: "lock.shield.fill", tint: ClipCategory.protected.tint)
                MenuStatPill(title: "呼出", value: store.quickPasteShortcutSymbol, icon: "cursorarrow.rays", tint: ClipCategory.quickPaste.tint)
            }
        }
        .padding(ClipFlowSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuHeader, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                            : [Color.white.opacity(0.30), Color.white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuHeader, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.52), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuHeader, style: .continuous)
                .stroke(Color.black.opacity(isDark ? 0.20 : 0.05), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.08), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Menu Stat Pill

struct MenuStatPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.smallIcon, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.11)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)

                Text(title)
                    .font(ClipFlowTypography.smallCaptionBold)
                    .foregroundStyle(tint.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color.white.opacity(0.06), tint.opacity(0.08)]
                            : [Color.white.opacity(0.58), tint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .stroke(tint.opacity(isDark ? 0.28 : 0.38), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .stroke(Color.white.opacity(isDark ? 0.06 : 0.32), lineWidth: 0.5)
        )
        .shadow(color: tint.opacity(isDark ? 0.06 : 0.10), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Menu Recent Clip Row

struct MenuRecentClipRow: View {
    let item: ClipboardItem
    let snippet: String
    @ObservedObject var store: ClipFlowStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(item.kind.tint.opacity(0.14))
                    .frame(width: 32, height: 32)

                Image(systemName: item.kind.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.kind.tint)
            }

            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                HStack(spacing: 6) {
                    Text(item.isImage ? item.title : snippet)
                        .font(ClipFlowTypography.bodyBold)
                        .lineLimit(item.isImage ? 1 : 2)

                    Spacer(minLength: ClipFlowSpacing.sm)

                    Text(item.timeLabel)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                }

                if !item.isImage {
                    Text(item.title)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                if item.isImage {
                    ClipThumbnailView(
                        store: store,
                        item: item,
                        height: 82,
                        cornerRadius: ClipFlowRadius.badge,
                        showsDimensionLabel: false,
                        contentMode: .fit,
                        insetPreview: true
                    )
                }

                Text(item.sourceApp)
                    .font(ClipFlowTypography.badge)
                    .foregroundStyle(item.kind.tint)
            }

            Image(systemName: "arrow.up.forward.app")
                .font(ClipFlowTypography.smallCaptionBold)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Menu Compact Action Label

struct MenuCompactActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.smallIcon, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(ClipFlowTypography.badge)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
    }
}
