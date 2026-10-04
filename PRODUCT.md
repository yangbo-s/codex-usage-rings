# Product

<!-- impeccable:product-schema 1 -->

## Platform
macOS 原生菜单栏应用，macOS 13+。

## Stack
SwiftUI + AppKit + Swift Package Manager，无第三方依赖。系统登录启动使用 ServiceManagement。

## Users
希望在使用 Codex 时，同时查看多个账户剩余额度，并严格控制后台耗电的 Mac 用户。

## Product Purpose
顶部菜单栏常驻细绿色用量圆环；一个已连接账户对应一个入口，环内以不带 `%` 的数字显示剩余百分比，点击查看额度周期与重置时间。

## Capabilities and Constraints
- 首次自动读取本机已有 Codex 登录。未连接时保留一个未知额度入口，每连接一个账户增加一个圆环；无演示模式。
- 有长周期和 5 小时额度时使用外长内短的同心环；仅一个额度窗口时使用较粗单环。
- 可用 banked reset 在环右侧逐个显示绿色竖线，数量来自接口，不提供兑换操作。
- 真实数据通过本地 Codex App Server 读取，额外账户使用隔离的配置目录。
- “登录时启动”默认关闭，开关反映 macOS 的实际状态，待批准和失败单独提示。
- 面板默认在鼠标移出 3 秒后自动收起，可关闭或设为 1–300 秒，设置持久保存；移回面板或编辑文字时取消计时。原生展开收起尊重系统 Reduce Motion 设置。
- 后台默认 5 分钟刷新，系统低电量模式 15 分钟；睡眠暂停，读取后关闭查询进程，无持续动画。
- 本次交付为可运行的本机应用；不包含 App Store 上架、Developer ID 公证或自动更新。
- 用户已明确确认菜单栏绿色圆环，并指定纯数字百分比、嵌套环、较厚单环、reset 细竖线及低耗电要求；当前修订缩小圆环并减细描边，无需重选视觉方案。

## Evidence on Hand
用户菜单栏截图、当前明确需求、Codex 官方 app-server/auth 文档、本机 SDK ServiceManagement 接口、实际只读查询、自动测试、原生离屏渲染与进程采样。

## Open Decisions
- 当前 Mac 已有自动测试及原生离屏证据；本轮 CUA 超时，实际 hover、编辑焦点、面板定位和 Reduce Motion 过渡尚未现场验证。多账户真实 OAuth、重启后的登录启动、跨系统与长期电池续航也仍需验证。
