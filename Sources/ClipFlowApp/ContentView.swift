import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipFlowStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)

        GeometryReader { proxy in
            let isCompact = proxy.size.width < 1460
            let horizontalPadding: CGFloat = isCompact ? 20 : 24

            ZStack {
                AppBackground(palette: palette)

                ScrollView {
                    VStack(spacing: 18) {
                        HeaderView(store: store, palette: palette)

                        if isCompact {
                            VStack(spacing: 18) {
                                SidebarView(store: store, palette: palette)
                                LibraryView(store: store, palette: palette)
                                    .frame(minHeight: 620)
                                DetailView(store: store, palette: palette)
                                    .frame(minHeight: 420)
                                IntegrationRow(integrations: store.integrations, palette: palette)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 18) {
                                SidebarView(store: store, palette: palette)
                                    .frame(width: 252)

                                VStack(spacing: 18) {
                                    LibraryView(store: store, palette: palette)
                                        .frame(minWidth: 640, minHeight: 760)
                                    IntegrationRow(integrations: store.integrations, palette: palette)
                                }
                                .frame(maxWidth: .infinity)

                                DetailView(store: store, palette: palette)
                                    .frame(width: 364)
                            }
                        }
                    }
                    .frame(maxWidth: 1580)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct HeaderView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: 18) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        introSection
                        overviewGrid
                            .frame(width: 400)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        introSection
                        overviewGrid
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        searchField
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        searchField
                        actionButtons
                    }
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("围绕呼出、回贴、分类与隐私保护打造的原生剪贴工作台")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            Text(store.capturePaused ? "监听当前已暂停，你仍然可以浏览历史并从快捷面板快速回贴内容。" : "复制任意文字或图片后，ClipFlow 会自动写入本地历史，并在指针附近提供快速回贴入口。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroSignalPills
                }

                VStack(alignment: .leading, spacing: 8) {
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
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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
                value: "⌥V",
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.inputFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("打开快捷面板") {
                ClipFlowRuntime.shared.showHUD()
            }
            .buttonStyle(ClipButtonStyle(fill: palette.primaryButtonFill, foreground: .white))

            Button(store.capturePaused ? "恢复监听" : "暂停监听") {
                store.capturePaused.toggle()
            }
            .buttonStyle(ClipButtonStyle(fill: palette.secondaryButtonFill))
        }
    }
}

