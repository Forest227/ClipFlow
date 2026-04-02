import CryptoKit
import Foundation
import ServiceManagement
import SwiftUI

enum ClipCategory: String, CaseIterable, Identifiable {
    case all
    case quickPaste
    case smartStacks
    case code
    case links
    case protected

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "全部内容"
        case .quickPaste: "快速粘贴"
        case .smartStacks: "智能分组"
        case .code: "代码片段"
        case .links: "链接资源"
        case .protected: "隐私保护"
        }
    }

    var subtitle: String {
        switch self {
        case .all: "按时间和来源整理的本地剪贴历史"
        case .quickPaste: "置顶内容与高置信推荐"
        case .smartStacks: "按语义、来源和复用行为自动归类"
        case .code: "命令、代码和终端可直接使用的文本"
        case .links: "网址、参考资料与可分享内容"
        case .protected: "遮罩显示、本地保存或自动过期的条目"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .quickPaste: "cursorarrow.click"
        case .smartStacks: "sparkles.rectangle.stack"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .links: "link"
        case .protected: "lock.shield"
        }
    }

    var tint: Color {
        switch self {
        case .all: Color(red: 0.34, green: 0.58, blue: 0.95)
        case .quickPaste: Color(red: 0.92, green: 0.58, blue: 0.23)
        case .smartStacks: Color(red: 0.39, green: 0.72, blue: 0.68)
        case .code: Color(red: 0.42, green: 0.66, blue: 0.98)
        case .links: Color(red: 0.29, green: 0.62, blue: 0.86)
        case .protected: Color(red: 0.83, green: 0.35, blue: 0.31)
        }
    }
}

enum ClipboardKind: String, Codable, CaseIterable {
    case text
    case code
    case link
    case secret
    case image

    var label: String {
        switch self {
        case .text: "文本"
        case .code: "代码"
        case .link: "链接"
        case .secret: "敏感"
        case .image: "图片"
        }
    }
}

enum PrivacyLevel: String, Codable {
    case standard
    case masked
    case vault

    var label: String {
        switch self {
        case .standard: "普通"
        case .masked: "遮罩"
        case .vault: "保险箱"
        }
    }

    var color: Color {
        switch self {
        case .standard: Color(red: 0.36, green: 0.62, blue: 0.54)
        case .masked: Color(red: 0.89, green: 0.61, blue: 0.25)
        case .vault: Color(red: 0.79, green: 0.32, blue: 0.28)
        }
    }
}

struct ClipboardItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var snippet: String
    var fullText: String
    var sourceApp: String
    var sourceBundleID: String?
    var createdAt: Date
    var kind: ClipboardKind
    var privacy: PrivacyLevel
    var labels: [String]
    var pinned: Bool
    var localOnly: Bool
    var autoExpire: Bool
    var pasteTargets: [String]
    var expiresAt: Date?
    var imageFilename: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var imageSignature: String?

    var timeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh-Hans")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var isSensitive: Bool {
        privacy != .standard || localOnly || autoExpire
    }

    var isImage: Bool {
        kind == .image
    }

    var imageDimensionText: String? {
        guard let imageWidth, let imageHeight else { return nil }
        let width = max(Int(imageWidth.rounded()), 1)
        let height = max(Int(imageHeight.rounded()), 1)
        return "\(width) × \(height)"
    }

    var primaryURL: URL? {
        guard kind == .link else { return nil }

        let sourceText = (fullText.isEmpty ? snippet : fullText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return nil }

        let range = NSRange(sourceText.startIndex..<sourceText.endIndex, in: sourceText)
        if let match = Self.linkDetector?.firstMatch(in: sourceText, options: [], range: range),
           let url = match.url {
            return url
        }

        return URL(string: sourceText)
    }

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}

struct FlowMetric: Identifiable {
    let id = UUID()
    let value: String
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}

struct IntegrationPill: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let detail: String
    let tint: Color
}

enum ClipboardClassifier {
    static func kind(for text: String) -> ClipboardKind {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalized.lowercased()

        if looksLikeSecret(lowered) {
            return .secret
        }

        if looksLikeURL(normalized) {
            return .link
        }

        if looksLikeCode(lowered) {
            return .code
        }

        return .text
    }

