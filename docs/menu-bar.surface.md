# Menu bar surface

Mode: Operate. 用户指定系统菜单栏绿色圆环，当前修订以用户新增要求覆盖早期单环、置顶与演示模式约定。

## Direction contract
THESIS: 顶栏直接读取每个真实账户的剩余额度，同时尽量减少后台唤醒。
OWN-WORLD: macOS 系统字体和原生弹出面板，绿色弧线、淡灰轨道、居中百分比，紧凑账户行。
STORY: 看百分比 → 点击查看两种额度和重置时间 → 连接账户或设置登录启动。
FIRST VIEWPORT: 起初一个 24pt 环，每连接一个账户增加一个；有 5 小时和长额度则同心双环，否则粗单环。右侧每个绿色竖线代表一个 reset。面板宽 360pt，头尾固定，中段滚动。
FORM: 用户截图与会话明确指定的 macOS 菜单栏布局；沿用既有原生视觉，不进行随机概念选择。无周期切换、置顶或演示控件。
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Runtime and evidence
圆环不持续动画；后台间隔 5 分钟，系统低电量模式 15 分钟，睡眠暂停。面板打开时复用最近 60 秒的快照。测试输入仅用于自动测试和标注清楚的离屏渲染，不属于应用模式。`.impeccable/review/v2/` 的图像不是桌面截图；实际点击路径仍未取得 CUA 证据。
