import AppKit
import SwiftUI

// MARK: - Main Window Content View

struct ContentView: View {
    @ObservedObject var store: ClipFlowStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var inspectingItemID: ClipboardItem.ID?

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)

        GeometryReader { proxy in
            let isCompact = proxy.size.width < 1140
            let horizontalPadding: CGFloat = proxy.size.width < 960 ? 14 : (isCompact ? 18 : 22)

            ZStack {
                AppBackground(palette: palette)

                ScrollView {
                    VStack(spacing: ClipFlowSpacing.lg) {
                        HeaderView(store: store, palette: palette)

                        if isCompact {
                            VStack(spacing: ClipFlowSpacing.lg) {
                                SidebarView(store: store, palette: palette)
                                LibraryView(store: store, palette: palette) { item in
                                    toggleLibraryInspector(for: item)
                                }
                                    .frame(minHeight: 520)
                                IntegrationRow(integrations: store.integrations, palette: palette)
                            }
                        } else {
                            HStack(alignment: .top, spacing: ClipFlowSpacing.lg) {
                                SidebarView(store: store, palette: palette)
                                    .frame(width: 228)

                                VStack(spacing: ClipFlowSpacing.lg) {
                                    LibraryView(store: store, palette: palette) { item in
                                        toggleLibraryInspector(for: item)
                                    }
                                        .frame(minWidth: 640, minHeight: 640)
                                    IntegrationRow(integrations: store.integrations, palette: palette)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: 1460)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, ClipFlowSpacing.xl)
                    .padding(.bottom, ClipFlowSpacing.xl)
                }
                .scrollIndicators(.hidden)
                .blur(radius: overlayActive ? ClipFlowMotion.backgroundDefocusRadius : 0)

                if overlayActive {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if inspectingItem != nil {
                                withAnimation(ClipFlowMotion.overlay) {
                                    inspectingItemID = nil
                                }
                            }
                        }
                        .zIndex(9)
                }

                if let inspectingItem {
                    LibraryInspectorOverlay(
                        item: inspectingItem,
                        store: store,
                        palette: palette,
                        maxHeight: min(max(proxy.size.height - 96, 420), 760)
                    ) {
                        withAnimation(ClipFlowMotion.overlay) {
                            inspectingItemID = nil
                        }
                    }
                    .frame(width: min(620, max(420, proxy.size.width - 120)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 48)
                    .transition(ClipFlowMotion.overlayTransition)
                    .zIndex(10)
                }

                if let permissionReport = store.startupPermissionReport {
                    StartupPermissionOverlay(
                        report: permissionReport,
                        palette: palette,
                        onDismiss: {
                            withAnimation(ClipFlowMotion.overlay) {
                                store.dismissStartupPermissionReport()
                            }
                        },
                        onRefresh: {
                            store.rerunPermissionCheck()
                        },
                        onRequestAccessibility: {
                            store.requestAccessibilityPermissionPrompt()
                        }
                    )
                    .frame(width: min(560, max(420, proxy.size.width - 120)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 48)
                    .transition(ClipFlowMotion.overlayTransition)
                    .zIndex(11)
                }
            }
        }
    }

    private var inspectingItem: ClipboardItem? {
        guard let inspectingItemID else { return nil }
        return store.item(withID: inspectingItemID)
    }

    private var overlayActive: Bool {
        inspectingItem != nil || store.startupPermissionReport != nil
    }

    private func toggleLibraryInspector(for item: ClipboardItem) {
        withAnimation(ClipFlowMotion.overlay) {
            store.select(item)
            inspectingItemID = inspectingItemID == item.id ? nil : item.id
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.lg) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: ClipFlowSpacing.lg) {
                        introSection
                        overviewGrid
                            .frame(width: 400)
                    }

                    VStack(alignment: .leading, spacing: ClipFlowSpacing.lg) {
                        introSection
                        overviewGrid
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ClipFlowSpacing.md) {
                        searchField
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                        searchField
                        actionButtons
                    }
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.cardPadding) {
            HStack(spacing: ClipFlowSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.96, green: 0.74, blue: 0.45), Color(red: 0.32, green: 0.62, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("ClipFlow 剪流")
                        .font(ClipFlowTypography.heroTitle)
                    Text("围绕呼出、回贴、分类与隐私保护打造的原生剪贴工作台")
                        .font(ClipFlowTypography.body)
                        .foregroundStyle(Color.secondary)
                }
            }

            Text(store.capturePaused ? "监听当前已暂停，你仍然可以浏览历史并从快捷面板快速回贴内容。" : "复制任意文字或图片后，ClipFlow 会自动写入本地历史，并在指针附近提供快速回贴入口。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: ClipFlowSpacing.sm) {
                    heroSignalPills
                }

                VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                    heroSignalPills
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSignalPills: some View {
        Group {
            HeroSignalPill(title: "仅本地保存", icon: "internaldrive", tint: ClipCategory.protected.tint)
            HeroSignalPill(title: "支持图片捕获", icon: "photo.on.rectangle", tint: ClipCategory.smartStacks.tint)
            HeroSignalPill(title: "智能分类", icon: "sparkles", tint: ClipCategory.quickPaste.tint)
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: ClipFlowSpacing.md), GridItem(.flexible(), spacing: ClipFlowSpacing.md)], spacing: ClipFlowSpacing.md) {
            HeaderOverviewCard(
                title: "当前状态",
                value: store.capturePaused ? "暂停" : "运行",
                detail: store.capturePaused ? "暂不捕获新内容" : "监听系统剪贴板",
                icon: store.capturePaused ? "pause.fill" : "record.circle.fill",
                tint: store.capturePaused ? ClipCategory.protected.tint : Color(red: 0.37, green: 0.67, blue: 0.54)
            )
            HeaderOverviewCard(
                title: "剪贴历史",
                value: "\(store.items.count)",
                detail: "本机最近复制内容",
                icon: "square.stack.3d.up.fill",
                tint: ClipCategory.all.tint
            )
            HeaderOverviewCard(
                title: "受保护",
                value: "\(store.protectedCount)",
                detail: "默认遮罩与自动过期",
                icon: "lock.shield.fill",
                tint: ClipCategory.protected.tint
            )
            HeaderOverviewCard(
                title: "快捷呼出",
                value: store.quickPasteShortcutSymbol,
                detail: "指针附近快速回贴",
                icon: "cursorarrow.click.2",
                tint: ClipCategory.quickPaste.tint
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)

            TextField("搜索内容、来源应用或标签", text: $store.searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, ClipFlowSpacing.inputPaddingH)
        .padding(.vertical, ClipFlowSpacing.inputPaddingV)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.input, style: .continuous)
                .fill(palette.inputFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.input, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: ClipFlowSpacing.md) {
            Button("打开快捷面板") {
                ClipFlowRuntime.shared.showHUD()
            }
            .buttonStyle(ClipFlowButtonStyle(fill: palette.primaryButtonFill, foreground: .white))

            Button("设置") {
                AppNavigationCenter.shared.openSettings()
            }
            .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill))

            Button(store.capturePaused ? "恢复监听" : "暂停监听") {
                store.capturePaused.toggle()
            }
            .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill))
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                HStack(spacing: 10) {
                    Text("分类")
                        .font(ClipFlowTypography.blockTitle)

                    Spacer()

                    Image(systemName: store.capturePaused ? "pause.circle.fill" : "record.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.capturePaused ? ClipCategory.protected.tint : Color(red: 0.37, green: 0.67, blue: 0.54))
                }

                LazyVGrid(columns: categoryColumns, spacing: ClipFlowSpacing.sm) {
                    ForEach(ClipCategory.allCases) { category in
                        Button {
                            withAnimation(ClipFlowMotion.selection) {
                                store.selectedCategory = category
                            }
                        } label: {
                            CategoryRow(
                                category: category,
                                count: store.count(for: category),
                                isSelected: store.selectedCategory == category
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: ClipFlowSpacing.sm), count: 3)
    }
}

// MARK: - Library View

struct LibraryView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette
    let onInspectItem: (ClipboardItem) -> Void

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.selectedCategory.title)
                            .font(ClipFlowTypography.sectionTitle)
                        Text(store.selectedCategory.subtitle)
                            .font(ClipFlowTypography.body)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: ClipFlowSpacing.sm) {
                        SmallBadge(title: "\(store.filteredItems.count) 条结果", tint: store.selectedCategory.tint)
                        Text(store.statusSummary)
                            .font(ClipFlowTypography.caption)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(store.metrics) { metric in
                        MetricCard(metric: metric, palette: palette)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                if store.filteredItems.isEmpty {
                    EmptyLibraryView(store: store, palette: palette)
                        .padding(.top, ClipFlowSpacing.xs)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.filteredItems) { item in
                                InteractiveCard(
                                    rootView: AnyView(
                                        ClipboardCard(
                                            item: item,
                                            isSelected: store.selectedItem?.id == item.id,
                                            displayedSnippet: store.displaySnippet(for: item),
                                            palette: palette,
                                            store: store
                                        )
                                    ),
                                    onPrimary: {
                                        withAnimation(ClipFlowMotion.selection) {
                                            store.select(item)
                                        }
                                    },
                                    onSecondary: {
                                        onInspectItem(item)
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, ClipFlowSpacing.xs)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                    Text("从复制开始，建立你的剪贴工作流")
                        .font(ClipFlowTypography.sectionTitle)

                    Text("去任意应用复制文字或图片，ClipFlow 会自动记录和分类。需要回贴时，按下 \(store.quickPasteShortcutReadable)，就能在指针附近快速调出内容。")
                        .font(ClipFlowTypography.body)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: ClipFlowSpacing.md)

                VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                    EmptyStateBadge(
                        icon: "cursorarrow.click.2",
                        title: "快捷呼出",
                        detail: store.quickPasteShortcutReadable
                    )
                    EmptyStateBadge(
                        icon: "lock.shield",
                        title: "隐私默认开启",
                        detail: "敏感内容自动遮罩"
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                EmptyStateCard(
                    icon: "sparkles.rectangle.stack",
                    tint: ClipCategory.quickPaste.tint,
                    title: "快速开始",
                    detail: "复制一段文字或图片后，这里会立即出现最近内容和下一步推荐动作。"
                )
                EmptyStateCard(
                    icon: "lock.rectangle.stack",
                    tint: ClipCategory.protected.tint,
                    title: "隐私保护",
                    detail: "验证码、密钥和敏感命令默认本地保存，并且支持自动过期。"
                )
                EmptyStateCard(
                    icon: "square.3.layers.3d.top.filled",
                    tint: ClipCategory.smartStacks.tint,
                    title: "智能分类",
                    detail: "内容会自动分到代码、链接、文本和受保护分组，查找更快。"
                )
            }

            VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                Text("使用步骤")
                    .font(ClipFlowTypography.cardTitle)

                StepRow(index: "1", text: "先去其他应用复制一段文字或图片")
                StepRow(index: "2", text: "按下 \(store.quickPasteShortcutReadable) 打开指针附近的快捷面板")
                StepRow(index: "3", text: "选择内容后直接粘贴，或回到这里继续整理")
            }

            HStack(spacing: ClipFlowSpacing.sm) {
                Button("打开快捷面板") {
                    ClipFlowRuntime.shared.showHUD()
                }
                .buttonStyle(ClipFlowButtonStyle(fill: palette.primaryButtonFill, foreground: .white, size: .dense))

                Button(store.capturePaused ? "恢复监听" : "暂停监听") {
                    store.capturePaused.toggle()
                }
                .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill, size: .dense))

                Button("退出应用") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(ClipFlowButtonStyle(fill: Color.red.opacity(0.14), foreground: Color.red, size: .dense))
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 10) {
                InfoStat(title: "当前记录", value: "\(store.items.count)")
                InfoStat(title: "隐私条目", value: "\(store.protectedCount)")
                InfoStat(title: "排除应用", value: "\(store.excludedAppCount)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 10)
    }
}

// MARK: - Integration Row

struct IntegrationRow: View {
    let integrations: [IntegrationPill]
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.cardPadding) {
                HStack {
                    Text("系统级集成")
                        .font(ClipFlowTypography.blockTitle)
                    Spacer()
                    Text("原生联动与权限能力")
                        .font(ClipFlowTypography.caption)
                        .foregroundStyle(Color.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(integrations) { integration in
                        HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                                    .fill(integration.tint.opacity(0.16))
                                    .frame(width: 34, height: 34)

                                Image(systemName: integration.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(integration.tint)
                            }

                            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                                Text(integration.title)
                                    .font(ClipFlowTypography.cardTitle)
                                Text(integration.detail)
                                    .font(ClipFlowTypography.caption)
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ClipFlowSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                                .fill(palette.softFill)
                        )
                    }
                }
            }
        }
    }
}