    static func privacy(for text: String, kind: ClipboardKind, sourceBundleID: String?, autoProtectSecrets: Bool) -> PrivacyLevel {
        let lowered = text.lowercased()
        let sensitiveSource = (sourceBundleID.map(sensitiveSourceBundleIDs.contains) ?? false)

        if kind == .secret || (autoProtectSecrets && looksLikeSecret(lowered)) || sensitiveSource {
            return .vault
        }

        if kind == .code && looksLikeOperationalCommand(lowered) {
            return .masked
        }

        return .standard
    }

    static func labels(for text: String, kind: ClipboardKind, sourceApp: String, privacy: PrivacyLevel) -> [String] {
        var labels: [String] = []
        let lowered = text.lowercased()

        labels.append(sourceApp)

        switch kind {
        case .text:
            if text.count > 120 {
                labels.append("长文本")
            } else {
                labels.append("便签")
            }
        case .code:
            labels.append("命令")
            if lowered.contains("swift") || lowered.contains("import ") {
                labels.append("Swift")
            }
            if lowered.contains("ssh") || lowered.contains("brew") || lowered.contains("git ") {
                labels.append("终端")
            }
        case .link:
            labels.append("参考")
            if lowered.contains("figma") {
                labels.append("设计")
            }
            if lowered.contains("github") || lowered.contains("developer.apple.com") {
                labels.append("文档")
            }
        case .secret:
            labels.append("敏感")
            if lowered.range(of: #"\b\d{4,8}\b"#, options: .regularExpression) != nil {
                labels.append("验证码")
            }
        case .image:
            labels.append("图片")
        }

        if privacy != .standard {
            labels.append("受保护")
        }

        return Array(NSOrderedSet(array: labels)) as? [String] ?? labels
    }

    static func pasteTargets(for kind: ClipboardKind) -> [String] {
        switch kind {
        case .text:
            return ["备忘录", "邮件", "微信/Slack"]
        case .code:
            return ["Xcode", "终端", "Cursor"]
        case .link:
            return ["Slack", "邮件", "信息"]
        case .secret:
            return ["浏览器", "密码管理器", "终端"]
        case .image:
            return ["备忘录", "设计工具", "聊天窗口"]
        }
    }

    static func makeItem(text: String, sourceApp: String, sourceBundleID: String?, autoProtectSecrets: Bool, existingItem: ClipboardItem?) -> ClipboardItem {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = kind(for: normalized)
        let privacy = privacy(for: normalized, kind: kind, sourceBundleID: sourceBundleID, autoProtectSecrets: autoProtectSecrets)
        let localOnly = privacy != .standard
        let autoExpire = kind == .secret || privacy == .masked
        let title = kind.label
        let snippet = makeSnippet(for: normalized)
        let labels = labels(for: normalized, kind: kind, sourceApp: sourceApp, privacy: privacy)
        let pasteTargets = pasteTargets(for: kind)

        return ClipboardItem(
            id: existingItem?.id ?? UUID(),
            title: title,
            snippet: snippet,
            fullText: normalized,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            createdAt: Date(),
            kind: kind,
            privacy: privacy,
            labels: labels,
            pinned: existingItem?.pinned ?? false,
            localOnly: localOnly,
            autoExpire: autoExpire,
            pasteTargets: pasteTargets,
            expiresAt: autoExpire ? Date().addingTimeInterval(kind == .secret ? 120 : 900) : nil,
            imageFilename: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageSignature: nil
        )
    }

    static func makeImageItem(
        imageFilename: String,
        imageSignature: String,
        imageSize: CGSize,
        sourceApp: String,
        sourceBundleID: String?,
        existingItem: ClipboardItem?
    ) -> ClipboardItem {
        let privacy = imagePrivacy(sourceBundleID: sourceBundleID)

        return ClipboardItem(
            id: existingItem?.id ?? UUID(),
            title: makeImageTitle(for: imageSize),
            snippet: makeImageSnippet(for: imageSize),
            fullText: "",
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            createdAt: Date(),
            kind: .image,
            privacy: privacy,
            labels: imageLabels(for: imageSize, sourceApp: sourceApp, privacy: privacy),
            pinned: existingItem?.pinned ?? false,
            localOnly: privacy != .standard,
            autoExpire: false,
            pasteTargets: pasteTargets(for: .image),
            expiresAt: nil,
            imageFilename: imageFilename,
            imageWidth: imageSize.width,
            imageHeight: imageSize.height,
            imageSignature: imageSignature
        )
    }

