# ClipFlow 技术设计文档

> 版本：v0.2.0（重构后）
> 更新日期：2026-04-03
> 状态：当前实现

---

## 1. 项目概述

ClipFlow（剪流）是一款 macOS 原生剪切板增强工具。核心价值：**在指针附近呼出、快速找回、直接粘贴、隐私优先**。

### 1.1 技术栈

| 项目 | 选型 |
|------|------|
| 语言 | Swift 6.0（严格并发安全） |
| UI 框架 | SwiftUI + AppKit 混合 |
| 构建系统 | Swift Package Manager（纯 SPM，无 Xcode 工程） |
| 最低系统 | macOS 14 Sonoma |
| 第三方依赖 | 无 |
| 界面语言 | 中文（zh-Hans） |
| Bundle ID | `com.clipflow.app` |

### 1.2 设计参考

品牌个性：**流畅、高级、干净、可信**
视觉参考：Linear / Raycast 风格 — 精致、高效、信息密度适中的现代开发者工具美学

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────┐
│                   ClipFlowApp (@main)               │
│         AppDelegate · WindowControllers             │
├──────────┬──────────┬───────────┬───────────────────┤
│  主窗口   │ 快捷面板  │ 状态栏菜单 │     设置窗口       │
│ContentView│QuickPaste│ MenuBar   │  SettingsView     │
│          │ PanelView│  View     │                   │
├──────────┴──────────┴───────────┴───────────────────┤
│              ClipFlowStore (@MainActor)              │
│       业务核心 · 状态管理 · 持久化 · 分类器            │
├──────────┬──────────┬───────────┬───────────────────┤
│Clipboard │  Paste   │  HotKey   │    CloudSync      │
│ Monitor  │ Service  │Controller │   Coordinator     │
├──────────┴──────────┴───────────┴───────────────────┤
│              macOS 系统层                             │
│  NSPasteboard · Carbon HotKey · AX · StatusBar      │
└─────────────────────────────────────────────────────┘
```

### 2.1 分层职责

| 层级 | 职责 | 关键类型 |
|------|------|---------|
| **应用入口** | 生命周期、窗口创建与导航 | `ClipFlowApp`, `ClipFlowAppDelegate`, `LibraryWindowController`, `SettingsWindowController`, `AppNavigationCenter` |
| **视图层** | 所有 UI 界面与交互 | `ContentView`, `QuickPastePanelView`, `MenuBarView`, `SettingsView`, `InspectorOverlay` |
| **业务层** | 数据模型、状态管理、智能分类 | `ClipFlowStore`, `ClipboardClassifier`, `ClipboardItem`, `ClipboardKind`, `PrivacyLevel` |
| **服务层** | 系统能力集成与后台任务 | `ClipFlowRuntime`, `ClipboardMonitor`, `PasteService`, `HotKeyController`, `CloudSyncCoordinator` |
| **设计系统** | 视觉 Token 与可复用组件 | `ClipFlowPalette`, `ClipFlowSpacing`, `ClipFlowRadius`, `ClipFlowTypography`, `ClipFlowMotion` |

---

## 3. 数据模型

### 3.1 ClipboardItem

```swift
struct ClipboardItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String              // 标题/摘要
    var snippet: String            // 预览文本（≤120 字符）
    var fullText: String           // 完整文本（≤20KB）
    var sourceApp: String          // 来源应用名
    var sourceBundleID: String?    // 来源 Bundle ID
    var createdAt: Date
    var kind: ClipboardKind        // 内容类型
    var privacy: PrivacyLevel      // 隐私级别
    var labels: [String]           // 智能标签
    var pinned: Bool               // 置顶
    var localOnly: Bool            // 仅本地
    var autoExpire: Bool           // 自动过期
    var pasteTargets: [String]     // 推荐粘贴目标
    var expiresAt: Date?
    // 图片专属字段
    var imageFilename: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var imageSignature: String?    // SHA256 去重签名
}
```

### 3.2 内容类型 (ClipboardKind)

| 类型 | 识别规则 | 图标 | 颜色 |
|------|---------|------|------|
| `text` | 默认 | `text.alignleft` | 蓝灰 |
| `code` | 含代码关键字/语法特征 | `terminal` | 浅蓝 |
| `link` | URL 格式匹配 | `link` | 浅蓝 |
| `secret` | 匹配 API Key/Token/SSH Key 等模式 | `lock.fill` | 红 |
| `image` | NSPasteboard 图片类型 | `photo.stack.fill` | 青绿 |

### 3.3 隐私级别 (PrivacyLevel)

| 级别 | 行为 |
|------|------|
| `standard` | 正常存储与显示 |
| `masked` | 预览遮罩，需手动显示 |
| `vault` | 遮罩 + 仅本地 + 自动过期 |

### 3.4 分类视图 (ClipCategory)

6 个分类面板：全部、快速粘贴、智能分组、代码、链接、隐私保护。每类带独立颜色、图标、标题和描述。

---

## 4. 核心服务

### 4.1 剪切板监听 (ClipboardMonitor)

```
定时轮询（0.24s 间隔，0.04s 容差）
  ↓
