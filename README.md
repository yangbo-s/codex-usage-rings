<p align="center">
  <img src="Resources/Brand/usage-rings-logo.png" width="112" alt="Usage Rings app icon">
</p>

# Codex Usage Rings

把 Codex 剩余额度放进 Mac 顶部菜单栏。可选择显示哪些账户圆环及其顺序，环内显示剩余数字（省略 %）或额度耗尽后的 `C`，点击查看额度周期、Credit 余额、重置时间和账户设置。

[下载 v0.6.0](https://github.com/yangbo-s/codex-usage-rings/releases/tag/v0.6.0) · [更新记录](docs/releases/v0.6.0.md) · [MIT License](LICENSE)

## 安装

当前预编译包适用于 **Apple Silicon（M 系列芯片）和 macOS 13 或更高版本**。使用安装包无需安装 Swift 或 Xcode。

1. 从 [Release](https://github.com/yangbo-s/codex-usage-rings/releases/tag/v0.6.0) 下载 `Codex-Usage-Rings-v0.6.0-macos-arm64.dmg`。
2. 双击 DMG，将里面的 `Codex Usage Rings.app` 拖到 `Applications` 文件夹入口。复制完成后推出磁盘映像，再从“应用程序”打开。
3. 先确保本机已安装 Codex CLI 或 Codex / ChatGPT 桌面应用，并使用 **ChatGPT 账户**登录。此工具复用本机 Codex 获取订阅用量；API Key 登录不提供这种额度。
4. 首次启动会尝试连接本机已有登录。成功后，菜单栏出现一个真实账户圆环；未连接时显示一个灰色入口，点击即可连接。

应用只在菜单栏运行，没有 Dock 图标。点击面板右下角电源图标即可直接退出；鼠标悬停时图标变红，也可使用 ⌘Q。

**当前是预览版，采用 ad-hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。** 首次打开可能被 macOS 拦截。确认下载来源及校验值后，可按 [Apple 的说明](https://support.apple.com/zh-cn/102445)，在尝试打开应用后前往“系统设置 → 隐私与安全性 → 仍要打开”。

Release 同时提供 `SHA256SUMS.txt`。把它与下载的 DMG 放在同一个目录，然后执行：

```sh
shasum -a 256 --ignore-missing -c SHA256SUMS.txt
```

使用 DMG 首次安装；Release 中的 ZIP 用于 Sparkle 应用内更新。

## 软件更新

在 **账户与设置 → 软件更新** 查看版本并点击 **检查更新…**。发现新版本后，可下载并选择更新重启，账户和设置保留。

后台发现更新时，面板会显示 **更新可用**，设置中可点击 **查看更新…**。

- **自动检查更新**：默认开启，每天检查一次。
- **自动下载并在退出时安装**：默认关闭；开启后后台下载，退出应用时安装，下次启动使用新版。安装位置需要额外权限时，系统仍可能要求授权。
- **v0.5.0 及更早版本**没有更新器，需要手动安装一次 v0.6.0。

更新通过 Sparkle 获取 GitHub 上的更新清单和安装包，解压前校验 EdDSA 签名，不发送账户凭据或启用 Sparkle 系统信息采集。应用仍未经过 Apple 公证，首次安装可能需要系统确认；不能保证所有 macOS 环境下的后续更新都没有系统提示。

## 圆环怎么看

| 元素 | 含义 |
| --- | --- |
| 彩色弧长和中心数字 | 剩余额度；中心数字对应外环的百分比，省略 % |
| 绿 / 蓝 / 黄 / 红 | 按显示整数：75–100 / 50–74 / 25–49 / 0–24；内外环分别取色 |
| 较厚单环 | 只有一个额度窗口，包括只有 5 小时额度的情况 |
| 外环 + 内环 | 同时有长周期与 5 小时额度：外环显示长周期，内环显示 5 小时 |
| 右侧绿色标记 | 1 次一根线，2 次两根线，3 次及以上为一根线＋竖向三点；与外环同宽，独立保持绿色；工具只读取，不兑换 |
| `—` | 当前额度未知，保留灰色；0% 则显示淡红色空轨道 |
| 灰色弧线和过期提示 | 同步失败时保留的上一次快照 |
| 红色 `C` | 至少一个额度窗口已耗尽且仍有可用 credits；无 credits 时耗尽窗口保持 `0`，未耗尽时正常显示数字 |

默认显示全部账户圆环；可在设置中限定数量并排序。入口按内容收紧宽度，最多显示两列 reset 标记。悬停查看准确次数和简要用量；点击圆环即可查看额度窗口与 Full reset 明细，每份 reset 独立一行：左侧加粗 **Full reset**，右侧如 **Expires October 29, 14:44**。日期按系统时区从早到晚排列，跨年时补充年份；同一到期时间也分行显示。无期限显示 No expiry，未知期限显示 Expiry unknown；明细不完整的差额单独汇总为未知。没有可用 reset 时不显示该区块。已到期显示 Expired，余额仍以服务端为准。应用没有演示模式。

**Credit 余额**显示在用量详情下方，不在菜单栏显示数值。额度、Credit 和 Full reset 按实际显示的区块用细线分隔；双额度窗口放在同一组。按系统数字格式最多显示两位小数，正数不足 0.01 显示 `< 0.01`，无限为“无限”。零余额、无 Credits 或非法余额时隐藏该区块；明确有 Credits 但未提供具体金额时显示“余额未知”。`C` 只表示额度耗尽且仍有 credits，不代表已观察到扣款或保证当前请求能执行；用量接口不提供实时扣款标志。额度恢复后回到数字，credits 用完后回到对应额度数字；过期状态继续使用灰色。

账户套餐 `pro` 显示为 **Pro 200**，`prolite` / `promax` 分别显示为 Pro Lite / Pro Max。

## 多账户

进入 **圆环 → 账户与设置**：

- **菜单栏圆环**：多账户时选择显示 1 到全部账户；列表从上到下对应菜单栏从左到右，仅显示前 N 个。使用账户旁的上下箭头调整顺序，设置自动保存。单账户自动显示它；其余账户仍在详情面板中并继续刷新。
- **连接本机 Codex**：读取现有本机登录，不更换账户、不登出、不发起模型推理。本机 Codex 换号后，这个入口跟随换号。
- **添加其他账户**：打开官方浏览器登录页，选择另一个账户。每个额外账户使用独立目录保存登录状态；等待超过 5 分钟可重新发起。
- **修改昵称 / 移除账户**：名称自动保存。移除只停止展示和查询，不删除凭据、不退出 Codex。移除最后一个账户后，下次启动不会自动重新添加。

本机账户与“添加其他账户”使用不同的登录目录；请在浏览器中确认选择的是期望连接的账户。

## 面板自动收起

在 **账户与设置 → 自动收起面板** 中调整：默认鼠标移出后 **3 秒**收起，可输入 **1–300 秒**，按 Return 或离开输入框提交，设置自动保存；关闭开关即可停用。移回面板会取消倒计时，编辑文字时暂停，结束编辑后重新计时。点击面板外部仍按 macOS 原生行为关闭。

顶栏圆环为 18pt，详情圆环为 36pt；环内只显示数字，100 按实际字形尽量放大并与环线保留间隙，详情和悬停提示仍保留百分比单位。浅色外观的黄色偏金黄，以保持细线可见。展开和收起使用系统过渡，遵循 macOS“减少动态效果”。仅鼠标离开可见面板时使用一次性计时器，无鼠标轮询和持续动画。

## 登录启动与省电

在“账户与设置”打开 **登录时启动**，下次登录 Mac 后会自动显示圆环。首次默认关闭，开关反映系统状态；需要系统批准时会给出入口。建议先把应用移入“应用程序”文件夹，再启用这个设置。

当前版本的刷新策略：

| 场景 | 行为 |
| --- | --- |
| 普通后台 | 每 5 分钟刷新 |
| 系统低电量模式 | 每 15 分钟刷新 |
| 打开面板 / 系统唤醒 | 按需更新，复用最近 60 秒的快照 |
| 点击“刷新用量” | 立即发起读取；已有刷新进行中时不重复发起 |
| 系统睡眠 | 停止计时器和自有查询进程 |
| 查询失败 | 逐步退避，重试间隔最高 60 分钟 |

定时器使用 20% 容差，允许系统合并唤醒，因此不承诺精确到秒。多个账户依次查询，读取完成即关闭 app-server；浏览器登录期间才临时保留相应进程，最长 5 分钟。没有持续动画或逐秒倒计时。

## 数据与凭据

用量通过本机 `codex app-server` 的 stdio JSON-RPC 获取。优先使用 `rateLimitsByLimitId.codex`，兼容 `rateLimits`；按实际 `windowDurationMins` 识别窗口。Banked reset 数量使用 `rateLimitResetCredits.availableCount`，不根据可能不完整的明细列表推算。到期时间取同一响应的 `credits[].expiresAt`，不会用额度窗口的重置时间代替，无额外网络请求。

Credit 余额取同一额度快照的 `credits.balance`、`hasCredits`、`unlimited`，不增加请求。原始小数字符串使用 `Decimal` 解析。账户排序复用 `profiles` 数组顺序，`menuBarRingLimit` 保存菜单栏显示上限；旧配置缺少该字段时继续显示全部账户。至少保留一个已连接账户入口。

应用自身不解析或打印登录令牌，不创建对话、不发起模型调用。数据保存在：

```text
~/Library/Application Support/Codex Usage Rings/
├── settings.json      # 账户元数据、首次自动连接标志与面板收起偏好
└── profiles/<id>/     # 由 Codex 维护的独立账户登录状态
```

独立账户使用隔离的 `CODEX_HOME` 和文件凭据存储；请把 `profiles` 及其备份视为敏感数据，不要提交到 Git。旧版演示记录会被过滤；设置损坏时保留原文件并显示错误，不静默覆盖。

## 常见问题

**打开后找不到窗口？** 这是菜单栏应用，请查看屏幕顶部右侧圆环。没有 Dock 图标是正常行为。

**提示找不到 Codex？** 安装 Codex CLI 或桌面应用后重启。默认搜索常见桌面应用和 Homebrew 路径；自定义位置可通过 `CODEX_CLI_PATH` 指定。

**已登录，但读不到额度？** 确认使用 ChatGPT 账户而非 API Key。登录过期时，先在 Codex 中重新登录；独立账户可重新添加。未知额度显示 `—`，同步失败会保留旧快照。

**自启动没有生效？** 打开面板查看是否显示“等待系统允许”，按提示到 macOS 登录项设置批准，并确认应用没有被移动或删除。

**是否支持 Intel Mac？** 当前预编译包只有 arm64，暂不提供 Intel 或 Universal 包。

## 从源码构建

需要 macOS、Swift 6 工具链及 Xcode Command Line Tools。SwiftPM 自动下载固定版本的 Sparkle 更新框架。

```sh
git clone https://github.com/yangbo-s/codex-usage-rings.git
cd codex-usage-rings
swift test
bash scripts/build-app.sh
open "dist/Codex Usage Rings.app" --args --show
```

输出位于 `dist/Codex Usage Rings.app`，构建脚本会加入图标、Sparkle 框架及其许可证，并进行 ad-hoc 签名与递归验签。

开发用环境变量：

| 变量 | 用途 |
| --- | --- |
| `CODEX_CLI_PATH` | 自定义 Codex 可执行文件路径 |
| `USAGE_RINGS_DATA_DIR` | 重定向元数据及独立账户目录 |
| `USAGE_RINGS_SNAPSHOT_DIR` | 仅供渲染测试导出图像 |

环境变量应传入实际启动的进程；从 Finder 打开的应用不会自动继承终端里临时 `export` 的值。需要自定义路径时可在终端直接启动可执行文件，例如：

```sh
CODEX_CLI_PATH="/absolute/path/to/codex" \
  "dist/Codex Usage Rings.app/Contents/MacOS/CodexUsageRings" --show
```

只读接口探针（不打印邮箱或令牌）：

```sh
swift run CodexUsageRings --probe
```

维护者发布前递增 `Resources/Info.plist` 的两个版本号，并添加 `docs/releases/v版本号.md`。首次准备官方签名工具：

```sh
bash scripts/setup-sparkle-tools.sh
```

打包要求钥匙串中存在账户名为 `dev.local.codex-usage-rings` 的 Sparkle EdDSA 私钥，且对应公钥与 `SUPublicEDKey` 一致。私钥不得提交到仓库，换机前应在安全位置备份；没有原私钥就不能给已安装用户签发可信更新。Fork 应使用自己的密钥、bundle ID 和更新源，不能沿用本项目的公钥进行发布。

生成 DMG、更新 ZIP、带更新包签名的 appcast 及校验清单：

```sh
bash scripts/package-release.sh
```

输出在 `dist/releases/v版本号/`，同时更新仓库根目录 `appcast.xml`。将 DMG、ZIP、appcast 和 SHA256SUMS 上传到对应 GitHub Release，并推送根目录 appcast。更新源使用固定的 raw GitHub 地址，支持本项目的预览版发布，不依赖 GitHub 的 latest 正式版接口。可用 `SPARKLE_BIN` 指定官方签名工具目录。

修改图标源图后，运行 `bash scripts/build-icon.sh`，再重新构建。原始 PNG 和 macOS `.icns` 均保存在 [Resources](Resources)。Logo 由 AI 生成。

## 已知限制

当前为预览版，仅提供 Apple Silicon 安装包，尚未经过 Developer ID 签名与 Apple 公证。多账户登录、系统登录启动、辅助功能及不同 macOS 版本的兼容性仍需完善；实际耗电随账户数量和使用情况变化。

参考：[Codex App Server](https://learn.chatgpt.com/docs/app-server)、[认证与凭据存储](https://learn.chatgpt.com/docs/auth)、[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。

## 许可证

本项目采用 [MIT License](LICENSE)，允许使用、修改、分发和商用；分发时须保留版权与许可声明。

应用包含 [Sparkle](https://github.com/sparkle-project/Sparkle)，其许可声明随安装包保存在 `Contents/Resources/Sparkle-LICENSE.txt`。