    static let sensitiveSourceBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop"
    ]

    private static func looksLikeURL(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        return detector.firstMatch(in: text, options: [], range: range)?.url != nil
    }

    private static func looksLikeCode(_ lowered: String) -> Bool {
        let codeMarkers = [
            "func ", "let ", "var ", "import ", "class ", "struct ",
            "git ", "ssh ", "brew ", "npm ", "pnpm ", "swift ",
            "{", "}", "=>", "::", "--", "</", "/>"
        ]

        return codeMarkers.contains { lowered.contains($0) }
    }

    private static func looksLikeOperationalCommand(_ lowered: String) -> Bool {
        lowered.contains("ssh ")
            || lowered.contains("export ")
            || lowered.contains("token")
            || lowered.contains("api_key")
            || lowered.contains("secret")
    }

    private static func looksLikeSecret(_ lowered: String) -> Bool {
        let secretMarkers = [
            "otp", "verification code", "one-time code", "password",
            "passcode", "api_key", "secret", "token", "bearer ",
            "sk-", "xoxb-", "ghp_", "ssh-rsa", "private key"
        ]

        if secretMarkers.contains(where: lowered.contains) {
            return true
        }

        if lowered.range(of: #"^\d{4,8}$"#, options: .regularExpression) != nil {
            return true
        }

        if lowered.range(of: #"[a-z0-9_\-]{24,}"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private static func imagePrivacy(sourceBundleID: String?) -> PrivacyLevel {
        let sensitiveSource = sourceBundleID.map(sensitiveSourceBundleIDs.contains) ?? false
        return sensitiveSource ? .vault : .standard
    }

    private static func makeImageTitle(for size: CGSize) -> String {
        "图片 \(formattedDimensionLabel(for: size))"
    }

    private static func makeImageSnippet(for size: CGSize) -> String {
        "图片内容 · \(formattedDimensionLabel(for: size))"
    }

    private static func imageLabels(for size: CGSize, sourceApp: String, privacy: PrivacyLevel) -> [String] {
        var labels = [sourceApp, "图片"]

        if size.width > size.height {
            labels.append("横向")
        } else if size.height > size.width {
            labels.append("纵向")
        } else {
            labels.append("方图")
        }

        if max(size.width, size.height) >= 2_000 {
            labels.append("高清")
        }

        if privacy != .standard {
            labels.append("受保护")
        }

        return Array(NSOrderedSet(array: labels)) as? [String] ?? labels
    }

    private static func formattedDimensionLabel(for size: CGSize) -> String {
        let width = max(Int(size.width.rounded()), 1)
        let height = max(Int(size.height.rounded()), 1)
        return "\(width) × \(height)"
    }

    private static func makeTitle(for text: String, kind: ClipboardKind) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? text

        let compact = firstLine.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let prefix = String(compact.prefix(54))

        if compact.count <= 54 {
            return prefix
        }

        switch kind {
        case .secret:
            return "受保护内容"
        case .image:
            return "图片"
        default:
            return "\(prefix)…"
        }
    }

    private static func makeSnippet(for text: String) -> String {
        let compact = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let prefix = String(compact.prefix(120))
        return compact.count > 120 ? "\(prefix)…" : prefix
    }
}

@MainActor
final class ClipFlowStore: ObservableObject {
    static let shared = ClipFlowStore()

