# ClipFlow 项目文件清单

> 适用场景：项目梳理、仓库迁移、重新推送 GitHub、发布前检查

## 1. 仓库定位

- 项目名称：`ClipFlow`
- 产品形态：macOS 原生剪贴板效率工具
- 技术栈：`Swift 6 + SwiftUI + AppKit + Swift Package Manager`
- 最低系统：`macOS 14`
- 依赖策略：无第三方依赖
- 主要界面语言：中文

## 2. 顶层目录

- `Sources/`：应用源码
- `docs/`：产品、技术、发布与项目清单文档
- `scripts/`：构建、打包与图标生成脚本
- `assets/`：图标素材
- `.github/`：GitHub Actions 工作流
- `Tests/`：测试目录，当前结构已创建但内容仍较少

## 3. 核心源码目录

项目核心代码集中在 `Sources/ClipFlowApp/`，其中最重要的文件如下：

- `ClipFlowApp.swift`
  应用入口、`AppDelegate`、主窗口与设置窗口控制

- `Models.swift`
  数据模型、分类器、`ClipFlowStore`、持久化与筛选逻辑

- `Services.swift`
  剪贴板监听、自动粘贴、快捷键、快捷面板和运行时服务

- `StatusBarController.swift`
  状态栏图标、菜单栏 Popover 和系统常驻入口

- `ContentView.swift`
  主窗口核心界面

- `MenuBarView.swift`
  状态栏菜单界面

- `SettingsView.swift`
  设置界面

- `CloudSync.swift`
  iCloud 同步协调逻辑

- `DesignTokens.swift`
  间距、圆角、排版、配色等视觉 Token

- `SharedComponents.swift`
  通用 UI 组件

## 4. 文档文件

当前主要文档包括：

- `README.md`
  仓库入口说明

- `.impeccable.md`
  设计上下文与品牌/体验边界

- `AGENTS.md`
  协作说明

- `CLAUDE.md`
  协作说明副本

- `docs/clipflow-design.md`
  产品与交互设计文档

- `docs/clipflow-technical-design.md`
  架构与实现说明

- `docs/releases/v0.0.1.md`
  `v0.0.1` 发布说明

- `docs/releases/v0.0.2.md`
  `v0.0.2` 发布说明

- `docs/project-inventory.md`
  当前这份项目清单

## 5. 构建与发布脚本

- `scripts/build_app.sh`
  构建 `ClipFlow.app`

- `scripts/build_release_dmg.sh`
  构建 `.dmg` 与校验文件

- `scripts/render_icon.swift`
  生成主图标

- `scripts/render_icon_classic.swift`
  生成经典图标

## 6. 素材与资源

- `assets/icon/ClipFlow-icon-1024.png`
  主图标源文件

- `assets/icon/ClipFlow-classic-icon-1024.png`
  经典图标源文件

- `assets/icon/ClipFlow-icon-1024_副本.png`
  额外图标副本，若不再需要可在清理仓库时移除

## 7. 本地产物与忽略项

以下目录或文件通常不应作为源码真源提交：

- `.build/`
  SwiftPM 构建缓存

- `dist/`
  构建出的 `.app`、图标集与临时发布产物

- `.claude/`
  本地工具配置

- `.DS_Store`
  Finder 自动生成文件

## 8. 当前代码体量

根据当前源码结构，项目体量大致如下：

- Swift 源文件数量：14
- 核心源码总行数：约 6000+ 行
- 体量较大的文件：
  - `Models.swift`
  - `Services.swift`
  - `SharedComponents.swift`
  - `ContentView.swift`

这说明项目当前仍采用“中心化 Store + 复合视图”的实现方式，后续可继续按模块拆分。

## 9. 重新推送 GitHub 时建议保留的内容

如果目标是重新整理一个可公开推送的源码仓库，建议优先保留：

- `Package.swift`
- `Sources/ClipFlowApp/`
- `scripts/`
- `assets/icon/`
- `docs/`
- `.github/workflows/`
- `README.md`
- `.impeccable.md`
- `AGENTS.md`
- `CLAUDE.md`
- `.gitignore`

## 10. 推送前建议检查

- 确认 `dist/` 与 `.build/` 没有被误提交
- 确认测试目录是否需要补充最基础的 smoke test
- 确认图标副本是否仍有保留必要
- 确认 `README.md` 与 `docs/` 中描述的版本、构建方式、发布方式与当前代码一致
- 若准备发布正式版本，确认签名、权限说明和 Release 产物目录已经整理完毕
