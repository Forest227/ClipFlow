import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var store: ClipFlowStore
    @State private var excludedAppsText = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)

        ZStack {
            AppBackground(palette: palette)

            ScrollView {
                VStack(spacing: ClipFlowSpacing.cardPadding) {
                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                            HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [ClipCategory.quickPaste.tint, ClipCategory.links.tint],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 46, height: 46)

                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("ClipFlow 剪流设置")
                                        .font(ClipFlowTypography.sectionTitle)
                                    Text("管理剪贴监听、隐私保护、开机启动与排除规则。")
                                        .font(ClipFlowTypography.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: ClipFlowSpacing.sm) {
                                    settingsStatusPills
                                }

                                LazyVGrid(columns: [GridItem(.flexible(), spacing: ClipFlowSpacing.sm), GridItem(.flexible(), spacing: ClipFlowSpacing.sm)], spacing: ClipFlowSpacing.sm) {
                                    settingsStatusPills
                                }
                            }
                        }
                    }

                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsSectionTitle(
                                title: "外观",
                                detail: "选择应用的颜色主题。"
                            )

                            HStack(spacing: 0) {
                                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                    let isSelected = store.appearanceMode == mode
                                    Button {
                                        withAnimation(ClipFlowMotion.selection) {
                                            store.appearanceMode = mode
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 11, weight: .semibold))
                                            Text(mode.label)
                                                .font(ClipFlowTypography.captionBold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                                                .fill(isSelected ? palette.primaryButtonFill.opacity(0.16) : Color.clear)
                                        )
                                        .foregroundStyle(isSelected ? palette.primaryButtonFill : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(3)
                            .background(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsSectionTitle(
                                title: "运行与隐私",
                                detail: "这些选项会影响剪流的后台行为和敏感内容处理方式。"
                            )

                            VStack(spacing: 0) {
                                SettingsToggleCard(
                                    icon: store.capturePaused ? "pause.fill" : "record.circle.fill",
                                    tint: store.capturePaused ? ClipCategory.protected.tint : Color.green,
                                    title: "暂停监听剪贴板",
                                    detail: "关闭后不再记录新复制内容，但历史与快捷粘贴仍可继续使用。",
                                    isOn: $store.capturePaused,
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "lock.shield.fill",
                                    tint: ClipCategory.quickPaste.tint,
                                    title: "自动保护疑似敏感内容",
                                    detail: "检测到验证码、令牌或敏感命令时，默认使用更严格的隐私策略。",
                                    isOn: $store.autoProtectSecrets,
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "power.circle.fill",
                                    tint: ClipCategory.links.tint,
                                    title: "开机自动启动",
                                    detail: "登录 macOS 后自动启动 ClipFlow。建议将应用保留在「应用程序」文件夹中。",
                                    isOn: Binding(
                                        get: { store.launchAtLogin },
                                        set: { store.setLaunchAtLogin($0) }
                                    ),
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "menubar.rectangle",
                                    tint: ClipCategory.all.tint,
                                    title: "启动时直接驻留状态栏",
                                    detail: "下次启动时不主动展示主窗口，只在状态栏中保持运行，需要时再从状态栏打开。",
                                    isOn: Binding(
                                        get: { store.launchToStatusBar },
                                        set: { store.setLaunchToStatusBar($0) }
                                    ),
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "folder.fill",
                                    tint: store.iCloudSyncTint,
                                    title: "文稿目录同步历史",
                                    detail: store.iCloudSyncDetail,
                                    isOn: Binding(
                                        get: { store.iCloudSyncEnabled },
                                        set: { store.setICloudSyncEnabled($0) }
                                    )
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                            SettingsSectionTitle(
                                title: "排除应用 Bundle ID",
                                detail: "每行一个。来自这些应用的复制内容将不会被记录，适合密码管理器或敏感工作流。"
                            )

                            TextEditor(text: $excludedAppsText)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                        .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                        .stroke(palette.border.opacity(0.7), lineWidth: 1)
                                )
                                .frame(height: 176)

                            HStack(spacing: 10) {
                                Button("恢复默认") {
                                    store.resetExcludedAppsToDefaults()
                                    excludedAppsText = store.excludedBundleIDs.joined(separator: "\n")
                                }
                                .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill))

                                Button("保存规则") {
                                    store.updateExcludedApps(from: excludedAppsText)
                                }
                                .buttonStyle(ClipFlowButtonStyle(fill: palette.primaryButtonFill, foreground: .white))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 540, idealWidth: 540, minHeight: 600, idealHeight: 600)
        .onAppear {
            excludedAppsText = store.excludedBundleIDs.joined(separator: "\n")
        }
    }
}

private extension SettingsView {
    var settingsStatusPills: some View {
        Group {
            SettingsStatusPill(
                title: "监听",
                value: store.capturePaused ? "已暂停" : "运行中",
                tint: store.capturePaused ? ClipCategory.protected.tint : Color.green
            )
            SettingsStatusPill(
                title: "自动保护",
                value: store.autoProtectSecrets ? "开启" : "关闭",
                tint: store.autoProtectSecrets ? ClipCategory.quickPaste.tint : ClipCategory.all.tint
            )
            SettingsStatusPill(
                title: "开机启动",
                value: store.launchAtLogin ? "已启用" : "未启用",
                tint: store.launchAtLogin ? ClipCategory.links.tint : ClipCategory.all.tint
            )
            SettingsStatusPill(
                title: "文稿同步",
                value: store.iCloudSyncStatusValue,
                tint: store.iCloudSyncTint
            )
        }
    }
}

// MARK: - Settings Sub-Components

struct SettingsStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ClipFlowTypography.badge)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(ClipFlowTypography.captionBold)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, ClipFlowSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.input, style: .continuous)
                .fill(tint.opacity(0.13))
        )
    }
}

struct SettingsSectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(ClipFlowTypography.settingsTitle)
            Text(detail)
                .font(ClipFlowTypography.smallCaption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsToggleCard: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var showsDivider = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(ClipFlowTypography.bodyBold)
                    Text(detail)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, ClipFlowSpacing.sm)

            if showsDivider {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.leading, 48)
            }
        }
    }
}
