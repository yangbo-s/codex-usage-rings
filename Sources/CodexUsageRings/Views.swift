import AppKit
import SwiftUI
import UsageCore

enum RingStyle {
    static let secondaryText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.secondaryLabelColor
            : NSColor(srgbRed: 0.38, green: 0.38, blue: 0.38, alpha: 1)
    })
    static let inkGreen = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.37, green: 0.88, blue: 0.55, alpha: 1)
            : NSColor(srgbRed: 0.08, green: 0.43, blue: 0.23, alpha: 1)
    })
}

struct UsagePanel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginAtLaunch: LoginAtLaunch
    var onHover: (Bool) -> Void = { _ in }
    var onEditing: (Bool) -> Void = { _ in }
    @FocusState private var editingField: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if let message = store.message {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button { store.message = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("关闭提示")
                        }
                        .foregroundStyle(RingStyle.secondaryText).padding(14)
                        Divider()
                    }
                    if store.managing { management } else { overview }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 360, height: store.managing ? 560 : panelHeight)
        .background(.regularMaterial)
        .tint(RingStyle.inkGreen)
        .onHover(perform: onHover)
        .onChange(of: editingField, perform: onEditing)
        .onDisappear { editingField = false; onEditing(false) }
    }

    private var panelHeight: CGFloat {
        store.visibleProfiles.isEmpty ? 330 : min(560, 335 + CGFloat(store.visibleProfiles.count - 1) * 80)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if store.managing {
                Button { store.managing = false } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).frame(width: 22, height: 30).accessibilityLabel("返回用量")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(store.managing ? "账户与设置" : "Usage Rings")
                    .font(.system(size: 18, weight: .semibold))
                Text(store.managing ? "每个账户，一个圆环" : "\(store.visibleProfiles.count) 个账户 · 剩余额度")
                    .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
            }
            Spacer()
            if store.isRefreshing || store.connecting { ProgressView().controlSize(.small).accessibilityLabel("正在同步") }
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
    }

    private var overview: some View {
        VStack(spacing: 0) {
            if store.visibleProfiles.isEmpty {
                VStack(spacing: 12) {
                    Image(nsImage: RingRenderer.image(RingPresentation(), diameter: 36))
                        .accessibilityHidden(true)
                    Text(store.connecting ? "正在连接本机账户…" : "连接你的第一个账户")
                        .font(.system(size: 14, weight: .semibold))
                    Text("每连接一个账户，顶栏就多一个圆环。")
                        .font(.system(size: 12)).foregroundStyle(RingStyle.secondaryText)
                    Button("连接本机 Codex") { Task { await store.connectLocal() } }
                        .buttonStyle(.borderedProminent).disabled(store.connecting)
                    Button("添加其他账户") { store.managing = true }.buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ForEach(store.visibleProfiles) { profile in
                    accountRow(profile)
                    if profile.id != store.visibleProfiles.last?.id { Divider().padding(.horizontal, 20) }
                }
            }
        }
    }

    private func accountRow(_ profile: Profile) -> some View {
        let state = store.states[profile.id] ?? AccountState()
        let selected = store.selectedID == profile.id
        return VStack(spacing: 0) {
            Button { store.selectedID = profile.id } label: {
                HStack(spacing: 12) {
                    Image(nsImage: RingRenderer.image(state.rings, stale: state.isStale, diameter: 36, includesResets: false))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.name.isEmpty ? "未命名账户" : profile.name)
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(state.isStale ? "数据已过期" : (state.plan?.capitalized ?? "等待同步"))
                            .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(state.usage?.bankedResetCount.map { "\($0) 次" } ?? "—")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(RingStyle.inkGreen)
                        Text("Banked reset").font(.system(size: 10)).foregroundStyle(RingStyle.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(profile.name)，剩余 \(state.rings.percentage)，查看详情")
            .padding(.horizontal, 20).padding(.vertical, 16)

            if selected {
                VStack(alignment: .leading, spacing: 13) {
                    if let outer = state.rings.outer {
                        windowRow(outer, label: state.rings.isNested ? "外环 · \(outer.title)" : outer.title, stale: state.isStale)
                    } else {
                        Text("暂无用量数据").font(.system(size: 12)).foregroundStyle(RingStyle.secondaryText)
                    }
                    if let inner = state.rings.inner { windowRow(inner, label: "内环 · \(inner.title)", stale: state.isStale) }
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("中心数字为\(state.rings.outer?.title ?? "主额度")剩余百分比；每条竖线代表一次 reset。")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                    if let error = state.error {
                        Text(error).font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let updated = state.updatedAt {
                        Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10)).foregroundStyle(RingStyle.secondaryText)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 18)
            }
        }
        .background(selected ? Color.primary.opacity(0.025) : .clear)
    }

    private func windowRow(_ window: UsageWindow, label: String, stale: Bool) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(window.percentage).font(.system(size: 11, weight: .semibold)).monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(Color(nsColor: UsagePalette.color(remaining: window.remaining, stale: stale)))
                        .frame(width: geometry.size.width * CGFloat((window.remaining ?? 0) / 100))
                }
            }
            .frame(height: 4).accessibilityHidden(true)
            HStack {
                Text(window.resetDescription())
                Spacer()
                if let remaining = window.remaining { Text("已用 \(Int((100 - remaining).rounded()))%") }
            }
            .font(.system(size: 10)).foregroundStyle(RingStyle.secondaryText).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var management: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("自动收起面板", isOn: Binding(
                    get: { store.settings.autoHideEnabled },
                    set: { store.setAutoHide(enabled: $0) }
                ))
                .toggleStyle(.switch).font(.system(size: 12))
                HStack {
                    Text("鼠标移出后")
                    Spacer()
                    TextField("秒数", value: Binding(
                        get: { store.settings.autoHideDelaySeconds },
                        set: { store.setAutoHide(delay: $0) }
                    ), format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .frame(width: 48).focused($editingField)
                    .accessibilityLabel("自动收起延迟，1 到 300 秒")
                    Text("秒收起")
                }
                .font(.system(size: 12)).disabled(!store.settings.autoHideEnabled)
                Text("可设为 1–300 秒；移回面板或编辑文字时暂停。")
                    .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            ForEach(store.visibleProfiles) { profile in
                VStack(spacing: 8) {
                    HStack {
                        TextField("账户名称", text: Binding(
                            get: { profile.name },
                            set: { value in store.update(profile.id) { $0.name = String(value.prefix(32)) } }
                        ))
                        .textFieldStyle(.roundedBorder).accessibilityLabel("账户名称").focused($editingField)
                        Button("移除") { store.remove(profile) }.font(.system(size: 11)).buttonStyle(.plain)
                    }
                    Text(profile.kind == .local ? "跟随本机 Codex 登录" : "独立登录账户")
                        .font(.system(size: 10)).foregroundStyle(RingStyle.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack(spacing: 9) {
                Button { Task { await store.connectLocal() } } label: {
                    Label("连接本机 Codex", systemImage: "desktopcomputer").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                Button { Task { await store.addAccount() } } label: {
                    Label("添加其他账户", systemImage: "plus").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
            .controlSize(.large).disabled(store.connecting || store.pendingProfile != nil)
            if store.pendingProfile != nil {
                VStack(alignment: .leading, spacing: 9) {
                    Text("请在浏览器中选择账户并完成登录").font(.system(size: 12, weight: .medium))
                    HStack {
                        if let url = store.loginURL { Button("重新打开登录页") { NSWorkspace.shared.open(url) } }
                        Spacer()
                        Button("取消") { store.cancelLogin() }
                    }.font(.system(size: 11))
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle("登录时启动", isOn: Binding(get: { loginAtLaunch.isOn }, set: { enabled in
                    Task { await loginAtLaunch.setEnabled(enabled) }
                }))
                .toggleStyle(.switch).disabled(loginAtLaunch.changing).font(.system(size: 12))
                Text("登录 Mac 后自动显示菜单栏圆环。")
                    .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                if loginAtLaunch.needsApproval {
                    Text("等待系统允许，当前尚未启用自动启动。")
                        .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                    Button("打开登录项设置") { loginAtLaunch.openSettings() }.font(.system(size: 11))
                }
                if let error = loginAtLaunch.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("低耗电刷新", systemImage: "leaf")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(RingStyle.inkGreen)
                Text("后台每 5 分钟刷新；系统低电量模式下每 15 分钟。打开面板按需更新，休眠时暂停。")
                Text("读取完即关闭查询进程，不持续播放动画。")
            }
            .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if store.managing {
                Text("设置自动保存").font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
            } else {
                Button { Task { await store.refreshAll(force: true) } } label: {
                    Label(store.isRefreshing ? "同步中…" : "刷新用量", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain).disabled(store.isRefreshing || store.visibleProfiles.isEmpty)
            }
            Spacer()
            Button { store.managing.toggle(); loginAtLaunch.refresh() } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.plain).help("账户与设置").accessibilityLabel("账户与设置")
            Menu {
                Button("退出 Usage Rings") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 18).accessibilityLabel("更多选项")
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}