检查 NSPasteboard.changeCount 变化
  ↓
排除检查（自身 / 排除列表 / 暂停状态）
  ↓
提取内容（文本优先，图片其次）
  ↓
ClipFlowStore.ingestCopiedText() 或 ingestCopiedImage()
  ↓
ClipboardClassifier 自动分类（kind + privacy + labels + pasteTargets）
```

**图片处理流程：**
1. 尝试从 NSPasteboard 直接获取 NSImage
2. 尝试从文件 URL 加载（拖入的图片文件）
3. 转换为 PNG 格式，提取尺寸信息
4. SHA256 签名去重

### 4.2 粘贴服务 (PasteService)

```
paste(item, preferredTarget)
  ↓
① 抑制监听器下一次捕获
  ↓
② 恢复内容到 NSPasteboard（文本 → setString，图片 → writeObjects）
  ↓
③ 激活目标应用
  ↓
④ 请求辅助功能权限（AXIsProcessTrustedWithOptions）
  ↓
⑤ 延迟 0.16s 后通过 CGEvent 发送 Cmd+V
```

### 4.3 全局快捷键 (HotKeyController)

- 使用 Carbon `RegisterEventHotKey` API
- 快捷键：**Option + V** (`kVK_ANSI_V` + `optionKey`)
- 触发 → `ClipFlowRuntime.toggleHUD()`

### 4.4 快捷粘贴面板 (QuickPastePanelController)

- NSPanel (borderless, nonactivatingPanel)
- 尺寸：352 × 520pt，圆角 24pt
- 层级：`.statusBar`
- **智能定位算法：**
  - 4 个候选位置（鼠标四象限）
  - 评分 = 溢出惩罚 × 20 + 距离惩罚
  - 选最优并 clamp 到屏幕安全区

### 4.5 iCloud 同步 (CloudSyncCoordinator)

**同步目录：** `~/Documents/ClipFlow/`

**同步策略：**
- 普通文本和图片 → 同步
- `localOnly` 或 `autoExpire` 项 → 不同步
- 删除记录（tombstone）保留 30 天
- 定期同步间隔 25 秒
- 图片通过 SHA256 签名去重

**合并算法：**
1. 合并双方 tombstones
2. 按 `lastModified` 选择较新版本
3. 过滤已删除项
4. 保留最近 maxItems 条
5. 双向同步图片文件
6. 清理孤立文件

---

## 5. 视图架构

### 5.1 文件结构

```
Sources/ClipFlowApp/
├── ClipFlowApp.swift          # @main 入口、AppDelegate、窗口控制器
├── Models.swift               # 数据模型、分类器、ClipFlowStore
├── Services.swift             # 运行时服务、HUD 视图
├── StatusBarController.swift  # 状态栏控制器
├── CloudSync.swift            # iCloud 同步
├── ClipFlowMotion.swift       # 动效参数
├── DesignTokens.swift         # 间距、圆角、排版、调色板
├── ButtonStyles.swift         # 统一按钮样式
├── InteractiveHostingView.swift # 通用交互卡片（NSViewRepresentable）
├── ContentView.swift          # 主窗口（Header、Sidebar、Library）
├── MenuBarView.swift          # 状态栏弹出菜单
├── SettingsView.swift         # 设置页
├── InspectorOverlay.swift     # 详情浮层、权限浮层
└── SharedComponents.swift     # 通用 UI 组件
```

### 5.2 界面层级

```
┌─ 主窗口 (ContentView) ─────────────────────────┐
│  HeaderView          搜索、概览、快捷按钮         │
│  ├─ SidebarView      6 个分类（网格 3×2）        │
│  └─ LibraryView      条目列表 + 指标卡片         │
│       └─ LibraryInspectorOverlay（浮层）         │
├─ 快捷面板 (QuickPastePanelView) ───────────────┤
│  搜索框 + 条目列表 + 操作按钮                     │
│       └─ HUDInspectorOverlay（浮层）             │
├─ 状态栏菜单 (MenuBarView) ─────────────────────┤
│  Header + 最近条目 + 操作按钮 + 退出              │
│       └─ HUDInspectorOverlay（浮层）             │
└─ 设置窗口 (SettingsView) ──────────────────────┘
   Toggle 卡片组 + 排除应用编辑器
