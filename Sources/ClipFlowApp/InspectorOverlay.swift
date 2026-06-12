import AppKit
import SwiftUI

// MARK: - Library Inspector Overlay

struct LibraryInspectorOverlay: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette
    let maxHeight: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("条目信息")
                        .font(ClipFlowTypography.captionBold)
                        .foregroundStyle(Color.secondary)
                    Text(item.title)
                        .font(ClipFlowTypography.menuTitle)
                    Text("\(item.sourceApp) · \(item.timeLabel)")
                        .font(ClipFlowTypography.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                KindBadge(kind: item.kind, tint: item.kind.tint)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.lg) {
                    PreviewPanel(
                        item: item,
                        displayedText: store.displayFullText(for: item),
                        palette: palette,
                        imagePreview: store.imagePreview(for: item),
                        isRevealed: store.isRevealed(item)
                    )

                    HorizontalViewThatFits {
                        HStack(spacing: 10) {
                            actionButtons
                        }
                    } second: {
                        VStack(alignment: .leading, spacing: 10) {
                            actionButtons
                        }
                    }

                    VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                        Text("信息摘要")
                            .font(ClipFlowTypography.bodyBold)
                            .foregroundStyle(Color.secondary)

                        PrivacyFactRow(title: "隐私级别", value: item.privacy.label, tint: item.privacy.color)
                        PrivacyFactRow(
                            title: "存储方式",
                            value: item.localOnly ? "仅本地保存" : "普通本地历史",
                            tint: item.localOnly ? ClipCategory.protected.tint : ClipCategory.smartStacks.tint
                        )
                        PrivacyFactRow(
                            title: "保留策略",
                            value: item.autoExpire ? "已开启自动过期" : "手动清理",
                            tint: item.autoExpire ? ClipCategory.quickPaste.tint : ClipCategory.all.tint
                        )
                    }

                    VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                        Text("建议粘贴位置")
                            .font(ClipFlowTypography.bodyBold)
                            .foregroundStyle(Color.secondary)

                        FlexiblePillRow(items: item.pasteTargets, tint: ClipCategory.links.tint)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("归类说明")
                            .font(ClipFlowTypography.bodyBold)
                            .foregroundStyle(Color.secondary)

                        Text(groupingReason)
                            .font(ClipFlowTypography.body)
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(ClipFlowSpacing.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.overlay, style: .continuous)
                .fill(palette.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.overlay, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 18)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            ClipFlowRuntime.shared.paste(item)
            onClose()
        } label: {
            DetailActionLabel(title: "立即粘贴", icon: "arrow.up.doc.fill", tint: ClipCategory.quickPaste.tint)
        }
        .buttonStyle(.plain)

        Button {
            store.togglePin(item.id)
        } label: {
            DetailActionLabel(title: item.pinned ? "取消置顶" : "置顶", icon: "pin.fill", tint: Color.purple)
        }
        .buttonStyle(.plain)

        if item.privacy != .standard {
            Button {
                store.toggleReveal(item.id)
            } label: {
                DetailActionLabel(
                    title: store.isRevealed(item) ? "隐藏内容" : "显示内容",
                    icon: store.isRevealed(item) ? "eye.slash.fill" : "eye.fill",
                    tint: item.privacy.color
                )
            }
            .buttonStyle(.plain)
        }

        Button(role: .destructive) {
            store.delete(item.id)
            onClose()
        } label: {
            DetailActionLabel(title: "删除", icon: "trash.fill", tint: Color.red)
        }
        .buttonStyle(.plain)
    }

    private var groupingReason: String {
        if item.kind == .image {
            return "已识别为图片内容，会保留缩略预览和尺寸信息，方便再次回贴。"
        }
        if item.kind == .code {
            return "已识别为代码或命令内容，因为文本里出现了明显的开发语法和终端特征。"
        }
        if item.kind == .secret || item.privacy != .standard {
            return "已进入保护分组，因为这条内容看起来像验证码、密钥或高风险敏感信息。"
        }
        if item.kind == .link {
            return "已识别为链接内容，因为系统检测到了可直接打开的网址。"
        }
        return "已保留在通用文本分组，因为它更像常规复制内容，不属于链接、代码或敏感项。"
    }
}

// MARK: - Startup Permission Overlay

struct StartupPermissionOverlay: View {
    let report: ClipFlowPermissionReport
    let palette: ClipFlowPalette
    let onDismiss: () -> Void
    let onRefresh: () -> Void
    let onRequestAccessibility: () -> Void

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.lg) {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: ClipFlowRadius.input, style: .continuous)
                                .fill((report.needsAttention ? ClipCategory.protected.tint : ClipCategory.smartStacks.tint).opacity(0.16))
                                .frame(width: 42, height: 42)

                            Image(systemName: report.needsAttention ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(report.needsAttention ? ClipCategory.protected.tint : ClipCategory.smartStacks.tint)
                        }

                        VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                            Text(report.title)
                                .font(ClipFlowTypography.overlayTitle)
                            Text(report.message)
                                .font(ClipFlowTypography.body)
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(report.items) { item in
                        HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                                    .fill(item.status.tint.opacity(0.14))
                                    .frame(width: 38, height: 38)

                                Image(systemName: item.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(item.status.tint)
                            }

                            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Text(item.status.label)
                                        .font(ClipFlowTypography.smallCaptionBold)
                                        .foregroundStyle(item.status.tint)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(item.status.tint.opacity(0.14))
                                        )
                                }

                                Text(item.detail)
                                    .font(ClipFlowTypography.caption)
                                    .foregroundStyle(Color.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(ClipFlowSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                .fill(Color.white.opacity(0.54))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                .stroke(palette.border.opacity(0.64), lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: 10) {
                    Button("继续使用", action: onDismiss)
                        .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill))

                    Button("重新检测", action: onRefresh)
                        .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill))

                    if report.items.contains(where: { $0.title == "辅助功能" && $0.status == .needsAttention }) {
                        Button("请求辅助功能权限", action: onRequestAccessibility)
                            .buttonStyle(ClipFlowButtonStyle(fill: palette.primaryButtonFill, foreground: .white))
                    }
                }
            }
        }
    }
}
