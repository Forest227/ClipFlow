# ClipFlow 技术设计文档

> 状态：当前实现整理版
> 技术栈：Swift 6 + SwiftUI + AppKit + SPM

## 1. 项目概览

ClipFlow 是一个 macOS 原生剪贴板工具，重点实现以下能力：

- 监听剪贴板变化
- 按内容类型进行本地识别
- 保存最近历史内容
- 在鼠标附近通过快捷面板快速找回并再次粘贴
- 通过状态栏菜单与主窗口提供更完整的浏览和管理能力
- 在隐私、同步和权限方面保持明确边界

## 2. 技术约束

- 最低系统：`macOS 14`
- 构建系统：`Swift Package Manager`
- UI 技术：`SwiftUI` 为主，`AppKit` 处理系统级能力
- 依赖策略：无第三方依赖
- 界面语言：中文

## 3. 架构总览

ClipFlow 的结构可以概括为四层：

1. 应用入口层：负责生命周期、窗口和全局导航
2. 视图层：负责主窗口、快捷面板、状态栏菜单和设置界面
3. 状态与业务层：负责条目模型、分类、筛选、持久化和同步调度
4. 系统服务层：负责剪贴板监听、自动粘贴、全局快捷键、状态栏和 iCloud 协调

核心关系如下：

```text
ClipFlowApp / AppDelegate
  -> ClipFlowRuntime
  -> StatusBarController
  -> WindowControllers

ClipFlowRuntime
  -> ClipFlowStore.shared
  -> ClipboardMonitor
  -> PasteService
  -> HotKeyController
  -> QuickPastePanelController

ClipFlowStore
  -> ClipboardClassifier
  -> local persistence
  -> CloudSyncCoordinator
```

## 4. 主要模块

### 4.1 `ClipFlowApp.swift`

负责应用入口与窗口组织：

- 注册 `AppDelegate`
- 创建主窗口和设置窗口
- 在启动后启动运行时服务
- 控制是否默认显示主窗口，还是驻留状态栏

### 4.2 `Models.swift`

这是业务核心文件，主要包含：

- 内容模型，例如 `ClipboardItem`
- 内容类型与隐私级别定义
- 分类与标签逻辑
- `ClipFlowStore` 单例
- 本地持久化与恢复
- 搜索、筛选、置顶、删除、过期清理

### 4.3 `Services.swift`

负责运行时服务与系统交互：

- `ClipFlowRuntime`：组织运行时生命周期
- `ClipboardMonitor`：监听 `NSPasteboard`
- `PasteService`：恢复内容并尝试自动粘贴
- `HotKeyController`：注册全局快捷键
- `QuickPastePanelController`：控制快捷面板显示与定位

### 4.4 `StatusBarController.swift`

负责菜单栏图标、Popover 和状态栏导航，承担系统常驻入口。

### 4.5 `CloudSync.swift`

负责 iCloud 文稿目录相关同步协调、冲突合并、删除墓碑和图片文件同步。

### 4.6 视图相关文件

- `ContentView.swift`：主窗口
- `MenuBarView.swift`：状态栏弹出菜单
- `SettingsView.swift`：设置页
- `InspectorOverlay.swift`：详情与权限提示浮层
- `SharedComponents.swift`：复用组件
- `ButtonStyles.swift`、`DesignTokens.swift`、`ClipFlowMotion.swift`：设计系统基础
- `InteractiveHostingView.swift`：SwiftUI 与 AppKit 交互桥接

## 5. 核心数据模型

### 5.1 `ClipboardItem`

每条历史记录至少包含以下维度：

- 唯一标识
- 标题与摘要
- 完整文本
- 来源应用与来源 Bundle ID
- 创建时间
- 内容类型
- 隐私级别
- 标签
- 是否置顶
- 是否仅本地保存
- 是否自动过期

对于图片条目，还会记录：

- 本地图片文件名
- 图片宽高
- 内容签名，用于去重

### 5.2 `ClipboardKind`

当前实现围绕以下主要类型展开：

- `text`
- `link`
- `code`
- `secret`
- `image`

该类型会影响图标、强调色、预览方式和默认动作。

### 5.3 `PrivacyLevel`

隐私级别决定条目的默认展示与同步行为。典型策略包括：

- 正常展示
- 遮罩展示
- 更强保护，同时仅本地保存或自动过期

## 6. `ClipFlowStore` 的职责

`ClipFlowStore` 是当前项目的中心状态对象，运行在 `@MainActor` 上。它的职责包括：

- 持有全部条目与筛选状态
- 处理搜索和分类切换
- 控制当前选中项
- 维护监听开关、外观模式、启动行为、同步开关等用户设置
- 调度本地持久化
- 触发 iCloud 同步
- 管理图片缓存和本地图片目录
- 处理启动时权限检查

当前架构的优点是实现路径直观，缺点是 `Models.swift` 与 `ClipFlowStore` 仍然偏大，后续仍有继续拆分空间。

## 7. 剪贴板监听流程

监听流程以轮询 `NSPasteboard.changeCount` 为核心：

