# ClipFlow 设计规范

## 产品定位

macOS 原生剪贴板效率工具。核心路径：复制 → 呼出面板 → 识别内容 → 回贴。隐私保护是主流程，不是附属设置。

## 视觉语言

### 色彩系统

深色模式背景：`#171A24` 系列（深蓝灰）
浅色模式背景：`#F0F0F2`（浅灰）
主色调：蓝色 `rgb(0.30, 0.59, 0.92)`

分类色彩（tint）：
- 全部：蓝色系
- 快速粘贴：橙色系
- 受保护：红/粉色系
- 链接：蓝绿色系
- 代码：紫色系
- 智能分组：青色系

### 圆角体系

```
panel: 28    overlay: 26    hudPanel: 24
card: 20     menuHeader: 20  innerCard: 18
input: 16    menuRow: 16     button: 15
menuButton: 14  hudButton: 13  badge: 12
icon: 12     smallIcon: 9
```

### 间距体系

```
xs: 4   sm: 8   md: 12   lg: 18   xl: 24
panelPadding: 18   cardPadding: 14
inputPaddingH: 14  inputPaddingV: 11
```

### 字体体系

- 标题：`.rounded` design，bold/semibold
- 正文：13pt medium/semibold
- 说明：12pt medium，次要信息用 `.secondary`
- 代码：monospaced 12pt
- 徽章：10pt bold，最小 9pt bold

## 组件规范

### FrostedPanel
主要容器，`softFill` 背景 + `border` 描边 + 阴影 `radius:28 y:18`。

### ClipboardCard
内容卡片，选中态：tint 12% 背景 + tint 40% 描边 + 0.996 缩放。

### CategoryRow
分类按钮，固定高度 92pt，选中态渐变背景 + tint 描边。

### 徽章/胶囊
统一用 `Capsule` + tint 12% 背景，文字用 tint 色。

### 按钮
三种尺寸：regular(13pt/14H/10V)、compact(12pt/12H/8V)、dense(12pt/13H/8V)。
按压态：0.985 缩放 + 75% 不透明度。

## 交互原则

- 选中/切换动画：`ClipFlowMotion.selection`
- 覆盖层动画：`ClipFlowMotion.overlay`，背景模糊 + 18% 黑色遮罩
- 按压动画：`ClipFlowMotion.press`
- 快捷面板：轻量 HUD，出现在鼠标附近，不做大窗口

## 布局规则

- 最大内容宽度：1460pt
- 宽屏（≥1140）：侧边栏(228pt) + 主内容区并排
- 窄屏（<1140）：垂直堆叠
- 使用 `ViewThatFits` 处理自适应布局

## 设计禁忌

- 不引入第三方视觉风格组件
- 不把快捷面板做成大窗口
- 不让详情区长期挤压主内容区
- 不把敏感内容保护藏入深层设置
- 不牺牲扫描效率换取展示感