struct SidebarView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("分类")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Image(systemName: store.capturePaused ? "pause.circle.fill" : "record.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.capturePaused ? ClipCategory.protected.tint : Color(red: 0.37, green: 0.67, blue: 0.54))
                }

                VStack(spacing: 8) {
                    ForEach(ClipCategory.allCases) { category in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
}

struct LibraryView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.selectedCategory.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(store.selectedCategory.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        SmallBadge(title: "\(store.filteredItems.count) 条结果", tint: store.selectedCategory.tint)
                        Text(store.statusSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(store.metrics) { metric in
                        MetricCard(metric: metric, palette: palette)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                if store.filteredItems.isEmpty {
                    EmptyLibraryView(store: store, palette: palette)
                        .padding(.top, 4)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.filteredItems) { item in
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                                        store.select(item)
                                    }
                                } label: {
                                    ClipboardCard(
                                        item: item,
                                        isSelected: store.selectedItem?.id == item.id,
                                        displayedSnippet: store.displaySnippet(for: item),
                                        palette: palette,
                                        store: store
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct EmptyLibraryView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("从复制开始，建立你的剪贴工作流")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("去任意应用复制文字或图片，ClipFlow 会自动记录和分类。需要回贴时，按下 Option + V，就能在指针附近快速调出内容。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 10) {
                    EmptyStateBadge(
                        icon: "cursorarrow.click.2",
                        title: "快捷呼出",
                        detail: "Option + V"
                    )
                    EmptyStateBadge(
                        icon: "lock.shield",
                        title: "隐私默认开启",
                        detail: "敏感内容自动遮罩"
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
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

            VStack(alignment: .leading, spacing: 10) {
                Text("使用步骤")
                    .font(.system(size: 14, weight: .semibold))

                StepRow(index: "1", text: "先去其他应用复制一段文字或图片")
                StepRow(index: "2", text: "按下 Option + V 打开指针附近的快捷面板")
                StepRow(index: "3", text: "选择内容后直接粘贴，或回到这里继续整理")
            }

            HStack(spacing: 10) {
                Button("打开快捷面板") {
                    ClipFlowRuntime.shared.showHUD()
                }
                .buttonStyle(ClipButtonStyle(fill: palette.primaryButtonFill, foreground: .white))

                Button(store.capturePaused ? "恢复监听" : "暂停监听") {
                    store.capturePaused.toggle()
                }
                .buttonStyle(ClipButtonStyle(fill: palette.secondaryButtonFill))

                Button("退出应用") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(ClipButtonStyle(fill: Color.red.opacity(0.14), foreground: Color.red))
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                InfoStat(title: "当前记录", value: "\(store.items.count)")
                InfoStat(title: "隐私条目", value: "\(store.protectedCount)")
                InfoStat(title: "排除应用", value: "\(store.excludedAppCount)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 10)
    }
}

struct DetailView: View {
    @ObservedObject var store: ClipFlowStore
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            if let item = store.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("详情预览")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                Text(item.title)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }

                            Spacer()

                            KindBadge(kind: item.kind, tint: kindTint(item.kind))
                        }

                        PreviewPanel(
                            item: item,
                            displayedText: store.displayFullText(for: item),
                            palette: palette,
                            store: store
                        )

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                actionButtons(for: item)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                actionButtons(for: item)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("建议粘贴位置")
                                .font(.system(size: 14, weight: .semibold))

                            FlexiblePillRow(items: item.pasteTargets, tint: ClipCategory.links.tint)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("隐私状态")
                                .font(.system(size: 14, weight: .semibold))

                            PrivacyFactRow(
                                title: "隐私级别",
                                value: item.privacy.label,
                                tint: item.privacy.color
                            )
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("分组原因")
                                .font(.system(size: 14, weight: .semibold))

                            Text(groupingReason(for: item))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button(role: .destructive) {
                            store.delete(item.id)
                        } label: {
                            Text("删除这条内容")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.red.opacity(0.82))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("尚未选择内容")
                        .font(.system(size: 20, weight: .bold))
                    Text("选择一条剪贴内容后，可以在这里查看详情、置顶、显示敏感信息，或者直接回贴到刚才使用的应用里。")
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for item: ClipboardItem) -> some View {
        Button {
            ClipFlowRuntime.shared.paste(item)
        } label: {
            DetailActionLabel(title: "立即粘贴", icon: "arrow.up.doc.fill", tint: ClipCategory.quickPaste.tint)
        }
        .buttonStyle(.plain)

        Button {
            store.togglePin(item.id)
        } label: {
            DetailActionLabel(title: item.pinned ? "取消置顶" : "加入快贴", icon: "pin.fill", tint: ClipCategory.smartStacks.tint)
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
    }

    private func kindTint(_ kind: ClipboardKind) -> Color {
        switch kind {
        case .text: ClipCategory.all.tint
        case .code: ClipCategory.code.tint
        case .link: ClipCategory.links.tint
        case .secret: ClipCategory.protected.tint
        case .image: ClipCategory.smartStacks.tint
        }
    }

    private func groupingReason(for item: ClipboardItem) -> String {
        if item.kind == .image {
            return "这条内容被识别为图片，因为系统在剪贴板中检测到了位图数据或图片文件，并保留了尺寸信息方便再次粘贴。"
        }
        if item.kind == .code {
            return "这条内容被归类为代码，因为其中包含语法关键字、命令行标记，或者常见的开发场景特征。"
        }
        if item.kind == .secret || item.privacy != .standard {
            return "这条内容进入了隐私保护分组，因为它看起来像验证码、令牌、密码片段，或者来自高风险来源应用。"
        }
        if item.kind == .link {
            return "这条内容被识别为链接，因为系统检测到了可解析的网址，通常会用于沟通、共享或参考。"
        }
        return "这条内容被保留在通用分组里，因为它更像普通文本，不属于命令、链接或敏感信息。"
    }
}

struct IntegrationRow: View {
    let integrations: [IntegrationPill]
    let palette: ClipFlowPalette

    var body: some View {
        FrostedPanel(palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("系统级集成")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("原生联动与权限能力")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(integrations) { integration in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(integration.tint.opacity(0.16))
                                    .frame(width: 34, height: 34)

                                Image(systemName: integration.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(integration.tint)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(integration.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(integration.detail)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.softFill)
                        )
                    }
                }
            }
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var store: ClipFlowStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let recentItems = Array(store.recentItems.prefix(3))

        VStack(alignment: .leading, spacing: 12) {
            MenuPanelHeader(store: store)

            if recentItems.isEmpty {
                Text("先去其他应用复制文字或图片，这里会立刻出现最近条目。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("最近内容")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text("点击即可粘贴")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }

                    ForEach(recentItems) { item in
                        Button {
                            ClipFlowRuntime.shared.paste(item)
                        } label: {
                            MenuRecentClipRow(
                                item: item,
                                snippet: store.displaySnippet(for: item)
                            )
                        }
                        .buttonStyle(MenuRowButtonStyle())
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "library")
                    ClipFlowRuntime.shared.openLibrary()
                } label: {
                    MenuCompactActionLabel(
                        title: "主窗口",
                        icon: "rectangle.on.rectangle",
                        tint: ClipCategory.all.tint
                    )
                }
                .buttonStyle(MenuCompactButtonStyle(fill: Color.primary.opacity(0.055)))

                Button {
                    ClipFlowRuntime.shared.showHUD()
                } label: {
                    MenuCompactActionLabel(
                        title: "快贴",
                        icon: "cursorarrow.click.2",
                        tint: ClipCategory.quickPaste.tint
                    )
                }
                .buttonStyle(MenuCompactButtonStyle(fill: ClipCategory.quickPaste.tint.opacity(0.14)))

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
                    MenuCompactButtonStyle(
                        fill: store.capturePaused ? ClipCategory.protected.tint.opacity(0.14) : Color.primary.opacity(0.055),
                        foreground: store.capturePaused ? ClipCategory.protected.tint : Color.primary
                    )
                )

                SettingsLink {
                    MenuCompactActionLabel(
                        title: "设置",
                        icon: "gearshape",
                        tint: ClipCategory.links.tint
                    )
                }
                .buttonStyle(MenuCompactButtonStyle(fill: Color.primary.opacity(0.055)))
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 8) {
                Button("清空") {
                    store.clearHistory()
                }
                .buttonStyle(MenuFooterActionStyle(fill: Color.red.opacity(0.10), foreground: Color.red))

                Button("重启") {
                    ClipFlowRuntime.shared.restartApplication()
                }
                .buttonStyle(MenuFooterActionStyle(fill: ClipCategory.quickPaste.tint.opacity(0.12), foreground: ClipCategory.quickPaste.tint))

                Button("退出") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(MenuFooterActionStyle(fill: Color.red.opacity(0.15), foreground: Color.red))
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

struct MenuPanelHeader: View {
    @ObservedObject var store: ClipFlowStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("ClipFlow 剪流")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text(store.statusSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                SmallBadge(
                    title: store.capturePaused ? "已暂停" : "运行中",
                    tint: store.capturePaused ? ClipCategory.protected.tint : Color.green
                )
            }

            HStack(spacing: 8) {
                MenuStatPill(title: "历史", value: "\(store.items.count)", tint: ClipCategory.all.tint)
                MenuStatPill(title: "隐私", value: "\(store.protectedCount)", tint: ClipCategory.protected.tint)
                MenuStatPill(title: "呼出", value: "⌥V", tint: ClipCategory.quickPaste.tint)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MenuSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
    }
}

struct MenuStatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint.opacity(0.92))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MenuEmptyStateCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ClipCategory.smartStacks.tint)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

struct MenuRecentClipRow: View {
    let item: ClipboardItem
    let snippet: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 32, height: 32)

                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(item.timeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                Text(snippet)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)

                Text(item.sourceApp)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }

            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tint: Color {
        switch item.kind {
        case .text: ClipCategory.all.tint
        case .code: ClipCategory.code.tint
        case .link: ClipCategory.links.tint
        case .secret: ClipCategory.protected.tint
        case .image: ClipCategory.smartStacks.tint
        }
    }

    private var iconName: String {
        switch item.kind {
        case .text: "text.alignleft"
        case .code: "terminal"
        case .link: "link"
        case .secret: "lock.fill"
        case .image: "photo"
        }
    }
}

struct MenuCompactActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
    }
}

struct MenuCompactButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct MenuFooterActionStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct MenuTileButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.09 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct SettingsView: View {
    @ObservedObject var store: ClipFlowStore
    @State private var excludedAppsText = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)

        ZStack {
            AppBackground(palette: palette)

            ScrollView {
                VStack(spacing: 18) {
                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [ClipCategory.quickPaste.tint, ClipCategory.links.tint],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)

                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("ClipFlow 剪流设置")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                    Text("管理剪贴监听、隐私保护、开机启动与排除规则。")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                }
                            }

                            HStack(spacing: 10) {
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
                            }
                        }
                    }

                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: 14) {
                            SettingsSectionTitle(
                                title: "运行与隐私",
                                detail: "这些选项会影响剪流的后台行为和敏感内容处理方式。"
                            )

                            SettingsToggleCard(
                                icon: store.capturePaused ? "pause.fill" : "record.circle.fill",
                                tint: store.capturePaused ? ClipCategory.protected.tint : Color.green,
                                title: "暂停监听剪贴板",
                                detail: "关闭后不再记录新复制内容，但历史与快捷粘贴仍可继续使用。",
                                isOn: $store.capturePaused
                            )

                            SettingsToggleCard(
                                icon: "lock.shield.fill",
                                tint: ClipCategory.quickPaste.tint,
                                title: "自动保护疑似敏感内容",
                                detail: "检测到验证码、令牌或敏感命令时，默认使用更严格的隐私策略。",
                                isOn: $store.autoProtectSecrets
                            )

                            SettingsToggleCard(
                                icon: "power.circle.fill",
                                tint: ClipCategory.links.tint,
                                title: "开机自动启动",
                                detail: "登录 macOS 后自动启动 ClipFlow。建议将应用保留在“应用程序”文件夹中。",
                                isOn: Binding(
                                    get: { store.launchAtLogin },
                                    set: { store.setLaunchAtLogin($0) }
                                )
                            )
                        }
                    }

                    FrostedPanel(palette: palette) {
                        VStack(alignment: .leading, spacing: 14) {
                            SettingsSectionTitle(
                                title: "排除应用 Bundle ID",
                                detail: "每行一个。来自这些应用的复制内容将不会被记录，适合密码管理器或敏感工作流。"
                            )

                            TextEditor(text: $excludedAppsText)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(palette.border.opacity(0.7), lineWidth: 1)
                                )
                                .frame(height: 220)

                            HStack(spacing: 10) {
                                Button("恢复默认") {
                                    store.resetExcludedAppsToDefaults()
                                    excludedAppsText = store.excludedBundleIDs.joined(separator: "\n")
                                }
                                .buttonStyle(ClipButtonStyle(fill: palette.secondaryButtonFill))

                                Button("保存规则") {
                                    store.updateExcludedApps(from: excludedAppsText)
                                }
                                .buttonStyle(ClipButtonStyle(fill: palette.primaryButtonFill, foreground: .white))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 720, height: 640)
        .onAppear {
            excludedAppsText = store.excludedBundleIDs.joined(separator: "\n")
        }
    }
}

