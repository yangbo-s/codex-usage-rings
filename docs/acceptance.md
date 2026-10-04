# 本机验收记录

## v0.4.0 余量分色与满额文字

2026-10-03。当前修订范围：四色、缩小顶栏环、reset 同宽及 `100/Full` 比较。用户澄清 `100` 尽量大，但不碰环线。可调刷新仅讨论，未实现。

| 需求 / 用例 | 证据 | 结果 |
| --- | --- | --- |
| REQ-016 / TC-016 | UsageBand、UsagePalette、Views；usageBandsMatchVisibleRoundedRemaining | 75/50/25 边界两侧、四舍五入、0/100、范围外及未知/非有限值通过；单双环独立颜色与详情条浅深色图一致 |
| REQ-017 / TC-017 | RingRenderer；resetStrokesMatchOuterRingInRenderedPixels | 顶栏 18pt、详情 36pt；单/双环实际绘制像素中，reset 与外环同宽（抗锯齿允许两像素差）；独立保持绿色 |
| REQ-018 / TC-017 | CoreText 字形边界；ringGeometryFitsNumbersAndCountsEveryReset；full-comparison-light/dark.png | 100/Full 均可适配；100 保留可见间隙、纯数字语义；Full 只在渲染测试对照中使用 |

- `USAGE_RINGS_SNAPSHOT_DIR="$PWD/.impeccable/review/v4" swift test` 26 项通过（1.041 秒，不含编译），导出 8 张图；新增像素同宽验证后 `swift test` 27 项全部通过（0.344 秒）。业务、进程、刷新和自动收起回归无失败。
- 原生八张离屏图分别为 `rings/overview/settings/full-comparison` 的浅色与深色图，主代理与独立 reviewer 均逐张打开；审查 disposition 为 **ship**，无 material fixes，仅覆盖本轮静态呈现与源码检查。
- 同为系统半粗体、等宽数字 8pt 时，NSString 文字布局框：100 为 16.36 × 10pt，Full 为 14.88 × 10pt。生产排版改用 CoreText 实际字形轮廓净空，在圆内保留至少 0.3pt 的径向间隙（随直径缩放）。两个数字表达的可读性和语义一致性优先，应用不引入 Full 切换设置。
- release 构建成功（3.29 秒），arm64、版本 0.4.0/build 4；Info.plist 检查通过。DMG 完整性、只读挂载、Applications 链接、全部 4 个应用文件哈希及严格代码签名验证通过；测试挂载已卸载清理。
- DMG 为 `Codex-Usage-Rings-v0.4.0-macos-arm64.dmg`，3,735,438 bytes；SHA-256：`28dbec26329587d9081e8a6da58925d5e79699e65bf7cdb103aa24931260489e`。

没有再次执行此前连续超时的原生 CUA；本轮不声称真实菜单栏像素、hover/focus、VoiceOver、系统事件或能耗已现场验证。没有执行秒级轮询，也没有据查询次数计算耗电百分比；当前刷新仍为 300/900 秒。旧版短时空闲样本不充当 v0.4.0 或可调刷新方案的能耗证据。

整体验收证据评分保持 **88/100**：覆盖 23/25（缺实机交互），边界 23/25（颜色、净空和像素线宽通过），测试 16/20（27 项通过，缺端到端和电池对照），架构 9/10（共享分段与配色），代码安全 9/10（无新依赖、无凭据改动），文档交付 8/10（预览包、非公证）。后续提升应优先验证真实桌面和电池场景，不扩大静态审查结论。

## v0.3.0 界面细节与收起控制

2026-10-03。本节是当前修订证据；下方 v0.2 记录为历史基线。新增需求依据用户的实际桌面截图以及“鼠标移出后计时”的确认。

