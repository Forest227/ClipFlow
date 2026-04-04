# ClipFlow 剪流

ClipFlow 是一款面向 macOS 的原生剪贴板效率工具，强调在当前上下文附近快速找回内容、直接完成再次粘贴，并把隐私保护放进日常交互流程中。

## 产品特点

- 快速：按 `Option + V` 可在鼠标附近呼出快捷面板
- 清楚：自动识别文本、链接、代码、图片和敏感内容
- 紧凑：主窗口、状态栏菜单和快捷面板都以高密度信息布局为核心
- 安全：支持敏感内容遮罩、排除应用、暂停监听和本地优先策略
- 原生：基于 SwiftUI 与 AppKit，保持 macOS 工具级体验

## 适合谁

- 经常在文档、浏览器、聊天工具和编辑器之间来回复制内容的人
- 需要反复粘贴链接、代码片段、命令、截图或说明文本的人
- 希望保留历史，但不希望敏感数据被长期无差别保存的人
- 偏好状态栏工具、快捷呼出和原生系统交互的人

## 核心能力

- 快捷粘贴面板：在鼠标附近显示最近历史，并支持快速选择与立即粘贴
- 历史内容库：在主窗口内浏览、筛选、检查和管理复制记录
- 类型识别：自动区分文本、链接、代码、图片和敏感内容
- 图片支持：记录图片、显示缩略图，并展示尺寸信息
- 链接直达：识别 URL 后可直接用默认浏览器打开
- 状态栏菜单：快速查看最近内容、切换监听状态并打开主界面
- 隐私控制：支持敏感内容遮罩、排除应用、暂停监听、仅本地保存
- 外观与启动行为：支持外观模式、开机启动和启动后驻留状态栏

## 技术概览

- 语言：`Swift 6`
- UI：`SwiftUI + AppKit`
- 构建：`Swift Package Manager`
- 系统：`macOS 14+`
- 依赖：无第三方依赖
- 语言：中文界面（`zh-Hans`）

## 仓库结构

- `Sources/ClipFlowApp`：应用主代码
- `docs/clipflow-design.md`：产品与交互设计说明
- `docs/clipflow-technical-design.md`：架构与实现说明
- `docs/releases/`：版本发布说明
- `scripts/`：构建、打包、图标生成脚本
- `assets/icon/`：应用图标素材

## 本地运行

```bash
swift build
swift run ClipFlowApp
```

## 构建应用

```bash
./scripts/build_app.sh
open dist/ClipFlow.app
```

## 打包 DMG

```bash
./scripts/build_release_dmg.sh v0.0.1
```

## 权限与限制

- 自动粘贴依赖 macOS 的“辅助功能”权限
- 若未授予该权限，ClipFlow 仍可记录历史，但无法自动触发回贴
- iCloud 同步需要正确签名和相关 capability，ad-hoc 构建通常不可用
- 当前实现主要面向 macOS 14 及以上系统

## 设计与文档

- 设计上下文：`.impeccable.md`
- 项目协作说明：`AGENTS.md`、`CLAUDE.md`
- 设计文档：`docs/clipflow-design.md`
- 技术文档：`docs/clipflow-technical-design.md`
- 发布说明：`docs/releases/`

## 项目状态

ClipFlow 当前已经具备可运行的主流程：监听剪贴板、保存历史、快速呼出、再次粘贴、状态栏控制和基础隐私策略。后续重点会继续放在同步完善、签名发布、内容识别增强和系统集成稳定性上。