struct SettingsStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                .font(.system(size: 18, weight: .semibold))
            Text(detail)
                .font(.system(size: 12, weight: .medium))
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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AppBackground: View {
    let palette: ClipFlowPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundStart, palette.backgroundMiddle, palette.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(palette.orbA)
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: -420, y: -180)

            Circle()
                .fill(palette.orbB)
                .frame(width: 520, height: 520)
                .blur(radius: 80)
                .offset(x: 420, y: 180)
        }
    }
}

struct FrostedPanel<Content: View>: View {
    let palette: ClipFlowPalette
    @ViewBuilder var content: Content

    init(palette: ClipFlowPalette, @ViewBuilder content: () -> Content) {
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: palette.shadow, radius: 28, x: 0, y: 18)
    }
}

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
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
    }
}

struct HeroSignalPill: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

struct HeaderOverviewCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Spacer()

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct CategoryRow: View {
    let category: ClipCategory
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(category.tint.opacity(isSelected ? 0.2 : 0.11))
                    .frame(width: 34, height: 34)

                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(category.tint)
            }

            Text(category.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? category.tint : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? category.tint.opacity(0.16) : Color.primary.opacity(0.06))
                )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? category.tint.opacity(0.1) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? category.tint.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PrivacyRuleRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ClipCategory.protected.tint)
                .frame(width: 18, height: 18)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ClipCategory.protected.tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MetricCard: View {
    let metric: FlowMetric
    let palette: ClipFlowPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(metric.tint.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: metric.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(metric.tint)
                }

                Spacer(minLength: 12)

                Text(metric.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(metric.tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(metric.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                Text(metric.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border.opacity(0.55), lineWidth: 1)
        )
    }
}

struct EmptyStateCard: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct EmptyStateBadge: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ClipCategory.quickPaste.tint)
                .frame(width: 18, height: 18)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ClipCategory.quickPaste.tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct StepRow: View {
    let index: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(index)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(ClipCategory.quickPaste.tint)
                )

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
    }
}

