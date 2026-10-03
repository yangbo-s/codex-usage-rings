---
name: Usage Rings
description: 以绿色圆环和居中百分比呈现每个 Codex 账户剩余额度的 macOS 菜单栏应用。
colors:
  ring-green: "color(srgb 0.13 0.70 0.39)"
  menu-ring-green: "color(srgb 0.16 0.81 0.43)"
  inner-ring-green: "color(srgb 0.40 0.91 0.61)"
  ink-green-light: "color(srgb 0.08 0.43 0.23)"
  ink-green-dark: "color(srgb 0.37 0.88 0.55)"
  secondary-text-light: "color(srgb 0.38 0.38 0.38)"
typography:
  headline:
    fontFamily: "macOS system font"
    fontSize: "18pt"
    fontWeight: 600
  title:
    fontFamily: "macOS system font"
    fontSize: "13pt"
    fontWeight: 600
  value:
    fontFamily: "macOS system font"
    fontSize: "14pt"
    fontWeight: 600
  percentage:
    fontFamily: "macOS system font, monospaced digits"
    fontSize: "8pt"
    fontWeight: 600
  body:
    fontFamily: "macOS system font"
    fontSize: "12pt"
    fontWeight: 400
  label:
    fontFamily: "macOS system font"
    fontSize: "11pt"
    fontWeight: 400
  caption:
    fontFamily: "macOS system font"
    fontSize: "10pt"
    fontWeight: 400
spacing:
  compact: "8pt"
  related: "12pt"
  support: "14pt"
  row: "16pt"
  section: "18pt"
  inset: "20pt"
components:
  usage-panel:
    width: "360pt"
  management-panel:
    width: "360pt"
    height: "560pt"
  account-ring:
    width: "44pt"
    height: "44pt"
  menu-ring-core:
    width: "24pt"
    height: "24pt"
  usage-bar:
    height: "4pt"
---

# Design System: Usage Rings

## Overview

**Creative North Star: "绿色圆环，原生顶栏"**

每个已连接账户对应一个绿色圆环入口，环内直接显示剩余百分比；额度周期、重置时间和账户设置在原生弹出面板中呈现。界面使用系统字体、SF Symbols 和 macOS 控件，保持紧凑、清楚、低干扰。

这是 v0.2 当前实现的记录，主要依据 `Sources/CodexUsageRings/Views.swift`、`RingRenderer.swift`、`Application.swift` 与 `LoginAtLaunch.swift`。尺寸均为 macOS 逻辑点，前置 token 不代表网页 CSS 配置；系统动态色、材质和控件外观继续由原生 API 决定。无演示模式，也不提供置顶或额度周期切换控件。

**Key Characteristics:**
- 一账户一入口：两种额度使用外长内短的同心环，单窗口使用粗单环。
- 中心数字显示外环剩余额度，右侧每条竖线代表一次可用 banked reset。
- 系统材质、系统字体和原生表单控件支持明暗外观。
- 无持续动画；刷新与状态提示优先服务低耗电和可读性。

视觉证据为 `.impeccable/review/v2/` 中的 `rings-light.png`、`rings-dark.png`、`settings-light.png` 和 `settings-dark.png`。这些图片使用测试输入进行原生离屏绘制，不是桌面截图，也不是发布资产。当前 finish review 的 ship 结论仅覆盖源码与原生离屏呈现；实际桌面点击、重启后登录启动和长期电池续航仍未验证。没有运行网页 detector。应用图标使用 Resources/Brand/usage-rings-logo.png，并转换成 Resources/AppIcon.icns 随包交付；生成来源与提示词见同目录的 usage-rings-logo.prompt.txt。菜单栏用量环仍为实时原生绘制。

## Colors

绿色承担额度和关键操作的识别，文字与结构采用系统中性色。

### Primary
- **进度绿**（`ring-green`）：SwiftUI 额度详情中的胶囊进度条。
- **主环亮绿**（`menu-ring-green`）：AppKit 绘制的单环、外环与 reset 竖线，顶栏和面板账户环共用同一 renderer。
- **内环浅绿**（`inner-ring-green`）：同心环中的 5 小时额度；与主环共同表达两个窗口。
- **文字绿**（`ink-green-light` / `ink-green-dark`）：根据 Aqua / Dark Aqua 切换，用于 reset 次数、低耗电标签及面板 tint。不要把进度绿直接用于小字号正文。