1. 定时检查粘贴板变更计数
2. 若没有变化，则跳过
3. 若当前处于暂停监听、自身写回抑制、或来源应用在排除列表中，则跳过
4. 优先读取文本内容，必要时读取图片内容
5. 交由分类逻辑决定类型、标题、标签和隐私级别
6. 将新条目插入历史并触发持久化

关键目标是避免以下问题：

- 自身写回被重复捕获
- 被排除应用的内容进入历史
- 图片文件无节制增长
- 敏感内容以普通项形式展示

## 8. 内容识别流程

ClipFlow 当前采用规则驱动的识别方式。大致顺序是：

1. URL 检测，识别链接
2. 代码特征检测，识别代码片段
3. 敏感模式检测，例如 Token、密钥、验证码和硬编码凭证
4. 兜底归类为普通文本

随后再根据来源应用、内容模式和用户设置，决定：

- 标题
- 预览摘要
- 标签
- 推荐粘贴目标
- 隐私等级

## 9. 再次粘贴流程

`PasteService` 负责重新回贴内容。典型过程如下：

1. 通知监听器忽略下一次由自身写入造成的变更
2. 将目标条目恢复到 `NSPasteboard`
3. 尝试激活原应用或当前目标应用
4. 检查辅助功能权限
5. 若权限可用，则通过系统事件发送 `Cmd+V`

这条链路的关键并不只是“写回剪贴板”，而是尽量让用户感知为“我在当前应用里直接重新粘贴了刚才那条内容”。

## 10. 快捷面板与状态栏

### 10.1 快捷面板

快捷面板基于 `NSPanel` 构建，负责：

- 在鼠标附近弹出
- 列出最近可用内容
- 接收键盘与鼠标选择
- 在必要时显示详情浮层

面板位置并非固定，而是会根据鼠标位置与屏幕安全区选择更合适的展示区域。

### 10.2 状态栏

状态栏入口基于 `NSStatusItem + NSPopover` 实现，负责：

- 常驻展示应用状态
- 提供最近历史概览
- 提供打开主窗口、设置和退出等动作
- 在暂停监听状态下改变图标语义

## 11. 持久化与文件结构

### 11.1 本地持久化

当前本地存储的主要内容包括：

- `history.json`：历史记录
- `images/`：本地图片文件
- `UserDefaults`：外观、开机启动、同步开关、排除应用等轻量设置

持久化策略重点包括：

- 原子写入
- 条目数量上限
- 过期内容清理
- 孤立图片文件清理
- 图片缓存

### 11.2 iCloud 同步

iCloud 同步目前被视为便利层，而不是主流程假设。同步时会考虑：

- 是否允许同步当前条目
- 敏感内容是否仅本地保留
- 删除墓碑合并
- 图片文件是否已存在
- 冲突时保留较新版本

## 12. UI 组织方式

### 12.1 主窗口

主窗口由 `ContentView` 负责，主要包含：

- 顶部信息区与搜索入口
- 分类区
- 历史内容列表
- 指标与概览信息
- 居中详情浮层

### 12.2 设置页

设置页独立成 `SettingsView`，用于承载：

- 外观模式
- 开机启动
- 启动时驻留状态栏
- iCloud 同步
- 自动保护敏感内容
- 排除应用编辑

### 12.3 菜单栏与快捷面板

`MenuBarView` 和 `QuickPastePanelView` 共用一部分组件和交互模型，从而保证：

- 视觉语言一致
- 条目认知模型一致
- 详情查看方式一致

## 13. 设计系统

当前设计系统分散在以下文件中：

- `DesignTokens.swift`：间距、圆角、排版、调色板
- `ButtonStyles.swift`：统一按钮风格
- `ClipFlowMotion.swift`：动效常量
- `SharedComponents.swift`：复用 UI 组件

这层的目标是确保主窗口、状态栏、快捷面板和设置页在视觉节奏上属于同一个产品。

## 14. 构建与发布

### 14.1 本地开发

```bash
swift build
swift run ClipFlowApp
```

### 14.2 构建 `.app`

```bash
./scripts/build_app.sh
```

构建脚本会完成以下工作：

1. 生成或刷新应用图标
2. 执行 release 构建
3. 创建 `.app` 目录结构
4. 生成 `Info.plist`
5. 拷贝二进制与图标资源
6. 完成 ad-hoc 签名

### 14.3 构建 `.dmg`

```bash
./scripts/build_release_dmg.sh v0.0.1
```

GitHub Actions 中的 `release.yml` 也使用同一套打包思路：根据 tag 构建 DMG 并更新 Release 资产。

## 15. 已知限制

- iCloud 同步依赖正式签名与 capability，本地 ad-hoc 构建通常不可用
- 自动粘贴依赖辅助功能权限
- 当前搜索仍以字符串匹配为主，尚未引入模糊搜索
- `ClipFlowStore` 与部分文件仍然偏大，后续可继续拆分
- 图片处理仍有继续优化压缩与性能的空间

## 16. 后续可演进方向

- 进一步拆分 `ClipFlowStore`
- 将分类器规则与展示逻辑解耦
- 增强图片与文件类内容支持
- 增强搜索、分组和语义标签能力
- 在正式签名后完善同步链路和发布流程
