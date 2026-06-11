import AppKit
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var store: ClipFlowStore
    @State private var excludedAppsText = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)
        let excludedAppsEditorFill = Color(nsColor: .textBackgroundColor)

        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: ClipFlowSpacing.cardPadding) {
                    // Top padding for title bar height when using fullSizeContentView
                    Spacer()
                        .frame(height: 28)
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
                                    Text("设置")
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

                            HStack(spacing: 6) {
                                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                    AppearanceModeSegmentButton(
                                        mode: mode,
                                        isSelected: store.appearanceMode == mode,
                                        palette: palette
                                    ) {
                                        withAnimation(ClipFlowMotion.selection) {
                                            store.appearanceMode = mode
                                        }
                                    }
                                }
                            }
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                                    .fill(palette.inputFill.opacity(colorScheme == .dark ? 0.92 : 1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                                    .stroke(palette.border.opacity(colorScheme == .dark ? 1 : 0.9), lineWidth: 1)
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
                                    detail: "暂停记录新内容，历史与快捷粘贴不受影响。",
                                    isOn: $store.capturePaused,
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "lock.shield.fill",
                                    tint: ClipCategory.quickPaste.tint,
                                    title: "自动保护敏感内容",
                                    detail: "验证码、密钥等自动加密保护。",
                                    isOn: $store.autoProtectSecrets,
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "power.circle.fill",
                                    tint: ClipCategory.links.tint,
                                    title: "开机自动启动",
                                    detail: "登录后自动启动，建议保留在应用程序文件夹。",
                                    isOn: Binding(
                                        get: { store.launchAtLogin },
                                        set: { store.setLaunchAtLogin($0) }
                                    ),
                                    showsDivider: true
                                )

                                SettingsToggleCard(
                                    icon: "dock.rectangle",
                                    tint: ClipCategory.smartStacks.tint,
                                    title: "隐藏 Dock 图标",
                                    detail: "通过状态栏图标或快捷键访问。",
                                    isOn: Binding(
                                        get: { store.hideDockIcon },
                                        set: { store.setHideDockIcon($0) }
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
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsSectionTitle(
                                title: "快捷键",
                                detail: "自定义各功能的全局快捷键。点击录制区域后按下新的组合键即可更改。"
                            )

                            VStack(spacing: 0) {
                                HotKeyRow(
                                    icon: "cursorarrow.rays",
                                    tint: ClipCategory.quickPaste.tint,
                                    title: "呼出快速粘贴面板",
                                    config: $store.hotKeyQuickPaste,
                                    defaultConfig: .quickPasteDefault,
                                    showsDivider: true
                                )
                                HotKeyRow(
                                    icon: "menubar.rectangle",
                                    tint: ClipCategory.all.tint,
                                    title: "呼出状态栏菜单",
                                    config: $store.hotKeyStatusBar,
                                    defaultConfig: .statusBarDefault,
                                    showsDivider: true
                                )
                                HotKeyRow(
                                    icon: "gearshape",
                                    tint: ClipCategory.smartStacks.tint,
                                    title: "打开设置",
                                    config: $store.hotKeySettings,
                                    defaultConfig: .settingsDefault,
                                    showsDivider: false
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
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(excludedAppsEditorFill)
                                .clipShape(RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous))
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
        .frame(minWidth: 380, idealWidth: 380, minHeight: 600, idealHeight: 600)
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

struct AppearanceModeSegmentButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let palette: ClipFlowPalette
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        isSelected ? .white.opacity(colorScheme == .dark ? 0.96 : 0.98) : Color.primary.opacity(colorScheme == .dark ? 0.84 : 0.72)
    }

    private var backgroundFill: Color {
        if isSelected {
            return palette.primaryButtonFill.opacity(colorScheme == .dark ? 0.34 : 0.24)
        }

        return isHovered
            ? Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55)
            : Color.white.opacity(colorScheme == .dark ? 0.03 : 0.36)
    }

    private var borderColor: Color {
        if isSelected {
            return palette.primaryButtonFill.opacity(colorScheme == .dark ? 0.32 : 0.24)
        }

        return palette.border.opacity(colorScheme == .dark ? 0.55 : 0.65)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 18, height: 18)

                Text(mode.label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .foregroundStyle(tint)
            .shadow(
                color: isSelected ? palette.primaryButtonFill.opacity(colorScheme == .dark ? 0.18 : 0.10) : .clear,
                radius: isSelected ? 10 : 0,
                x: 0,
                y: isSelected ? 5 : 0
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous))
        .onHover { hovering in
            withAnimation(ClipFlowMotion.fade) {
                isHovered = hovering
            }
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ClipFlowTypography.captionBold)
                    Text(detail)
                        .font(ClipFlowTypography.smallCaption)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)

            if showsDivider {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.leading, 48)
            }
        }
    }
}

// MARK: - HotKey Row

struct HotKeyRow: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var config: HotKeyConfig
    let defaultConfig: HotKeyConfig
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

                Text(title)
                    .font(ClipFlowTypography.bodyBold)

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    HotKeyRecorderField(config: $config)
                        .frame(width: 72, height: 26)

                    Button {
                        config = defaultConfig
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 22, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("恢复默认")
                }
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

// MARK: - HotKey Recorder Field

struct HotKeyRecorderField: NSViewRepresentable {
    @Binding var config: HotKeyConfig

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let view = HotKeyRecorderNSView()
        view.onConfigChanged = { newConfig in
            config = newConfig
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        nsView.currentConfig = config
    }
}

final class HotKeyRecorderNSView: NSView {
    var currentConfig: HotKeyConfig = .quickPasteDefault {
        didSet { updateLabel() }
    }
    var onConfigChanged: ((HotKeyConfig) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            heightAnchor.constraint(equalToConstant: 26)
        ])
        updateLabel()
    }

    private func updateLabel() {
        if isRecording {
            label.stringValue = "录制中… 按 ESC 取消"
            label.textColor = NSColor.controlAccentColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            layer?.borderWidth = 1
        } else {
            label.stringValue = currentConfig.displayString
            label.textColor = NSColor.labelColor
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            layer?.borderWidth = 1
        }
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        updateLabel()
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // ESC cancels recording, restoring the previous config
        if event.keyCode == 53 {
            isRecording = false
            updateLabel()
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else { return }

        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= 256 }
        if flags.contains(.option)  { carbonMods |= 2048 }
        if flags.contains(.shift)   { carbonMods |= 512 }
        if flags.contains(.control) { carbonMods |= 4096 }

        let newConfig = HotKeyConfig(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
        isRecording = false
        currentConfig = newConfig
        onConfigChanged?(newConfig)
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            updateLabel()
        }
        return super.resignFirstResponder()
    }
}