### Neutral
- SwiftUI 主文字使用 `primary`；圆环中心使用 `NSColor.labelColor`；面板使用 `regularMaterial`。
- 次级文字在浅色外观使用 `secondary-text-light`，深色外观使用 `NSColor.secondaryLabelColor`。
- 圆环轨道使用 `NSColor.labelColor` 的 18% 不透明度；额度条轨道使用 `primary` 的 8%，选中账户背景使用 2.5%；分隔线使用系统 `Divider`。
- 数据过期时圆弧和 reset 竖线使用系统次级色，账户行同时显示“数据已过期”。中心数字保留系统主文字色。

**The Remaining Rule.** 弧长和额度条长度都表示剩余额度；中心数字取外环窗口，详情文字明确该窗口名称。

## Typography

全部文字使用系统字体，不随包提供自定义字体。面板标题、账户名、reset 数值、正文、标签和小注释对应前置 token；空状态标题也使用 value 层级。额度名称与低耗电标签使用 medium，额度百分比使用 semibold。

percentage 是顶栏基础尺寸的起始字号，使用 `NSFont.monospacedDigitSystemFont`。`RingRenderer` 按绘制直径等比缩放，并以（0.2pt × 比例）逐步缩小，直到文字包围盒的对角线适配环内空间；不得把起始字号理解为固定最终字号。面板账户环复用此计算，中心数字不再使用独立的大号圆润字体。

额度详情中的数字、重置时间与已用比例使用 `monospacedDigit()`，避免数值变化造成跳动。账户名最多一行，空名称显示“未命名账户”；提示、错误与设置说明允许换行。

## Layout

面板固定宽度，头尾固定，中段滚动。管理面板高度由 management-panel 定义；总览无账户时高（330pt），有账户时为 `min(560, 335 + (账户数 - 1) × 80)` 逻辑点。不设网页断点或移动端布局。

常规左右内边距使用 inset；账户行垂直内边距使用 row，头部使用 section，底栏使用 support。账户行左侧是带中心数字的圆环，中部是账户名称和状态，右侧是 reset 次数与标签。详情沿用同一左右边界；管理区使用账户名称输入框、移除入口、全宽连接按钮、登录启动开关及低耗电说明。

顶栏圆环主体尺寸由 menu-ring-core 定义。无 reset 时状态栏入口宽（30pt）；每个入口宽度为 renderer 图像宽度加（6pt）。有 N 个 reset 时，基础图像向右额外扩展 `4 + 4 × N` 逻辑点，避免竖线覆盖圆环；账户排列交给系统状态栏。面板账户环隐藏竖线，在行右侧用数值表达 reset 次数。

## Elevation & Depth

深度来自 `NSPopover`、`regularMaterial` 和系统控件。项目没有自定义阴影 token。列表通过分隔线与轻微底色区分区域，选中账户不新增悬浮卡片。

弹出面板采用 `.transient` 行为且 `animates = false`。圆环和额度条没有持续动画；同步期间使用原生小型 `ProgressView`。后台默认每 5 分钟刷新，系统低电量模式每 15 分钟；睡眠暂停，查询结束关闭查询进程。打开面板复用最近 60 秒的快照。低耗电策略是实现约束，不代表已完成长期电池续航测量。

## Shapes

核心几何是圆环、圆端弧线、圆端 reset 竖线和胶囊额度条。以下 renderer 几何以顶栏基础直径为基准，其他直径按比例缩放。

单窗口描边（3.8pt）；同心环外描边（1.65pt），内描边（1.45pt），内环路径半径（8.5pt）。外环路径半径为 `直径 / 2 - 外描边 / 2 - 0.6`。弧线从顶部开始顺时针增长；100% 绘制完整圆，0% 只保留轨道。