    @Published var searchText = "" {
        didSet { ensureSelectionStillValid() }
    }
    @Published var selectedCategory: ClipCategory = .all {
        didSet { ensureSelectionStillValid() }
    }
    @Published var selectedItemID: ClipboardItem.ID?
    @Published var capturePaused: Bool {
        didSet { defaults.set(capturePaused, forKey: Keys.capturePaused) }
    }
    @Published var autoProtectSecrets: Bool {
        didSet { defaults.set(autoProtectSecrets, forKey: Keys.autoProtectSecrets) }
    }
    @Published var launchAtLogin: Bool
    @Published var launchToStatusBar: Bool {
        didSet { defaults.set(launchToStatusBar, forKey: Keys.launchToStatusBar) }
    }
    @Published var iCloudSyncEnabled: Bool
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }
    @Published var revealedItemIDs: Set<UUID> = []
    @Published var lastCaptureStatus: String = "准备就绪"
    @Published private(set) var iCloudSyncPhase: ClipFlowCloudSyncPhase = .disabled
    @Published private(set) var iCloudLastSyncedAt: Date?

    @Published private(set) var items: [ClipboardItem] = [] {
        didSet {
            persistItems()
            ensureSelectionStillValid()
            if iCloudSyncEnabled && !isApplyingCloudSnapshot {
                scheduleICloudSync()
            }
        }
    }

    let integrations = ClipFlowCatalog.integrations
    let maxItems = 80

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let historyURL: URL
    private let imagesDirectoryURL: URL
    private let cloudSyncCoordinator: ClipFlowCloudSyncCoordinator
    private var localSyncTombstones: [UUID: Date] = [:] {
        didSet { persistLocalSyncTombstones() }
    }
    private var cloudSyncLoopTask: Task<Void, Never>?
    private var pendingCloudSyncTask: Task<Void, Never>?
    private var isApplyingCloudSnapshot = false

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ClipFlow", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        historyURL = appSupport.appendingPathComponent("history.json")
        imagesDirectoryURL = appSupport.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        cloudSyncCoordinator = ClipFlowCloudSyncCoordinator(localImagesDirectoryURL: imagesDirectoryURL)

        capturePaused = defaults.object(forKey: Keys.capturePaused) as? Bool ?? false
        autoProtectSecrets = defaults.object(forKey: Keys.autoProtectSecrets) as? Bool ?? true
        launchAtLogin = Self.currentLaunchAtLoginState()
        launchToStatusBar = defaults.object(forKey: Keys.launchToStatusBar) as? Bool ?? false
        iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSyncEnabled) as? Bool ?? false
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? Self.defaultExcludedBundleIDs
        iCloudLastSyncedAt = defaults.object(forKey: Keys.iCloudLastSyncedAt) as? Date
        localSyncTombstones = Self.decodeTombstones(from: defaults.data(forKey: Keys.iCloudSyncTombstones))
        items = loadItems()
        cleanupOrphanedImageFiles()
        selectedItemID = items.first?.id

        if iCloudSyncEnabled {
            Task { [weak self] in
                self?.enableICloudSyncIfPossible(announceResult: false)
            }
        }
    }

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = sortedItems.filter(matchesSelectedCategory)

        guard !query.isEmpty else {
            return base
        }

        return base.filter { item in
            item.title.lowercased().contains(query)
                || item.snippet.lowercased().contains(query)
                || item.fullText.lowercased().contains(query)
                || item.sourceApp.lowercased().contains(query)
                || item.labels.joined(separator: " ").lowercased().contains(query)
        }
    }

    var selectedItem: ClipboardItem? {
        if let selectedItemID,
           let selected = filteredItems.first(where: { $0.id == selectedItemID }) {
            return selected
        }

        return filteredItems.first
    }

    var metrics: [FlowMetric] {
        let protectedCount = items.filter(\.isSensitive).count
        let codeCount = items.filter { $0.kind == .code }.count
        let stackCount = Set(items.flatMap(\.labels)).count

        return [
            FlowMetric(
                value: "\(items.count)",
                title: "当前条目",
                detail: "仅保存在这台 Mac 上的最近剪贴内容",
                icon: "waveform.path.ecg.rectangle",
                tint: ClipCategory.quickPaste.tint
            ),
            FlowMetric(
                value: "\(max(stackCount, 1))",
                title: "智能信号",
                detail: "结合内容类型、来源应用与复用行为生成",
                icon: "square.3.layers.3d.top.filled",
                tint: ClipCategory.smartStacks.tint
            ),
            FlowMetric(
                value: "\(max(protectedCount, codeCount))",
                title: "重点内容",
                detail: "高价值代码或敏感内容会被优先显示",
                icon: "lock.badge.clock",
                tint: ClipCategory.protected.tint
            )
        ]
    }

    var recentItems: [ClipboardItem] {
        Array(sortedItems.prefix(50))
    }

    var quickPasteItems: [ClipboardItem] {
        let pins = sortedItems.filter(\.pinned)
        let recent = sortedItems.filter { !$0.pinned }
        return Array((pins + recent).prefix(50))
    }

    func count(for category: ClipCategory) -> Int {
        sortedItems.filter { matchesSelectedCategory($0, category: category) }.count
    }

    func item(withID id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    func select(_ item: ClipboardItem) {
        selectedItemID = item.id
    }

    func togglePin(_ itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].pinned.toggle()
        items[index].createdAt = Date()
        lastCaptureStatus = items[index].pinned ? "已置顶到快速粘贴" : "已取消快速置顶"
    }

    func delete(_ itemID: UUID) {
        if let item = items.first(where: { $0.id == itemID }) {
            rememberCloudDeletion(for: [item])
            removeStoredAssetIfNeeded(for: item)
        }
        items.removeAll { $0.id == itemID }
        revealedItemIDs.remove(itemID)
        lastCaptureStatus = "已删除该条内容"
    }

    func clearHistory() {
        let pinned = items.filter(\.pinned)
        rememberCloudDeletion(for: items.filter { !$0.pinned })
        items.filter { !$0.pinned }.forEach(removeStoredAssetIfNeeded)
        items = pinned
        revealedItemIDs.removeAll()
        lastCaptureStatus = pinned.isEmpty ? "历史记录已清空" : "历史记录已清空，已保留置顶内容"
    }

    func ingestCopiedText(_ text: String, sourceApp: String, sourceBundleID: String?) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard normalized.count <= 20_000 else {
            lastCaptureStatus = "已跳过过大的剪贴内容"
            return
        }

        purgeExpired()

        let existingIndex = items.firstIndex { $0.fullText == normalized }
        let existing = existingIndex.map { items.remove(at: $0) }
        let item = ClipboardClassifier.makeItem(
            text: normalized,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            autoProtectSecrets: autoProtectSecrets,
            existingItem: existing
        )

        items.insert(item, at: 0)
        trimItemsToLimit()

        selectedItemID = selectedItemID ?? item.id
        lastCaptureStatus = "已从 \(sourceApp) 捕获新内容"
    }

    func ingestCopiedImage(_ imageData: Data, size: CGSize, sourceApp: String, sourceBundleID: String?) {
        guard !imageData.isEmpty else { return }
        guard imageData.count <= 25_000_000 else {
            lastCaptureStatus = "已跳过过大的图片"
            return
        }

        purgeExpired()

        let signature = SHA256.hash(data: imageData)
            .map { String(format: "%02x", $0) }
            .joined()
        let existingIndex = items.firstIndex { $0.imageSignature == signature }
        let existing = existingIndex.map { items.remove(at: $0) }
        let itemID = existing?.id ?? UUID()
        let imageFilename = "\(itemID.uuidString).png"
        let imageURL = imagesDirectoryURL.appendingPathComponent(imageFilename)

        do {
            try imageData.write(to: imageURL, options: [.atomic])
        } catch {
            if let existing {
                items.insert(existing, at: 0)
            }
            lastCaptureStatus = "保存图片失败"
            return
        }

        if let existing, existing.imageFilename != imageFilename {
            removeStoredAssetIfNeeded(for: existing)
        }

        let item = ClipboardClassifier.makeImageItem(
            imageFilename: imageFilename,
            imageSignature: signature,
            imageSize: size,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            existingItem: existing
        )

        items.insert(item, at: 0)
        trimItemsToLimit()

        selectedItemID = selectedItemID ?? item.id
        lastCaptureStatus = "已从 \(sourceApp) 捕获图片"
    }

    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    func updateExcludedApps(from rawValue: String) {
        let cleaned = rawValue
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        excludedBundleIDs = cleaned.isEmpty ? Self.defaultExcludedBundleIDs : cleaned
    }

    func resetExcludedAppsToDefaults() {
        excludedBundleIDs = Self.defaultExcludedBundleIDs
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            launchAtLogin = enabled
            defaults.set(enabled, forKey: Keys.launchAtLogin)
            lastCaptureStatus = enabled ? "已开启开机自动启动" : "已关闭开机自动启动"
        } catch {
            launchAtLogin = Self.currentLaunchAtLoginState()
            lastCaptureStatus = "开机自动启动设置失败，请将 ClipFlow 放在应用程序目录后再试"
        }
    }

    func setLaunchToStatusBar(_ enabled: Bool) {
        launchToStatusBar = enabled
        lastCaptureStatus = enabled ? "启动后将直接驻留状态栏" : "启动后将显示主窗口"
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        if enabled {
            iCloudSyncEnabled = true
            defaults.set(true, forKey: Keys.iCloudSyncEnabled)
            Task { [weak self] in
                self?.enableICloudSyncIfPossible(announceResult: true)
            }
        } else {
            pendingCloudSyncTask?.cancel()
            cloudSyncLoopTask?.cancel()
            iCloudSyncEnabled = false
            defaults.set(false, forKey: Keys.iCloudSyncEnabled)
            iCloudSyncPhase = .disabled
            lastCaptureStatus = "已关闭 iCloud 同步"
        }
    }

    func toggleReveal(_ itemID: UUID) {
        if revealedItemIDs.contains(itemID) {
            revealedItemIDs.remove(itemID)
            lastCaptureStatus = "敏感内容已隐藏"
        } else {
            revealedItemIDs.insert(itemID)
            lastCaptureStatus = "敏感内容已显示"
        }
    }

    func isRevealed(_ item: ClipboardItem) -> Bool {
        item.privacy == .standard || revealedItemIDs.contains(item.id)
    }

    func displaySnippet(for item: ClipboardItem) -> String {
        if item.isImage && !isRevealed(item) {
            return "图片预览已隐藏"
        }
        return isRevealed(item) ? item.snippet : masked(text: item.snippet)
    }

    func displayFullText(for item: ClipboardItem) -> String {
        if item.isImage && !isRevealed(item) {
            return "图片预览已隐藏"
        }
        if item.isImage {
            return item.snippet
        }
        return isRevealed(item) ? item.fullText : masked(text: item.fullText)
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let imageFilename = item.imageFilename else { return nil }
        return imagesDirectoryURL.appendingPathComponent(imageFilename)
    }

    func imageData(for item: ClipboardItem) -> Data? {
        guard let imageURL = imageURL(for: item) else { return nil }
        return try? Data(contentsOf: imageURL)
    }

    func purgeExpired() {
        let now = Date()
        let expiredItems = items.filter { item in
            if item.pinned {
                return false
            }

            guard let expiresAt = item.expiresAt else {
                return false
            }

            return expiresAt <= now
        }

        let before = items.count
        expiredItems.forEach(removeStoredAssetIfNeeded)
        items.removeAll { expiredItems.contains($0) }

        if items.count < before {
            lastCaptureStatus = "已清理过期的敏感内容"
        }
    }

    func hudItems(matching query: String) -> [ClipboardItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = quickPasteItems.isEmpty ? recentItems : quickPasteItems

        guard !normalized.isEmpty else {
            return base
        }

        return base.filter { item in
            item.title.lowercased().contains(normalized)
                || item.snippet.lowercased().contains(normalized)
                || item.fullText.lowercased().contains(normalized)
                || item.sourceApp.lowercased().contains(normalized)
                || item.labels.joined(separator: " ").lowercased().contains(normalized)
        }
    }

    var protectedCount: Int {
        items.filter(\.isSensitive).count
    }

    var excludedAppCount: Int {
        excludedBundleIDs.count
    }

    var statusSummary: String {
        capturePaused ? "已暂停剪贴监听" : lastCaptureStatus
    }

    var iCloudSyncStatusValue: String {
        switch iCloudSyncPhase {
        case .disabled:
            return "未启用"
        case .syncing:
            return "同步中"
        case .active:
            return "已连接"
        case .unavailable:
            return "不可用"
        case .failed:
            return "异常"
        }
    }

    var iCloudSyncTint: Color {
        switch iCloudSyncPhase {
        case .disabled:
            return ClipCategory.all.tint
        case .syncing:
            return ClipCategory.quickPaste.tint
        case .active:
            return ClipCategory.smartStacks.tint
        case .unavailable, .failed:
            return ClipCategory.protected.tint
        }
    }

    var iCloudSyncDetail: String {
        switch iCloudSyncPhase {
        case .disabled:
            return "仅同步普通文本与图片历史，受保护内容会继续保留在本地。"
        case .syncing:
            return "正在合并本机与 iCloud 历史内容。"
        case .active:
            if let iCloudLastSyncedAt {
                return "已连接 iCloud，上次同步于 \(Self.syncFormatter.string(from: iCloudLastSyncedAt))。受保护内容不会上传。"
            }
            return "已连接 iCloud，普通历史内容会在设备间同步。"
        case .unavailable:
            return cloudSyncCoordinator.resolveAvailabilityDescription() ?? "当前无法访问 iCloud 容器。"
        case .failed(let message):
            return message
        }
    }

    private var sortedItems: [ClipboardItem] {
        sortItems(items)
    }

    private func masked(text: String) -> String {
        let compact = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(repeating: "•", count: max(8, min(compact.count, 28)))
    }

    private func ensureSelectionStillValid() {
        guard let selectedItemID else {
            self.selectedItemID = filteredItems.first?.id
            return
        }

        if !filteredItems.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = filteredItems.first?.id
        }
    }

    private func matchesSelectedCategory(_ item: ClipboardItem) -> Bool {
        matchesSelectedCategory(item, category: selectedCategory)
    }

    private func matchesSelectedCategory(_ item: ClipboardItem, category: ClipCategory) -> Bool {
        switch category {
        case .all:
            return true
        case .quickPaste:
            return item.pinned || item.createdAt > Date().addingTimeInterval(-900)
        case .smartStacks:
            return item.labels.count >= 3
        case .code:
            return item.kind == .code
        case .links:
            return item.kind == .link
        case .protected:
            return item.isSensitive
        }
    }

    private func loadItems() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: historyURL) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            return decoded.filter {
                if $0.isImage, let imageURL = imageURL(for: $0), !fileManager.fileExists(atPath: imageURL.path) {
                    return false
                }
                guard let expiresAt = $0.expiresAt else { return true }
                return expiresAt > Date() || $0.pinned
            }
        } catch {
            return []
        }
    }

    private func persistItems() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            lastCaptureStatus = "保存历史记录失败"
        }
    }

    private func trimItemsToLimit() {
        guard items.count > maxItems else { return }
        let overflow = Array(items.dropFirst(maxItems))
        rememberCloudDeletion(for: overflow)
        overflow.forEach(removeStoredAssetIfNeeded)
        items = Array(items.prefix(maxItems))
    }

    private func removeStoredAssetIfNeeded(for item: ClipboardItem) {
        guard let imageURL = imageURL(for: item), fileManager.fileExists(atPath: imageURL.path) else {
            return
        }

        try? fileManager.removeItem(at: imageURL)
    }

    private func cleanupOrphanedImageFiles() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }

        let activeFilenames = Set(items.compactMap(\.imageFilename))
        for fileURL in fileURLs where !activeFilenames.contains(fileURL.lastPathComponent) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func isEligibleForICloudSync(_ item: ClipboardItem) -> Bool {
        !item.localOnly && !item.autoExpire
    }

    private func rememberCloudDeletion(for removedItems: [ClipboardItem]) {
        let now = Date()
        for item in removedItems where isEligibleForICloudSync(item) {
            localSyncTombstones[item.id] = now
        }
    }

    private func enableICloudSyncIfPossible(announceResult: Bool) {
        startCloudSyncLoop()
        runICloudSync(announceSuccess: announceResult)
    }

    private func startCloudSyncLoop() {
        cloudSyncLoopTask?.cancel()
        cloudSyncLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                self?.refreshICloudSyncIfNeeded()
            }
        }
    }

    private func refreshICloudSyncIfNeeded() {
        guard iCloudSyncEnabled else { return }
        runICloudSync(announceSuccess: false)
    }

    private func scheduleICloudSync() {
        pendingCloudSyncTask?.cancel()
        pendingCloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.refreshICloudSyncIfNeeded()
        }
    }

    private func runICloudSync(announceSuccess: Bool) {
        guard iCloudSyncEnabled else { return }

        iCloudSyncPhase = .syncing

        do {
            let result = try cloudSyncCoordinator.synchronize(
                localItems: items,
                tombstones: localSyncTombstones,
                maxItems: maxItems
            )

            applyCloudItems(result.localItems)
            localSyncTombstones = result.tombstones
            iCloudLastSyncedAt = Date()
            defaults.set(iCloudLastSyncedAt, forKey: Keys.iCloudLastSyncedAt)
            iCloudSyncPhase = .active

            if announceSuccess {
                lastCaptureStatus = "已开启 iCloud 同步"
            }
        } catch let error as ClipFlowCloudSyncError {
            handleICloudSyncFailure(error)
        } catch {
            handleICloudSyncFailure(.writeFailed)
        }
    }

    private func handleICloudSyncFailure(_ error: ClipFlowCloudSyncError) {
        pendingCloudSyncTask?.cancel()
        cloudSyncLoopTask?.cancel()
        iCloudSyncEnabled = false
        defaults.set(false, forKey: Keys.iCloudSyncEnabled)

        switch error {
        case .unavailable:
            iCloudSyncPhase = .unavailable
            lastCaptureStatus = error.errorDescription ?? "iCloud 不可用"
        case .invalidState, .writeFailed:
            iCloudSyncPhase = .failed(error.errorDescription ?? "iCloud 同步失败")
            lastCaptureStatus = error.errorDescription ?? "iCloud 同步失败"
        }
    }

    private func applyCloudItems(_ cloudItems: [ClipboardItem]) {
        let preservedLocalItems = items.filter { !isEligibleForICloudSync($0) }
        var combinedByID = Dictionary(uniqueKeysWithValues: preservedLocalItems.map { ($0.id, $0) })

        for item in cloudItems {
            combinedByID[item.id] = item
        }

        let combinedItems = sortItems(Array(combinedByID.values))
        guard combinedItems != items else { return }

        isApplyingCloudSnapshot = true
        items = combinedItems
        isApplyingCloudSnapshot = false
        cleanupOrphanedImageFiles()
    }

    private func sortItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func persistLocalSyncTombstones() {
        guard let data = try? JSONEncoder().encode(localSyncTombstones) else { return }
        defaults.set(data, forKey: Keys.iCloudSyncTombstones)
    }

    private enum Keys {
        static let capturePaused = "capturePaused"
        static let autoProtectSecrets = "autoProtectSecrets"
        static let launchAtLogin = "launchAtLogin"
        static let launchToStatusBar = "launchToStatusBar"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let iCloudLastSyncedAt = "iCloudLastSyncedAt"
        static let iCloudSyncTombstones = "iCloudSyncTombstones"
        static let excludedBundleIDs = "excludedBundleIDs"
    }

    private static let defaultExcludedBundleIDs: [String] = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop"
    ]

    private static func currentLaunchAtLoginState() -> Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    private static func decodeTombstones(from data: Data?) -> [UUID: Date] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([UUID: Date].self, from: data)) ?? [:]
    }

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum ClipFlowCatalog {
    static let integrations: [IntegrationPill] = [
        IntegrationPill(
            title: "菜单栏入口",
            icon: "menubar.rectangle",
            detail: "从菜单栏暂停监听、查看最近内容，或重新打开主窗口。",
            tint: ClipCategory.all.tint
        ),
        IntegrationPill(
            title: "全局呼出",
            icon: "command.circle",
            detail: "按下 Option + V，在指针附近呼出快速粘贴面板。",
            tint: ClipCategory.quickPaste.tint
        ),
        IntegrationPill(
            title: "隐私优先",
            icon: "lock.rectangle.stack",
            detail: "敏感内容默认遮罩显示，仅本地保存，并可自动过期。",
            tint: ClipCategory.protected.tint
        ),
        IntegrationPill(
            title: "原生粘贴",
            icon: "arrow.up.doc",
            detail: "选中条目后会重新写入剪贴板，并向目标应用发送粘贴操作。",
            tint: ClipCategory.links.tint
        )
    ]
}
