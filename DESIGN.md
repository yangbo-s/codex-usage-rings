---
name: Usage Rings
description: 以余量分色圆环和居中数字呈现每个 Codex 账户剩余额度的 macOS 菜单栏应用。
colors:
  usage-green-light: "color(srgb 0.06 0.58 0.29)"
  usage-green-dark: "color(srgb 0.16 0.81 0.43)"
  usage-blue-light: "color(srgb 0.05 0.42 0.88)"
  usage-blue-dark: "color(srgb 0.28 0.65 1)"
  usage-yellow-light: "color(srgb 0.68 0.48 0.02)"
  usage-yellow-dark: "color(srgb 1 0.80 0.20)"
  usage-red-light: "color(srgb 0.85 0.16 0.19)"
  usage-red-dark: "color(srgb 1 0.36 0.38)"
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
  ring-number:
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
    width: "36pt"
    height: "36pt"
  menu-ring-core:
    width: "18pt"
    height: "18pt"
  usage-bar:
    height: "4pt"
---

# Design System: Usage Rings

## Overview

**Creative North Star: "余量圆环，原生顶栏"**

每个已连接账户对应一个按余量分色的细圆环入口，环内以不带 `%` 的数字显示剩余百分比；额度周期、重置时间和账户设置在原生弹出面板中呈现。界面使用系统字体、SF Symbols 和 macOS 控件，保持紧凑、清楚、低干扰。

这是 v4 视觉修订的实现记录，主要依据 `Sources/CodexUsageRings/Views.swift`、`RingRenderer.swift`、`UsagePalette.swift`、`Application.swift`、`PanelAutoHide.swift`、`LoginAtLaunch.swift` 与 `Sources/UsageCore/UsageBand.swift`、`Models.swift`。尺寸均为 macOS 逻辑点，前置 token 不代表网页 CSS 配置；系统动态色、材质和控件外观继续由原生 API 决定。无演示模式，也不提供置顶或额度周期切换控件。

**Key Characteristics:**
- 一账户一入口：两种额度使用外长内短的同心环，单窗口使用较厚单环。
- 中心数字显示外环剩余额度且不带 `%`；内外环各自按显示整数选择绿、蓝、黄、红，详情条保持一致。
- 右侧 1 次 reset 一根绿色线、2 次两根、3 次及以上一根线加竖向三点；线宽和点径与当前外环相同。
- 系统材质、系统字体和原生表单控件支持明暗外观。
- 面板支持可配置的鼠标移出自动收起；原生展开收起遵循减少动态效果，无持续动画。

用户实际截图与新增要求构成本轮继续缩小圆环、四段分色、统一 reset 线宽并放大 `100` 的修订依据。当前视觉证据为 `.impeccable/review/v4/` 中 `rings`、`overview`、`settings`、`full-comparison` 各自的 `-light.png` 与 `-dark.png`，共八张，主实现者与独立审查者均已打开检查。这些图片使用测试输入进行原生离屏绘制，不是桌面截图，也不是发布资产；`100` 与 `Full` 仅在 renderer 测试中对比，应用仍只显示数字。独立 `finish-review.md` 的 ship 结论仅覆盖静态原生呈现与源码检查，无需追加修复；主实现流程报告本轮 27 项测试通过，文档更新未重复运行。此前 CUA 桌面交互尝试超时，本轮未再次尝试，实际指针移出/移回、编辑与焦点、切换账户定位、展开收起观感和 Reduce Motion 行为仍未取得现场证据。重启后登录启动及长期电池续航也未验证，本轮未进行耗电测量。没有运行网页 detector。应用图标保持不变，使用 Resources/Brand/usage-rings-logo.png，并转换成 Resources/AppIcon.icns 随包交付；生成来源与提示词见同目录的 usage-rings-logo.prompt.txt。菜单栏用量环仍为实时原生绘制。

## Colors

额度环和详情条共用四段余量色，依明暗外观切换；reset 与关键操作保留绿色，文字与结构采用系统中性色。

### Primary

- **充足绿**（`usage-green-light` / `usage-green-dark`）：显示整数余量为 75–100 时的额度弧线与详情条；reset 竖线始终使用同一自适应绿色，不随额度分段改变。
- **文字绿**（`ink-green-light` / `ink-green-dark`）：根据 Aqua / Dark Aqua 切换，用于 reset 次数、低耗电标签及面板 tint。不要把额度弧线的颜色直接用于小字号正文。

