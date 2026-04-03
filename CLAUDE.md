# ClipFlow 协作指南

## 项目目标

ClipFlow 是一个面向 macOS 的原生剪贴板效率工具。所有实现都应服务于同一条主路径：复制内容、在当前上下文附近找回内容、立刻再次粘贴。

## 协作基线

- 保持“指针优先、上下文不中断”的产品方向
- 保持“识别优于回忆”的内容组织方式
- 把隐私能力视为主流程，而不是附属设置
- 优先维持 macOS 原生体验，而不是堆叠跨平台式功能
- 在高信息密度下仍然保证阅读层次和可扫描性
- 默认使用中文界面与中文文档

## 技术约束

- `SwiftUI + AppKit` 混合架构
- `Swift 6`
- `macOS 14+`
- 纯 `SPM` 构建
- 不引入第三方依赖

## 改动优先级

1. 先保护主流程：监听、历史、快捷呼出、回贴
2. 再保护信任模型：敏感内容、排除应用、暂停监听、同步边界
3. 最后再扩展次要功能和视觉抛光

## 关键文件

- `Sources/ClipFlowApp/ClipFlowApp.swift`：应用入口与窗口控制
- `Sources/ClipFlowApp/ContentView.swift`：主窗口核心界面
- `Sources/ClipFlowApp/Models.swift`：数据模型、分类器、Store、持久化
- `Sources/ClipFlowApp/Services.swift`：监听、粘贴、快捷键、快捷面板
- `Sources/ClipFlowApp/StatusBarController.swift`：状态栏与 Popover
- `Sources/ClipFlowApp/SettingsView.swift`：设置页
- `Sources/ClipFlowApp/DesignTokens.swift`：设计 Token
- `docs/clipflow-design.md`：产品与交互设计说明
- `docs/clipflow-technical-design.md`：架构与实现说明

## UI 改动要求

- 不要把快捷粘贴面板做成笨重的大窗口
- 不要让详情区长期挤压主内容区
- 不要为了展示感牺牲扫描效率
- 不要把敏感内容保护隐藏到深层设置中
- 不要引入与现有视觉语言冲突的组件风格

## 服务层改动要求

- 监听逻辑必须尽量减少误捕获与自捕获
- 自动粘贴链路必须优先保证稳定性和可预期性
- iCloud 同步要保持“便利层”定位，不可假设其一定可用
- 对敏感内容的处理必须优先保守

## 文档同步要求

涉及下列变化时，需要同步更新文档：

- 产品定位或核心交互变化：更新 `README.md` 与 `docs/clipflow-design.md`
- 架构、模块职责、持久化、构建流程变化：更新 `docs/clipflow-technical-design.md`
- 发布内容变化：更新 `docs/releases/`

## 常用验证

```bash
swift build
swift run ClipFlowApp
./scripts/build_app.sh
./scripts/build_release_dmg.sh v0.0.1
```

## 交付标准

- 主流程完整可用
- 视觉与交互不偏离既有品牌方向
- 隐私与系统集成能力没有被弱化
- 文档与实际代码结构保持一致