```

### 5.3 交互模型

| 界面 | 左键 | 双击 | 右键 |
|------|------|------|------|
| 主窗口条目 | 选中 | — | 打开详情浮层 |
| 快捷面板条目 | 选中 | 立即粘贴 | 打开详情浮层 |
| 菜单栏条目 | 复制到剪贴板 | 快贴模式下粘贴 | 打开详情浮层 |

交互通过统一的 `InteractiveCard`（NSViewRepresentable）实现，支持 `onPrimary`、`onDoubleTap`、`onSecondary` 三个回调。

---

## 6. 设计系统（Design Tokens）

### 6.1 间距 (ClipFlowSpacing)

| Token | 值 | 用途 |
|-------|-----|------|
| `xs` | 4pt | 最小间隙 |
| `sm` | 8pt | 行内间距 |
| `md` | 12pt | 组件间距 |
| `lg` | 18pt | 区块间距 |
| `xl` | 24pt | 页面级间距 |
| `cardPadding` | 14pt | 卡片内边距 |
| `panelPadding` | 18pt | 面板内边距 |

### 6.2 圆角 (ClipFlowRadius)

| Token | 值 | 用途 |
|-------|-----|------|
| `panel` | 28pt | 主面板/窗口 |
| `overlay` | 26pt | 浮层 |
| `hudPanel` | 24pt | HUD 面板 |
| `card` | 20pt | 卡片 |
| `innerCard` | 18pt | 嵌套卡片 |
| `input` | 16pt | 输入框 |
| `button` | 15pt | 按钮 |
| `badge` | 12pt | 徽章/图标 |

### 6.3 排版 (ClipFlowTypography)

| Token | 字号 | 字重 | 设计 |
|-------|------|------|------|
| `heroTitle` | 30pt | bold | rounded |
| `sectionTitle` | 28pt | bold | rounded |
| `overlayTitle` | 24pt | bold | rounded |
| `menuTitle` | 15pt | bold | rounded |
| `body` | 13pt | medium | default |
| `bodyBold` | 13pt | bold | rounded |
| `caption` | 12pt | medium | default |
| `captionCode` | 12pt | medium | monospaced |
| `badge` | 10pt | bold | default |
| `smallCaption` | 11pt | medium | default |

### 6.4 调色板 (ClipFlowPalette)

支持明暗双模式，通过 `ClipFlowPalette.resolve(for:)` 获取。

**核心颜色：**
- 主强调色：`Color(red: 0.30, green: 0.59, blue: 0.92)`
- 分类色系：橙（快贴）、青绿（分组）、浅蓝（代码/链接）、红（隐私）、绿（运行状态）
- 表面：毛玻璃材质 + 渐变分层

### 6.5 动效 (ClipFlowMotion)

| Token | 值 | 用途 |
|-------|-----|------|
| `overlay` | spring(0.22, 0.92) | 浮层出入 |
| `selection` | easeOut(0.14s) | 选中态 |
| `press` | easeOut(0.10s) | 按压态 |
| `fade` | easeOut(0.16s) | 淡入淡出 |
| `overlayTransition` | scale(0.985) + opacity | 浮层转场 |

### 6.6 按钮样式

**ClipFlowButtonStyle** — 通用按钮，支持 3 种尺寸：
- `.regular`：14pt 字号，H14/V10 内边距，15pt 圆角
- `.compact`：12pt 字号，H12/V8 内边距，13pt 圆角
- `.dense`：11pt 字号，H10/V6 内边距，12pt 圆角

**MenuActionButtonStyle** — 菜单栏专用，支持 4 种布局：
- `.compact` / `.footer` / `.tile` / `.row`

---

## 7. 持久化策略

### 7.1 本地存储

| 数据 | 位置 | 格式 |
|------|------|------|
| 历史记录 | `~/Library/Application Support/ClipFlow/history.json` | JSON (sorted keys) |
| 图片文件 | `~/Library/Application Support/ClipFlow/images/` | PNG (UUID.png) |
| 用户设置 | UserDefaults | Key-Value |

### 7.2 写入策略

- **原子写入**：防止中途崩溃损坏文件
- **条目上限**：80 条，超限删除最老非置顶项
- **图片缓存**：NSCache（最多 100 张）
- **过期清理**：启动时自动清理过期项
- **孤立文件清理**：定期检查无引用的图片文件

### 7.3 iCloud 同步存储

| 数据 | 位置 |
|------|------|
| 同步记录 | `~/Documents/ClipFlow/history.json` |
| 同步图片 | `~/Documents/ClipFlow/images/` |

---

## 8. 窗口管理

### 8.1 窗口类型

| 窗口 | 尺寸 | 最小尺寸 | 行为 |
|------|------|---------|------|
| 主窗口 | 500×780 | 500×600 | 关闭时隐藏，位置记忆 |
| 设置窗口 | 540×600 | 540×600 | 关闭时隐藏，位置记忆 |
| 快捷面板 | 352×520 | 固定 | borderless panel，失焦自动关闭 |
| 状态栏菜单 | 320×620 | — | NSPopover |

### 8.2 启动行为

- **正常启动**：显示主窗口
- **驻留模式**（launchToStatusBar=true）：仅显示状态栏图标
- **开机启动**：通过 SMAppService 或 LaunchAtLogin 集成

---

## 9. 安全与隐私

### 9.1 权限需求

| 权限 | 用途 | 必须 |
|------|------|------|
| 辅助功能 | 自动粘贴（CGEvent 发送 Cmd+V） | 可选 |
| 文稿目录 | iCloud 同步 | 可选 |

### 9.2 敏感内容检测

自动匹配以下模式：
- API Key / Token（`sk-`、`ghp_`、`AKIA` 等前缀）
- JWT Token
- SSH 私钥
- AWS 访问密钥
- 硬编码凭证（`password=`、`secret=` 等）
- 验证码模式（纯数字 4-8 位）

检测到后自动设置 `privacy = .masked` 或 `.vault`，根据来源应用进一步升级。

### 9.3 排除应用

用户可配置 Bundle ID 列表，来自这些应用的复制操作完全不被记录。默认排除：
- 1Password、Bitwarden 等密码管理器
- Keychain Access

---

## 10. 智能分类器 (ClipboardClassifier)

### 10.1 分类流程

```
输入文本
  ↓