### Secondary

- **中段蓝**（`usage-blue-light` / `usage-blue-dark`）：显示整数余量为 50–74 时的额度弧线与详情条。
- **低段黄**（`usage-yellow-light` / `usage-yellow-dark`）：显示整数余量为 25–49 时的额度弧线与详情条。
- **临界红**（`usage-red-light` / `usage-red-dark`）：显示整数余量为 0–24 时的额度弧线与详情条。

### Neutral

- SwiftUI 主文字使用 `primary`；圆环中心使用 `NSColor.labelColor`；面板使用 `regularMaterial`。
- 次级文字在浅色外观使用 `secondary-text-light`，深色外观使用 `NSColor.secondaryLabelColor`。
- 圆环轨道使用 `NSColor.labelColor` 的 18% 不透明度；额度条轨道使用 `primary` 的 8%，选中账户背景使用 2.5%；分隔线使用系统 `Divider`。
- 余量为 0 时不画进度弧，空轨道改用当前余量色的 55% 不透明度，保留红色状态；未知额度保留灰色轨道与“—”。
- 数据过期时圆弧、额度条和 reset 竖线使用系统次级色，账户行同时显示“数据已过期”。中心数字保留系统主文字色。

**The Remaining Rule.** 弧长和额度条长度都表示剩余额度；中心数字取外环窗口，详情文字明确该窗口名称。

**The Band Rule.** 内外环独立按各自剩余百分比四舍五入后的显示整数取色，详情条复用同一分段规则；reset 保持绿色，过期状态统一转灰。

## Typography

全部文字使用系统字体，不随包提供自定义字体。面板标题、账户名、reset 数值、正文、标签和小注释对应前置 token；空状态标题也使用 value 层级。额度名称与低耗电标签使用 medium，额度百分比使用 semibold。

ring-number 是顶栏基础尺寸的起始字号，使用 `NSFont.monospacedDigitSystemFont`。`RingRenderer` 按绘制直径等比缩放，用 CoreText 的 `.useGlyphPathBounds` 取得真实字形边界，并以（0.05pt × 比例）逐步缩小，直到字形包围盒的对角线不超过环内直径减（0.6pt × 比例）的总间隙；循环下限为（4pt × 比例）。字形按其边界中心定位，使 `100` 在不触碰环线的前提下尽量大；不得把起始字号理解为固定最终字号。面板账户环复用此计算，中心只保留数字或未知符号，不绘制 `%`。详情文字、tooltip 和辅助标签继续表达完整百分比语义。

额度详情中的数字、重置时间与已用比例使用 `monospacedDigit()`，避免数值变化造成跳动。账户名最多一行，空名称显示“未命名账户”；提示、错误与设置说明允许换行。

## Layout

面板固定宽度，头尾固定，中段滚动。管理面板高度由 management-panel 定义；总览无账户时高（330pt），有账户时为 `min(560, 285 + (账户数 - 1) × 80 + reset 明细高度)` 逻辑点；明细高度为标题 30pt 加每行 22pt，最多按四行增高。不设网页断点或移动端布局。

常规左右内边距使用 inset；账户行垂直内边距使用 row，头部使用 section，底栏使用 support。账户行左侧是带中心数字的圆环，中部是账户名称和状态，右侧是 reset 次数与标签。详情沿用同一左右边界；管理区首先呈现自动收起开关及秒数，随后为账户名称输入框、移除入口、全宽连接按钮、登录启动开关及低耗电说明。

顶栏圆环主体尺寸由 menu-ring-core 定义。状态栏入口 length 等于 renderer 图像宽度，不再另加 6pt。无 reset 时图像 18pt；单环 1 次为 22pt、2 次及以上为 25.5pt；双环按较细外描边略缩右沿。macOS 仍管理相邻状态项间距。面板账户环隐藏竖线，在行右侧用准确数值表达 reset 次数。

## Elevation & Depth

深度来自 `NSPopover`、`regularMaterial` 和系统控件。项目没有自定义阴影 token。列表通过分隔线与轻微底色区分区域，选中账户不新增悬浮卡片。

