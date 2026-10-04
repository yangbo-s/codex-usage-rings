# Menu bar surface

Mode: Operate. 用户指定系统菜单栏绿色圆环，当前修订以用户新增要求覆盖早期单环、置顶与演示模式约定。

## Direction contract
THESIS: 顶栏直接读取每个真实账户的剩余额度，同时尽量减少后台唤醒。
OWN-WORLD: macOS 系统字体和原生弹出面板，细绿色弧线、淡灰轨道、居中数字，紧凑账户行。
STORY: 看剩余数字 → 点击查看额度与重置时间 → 设置鼠标移出后的收起延迟。
FIRST VIEWPORT: 起初一个 20pt 环，每连接一个账户增加一个；有 5 小时和长额度则同心双环，否则较厚单环。中心数字不带 %，右侧每个细绿色竖线代表一个 reset。面板宽 360pt，详情环 36pt，头尾固定，中段滚动。设置首项为自动收起：默认移出 3 秒、可关闭或自定义 1–300 秒；移回或编辑取消计时。展开收起使用原生过渡，遵循减少动态效果，无循环动画。
FORM: 用户截图与会话明确指定的 macOS 菜单栏布局；沿用既有原生视觉，不进行随机概念选择。无周期切换、置顶或演示控件。
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Runtime and evidence
圆环不持续动画；后台间隔 5 分钟，系统低电量模式 15 分钟，睡眠暂停。面板打开时复用最近 60 秒的快照；自动收起最多使用一个一次性计时器，移回、编辑、禁用或关闭均取消，无周期性鼠标轮询。展开收起使用系统原生过渡并尊重 Reduce Motion。

用户实际截图是本轮缩小圆环、减细描边的修订依据。`.impeccable/review/v3/` 的六张 `rings/overview/settings` 浅深色 PNG 使用测试输入进行原生离屏绘制，非桌面截图或发布资产；测试输入不属于应用模式。独立 `finish-review.md` 的 ship 结论限于静态原生呈现与源码检查，本轮 25 项测试通过。CUA 交互尝试超时，实际指针移出/移回、编辑焦点、账户切换定位、展开收起观感和 Reduce Motion 行为仍无现场证据；登录启动重启验证与长期耗电测量也未完成。现有应用图标保持不变，来源与提示词保留于 `Resources/Brand/usage-rings-logo.prompt.txt`。
