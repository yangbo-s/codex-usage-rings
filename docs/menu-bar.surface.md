# Menu bar surface

Mode: Operate. 用户指定原生菜单栏圆环，当前修订以余量四色和用户新增要求覆盖早期单色、单环、置顶与演示模式约定。

## Direction contract
THESIS: 顶栏直接读取每个真实账户的剩余额度，同时尽量减少后台唤醒。
OWN-WORLD: macOS 系统字体和原生弹出面板，余量按绿/蓝/黄/红分段，淡灰轨道、居中数字，紧凑账户行；reset 独立保持绿色。
STORY: 看剩余数字 → 点击查看额度与重置时间 → 设置鼠标移出后的收起延迟。
FIRST VIEWPORT: 起初一个 18pt 环，每连接一个账户增加一个；有 5 小时和长额度则同心双环，否则较厚单环。各环和详情条按显示整数余量取色：75–100 绿、50–74 蓝、25–49 黄、0–24 红。中心数字无 %，100 尽量大且不碰环线；reset 竖线与外环同宽。面板宽 360pt，详情环 36pt，头尾固定，中段滚动。自动收起仍默认移出 3 秒，可配置或关闭；系统过渡遵循减少动态效果，无循环动画。
FORM: 用户截图与会话明确指定的 macOS 菜单栏布局；沿用既有原生视觉，不进行随机概念选择。无周期切换、置顶或演示控件。
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Runtime and evidence
圆环不持续动画；后台间隔 5 分钟，系统低电量模式 15 分钟，睡眠暂停。面板打开时复用最近 60 秒的快照；自动收起最多使用一个一次性计时器，移回、编辑、禁用或关闭均取消，无周期性鼠标轮询。展开收起使用系统原生过渡并尊重 Reduce Motion。

用户实际截图与新增要求是本轮继续缩小圆环、四段余量分色、统一 reset 线宽及放大 `100` 的修订依据。`.impeccable/review/v4/` 的八张 `rings/overview/settings/full-comparison` 浅深色 PNG 使用测试输入进行原生离屏绘制，已由主实现者与独立审查者打开检查；非桌面截图或发布资产，`100` 与 `Full` 对比仅用于 renderer 测试，不属于应用模式。独立 `finish-review.md` 的 ship 结论限于静态原生呈现与源码检查，无需追加修复；主实现流程报告本轮 27 项测试通过。此前 CUA 交互尝试超时，本轮未重试，实际指针移出/移回、编辑焦点、账户切换定位、展开收起观感和 Reduce Motion 行为仍无现场证据；登录启动重启验证与长期耗电测量也未完成，本轮未进行耗电测量。可选刷新间隔与实时刷新仅处于讨论阶段，现有 300/900 秒刷新和自动收起策略未改变。没有运行网页 detector。现有应用图标保持不变，来源与提示词保留于 `Resources/Brand/usage-rings-logo.prompt.txt`。