弹出面板采用 `.transient` 行为，展开与收起使用 `NSPopover` 原生过渡；每次操作读取系统 Reduce Motion 设置，开启“减少动态效果”时禁用过渡。切换账户时重新定位已显示的面板，不先关闭再打开。圆环和额度条没有持续动画；同步期间使用原生小型 `ProgressView`。后台默认每 5 分钟刷新，系统低电量模式每 15 分钟；睡眠暂停，查询结束关闭查询进程。打开面板复用最近 60 秒的快照。低耗电策略是实现约束，不代表已完成长期电池续航测量。

## Shapes

核心几何是圆环、圆端弧线、圆端 reset 竖线和胶囊额度条。以下 renderer 几何以顶栏基础直径为基准，其他直径按比例缩放。

单窗口描边（2pt）；同心环外描边（1.15pt），内描边（1.05pt），内环路径半径（6.2pt）。外环路径半径为 `直径 / 2 - 外描边 / 2 - 0.6`。弧线从顶部开始顺时针增长；100% 绘制完整圆，0% 只保留轨道。

每条 reset 竖线直接复用当前外环描边宽度，单环为（2pt）、双环为（1.15pt），路径高（10pt）；第一条位于主体右侧（2.5pt），第二列间隔（3.5pt），上下路径端点各内缩（4pt）。3 次及以上时第二列改为圆点，圆心 y 为 4/9/14pt、点径与外环线宽相同；最多两列。右沿保留半描边加 0.5pt，避免裁切。数值未知时中心显示“—”，未知 reset 不绘制竖线并在文字中保留未知状态。

按钮、输入框、开关和弹出容器保留系统圆角，不人为设置统一圆角值。

## Components

### Usage rings and account rows

每个已连接账户生成独立 `NSStatusItem`。若同时存在长周期和 5 小时额度，外环显示长周期、内环显示 5 小时；仅一个窗口时绘制较厚单环，包括仅有 5 小时额度的情况。不为缺失窗口虚构第二个环。中心数字与外环一致，不附加 `%`。

点击状态栏入口选择对应账户并打开详情；已打开同一账户时再次点击关闭。没有账户时保留一个未知额度入口，点击进入账户与设置。面板账户行使用 plain 按钮，点击后选择并展开该账户详情。

reset 数量以 availableCount 为准：1 次一根线、2 次两根线、3 次及以上一根线加竖向三点；0 次与未知都没有标记，tooltip 和面板文字区分两者。面板直接显示按系统时区排序的独立明细，左侧加粗 Full reset，右侧 Expires October 29, 14:44；同期限也逐条列出。null 期限为 No expiry，缺失或非法期限为 Expiry unknown，缺失明细的差额单独汇总未知。此界面展示余额，不提供兑换操作。

图像保持非模板模式以保留颜色；面板中的装饰环和额度条对辅助技术隐藏。账户按钮提供账户名、中心剩余额度和查看详情标签，状态栏 tooltip 与辅助标签提供窗口额度、reset 次数和过期说明。不要仅靠颜色表达状态。

### Quota details

各实际窗口使用名称、百分比、胶囊额度条和重置说明。双环详情加“外环”和“内环”标签，并解释中心数字的来源；详情也显示已用比例和更新时间。不存在周期选择器。每个窗口的辅助技术子元素组合朗读。

### Buttons and fields

底栏右侧使用 SF Symbols power 电源图标（14pt medium、24pt 点击区域），悬停为系统红色、移出恢复主文字色。点击一次终止应用，保留 ⌘Q、tooltip 与完整辅助标签，无更多菜单。

主要连接操作使用 `.borderedProminent`，添加账户使用 `.bordered`，管理区两者均为 `.large` 控件尺寸。普通图标、账户行及底栏操作使用 `.plain`；名称字段使用 `.roundedBorder`，名称最多 32 个字符。悬停、焦点、按下和禁用外观由 macOS 原生控件负责。

连接中或等待登录时禁用管理区连接按钮；等待登录区提供重开登录页和取消入口。图标操作具有辅助标签，关键操作附带文字或 tooltip。错误提示使用图标或可换行文字；顶部提示可关闭。

### Auto-hide, login at launch and energy settings

“自动收起面板”使用原生 `.switch`，默认开启；鼠标移出后默认等待（3 秒）。秒数字段使用 `.roundedBorder`，输入范围限制为（1–300 秒），关闭自动收起时禁用秒数字段；两项设置自动持久保存，旧配置缺少字段时采用默认值。