struct InfoStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

struct ClipThumbnailView: View {
    @ObservedObject var store: ClipFlowStore
    let item: ClipboardItem
    let height: CGFloat
    var cornerRadius: CGFloat = 20
    var showsDimensionLabel: Bool = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.10))

            previewContent

            if showsDimensionLabel, let dimension = item.imageDimensionText {
                Text(dimension)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    )
                    .padding(12)
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
        if !store.isRevealed(item) {
            previewPlaceholder(
                title: "图片预览已隐藏",
                icon: "lock.fill",
                tint: item.privacy.color
            )
        } else if let imageURL = store.imageURL(for: item),
                  let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.system(size: 13, weight: .semibold))
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

struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let displayedSnippet: String
    let palette: ClipFlowPalette
    @ObservedObject var store: ClipFlowStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.sourceApp)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)

                        KindBadge(kind: item.kind, tint: tint(for: item.kind))

                        if item.pinned {
                            SmallBadge(title: "已置顶", tint: ClipCategory.quickPaste.tint)
                        }
                    }

                    Text(item.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(item.timeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    SmallBadge(title: item.privacy.label, tint: item.privacy.color)
                }
            }

            if item.isImage {
                ClipThumbnailView(store: store, item: item, height: 164)
            }

            Text(displayedSnippet)
                .font(.system(size: item.kind == .code ? 12 : 14, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                .foregroundStyle(Color.secondary)
                .lineLimit(item.isImage ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(item.labels.prefix(4), id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.softFill)
                        )
                }

                Spacer()

                Label("粘贴", systemImage: "arrowshape.turn.up.right.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint(for: item.kind))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isSelected ? tint(for: item.kind).opacity(0.12) : palette.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? tint(for: item.kind).opacity(0.4) : palette.border.opacity(0.65), lineWidth: 1)
        )
    }

    private func tint(for kind: ClipboardKind) -> Color {
        switch kind {
        case .text: ClipCategory.all.tint
        case .code: ClipCategory.code.tint
        case .link: ClipCategory.links.tint
        case .secret: ClipCategory.protected.tint
        case .image: ClipCategory.smartStacks.tint
        }
    }
}

