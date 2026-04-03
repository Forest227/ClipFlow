# ClipFlow 项目指南

## Design Context

详细设计上下文请参考 `.impeccable.md`。以下为核心要点：

### 品牌个性
流畅、高级、干净、可信

### 设计原则
1. **指针优先，上下文不中断** — 快捷面板贴近指针，操作完成立即回到原上下文
2. **识别优于回忆** — 类型图标 + 来源 + 时间 + 颜色编码，一眼可识别
3. **隐私是主流程** — 敏感遮罩、排除应用、暂停监听在日常交互中可见可控
4. **系统级融入 > 功能堆叠** — macOS 原生体验优先：毛玻璃、连续曲率、状态栏
5. **高密度 + 高可读 = 高效率** — 紧凑空间内展示有用信息，通过视觉层次实现可读性

### 参考方向
Linear / Raycast 风格 — 精致、高效、信息密度适中的现代开发者工具美学

### 技术栈
- SwiftUI + AppKit 混合架构，macOS 14+，Swift 6.0
- 纯 SPM 构建，无第三方依赖
- 中文界面（zh-Hans）

### 关键文件
- `ContentView.swift` — 主窗口全部 UI 组件 + ClipFlowPalette 调色板
- `Models.swift` — 数据模型、分类器、ClipFlowStore（业务核心）
- `Services.swift` — 运行时服务（监听、粘贴、快捷键、HUD 面板）
- `StatusBarController.swift` — 状态栏、Popover 菜单
- `CloudSync.swift` — iCloud 同步
- `ClipFlowMotion.swift` — 动效参数