每条 reset 竖线宽（2pt）、高（14pt）；第一条位于主体右侧（5pt），后续间隔（4pt），竖向居中。数值未知时中心显示“—”，未知 reset 不绘制竖线并在文字中保留未知状态。

按钮、输入框、开关和弹出容器保留系统圆角，不人为设置统一圆角值。

## Components

### Usage rings and account rows

每个已连接账户生成独立 `NSStatusItem`。若同时存在长周期和 5 小时额度，外环显示长周期、内环显示 5 小时；仅一个窗口时绘制粗单环，包括仅有 5 小时额度的情况。不为缺失窗口虚构第二个环。中心百分比与外环一致。

点击状态栏入口选择对应账户并打开详情；已打开同一账户时再次点击关闭。没有账户时保留一个未知额度入口，点击进入账户与设置。面板账户行使用 plain 按钮，点击后选择并展开该账户详情。

reset 数量来自接口，每一个可用 reset 对应一条相邻竖线；0 次与未知都没有竖线，但 tooltip 和面板文字区分两者。此界面展示余额，不提供兑换操作。

图像保持非模板模式以保留颜色；面板中的装饰环和额度条对辅助技术隐藏。账户按钮提供账户名、中心剩余额度和查看详情标签，状态栏 tooltip 与辅助标签提供窗口额度、reset 次数和过期说明。不要仅靠颜色表达状态。

### Quota details

各实际窗口使用名称、百分比、胶囊额度条和重置说明。双环详情加“外环”和“内环”标签，并解释中心数字的来源；详情也显示已用比例和更新时间。不存在周期选择器。每个窗口的辅助技术子元素组合朗读。

### Buttons and fields

主要连接操作使用 `.borderedProminent`，添加账户使用 `.bordered`，管理区两者均为 `.large` 控件尺寸。普通图标、账户行及底栏操作使用 `.plain`；名称字段使用 `.roundedBorder`，名称最多 32 个字符。悬停、焦点、按下和禁用外观由 macOS 原生控件负责。

连接中或等待登录时禁用管理区连接按钮；等待登录区提供重开登录页和取消入口。图标操作具有辅助标签，关键操作附带文字或 tooltip。错误提示使用图标或可换行文字；顶部提示可关闭。

### Login at launch and energy settings

“登录时启动”使用原生 `.switch`。应用不主动注册，初始默认关闭；每次打开面板从 `SMAppService` 读取实际系统状态，已有启用状态保留。请求变更期间禁用开关。

系统状态为 `requiresApproval` 时开关保持开启以表达已提出请求，同时显示“等待系统允许，当前尚未启用自动启动。”和“打开登录项设置”入口。注册或取消失败时显示错误并重新读取状态，不能把开关开启本身当作登录启动已生效的证据。

低耗电说明用绿色叶片标签与普通次级文字呈现刷新周期、睡眠暂停和无持续动画；没有独立的刷新频率控件。

### Empty and stale states

无账户总览显示未知额度环、连接说明和连接入口；自动连接期间标题显示进度文字。未知额度显示“—”，过期数据保留最后数值并配合灰色弧线与“数据已过期”。测试数据仅用于自动测试和标注清楚的离屏渲染，不是应用模式。

## Do's and Don'ts

### Do:
- **Do** 保持一账户一入口，按真实窗口使用外长内短双环或粗单环。
- **Do** 让中心百分比与外环一致，并逐条显示实际可用 reset。
- **Do** 用文字绿承载小字号绿色文字，并在明暗外观检查可读性。
- **Do** 保留系统控件、键盘焦点和辅助标签，让 macOS 管理原生反馈。
- **Do** 用文字区分未知、过期、等待批准和真实已同步状态。

### Don't:
- **Don't** 恢复演示、置顶或额度周期切换控件。
- **Don't** 为缺失窗口或未知 reset 数量生成推测的环或竖线。
- **Don't** 为原生材质、系统动态色或系统圆角杜撰固定 CSS token。
- **Don't** 加入持续动画或绕过既有低耗电刷新节奏。
- **Don't** 将离屏 QA 渲染宣称为实际桌面截图、点击验证或电池续航证据。
