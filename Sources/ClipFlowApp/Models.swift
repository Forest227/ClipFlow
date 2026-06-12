import AppKit
import ApplicationServices
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

    var tint: Color {
        switch self {
        case .text: ClipCategory.all.tint
        case .code: ClipCategory.code.tint
        case .link: ClipCategory.links.tint
        case .secret: ClipCategory.protected.tint
        case .image: ClipCategory.smartStacks.tint
        }
    }

    var iconName: String {
        switch self {
        case .text: "text.alignleft"
        case .code: "terminal"
        case .link: "link"
        case .secret: "lock.fill"
        case .image: "photo.stack.fill"
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
    /// Pre-lowered concatenation of searchable fields — computed once at creation to avoid
    /// repeated .lowercased() calls on every search keystroke.
    var searchKey: String = ""

    enum CodingKeys: String, CodingKey {
        case id, title, snippet, fullText, sourceApp, sourceBundleID, createdAt
        case kind, privacy, labels, pinned, localOnly, autoExpire, pasteTargets
        case expiresAt, imageFilename, imageWidth, imageHeight, imageSignature
        // searchKey is intentionally excluded from Codable — recomputed on decode
    }

    init(
        id: UUID, title: String, snippet: String, fullText: String,
        sourceApp: String, sourceBundleID: String? = nil, createdAt: Date,
        kind: ClipboardKind, privacy: PrivacyLevel, labels: [String],
        pinned: Bool, localOnly: Bool, autoExpire: Bool, pasteTargets: [String],
        expiresAt: Date? = nil, imageFilename: String? = nil,
        imageWidth: Double? = nil, imageHeight: Double? = nil,
        imageSignature: String? = nil, searchKey: String = ""
    ) {
        self.id = id; self.title = title; self.snippet = snippet; self.fullText = fullText
        self.sourceApp = sourceApp; self.sourceBundleID = sourceBundleID; self.createdAt = createdAt
        self.kind = kind; self.privacy = privacy; self.labels = labels
        self.pinned = pinned; self.localOnly = localOnly; self.autoExpire = autoExpire
        self.pasteTargets = pasteTargets; self.expiresAt = expiresAt
        self.imageFilename = imageFilename; self.imageWidth = imageWidth
        self.imageHeight = imageHeight; self.imageSignature = imageSignature
        self.searchKey = searchKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        snippet = try container.decode(String.self, forKey: .snippet)
        fullText = try container.decode(String.self, forKey: .fullText)
        sourceApp = try container.decode(String.self, forKey: .sourceApp)
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decode(ClipboardKind.self, forKey: .kind)
        privacy = try container.decode(PrivacyLevel.self, forKey: .privacy)
        labels = try container.decode([String].self, forKey: .labels)
        pinned = try container.decode(Bool.self, forKey: .pinned)
        localOnly = try container.decode(Bool.self, forKey: .localOnly)
        autoExpire = try container.decode(Bool.self, forKey: .autoExpire)
        pasteTargets = try container.decode([String].self, forKey: .pasteTargets)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        imageFilename = try container.decodeIfPresent(String.self, forKey: .imageFilename)
        imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
        imageSignature = try container.decodeIfPresent(String.self, forKey: .imageSignature)
        searchKey = Self.buildSearchKey(title: title, snippet: snippet, fullText: fullText, sourceApp: sourceApp, labels: labels)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(snippet, forKey: .snippet)
        try container.encode(fullText, forKey: .fullText)
        try container.encode(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(kind, forKey: .kind)
        try container.encode(privacy, forKey: .privacy)
        try container.encode(labels, forKey: .labels)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(localOnly, forKey: .localOnly)
        try container.encode(autoExpire, forKey: .autoExpire)
        try container.encode(pasteTargets, forKey: .pasteTargets)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(imageFilename, forKey: .imageFilename)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(imageSignature, forKey: .imageSignature)
    }

    fileprivate static func buildSearchKey(title: String, snippet: String, fullText: String, sourceApp: String, labels: [String]) -> String {
        (title + " " + snippet + " " + fullText + " " + sourceApp + " " + labels.joined(separator: " ")).lowercased()
    }

    nonisolated(unsafe) private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh-Hans")
        return formatter
    }()

    var timeLabel: String {
        Self.timeFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    static func formattedTimeLabel(for date: Date, relativeTo now: Date = Date()) -> String {
        timeFormatter.localizedString(for: date, relativeTo: now)
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

    fileprivate static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
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

enum ClipFlowPermissionStatus {
    case granted
    case needsAttention
    case notRequired

    var label: String {
        switch self {
        case .granted:
            return "正常"
        case .needsAttention:
            return "需要处理"
        case .notRequired:
            return "当前无需"
        }
    }

    var tint: Color {
        switch self {
        case .granted:
            return Color(red: 0.34, green: 0.67, blue: 0.53)
        case .needsAttention:
            return ClipCategory.protected.tint
        case .notRequired:
            return ClipCategory.all.tint
        }
    }
}

struct ClipFlowPermissionItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let status: ClipFlowPermissionStatus
}

struct ClipFlowPermissionReport: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let items: [ClipFlowPermissionItem]

    var needsAttention: Bool {
        items.contains { $0.status == .needsAttention }
    }
}

enum ClipboardClassifier {
    static func kind(for text: String) -> ClipboardKind {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalized.lowercased()
        let codeLike = looksLikeCode(normalized)
        let secretLike = looksLikeSecretPayload(normalized, lowered: lowered, codeLike: codeLike)

        if secretLike {
            return .secret
        }

        if looksLikeURL(normalized) && !codeLike {
            return .link
        }

        if codeLike {
            return .code
        }

        return .text
    }

    static func privacy(for text: String, kind: ClipboardKind, sourceBundleID: String?, autoProtectSecrets: Bool) -> PrivacyLevel {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalized.lowercased()
        let codeLike = kind == .code
        let sensitiveSource = (sourceBundleID.map(sensitiveSourceBundleIDs.contains) ?? false)
        let secretLike = looksLikeSecretPayload(normalized, lowered: lowered, codeLike: codeLike)

        if kind == .secret || (autoProtectSecrets && secretLike) || sensitiveSource {
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
            labels.append(isLikelyShellCommand(text, lowered: lowered) ? "命令" : "代码")
            if lowered.contains("swift") || lowered.contains("import swiftui") || lowered.contains("import foundation") {
                labels.append("Swift")
            }
            if lowered.contains("python") || lowered.contains("def ") || lowered.contains("print(") {
                labels.append("Python")
            }
            if lowered.contains("select ") || lowered.contains("insert into") || lowered.contains("update ") || lowered.contains("delete from") {
                labels.append("SQL")
            }
            if lowered.contains("<div") || lowered.contains("</") || lowered.contains("/>") || lowered.contains("<html") {
                labels.append("HTML")
            }
            if looksLikeJSON(text) {
                labels.append("JSON")
            }
            if isLikelyShellCommand(text, lowered: lowered) {
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
            searchKey: ClipboardItem.buildSearchKey(title: title, snippet: snippet, fullText: normalized, sourceApp: sourceApp, labels: labels)
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
        let title = makeImageTitle(for: imageSize)
        let snippet = makeImageSnippet(for: imageSize)
        let labels = imageLabels(for: imageSize, sourceApp: sourceApp, privacy: privacy)

        return ClipboardItem(
            id: existingItem?.id ?? UUID(),
            title: title,
            snippet: snippet,
            fullText: "",
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            createdAt: Date(),
            kind: .image,
            privacy: privacy,
            labels: labels,
            pinned: existingItem?.pinned ?? false,
            localOnly: privacy != .standard,
            autoExpire: false,
            pasteTargets: pasteTargets(for: .image),
            imageFilename: imageFilename,
            imageWidth: imageSize.width,
            imageHeight: imageSize.height,
            imageSignature: imageSignature,
            searchKey: ClipboardItem.buildSearchKey(title: title, snippet: snippet, fullText: "", sourceApp: sourceApp, labels: labels)
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
        guard let detector = ClipboardItem.linkDetector else { return false }
        let range = NSRange(location: 0, length: text.utf16.count)
        return detector.firstMatch(in: text, options: [], range: range)?.url != nil
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowered = trimmed.lowercased()
        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if trimmed.hasPrefix("```") || trimmed.contains("\n```") {
            return true
        }

        if looksLikeJSON(trimmed) {
            return true
        }

        if isLikelyShellCommand(trimmed, lowered: lowered) || looksLikeSQL(trimmed, lowered: lowered) {
            return true
        }

        var score = 0

        if lines.count >= 2 {
            score += 1
        }

        let keywordHits = codeKeywordPatterns.filter {
            lowered.range(of: $0, options: .regularExpression) != nil
        }.count
        score += min(keywordHits, 3)

        let symbolHits = codeSymbolPatterns.filter {
            trimmed.range(of: $0, options: .regularExpression) != nil
        }.count
        score += min(symbolHits, 2)

        let codeLikeLines = lines.filter { lineLooksLikeCode($0) }.count
        if codeLikeLines >= max(1, lines.count / 2) {
            score += 2
        }

        if lines.count == 1,
           trimmed.range(of: #"^(?:<[^>]+>.*</[^>]+>|[a-z_][a-z0-9_]*\s*\(.*\)|[a-z_][a-z0-9_]*\s*=\s*.+)$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            score += 2
        }

        return score >= (lines.count <= 1 ? 3 : 4)
    }

    private static func looksLikeOperationalCommand(_ lowered: String) -> Bool {
        lowered.contains("ssh ")
            || lowered.contains("export ")
            || lowered.contains("token")
            || lowered.contains("api_key")
            || lowered.contains("secret")
    }

    private static func looksLikeSecretPayload(_ text: String, lowered: String, codeLike: Bool) -> Bool {
        if lowered.range(of: #"^\d{4,8}$"#, options: .regularExpression) != nil {
            return true
        }

        let hardSecretPatterns = [
            #"\b(?:sk|rk)-[a-z0-9]{16,}\b"#,
            #"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"#,
            #"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#,
            #"\beyJ[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}\b"#,
            #"\bssh-rsa\s+[A-Za-z0-9+/=]{40,}"#,
            #"\bAKIA[0-9A-Z]{16}\b"#
        ]

        if hardSecretPatterns.contains(where: { lowered.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }

        if looksLikeHardcodedCredential(text, lowered: lowered, codeLike: codeLike) {
            return true
        }

        if codeLike {
            return false
        }

        let softSecretMarkers = [
            "otp", "verification code", "one-time code", "password",
            "passcode", "api_key", "secret", "token", "bearer ", "private key"
        ]

        if text.count <= 160, softSecretMarkers.contains(where: lowered.contains) {
            return true
        }

        if lowered.range(of: #"[a-z0-9_\-]{24,}"#, options: .regularExpression) != nil,
           !lowered.contains(" ") {
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

    private static func isLikelyShellCommand(_ text: String, lowered: String) -> Bool {
        let commandRegex = #"^(?:[$>%#]\s*)?(?:git|ssh|scp|brew|npm|pnpm|yarn|npx|node|python|python3|pip|pip3|curl|wget|docker|kubectl|defaults|chmod|chown|find|grep|sed|awk|cat|ls|cd|pwd|cp|mv|rm|mkdir|touch|swift|xcodebuild|pod|bundle|rails)\b"#
        if lowered.range(of: commandRegex, options: .regularExpression) != nil {
            return true
        }

        return text.contains("\n$ ")
            || text.contains("\n% ")
            || text.contains("\n> ")
    }

    private static func looksLikeSQL(_ text: String, lowered: String) -> Bool {
        let sqlRegex = #"^(?:with|select|insert\s+into|update|delete\s+from|create\s+table|alter\s+table|drop\s+table)\b"#
        return lowered.range(of: sqlRegex, options: .regularExpression) != nil
            || text.range(of: #"\bfrom\b.+\bwhere\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        guard text.first == "{" || text.first == "[" else { return false }
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func looksLikeHardcodedCredential(_ text: String, lowered: String, codeLike: Bool) -> Bool {
        if codeLike {
            return text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .contains(where: lineLooksLikeHardcodedCredential)
        }

        let assignmentPatterns = [
            #"(?:api[_\- ]?key|access[_\- ]?token|refresh[_\- ]?token|client[_\- ]?secret|password|passcode|bearer)\s*[:=]\s*[\"']?[A-Za-z0-9_\-\/+=]{8,}"#,
            #"(?:authorization)\s*[:=]\s*[\"']?bearer\s+[A-Za-z0-9_\-\/+=\.]{8,}"#
        ]

        if assignmentPatterns.contains(where: { lowered.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }

        return text.range(of: #"(?:api[_\- ]?key|token|secret|password)\s*[:=]\s*`[^`]{8,}`"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func lineLooksLikeHardcodedCredential(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        guard !lineLooksLikeRegexPatternDefinition(line) else { return false }

        let inlineSecretAssignmentPatterns = [
            #"\b(?:api[_\- ]?key|access[_\- ]?token|refresh[_\- ]?token|client[_\- ]?secret|password|passcode)\b.{0,24}(?:=|:)\s*(?:\"[^\"]{8,}\"|'[^']{8,}'|`[^`]{8,}`)"#,
            #"\b(?:authorization|bearer)\b.{0,24}(?:=|:)\s*(?:\"bearer\s+[A-Za-z0-9_\-\/+=\.]{8,}\"|'bearer\s+[A-Za-z0-9_\-\/+=\.]{8,}'|bearer\s+[A-Za-z0-9_\-\/+=\.]{8,})"#,
            #"^(?:export\s+)?(?:api[_\- ]?key|token|secret|password)\s*=\s*[A-Za-z0-9_\-\/+=\.]{12,}$"#
        ]

        return inlineSecretAssignmentPatterns.contains {
            line.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func lineLooksLikeRegexPatternDefinition(_ line: String) -> Bool {
        let lowered = line.lowercased()

        if lowered.contains("options: .regularexpression") || lowered.contains("nsregularexpression") {
            return true
        }

        let regexMarkers = [
            #"\"#, #"\d"#, #"\w"#, #"\b"#, #"\s"#,
            "(?:", "(?=", "(?!", "[a-z", "[0-9", "[^", "{8,}", "{10,}", ".*", ".+",
            #"range(of: #""#, #"try? regularexpression"#, #"checkingtype.link"#, #"detector.firstmatch"#
        ]

        return regexMarkers.contains { line.contains($0) }
    }

    private static func lineLooksLikeCode(_ line: String) -> Bool {
        let lowered = line.lowercased()

        if isLikelyShellCommand(line, lowered: lowered) || looksLikeSQL(line, lowered: lowered) {
            return true
        }

        if lowered.range(of: #"^(?:func|let|var|const|import|from|def|class|struct|enum|interface|public|private|protected|return|if|else|for|while|switch|case)\b"#, options: .regularExpression) != nil {
            return true
        }

        return line.range(of: #"[{}[\]();:=<>]|=>|->|::|</|/>"#, options: .regularExpression) != nil
    }

    private static let codeKeywordPatterns = [
        #"\bfunc\b"#,
        #"\blet\b"#,
        #"\bvar\b"#,
        #"\bconst\b"#,
        #"\bimport\b"#,
        #"\bfrom\b"#,
        #"\bdef\b"#,
        #"\bclass\b"#,
        #"\bstruct\b"#,
        #"\benum\b"#,
        #"\binterface\b"#,
        #"\bpublic\b"#,
        #"\bprivate\b"#,
        #"\breturn\b"#,
        #"\bif\s*\("#,
        #"\bfor\s*\("#,
        #"\bwhile\s*\("#,
        #"\bselect\b"#,
        #"\bcreate\s+table\b"#,
        #"\b<!doctype\b"#,
        #"<[a-z][^>]*>"#
    ]

    private static let codeSymbolPatterns = [
        #"[{}]"#,
        #"\=\>"#,
        #"\-\>"#,
        #"\=\s*[^=]"#,
        #";"#,
        #"</"#,
        #"/>"#,
        #"\[[^\]]+\]"#
    ]
}

enum AppearanceMode: Int, CaseIterable, Codable {
    case system = 0
    case light = 1
    case dark = 2

    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - HotKey Configuration

struct HotKeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    // Carbon modifier constants
    private static let optMod:  UInt32 = 2048  // optionKey
    private static let shiftMod: UInt32 = 512  // shiftKey
    private static let cmdMod:  UInt32 = 256   // cmdKey
    private static let ctrlMod: UInt32 = 4096  // controlKey

    static let quickPasteDefault = HotKeyConfig(keyCode: 9,  modifiers: optMod)                   // ⌥V
    static let statusBarDefault  = HotKeyConfig(keyCode: 9,  modifiers: optMod | shiftMod)        // ⌥⇧V
    static let libraryDefault    = HotKeyConfig(keyCode: 9,  modifiers: optMod | cmdMod)           // ⌥⌘V
    static let settingsDefault   = HotKeyConfig(keyCode: 44, modifiers: optMod | cmdMod)           // ⌥⌘,

    var displayString: String {
        var parts: [String] = []
        if modifiers & Self.ctrlMod  != 0 { parts.append("⌃") }
        if modifiers & Self.optMod   != 0 { parts.append("⌥") }
        if modifiers & Self.shiftMod != 0 { parts.append("⇧") }
        if modifiers & Self.cmdMod   != 0 { parts.append("⌘") }
        parts.append(Self.keyCodeLabel(keyCode))
        return parts.joined()
    }

    private static func keyCodeLabel(_ code: UInt32) -> String {
        let map: [UInt32: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
            11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",31:"O",32:"U",
            34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
            44:",",47:".",43:";",41:"'",42:"\\",50:"`",
            18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",
            27:"-",28:"8",29:"0",
            36:"↩",48:"⇥",49:"Space",51:"⌫",53:"Esc",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return map[code] ?? "(\(code))"
    }
}

// MARK: - Thumbnail Downsampling (not @MainActor so it can be called from capture pipeline)

enum ClipFlowThumbnail {
    /// Maximum pixel dimension for cached thumbnails — full images are loaded from disk only when needed for paste
    static let maxDimension: CGFloat = 320

    /// Downsample an NSImage to a target maximum dimension, producing a lightweight thumbnail for display.
    /// The original full-size image remains on disk and is loaded only when needed for paste/export.
    static func downsample(_ image: NSImage, maxDimension: CGFloat = ClipFlowThumbnail.maxDimension) -> NSImage {
        let originalSize = image.size

        guard max(originalSize.width, originalSize.height) > maxDimension else {
            return image
        }

        let scale = maxDimension / max(originalSize.width, originalSize.height)
        let targetSize = CGSize(
            width: ceil(originalSize.width * scale),
            height: ceil(originalSize.height * scale)
        )

        guard let tiffData = image.tiffRepresentation,
              let _ = NSBitmapImageRep(data: tiffData) else {
            return image
        }

        guard let scaledBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }

        scaledBitmap.size = targetSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledBitmap)
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let thumbnail = NSImage(size: targetSize)
        thumbnail.addRepresentation(scaledBitmap)
        return thumbnail
    }
}

@MainActor
final class ClipFlowStore: ObservableObject {
    static let shared = ClipFlowStore()

    @Published var searchText = "" {
        didSet { invalidateDerivedCaches(); ensureSelectionStillValid() }
    }
    @Published var selectedCategory: ClipCategory = .all {
        didSet { invalidateDerivedCaches(); ensureSelectionStillValid() }
    }
    @Published var selectedItemID: ClipboardItem.ID?
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }
    @Published var capturePaused: Bool {
        didSet { defaults.set(capturePaused, forKey: Keys.capturePaused) }
    }
    @Published var autoProtectSecrets: Bool {
        didSet { defaults.set(autoProtectSecrets, forKey: Keys.autoProtectSecrets) }
    }
    @Published var launchAtLogin: Bool
    @Published var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
    }
    @Published var menuQuickPasteModeEnabled: Bool {
        didSet { defaults.set(menuQuickPasteModeEnabled, forKey: Keys.menuQuickPasteModeEnabled) }
    }
    @Published var iCloudSyncEnabled: Bool
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }
    @Published var hotKeyQuickPaste: HotKeyConfig {
        didSet { saveHotKey(hotKeyQuickPaste, forKey: Keys.hotKeyQuickPaste) }
    }
    @Published var hotKeyStatusBar: HotKeyConfig {
        didSet { saveHotKey(hotKeyStatusBar, forKey: Keys.hotKeyStatusBar) }
    }
    @Published var hotKeyLibrary: HotKeyConfig {
        didSet { saveHotKey(hotKeyLibrary, forKey: Keys.hotKeyLibrary) }
    }
    @Published var hotKeySettings: HotKeyConfig {
        didSet { saveHotKey(hotKeySettings, forKey: Keys.hotKeySettings) }
    }
    @Published var revealedItemIDs: Set<UUID> = []
    @Published var lastCaptureStatus: String = "准备就绪"
    @Published private(set) var iCloudSyncPhase: ClipFlowCloudSyncPhase = .disabled
    @Published private(set) var iCloudLastSyncedAt: Date?
    @Published var startupPermissionReport: ClipFlowPermissionReport?

    @Published private(set) var items: [ClipboardItem] = [] {
        didSet {
            invalidateDerivedCaches()
            rebuildItemsIndex()
            schedulePersistItems()
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
    private let persistenceQueue = DispatchQueue(label: "ClipFlow.persistence", qos: .utility)
    private let imagePreviewCache = NSCache<NSString, NSImage>()
    /// Maximum memory budget for cached thumbnails: 60 MB
    private static let imageCacheTotalCostLimit = 60_000_000
    private let historyURL: URL
    private let imagesDirectoryURL: URL
    private let cloudSyncCoordinator: ClipFlowCloudSyncCoordinator
    private var pendingPersistWorkItem: DispatchWorkItem?
    private var localSyncTombstones: [UUID: Date] = [:] {
        didSet { persistLocalSyncTombstones() }
    }
    private var cloudSyncLoopTask: Task<Void, Never>?
    private var pendingCloudSyncTask: Task<Void, Never>?
    private var isApplyingCloudSnapshot = false

    // MARK: - Derived Data Caches (invalidated when items/searchText/selectedCategory change)

    private var _sortedItemsCache: [ClipboardItem]?
    private var _filteredItemsCache: [ClipboardItem]?
    private var _recentItemsCache: [ClipboardItem]?
    private var _quickPasteItemsCache: [ClipboardItem]?
    private var _metricsCache: [FlowMetric]?
    private var _categoryCountsCache: [ClipCategory: Int]?
    private var _itemsByID: [UUID: ClipboardItem] = [:]

    private func invalidateDerivedCaches() {
        _sortedItemsCache = nil
        _filteredItemsCache = nil
        _recentItemsCache = nil
        _quickPasteItemsCache = nil
        _metricsCache = nil
        _categoryCountsCache = nil
    }

    private func rebuildItemsIndex() {
        var dict = [UUID: ClipboardItem]()
        dict.reserveCapacity(items.count)
        for item in items {
            dict[item.id] = item
        }
        _itemsByID = dict
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ClipFlow", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        historyURL = appSupport.appendingPathComponent("history.json")
        imagesDirectoryURL = appSupport.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        imagePreviewCache.countLimit = maxItems + 20
        imagePreviewCache.totalCostLimit = Self.imageCacheTotalCostLimit
        cloudSyncCoordinator = ClipFlowCloudSyncCoordinator(localImagesDirectoryURL: imagesDirectoryURL)

        appearanceMode = AppearanceMode(rawValue: defaults.integer(forKey: Keys.appearanceMode)) ?? .system
        capturePaused = defaults.object(forKey: Keys.capturePaused) as? Bool ?? false
        autoProtectSecrets = defaults.object(forKey: Keys.autoProtectSecrets) as? Bool ?? true
        launchAtLogin = Self.currentLaunchAtLoginState()
        hideDockIcon = defaults.object(forKey: Keys.hideDockIcon) as? Bool ?? false
        menuQuickPasteModeEnabled = defaults.object(forKey: Keys.menuQuickPasteModeEnabled) as? Bool ?? true
        iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSyncEnabled) as? Bool ?? false
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? Self.defaultExcludedBundleIDs
        hotKeyQuickPaste = Self.loadHotKey(forKey: Keys.hotKeyQuickPaste, default: .quickPasteDefault)
        hotKeyStatusBar  = Self.loadHotKey(forKey: Keys.hotKeyStatusBar,  default: .statusBarDefault)
        hotKeyLibrary    = Self.loadHotKey(forKey: Keys.hotKeyLibrary,    default: .libraryDefault)
        hotKeySettings   = Self.loadHotKey(forKey: Keys.hotKeySettings,   default: .settingsDefault)
        iCloudLastSyncedAt = defaults.object(forKey: Keys.iCloudLastSyncedAt) as? Date
        localSyncTombstones = Self.decodeTombstones(from: defaults.data(forKey: Keys.iCloudSyncTombstones))
        items = loadItems()
        rebuildItemsIndex()
        cleanupOrphanedImageFiles()
        selectedItemID = items.first?.id
        runStartupPermissionCheck()

        if iCloudSyncEnabled {
            Task { [weak self] in
                self?.enableICloudSyncIfPossible(announceResult: false)
            }
        }
    }

    var quickPasteShortcutSymbol: String { hotKeyQuickPaste.displayString }
    var quickPasteShortcutReadable: String { hotKeyQuickPaste.displayString }

    var filteredItems: [ClipboardItem] {
        if let cached = _filteredItemsCache { return cached }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = sortedItems.filter(matchesSelectedCategory)

        let result: [ClipboardItem]
        if query.isEmpty {
            result = base
        } else {
            result = base.filter { $0.searchKey.contains(query) }
        }

        _filteredItemsCache = result
        return result
    }

    var selectedItem: ClipboardItem? {
        if let selectedItemID,
           let selected = filteredItems.first(where: { $0.id == selectedItemID }) {
            return selected
        }

        return filteredItems.first
    }

    var metrics: [FlowMetric] {
        if let cached = _metricsCache { return cached }

        // Single pass instead of 3 separate filter/flatMap operations
        var protectedCount = 0
        var codeCount = 0
        var allLabels = Set<String>()
        for item in items {
            if item.isSensitive { protectedCount += 1 }
            if item.kind == .code { codeCount += 1 }
            allLabels.formUnion(item.labels)
        }
        let stackCount = allLabels.count

        let result: [FlowMetric] = [
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

        _metricsCache = result
        return result
    }

    var recentItems: [ClipboardItem] {
        if let cached = _recentItemsCache { return cached }
        let result = Array(sortedItems.prefix(50))
        _recentItemsCache = result
        return result
    }

    var quickPasteItems: [ClipboardItem] {
        if let cached = _quickPasteItemsCache { return cached }
        let pins = sortedItems.filter(\.pinned)
        let recent = sortedItems.filter { !$0.pinned }
        let result = Array((pins + recent).prefix(50))
        _quickPasteItemsCache = result
        return result
    }

    func count(for category: ClipCategory) -> Int {
        if let cached = _categoryCountsCache?[category] { return cached }

        // Single pass through items instead of 6 separate filter passes
        var counts = [ClipCategory: Int]()
        for cat in ClipCategory.allCases { counts[cat] = 0 }

        let now = Date()
        for item in items {
            counts[.all, default: 0] += 1
            if item.pinned || item.createdAt > now.addingTimeInterval(-900) {
                counts[.quickPaste, default: 0] += 1
            }
            if item.labels.count >= 3 { counts[.smartStacks, default: 0] += 1 }
            if item.kind == .code { counts[.code, default: 0] += 1 }
            if item.kind == .link { counts[.links, default: 0] += 1 }
            if item.isSensitive { counts[.protected, default: 0] += 1 }
        }

        _categoryCountsCache = counts
        return counts[category] ?? 0
    }

    func item(withID id: UUID) -> ClipboardItem? {
        _itemsByID[id]
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

    func ingestCopiedImage(_ imageData: Data, size: CGSize, fileExtension: String = "png", sourceApp: String, sourceBundleID: String?, previewThumbnail: NSImage? = nil) {
        guard !imageData.isEmpty else { return }
        guard imageData.count <= 25_000_000 else {
            lastCaptureStatus = "已跳过过大的图片"
            return
        }

        purgeExpired()

        let hash = SHA256.hash(data: imageData)
        let signature = String(unsafeUninitializedCapacity: 64) { buf in
            var i = 0
            for byte in hash {
                let lo = byte & 0x0F
                let hi = byte >> 4
                buf[i] = hi < 10 ? hi + 48 : hi + 87
                buf[i + 1] = lo < 10 ? lo + 48 : lo + 87
                i += 2
            }
            return 64
        }
        let existingIndex = items.firstIndex { $0.imageSignature == signature }
        let existing = existingIndex.map { items.remove(at: $0) }
        let itemID = existing?.id ?? UUID()
        let imageFilename = "\(itemID.uuidString).\(fileExtension)"
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

        // Use the pre-created thumbnail from the capture pipeline if available,
        // avoiding a second full-image load + downsample cycle
        if let thumbnail = previewThumbnail {
            let pixelSize = thumbnail.size.width * thumbnail.size.height * 4
            imagePreviewCache.setObject(thumbnail, forKey: imageFilename as NSString, cost: Int(pixelSize))
        } else if let previewImage = NSImage(data: imageData) {
            // Fallback: create and cache a thumbnail-sized version
            let thumbnail = ClipFlowThumbnail.downsample(previewImage)
            let pixelSize = thumbnail.size.width * thumbnail.size.height * 4
            imagePreviewCache.setObject(thumbnail, forKey: imageFilename as NSString, cost: Int(pixelSize))
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
        if #available(macOS 13.0, *) {
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
        } else {
            launchAtLogin = enabled
            defaults.set(enabled, forKey: Keys.launchAtLogin)
            lastCaptureStatus = enabled ? "已开启开机自动启动" : "已关闭开机自动启动"
        }
    }

    func setHideDockIcon(_ enabled: Bool) {
        hideDockIcon = enabled
        lastCaptureStatus = enabled ? "已隐藏 Dock 图标，可从状态栏或快捷键打开" : "已恢复 Dock 图标显示"
    }

    func toggleMenuQuickPasteMode() {
        menuQuickPasteModeEnabled.toggle()
        lastCaptureStatus = menuQuickPasteModeEnabled
            ? "已开启快贴模式，双击最近条目会直接粘贴"
            : "已关闭快贴模式，左键点击最近条目会复制到剪贴板"
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        if enabled {
            iCloudSyncEnabled = true
            defaults.set(true, forKey: Keys.iCloudSyncEnabled)
            refreshPermissionReport(showEvenIfHealthy: false, promptForAccessibility: false)
            Task { [weak self] in
                self?.enableICloudSyncIfPossible(announceResult: true)
            }
        } else {
            pendingCloudSyncTask?.cancel()
            cloudSyncLoopTask?.cancel()
            iCloudSyncEnabled = false
            defaults.set(false, forKey: Keys.iCloudSyncEnabled)
            iCloudSyncPhase = .disabled
            lastCaptureStatus = "已关闭文稿目录同步"
        }
    }

    func dismissStartupPermissionReport() {
        startupPermissionReport = nil
    }

    func rerunPermissionCheck() {
        refreshPermissionReport(showEvenIfHealthy: true, promptForAccessibility: false)
    }

    func requestAccessibilityPermissionPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissionReport(showEvenIfHealthy: true, promptForAccessibility: false)
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
        return try? Data(contentsOf: imageURL, options: [.mappedIfSafe])
    }

    func imagePreview(for item: ClipboardItem) -> NSImage? {
        guard let imageFilename = item.imageFilename else { return nil }

        let cacheKey = imageFilename as NSString
        if let cachedImage = imagePreviewCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let imageURL = imageURL(for: item),
              let fullImage = NSImage(contentsOf: imageURL) else {
            return nil
        }

        let thumbnail = ClipFlowThumbnail.downsample(fullImage)
        let pixelSize = thumbnail.size.width * thumbnail.size.height * 4 // RGBA cost estimate
        imagePreviewCache.setObject(thumbnail, forKey: cacheKey, cost: Int(pixelSize))
        return thumbnail
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

        return base.filter { $0.searchKey.contains(normalized) }
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
            return "整理中"
        case .active:
            return "已启用"
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
            return "将普通文本与图片历史镜像到“文稿/ClipFlow”。如果系统已开启 iCloud Drive 的“桌面与文稿文件夹”，这些内容会随系统同步。"
        case .syncing:
            return "正在合并本机与“文稿/ClipFlow”中的历史内容。"
        case .active:
            if let iCloudLastSyncedAt {
                return "已启用文稿目录同步，上次整理于 \(Self.syncFormatter.string(from: iCloudLastSyncedAt))。受保护内容不会写入“文稿/ClipFlow”。"
            }
            return "已启用文稿目录同步。若系统已开启文稿同步，普通历史内容会随系统在设备间同步。"
        case .unavailable:
            return cloudSyncCoordinator.resolveAvailabilityDescription() ?? "当前无法访问“文稿/ClipFlow”。"
        case .failed(let message):
            return message
        }
    }

    private var sortedItems: [ClipboardItem] {
        if let cached = _sortedItemsCache { return cached }
        let result = sortItems(items)
        _sortedItemsCache = result
        return result
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

    private func schedulePersistItems() {
        let destinationURL = historyURL

        pendingPersistWorkItem?.cancel()

        let data: Data
        do {
            data = try JSONEncoder().encode(items)
        } catch {
            lastCaptureStatus = "保存历史记录失败"
            return
        }

        let writer: @Sendable () -> Void = {
            do {
                try data.write(to: destinationURL, options: [.atomic])
            } catch {
                Task { @MainActor in
                    ClipFlowStore.shared.lastCaptureStatus = "保存历史记录失败"
                }
            }
        }

        let workItem = DispatchWorkItem(qos: .utility, flags: .assignCurrentContext, block: writer)

        pendingPersistWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func trimItemsToLimit() {
        guard items.count > maxItems else { return }
        let overflow = Array(items.dropFirst(maxItems))
        rememberCloudDeletion(for: overflow)
        overflow.forEach(removeStoredAssetIfNeeded)
        items = Array(items.prefix(maxItems))
    }

    private func removeStoredAssetIfNeeded(for item: ClipboardItem) {
        if let imageFilename = item.imageFilename {
            imagePreviewCache.removeObject(forKey: imageFilename as NSString)
        }

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
                try? await Task.sleep(nanoseconds: 25_000_000_000)
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
            try? await Task.sleep(nanoseconds: 900_000_000)
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
                lastCaptureStatus = "已开启文稿目录同步"
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
            lastCaptureStatus = cloudSyncCoordinator.resolveAvailabilityDescription() ?? "无法访问“文稿”目录"
        case .invalidState, .writeFailed:
            iCloudSyncPhase = .failed(error.errorDescription ?? "文稿目录同步失败")
            lastCaptureStatus = error.errorDescription ?? "文稿目录同步失败"
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

    private func runStartupPermissionCheck() {
        refreshPermissionReport(showEvenIfHealthy: false, promptForAccessibility: true)
    }

    private func refreshPermissionReport(showEvenIfHealthy: Bool, promptForAccessibility: Bool) {
        let report = buildPermissionReport(promptForAccessibility: promptForAccessibility)

        if report.needsAttention || showEvenIfHealthy {
            startupPermissionReport = report
        } else {
            startupPermissionReport = nil
            lastCaptureStatus = "启动权限检查完成"
        }
    }

    private func buildPermissionReport(promptForAccessibility: Bool) -> ClipFlowPermissionReport {
        let accessibilityGranted = checkAccessibilityPermission(promptIfNeeded: promptForAccessibility)
        let accessibilityItem = ClipFlowPermissionItem(
            title: "辅助功能",
            detail: accessibilityGranted
                ? "已授权。ClipFlow 可以在回填剪贴板后自动触发粘贴。"
                : "未授权。没有这个权限时，ClipFlow 只能保存历史，无法自动把内容粘贴回输入框。",
            icon: "figure.wave.circle",
            status: accessibilityGranted ? .granted : .needsAttention
        )

        let documentsAccessGranted = checkDocumentsFolderAccessIfNeeded()
        let documentsItem = ClipFlowPermissionItem(
            title: "文稿目录",
            detail: iCloudSyncEnabled
                ? (documentsAccessGranted
                    ? "已可读写“文稿/ClipFlow”，普通历史内容会镜像到这个文件夹。"
                    : "文稿目录同步已开启，但当前还不能稳定读写“文稿/ClipFlow”。如系统弹出权限提示，请选择允许。")
                : "当前未开启文稿目录同步，因此不需要检查这个权限。",
            icon: "folder.badge.gearshape",
            status: iCloudSyncEnabled ? (documentsAccessGranted ? .granted : .needsAttention) : .notRequired
        )

        let items = [accessibilityItem, documentsItem]
        let hasIssue = items.contains { $0.status == .needsAttention }

        return ClipFlowPermissionReport(
            title: hasIssue ? "启动时发现权限未完整" : "权限检查完成",
            message: hasIssue
                ? "ClipFlow 已在启动时完成权限检测。部分系统权限还未就绪，相关功能可能会受影响。"
                : "ClipFlow 已完成本次启动权限检测，当前核心权限状态正常。",
            items: items
        )
    }

    private func checkAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }

    private func checkDocumentsFolderAccessIfNeeded() -> Bool {
        guard iCloudSyncEnabled else { return true }
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let clipFlowDirectory = documentsURL.appendingPathComponent("ClipFlow", isDirectory: true)
        let probeURL = clipFlowDirectory.appendingPathComponent(".permission-probe")

        do {
            try fileManager.createDirectory(at: clipFlowDirectory, withIntermediateDirectories: true)
            let probeData = Data("clipflow".utf8)
            try probeData.write(to: probeURL, options: [.atomic])
            try? fileManager.removeItem(at: probeURL)
            return true
        } catch {
            return false
        }
    }

    private enum Keys {
        static let capturePaused = "capturePaused"
        static let autoProtectSecrets = "autoProtectSecrets"
        static let launchAtLogin = "launchAtLogin"
        static let hideDockIcon = "hideDockIcon"
        static let menuQuickPasteModeEnabled = "menuQuickPasteModeEnabled"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let iCloudLastSyncedAt = "iCloudLastSyncedAt"
        static let iCloudSyncTombstones = "iCloudSyncTombstones"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let appearanceMode = "appearanceMode"
        static let hotKeyQuickPaste = "hotKeyQuickPaste"
        static let hotKeyStatusBar = "hotKeyStatusBar"
        static let hotKeyLibrary = "hotKeyLibrary"
        static let hotKeySettings = "hotKeySettings"
    }

    private static let defaultExcludedBundleIDs: [String] = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop"
    ]

    private static func loadHotKey(forKey key: String, default fallback: HotKeyConfig) -> HotKeyConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(HotKeyConfig.self, from: data) else {
            return fallback
        }
        return config
    }

    private func saveHotKey(_ config: HotKeyConfig, forKey key: String) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }

    private static func currentLaunchAtLoginState() -> Bool {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                return true
            default:
                return false
            }
        }
        return false
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