struct PreviewPanel: View {
    let item: ClipboardItem
    let displayedText: String
    let palette: ClipFlowPalette
    @ObservedObject var store: ClipFlowStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.sourceApp)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(item.timeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }

            if item.isImage {
                VStack(alignment: .leading, spacing: 12) {
                    ClipThumbnailView(store: store, item: item, height: 260, cornerRadius: 22)

                    Text(displayedText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.softFill)
                )
            } else {
                Text(displayedText)
                    .font(.system(size: item.kind == .code ? 12 : 14, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.softFill)
                    )
            }
        }
    }
}

struct DetailActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

struct PrivacyFactRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold))
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

struct FlexiblePillRow: View {
    let items: [String]
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                rowContent
            }
            VStack(alignment: .leading, spacing: 8) {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.system(size: 12, weight: .semibold))
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

struct KindBadge: View {
    let kind: ClipboardKind
    let tint: Color

    var body: some View {
        Text(kind.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
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
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

struct ClipButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

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
                border: Color.white.opacity(0.14),
                shadow: Color.black.opacity(0.34),
                softFill: Color.white.opacity(0.06),
                inputFill: Color.white.opacity(0.08),
                primaryButtonFill: Color(red: 0.30, green: 0.59, blue: 0.92),
                secondaryButtonFill: Color.white.opacity(0.10)
            )
        }

        return ClipFlowPalette(
            backgroundStart: Color(red: 0.98, green: 0.95, blue: 0.90),
            backgroundMiddle: Color(red: 0.93, green: 0.96, blue: 0.99),
            backgroundEnd: Color(red: 0.95, green: 0.93, blue: 0.98),
            orbA: Color(red: 0.98, green: 0.80, blue: 0.47).opacity(0.38),
            orbB: Color(red: 0.40, green: 0.73, blue: 0.95).opacity(0.22),
            border: Color.white.opacity(0.7),
            shadow: Color.black.opacity(0.10),
            softFill: Color.white.opacity(0.46),
            inputFill: Color.white.opacity(0.68),
            primaryButtonFill: Color(red: 0.30, green: 0.59, blue: 0.92),
            secondaryButtonFill: Color.white.opacity(0.74)
        )
    }
}