URL 检测 → kind: .link
  ↓
代码特征检测 → kind: .code
  （关键字密度、语法符号、Shell 命令模式）
  ↓
敏感模式检测 → kind: .secret
  ↓
默认 → kind: .text
  ↓
隐私级别判定（来源应用 + 内容模式 + 用户设置）
  ↓
智能标签生成（来源、类型、语言、操作类型等）
  ↓
推荐粘贴目标（基于 kind）
```

### 10.2 编程语言识别

支持识别标签：Swift、Python、JavaScript、TypeScript、HTML、CSS、JSON、SQL、Shell、Go、Rust、Java、Kotlin、Ruby、PHP、C/C++、Markdown

---

## 11. 构建与发布

### 11.1 本地构建

```bash
# 调试构建
swift build
swift run ClipFlowApp

# 发布构建
swift build -c release

# 打包 .app
./scripts/build_app.sh
open dist/ClipFlow.app
```

### 11.2 打包流程 (build_app.sh)

1. 渲染应用图标（1024px → iconset → .icns）
2. `swift build -c release`
3. 创建 .app 目录结构
4. 复制二进制到 `Contents/MacOS/`
5. 生成 `Info.plist`
6. 生成 `.icns` 到 `Contents/Resources/`
7. Ad-hoc 签名 (`codesign --force --deep --sign -`)

### 11.3 自动化发布

GitHub Actions 工作流：推送 tag 时自动构建 DMG 并创建 Release。

---

## 12. 项目依赖图

```
ClipFlowApp.swift
  └── ClipFlowAppDelegate
        ├── ClipFlowRuntime (singleton)
        │     ├── ClipFlowStore (singleton, @MainActor)
        │     │     └── ClipboardClassifier
        │     ├── ClipboardMonitor
        │     ├── PasteService
        │     ├── HotKeyController
        │     └── QuickPastePanelController
        ├── StatusBarController
        │     └── MenuBarView → ClipFlowStore
        ├── LibraryWindowController
        │     └── ContentView → ClipFlowStore
        ├── SettingsWindowController
        │     └── SettingsView → ClipFlowStore
        └── CloudSyncCoordinator → ClipFlowStore
```

---

## 13. 已知限制

1. **iCloud 同步**：需要正式签名和 iCloud capability，ad-hoc 构建下不可用
2. **辅助功能**：首次使用自动粘贴时需手动授权
3. **图片存储**：仅支持 PNG 格式，大图未做压缩优化
4. **条目上限**：固定 80 条，无自适应策略
5. **搜索**：仅支持全文字符串匹配，无模糊搜索

---

## 14. 后续规划

- [ ] 图片 OCR 文字识别
- [ ] 更强的语义分组能力
- [ ] 文件类内容支持
- [ ] 项目化内容栈
- [ ] 快捷指令 (Shortcuts) 集成
- [ ] 正式签名后完善 iCloud 同步
- [ ] 自动化工作流
- [ ] 多语言支持
