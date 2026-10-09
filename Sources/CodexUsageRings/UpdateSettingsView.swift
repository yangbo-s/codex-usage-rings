import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: SoftwareUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("软件更新").fontWeight(.medium)
                Spacer()
                Text("版本 \(updater.version)").foregroundStyle(RingStyle.secondaryText)
            }
            Toggle("自动检查更新", isOn: Binding(
                get: { updater.automaticallyChecks }, set: updater.setAutomaticallyChecks
            ))
            .toggleStyle(.switch).disabled(updater.error != nil)
            Toggle("自动下载并在退出时安装", isOn: Binding(
                get: { updater.automaticallyDownloads }, set: updater.setAutomaticallyDownloads
            ))
            .toggleStyle(.switch).disabled(!updater.automaticallyChecks || updater.error != nil)
            Text("每天检查一次。关闭自动安装时，可手动选择更新并重启。")
                .font(.system(size: 11)).foregroundStyle(RingStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(updater.availableVersion == nil ? "检查更新…" : "查看更新…", action: updater.checkForUpdates)
                    .disabled(!updater.canCheckForUpdates || updater.error != nil)
                if let version = updater.availableVersion {
                    Text("发现新版本 \(version)").foregroundStyle(RingStyle.inkGreen)
                        .lineLimit(1).truncationMode(.middle)
                } else if updater.sessionInProgress {
                    ProgressView().controlSize(.small).accessibilityLabel("正在处理更新")
                    Text("正在处理更新…").foregroundStyle(RingStyle.secondaryText)
                }
            }
            if let error = updater.error {
                Text(error).foregroundStyle(RingStyle.secondaryText)
                    .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(updater.lastCheck.map { "上次检查：\($0.formatted(date: .abbreviated, time: .shortened))" } ?? "尚未检查更新")
                    .font(.system(size: 10)).foregroundStyle(RingStyle.secondaryText)
            }
        }
        .font(.system(size: 12))
    }
}