| 需求 / 用例 | 实现与证据 | 结果 |
| --- | --- | --- |
| REQ-013 / TC-013 | 20pt 顶栏、36pt 详情；2.2pt 单环、1.25/1.15pt 双环、1.2pt reset；中心纯数字，详情保留单位 | 0/100/未知、单双环净空测试及浅深色渲染通过 |
| REQ-014 / TC-014 | 默认移出 3 秒，可设 1–300 秒或关闭；进出、编辑、关闭、禁用、过期回调及设置持久化 | 纯状态与调度模块测试通过；真实鼠标/focus 集成路径未验证 |
| REQ-015 / TC-015 | NSPopover 原生过渡，遵循减少动态效果；切换账户直接重新定位，无周期动画和鼠标轮询 | 源码检查与 release 构建通过；实际过渡观感未验证 |

执行记录：

- `USAGE_RINGS_SNAPSHOT_DIR="$PWD/.impeccable/review/v3" swift test`：25 项全部通过，1.135 秒（不含编译）。新增 5 项分别验证数字语义、旧配置迁移/钳制、收起取消、编辑/关闭/禁用以及偏好持久化；既有数据、进程与登录项回归通过。
- 原生离屏图：v3 目录的 `rings-light/dark.png`、`overview-light/dark.png`、`settings-light/dark.png`，共 6 张；测试输入仅在测试目标中，运行应用没有演示模式。
- 独立 finish review 为 **ship**，仅覆盖有效的六张静态原生图及源码行为检查，无可证实的实现阻断项；不把该结论扩展成真实桌面交互通过。
- `bash scripts/build-app.sh` 成功；`codesign --verify --strict` 和 `plutil -lint` 通过；二进制 arm64、minos 13.0，版本 0.3.0 / build 3。
- 本次构建已实际启动。运行 1 分 06 秒时采样：CPU 0.0%、RSS 52,992 KiB（约 51.8 MiB）、累计 CPU 0.16 秒、自有直接子进程为空。仅为短时空闲样本，不是电池耗电或完整刷新周期测试。
- `cua.getApp` 连接新版应用 8 秒后返回 `timeoutReached`。未绕过该限制或把离屏图冒充真实菜单栏截图；实际 hover/focus、原生过渡、Reduce Motion 的现场行为仍待验证。
- `package-release.sh` 与 `hdiutil verify` 成功；只读挂载后可见入口为应用与 Applications 链接，目标正确；应用全部 4 个文件哈希与构建一致，签名再次通过，测试挂载已卸载。

DMG：`Codex-Usage-Rings-v0.3.0-macos-arm64.dmg`，3,728,071 bytes。SHA-256：`a1f285fd7c4c7937f61b66a5f30a19935138433d490089ad1242e9ab7908870b`。