自动收起由事件驱动，最多保留一个一次性计时器。指针回到面板、名称或延迟字段处于编辑焦点、禁用自动收起或关闭面板都会取消计时；停止编辑且指针仍在外部时重新开始完整延迟，过期回调不得关闭新状态。隐藏面板时不保留计时器，不加入周期性鼠标轮询。此处描述源码与定向测试行为，实际桌面 hover 和焦点连接仍需验证。

“登录时启动”使用原生 `.switch`。应用不主动注册，初始默认关闭；每次打开面板从 `SMAppService` 读取实际系统状态，已有启用状态保留。请求变更期间禁用开关。

系统状态为 `requiresApproval` 时开关保持开启以表达已提出请求，同时显示“等待系统允许，当前尚未启用自动启动。”和“打开登录项设置”入口。注册或取消失败时显示错误并重新读取状态，不能把开关开启本身当作登录启动已生效的证据。

低耗电说明用绿色叶片标签与普通次级文字呈现刷新周期、睡眠暂停和无持续动画；没有独立的刷新频率控件。可选刷新间隔与实时刷新仅处于讨论阶段，未实现，也未改变现有 300/900 秒默认策略。

### Empty and stale states

无账户总览显示未知额度环、连接说明和连接入口；自动连接期间标题显示进度文字。未知额度显示“—”，过期数据保留最后数值并配合灰色弧线与“数据已过期”。测试数据仅用于自动测试和标注清楚的离屏渲染，不是应用模式。

## Do's and Don'ts

### Do:
- **Do** 保持一账户一入口，按真实窗口使用外长内短双环或较厚单环。
- **Do** 让中心数字与外环一致，省略环内 `%`，并用最多两列标记概括 reset，在面板显示准确次数与到期时间。
- **Do** 让内外环与各自详情条共享四段余量规则，reset 保持绿色且与外环同宽。
- **Do** 用文字绿承载小字号绿色文字，并在明暗外观检查可读性。
- **Do** 保留系统控件、键盘焦点和辅助标签，让 macOS 管理原生反馈。
- **Do** 在原生展开收起时尊重 Reduce Motion，并在移回或编辑时取消自动收起计时。
- **Do** 用文字区分未知、过期、等待批准和真实已同步状态。

### Don't:
- **Don't** 恢复演示、置顶或额度周期切换控件，也不要把测试中的 `Full` 作为应用显示模式。
- **Don't** 为缺失窗口或未知 reset 数量生成推测的环或竖线。
- **Don't** 为原生材质、系统动态色或系统圆角杜撰固定 CSS token。
- **Don't** 加入持续动画或绕过既有低耗电刷新节奏。
- **Don't** 将离屏 QA 渲染宣称为实际桌面截图、点击验证或电池续航证据。

## v0.4.2 紧凑入口与到期明细

账户套餐显示用户确认的 Pro 200；其他协议档位单独命名。数据过期时仍保留套餐名并附过期状态。详情新增 Reset 到期时间，采用现有 11pt 标签与系统次级色，明细右对齐；头部说明本地时间。面板根据到期分组增加高度，每组 22pt 加标题 30pt，最多按四组增高，总高仍不超过 560pt，更多内容由原有区域滚动。未增加刷新请求或动画。

本轮通过 32 项测试，新增数据链路断言另行定向通过；主实现者检查 v4.2 原生离屏浅深色圆环与总览图，Pro 200、分组日期、三点与退出按钮均可见。离屏图不证明实机菜单栏宽度和桌面交互；既有长期耗电与系统流程未验证项保持开放。

## v0.4.3 当前面板修订

用户要求每份 reset 独立一行，覆盖 v0.4.2 的分组合并展示。标题仅保留 Reset 到期时间，左侧 Full reset 使用 11pt semibold，右侧为英文 Expires + 月日 + 24 小时时分，跨年追加年份；数据依然以系统时区换算，不单独显示本地时间标签。取消 info.circle 解释段落，保留实际错误和更新时间。总览基础高度由 335pt 改为 285pt，每条明细增加 22pt，加标题 30pt，最多按四条增高、总高上限 560pt。

退出为 SF Symbols power，14pt medium、24×24pt 点击区域；独立 hover 状态切换主文字色/系统红色，无动画或计时器，移出与消失均复位。保留快捷键、tooltip 和 VoiceOver 名称。

本轮 33 项测试通过，浅深色总览与设置页离屏图已检查，日期行和图标完整可见。源码核对 hover 颜色切换、复位、快捷键及辅助名称；实际桌面指针 hover 尚未取证，不把静态图当作交互证明。