发布交付：源码与 README 已推送，标签 `v0.3.0` 指向 `be9d5d6a6cc475528b914185f5c55156d0e28ba7`。[GitHub Release](https://github.com/yangbo-s/codex-usage-rings/releases/tag/v0.3.0) 为非 draft 的 prerelease，DMG 与 SHA256SUMS.txt 均为 uploaded。回下载两个附件后，SHA-256 与逐字节比较均通过；临时下载目录已清理。本次验证启动的预览实例已退出，未替换用户在 Applications 中的旧版本；旧 v0.2.0 标签和附件保留。

当前证据评分 **88/100**：需求覆盖 23/25（缺真实交互），功能边界 23/25（状态/取消/迁移通过，系统集成待验），测试 16/20（25 项与六张原生渲染通过，缺端到端和长期耗电），架构 9/10（事件驱动和可注入调度），代码安全 9/10（无新依赖、不处理令牌），文档交付 8/10（可安装预览产物，未公证且实际交互缺证据）。改进方向为完成真实鼠标、键盘、减少动态效果与长期电池测量。本次可供预览试用，不宣称所有 P1 实机验收完成。

## v0.2 历史基线

日期：2026-10-03，版本 0.2。范围：真实多账户圆环、百分比/同心环/reset 竖线、登录启动设置和低耗电运行。

结论：新版应用已构建并启动，本机一个真实账户已连接；20 项测试通过。原生离屏渲染、真实只读查询、空闲资源采样通过。实际菜单点击、多账户真实 OAuth、重启登录与长期电池耗电仍未验证，因此不声明正式验收全部通过。

## 追踪矩阵

| 需求 / 验收 | 实现与证据 | 结果 |
| --- | --- | --- |
| REQ-001 / AC-001 真实账户逐个增加 | Models、UsageStore、Application；TC-001,004,006 | 无 runtime demo；实际 settings 仅 1 个 local 账户；未知时 1 个入口 |
| REQ-002 / AC-002 百分比及单双环 | RingRenderer、Models、Views；TC-001,003,007 | 明暗渲染、100/0/未知、5h 位置互换和单窗口测试通过；真实顶栏文字大小未截图验证 |
| REQ-003 / AC-003 设置和迁移 | UsageStore；TC-004 | 旧 demo 剔除、真实账户保留、重建 Store、删除最后账户、损坏文件保护通过 |
| REQ-004 / AC-004 真实数据与隔离 | CodexClient；TC-002,005 | 本机接口读取通过；独立目录、分包、错误、超时/退出测试通过；第二个真实账户登录未运行 |
| REQ-005 / AC-005 构建与启动 | SwiftPM、build-app.sh；TC-006 | release 构建、签名验证、Info.plist、启动进程均通过 |
| REQ-006 / AC-006 reset 竖线 | Models、RingRenderer；TC-002,007 | authoritative availableCount、缺失/0/负数/明细不全测试通过，0/2/3 根线渲染通过；真实接口读取成功 |
| REQ-007 / AC-007 登录启动 | LoginAtLaunch、Views；TC-008 | 默认无注册、开启/关闭、待批准和失败替身测试通过；未修改真实登录项或重启 Mac |
| REQ-008 / AC-008 低耗电 | RefreshPolicy、UsageStore；TC-009、进程采样 | 5/15 分钟与缓存/退避测试通过，查询后释放子进程；空闲 CPU 0.0%；睡眠/唤醒和低电量系统事件仅源码检查，未做真实切换和电池测试 |

## 已执行证据

- `USAGE_RINGS_SNAPSHOT_DIR="$PWD/.impeccable/review/v2" swift test`：20 项通过，0.701 秒（不含编译）。
- 修正测试截图的动态外观上下文后，定向 `swift test --filter ringGeometryFitsPercentAndCountsEveryReset`：1 项通过，0.424 秒。修正只影响测试截图，不改变生产代码；之后仅整理测试缩进。
- `bash scripts/build-app.sh`：release 构建成功，3.48 秒；产物 `dist/Codex Usage Rings.app`。
- `codesign --verify --verbose=2 "dist/Codex Usage Rings.app"`：valid on disk / satisfies its Designated Requirement。
- `plutil -lint Resources/Info.plist`：OK。
- `open "dist/Codex Usage Rings.app" --args --show` 后已确认进程运行，路径指向本次产物。
- 真实 `--probe` 已成功读取账户类型、实际额度周期及 banked reset 数量。发布文档不保留个人账户套餐与余量快照；未输出邮箱或 token，未兑换 reset。
- 启动后只检查设置元数据：profiles=1、kinds=[local]、autoConnectLocal=false。

原生离屏证据：`.impeccable/review/v2/rings-light.png`、`rings-dark.png`、`settings-light.png`、`settings-dark.png`。圆环板明确标注“测试输入”，仅存在测试目标中。图像由 AppKit / NSHostingView 渲染，**不是实际菜单栏截图，也不证明真实点击已通过**。

独立界面复核结论：`ship`，限定为提供的原生离屏图与源码证据；确认百分比、单双环、逐个 reset、明暗设置页和节能生命周期，无实质阻断项。未扩大为桌面交互、重启登录或续航验证。

## 资源观测

当前 Mac，release 产物，1 个真实账户，无持续登录操作。`ps` 两次空闲采样：

| 应用运行时长 | CPU | RSS | 累计 CPU 时间 | 自有直接子进程 |
| --- | ---: | ---: | ---: | --- |
| 10 秒 | 0.0% | 58,640 KiB（57.3 MiB） | 0.14 秒 | 此次未采 |
| 2 分 06 秒 | 0.0% | 55,280 KiB（54.0 MiB） | 0.14 秒 | 无，pgrep 返回 1 |

第二次原始记录：`.impeccable/review/v2/idle-samples.jsonl`。首次采样保留于执行输出。两个样本之间累计 CPU 未增长到显示精度，未观察到后台查询进程常驻。

这是短时空闲观测，未覆盖完整刷新周期、联网波动、多账户规模、每次查询峰值或长时间电池消耗；不能据此给出“每小时耗电百分比”或续航保证。实现通过低频计时、容差、睡眠暂停、串行读取、读完关进程和失败退避减少无效开销。

## 测试清单

Core（11）：remainingPercentHandlesBoundariesAndUnknown、decodesLegacyAndPrefersCodexBucket、nullAndInvalidDataNeverBecomeFullQuota、resetTimesNeverShowNegativeOrFalseReset、labelsUseActualWindowDuration、settingsRoundTripPreservesRealAccounts、migratesPreviewSettingsWithoutLosingRealAccounts、nestedRingsFollowDurationNotPosition、unknownWindowIsNotInventedAsFiveHours、bankedResetCountIsAuthoritativeAndOptional、powerPolicyCoalescesAndBacksOff。

App（6）：fragmentedResponsesAndIndependentHomes、serverErrorsPropagateWithoutHanging、timeoutAndProcessExitReleaseRequests、metadataPersistsAndRemovingLastAccountStaysEmpty、unreadableSettingsArePreserved、successfulUsageReadLeavesNoQueryProcess。

Login（2）：loginSettingDefaultsOffAndFollowsSystem、pendingApprovalAndFailuresAreNotReportedAsEnabled。

Rendering（1）：ringGeometryFitsPercentAndCountsEveryReset。

## 失败、修复和未运行项

- 测试初次编译遇到 Swift Testing 宏嵌套限制，拆开 require 后全量通过。
- 首次圆环浅色离屏图受 AppKit 动态色上下文影响生成了深色；显式指定绘制外观后定向通过并重新检查浅深色。
- 早期原生 CUA 分别按路径和 bundle ID 选择应用均超时；此次不把离屏图冒充系统截图。实际菜单栏位置、点击、键盘/VoiceOver 和刘海屏挤压仍缺证据。
- 第二个真实账户 OAuth、登录续期、系统批准登录项后重启、真实睡眠/唤醒和低电量切换未执行。
- 未进行长时功耗测量、完整刷新周期采样、多账户资源压测、跨 macOS 版本测试、Developer ID 签名或公证。

## 质量评分

100 分制证据评分，不是认证，也不替代未完成的实际验收。

| 项目 | 得分 | 依据与扣分 |
| --- | ---: | --- |
| 需求与验收覆盖 | 23/25 | 当前需求逐项实现，实际 UI 与重启登录证据未取得 |
| 功能正确性与边界 | 22/25 | 真实读取、空值、异常、迁移通过，完整 OAuth/系统事件待验 |
| 测试充分性与结果 | 16/20 | 20 测试、离屏渲染、资源采样通过，缺端到端与长期耗电 |
| 架构与接口 | 9/10 | 数据/绘制/系统登录/省电策略分层，CLI 发现依赖本机安装路径 |
| 代码质量与安全 | 9/10 | 无第三方依赖、不打印令牌、目录隔离，独立账户使用文件凭据 |
| 文档与交付 | 9/10 | 运行产物、测试、使用说明与限制齐全，未正式分发 |
| 合计 | 88/100 | 可在本机使用，未声称所有 P1 实际验收通过 |

剩余人工路径：点击顶栏环核对比例与线条 → 账户与设置开启登录启动并按系统提示批准 → 下次正常登录 Mac 检查自动启动。额外账户由用户自行完成官方浏览器登录；耗电需单独开展覆盖多次刷新和睡眠唤醒的长时测量。

## 2026-10-03 图标补充

新增简约 SaaS 应用图标：绿色开口环和独立竖线，深色圆角底，外围真实透明。内置 image_gen 生成原始 PNG（1254 × 1254、RGBA 8-bit）；提示词与来源保存在 Resources/Brand。`build-icon.sh` 用系统 sips 缩放并用 iconutil 打包 16–1024px 共 10 个图标表示；原图保持不变。

`iconutil` 在沙箱中首次返回 Invalid Iconset，使用系统工具执行权限后成功；反向解包验证和小尺寸视觉检查通过。应用 build、plist、图标复制一致性和 codesign 校验通过。只修改静态资产、plist 与打包脚本，未修改 Swift 刷新逻辑，因此没有重跑数据测试，也没有将新的刷新建议写成已实施行为。Finder 的图标缓存展示未做 GUI 验证。

## v0.2.0 发布前验证

REQ-009 / AC-009：README 已补齐安装、Release 下载、系统/架构、Codex 登录依赖、圆环说明、登录启动、刷新策略、数据位置、问题排查、源码构建与已知限制。应用功能与实际实现保持一致。

TC-010：发布前 `swift test` 20 项全部通过（0.373 秒，不含编译）；`build-app.sh` 与 `package-release.sh` 成功。应用二进制为 arm64，LC_BUILD_VERSION 的 minos 为 13.0。shell 语法、Info.plist 与设计 JSON 校验通过。

实际交付包：`Codex-Usage-Rings-v0.2.0-macos-arm64.zip`，1,583,659 bytes。包解压后主程序与原始构建一致、图标一致、严格签名校验通过。ZIP 内没有账户配置、凭据或构建缓存。`SHA256SUMS.txt` 本地检查通过。

SHA-256：`092d5be7eb61b6b94e0d15be9465273347d9be402cc8aea59fd2a42198adae73`。

REQ-010 / AC-010：代码与 README 已推送至 `yangbo-s/codex-usage-rings` 的 `main`。版本标签 `v0.2.0` 解析到提交 `d5335e476a2b5f1191e1dfea4004c2e3179eac19`，与本次应用源码提交一致；随后仅追加发布验收记录。

REQ-011 / AC-011 / TC-011：[GitHub Release](https://github.com/yangbo-s/codex-usage-rings/releases/tag/v0.2.0) 已发布，`isDraft=false`、`isPrerelease=true`；ZIP 和 SHA256SUMS.txt 均为 uploaded。GitHub 返回的 ZIP SHA-256 与上方值一致。从 GitHub 回下载两个附件后，校验清单通过，且两个文件与本地原件逐字节一致。临时解包/下载目录已清理。

仓库保持 private，发布为 prerelease，不扩大已有系统流程和续航验证范围。REQ-009/010/011 发布交付项均通过；整体产品证据评分仍为 88/100，待验证的实际系统行为仍按上文保留。

## DMG 分发补充

REQ-012 / AC-012 / TC-012：用户选择 DMG 后，`package-release.sh` 改为生成 HFS+ / UDZO 只读映像。根目录只有两个可见入口：`Codex Usage Rings.app` 和指向 `/Applications` 的 `Applications` 符号链接；另含隐藏的卷图标与禁止 Spotlight 索引标记。

- `hdiutil verify`：映像校验通过。
- 只读挂载：成功；Applications 链接目标与两个可见入口检查通过。
- 映像内应用严格代码签名校验通过；全部 4 个应用文件的哈希与已发布 ZIP 内对应文件一致。
- 完整校验清单（DMG + ZIP）检查通过；仅下载 DMG 时，README 中 `--ignore-missing` 校验命令也通过。
- DMG 已补充到原 v0.2.0 prerelease；原 ZIP 字节及标签保持不变。Release 安装说明改为 DMG，SHA256SUMS.txt 同时涵盖两个附件。
- 从 GitHub 回下载 DMG 与新清单，SHA-256 通过，两个文件与本地逐字节一致。临时挂载与下载目录均已清理。

DMG 大小：3,561,605 bytes。SHA-256：`d4a944843a37deb3e20b63ef4f7cffa49865d847874577328e16b9c6da4dd034`。

本次仅改包装脚本与文档，未修改或重编译应用，沿用发布前通过的 20 项业务测试；没有再次执行无关测试。未实际拖拽覆盖 /Applications 中的应用，也未检查 Finder 窗口中图标的具体位置。当前系统对 hdiutil 发出了弃用提示，但命令成功；脚本保留该工具以兼容项目最低 macOS 13。产品证据评分仍为 88/100，DMG 包装与上传验证项通过，既有实际系统流程与长期耗电限制不变。
