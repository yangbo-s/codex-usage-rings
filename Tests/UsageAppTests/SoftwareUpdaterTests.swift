import Foundation
import Testing
@testable import CodexUsageRings

@Test @MainActor func sparklePreferencesPersistInTheirOwnDomain() throws {
    let id = "dev.local.codex-usage-rings.tests.\(UUID().uuidString)"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).app")
    let contents = directory.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    defer {
        UserDefaults.standard.removePersistentDomain(forName: id)
        try? FileManager.default.removeItem(at: directory)
    }
    let plist: [String: Any] = [
        "CFBundleIdentifier": id, "CFBundleName": "Updater Test", "CFBundleVersion": "1",
        "CFBundleShortVersionString": "0.6.0", "CFBundlePackageType": "APPL",
        "SUEnableAutomaticChecks": true, "SUAutomaticallyUpdate": false
    ]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        .write(to: contents.appendingPathComponent("Info.plist"))
    let bundle = try #require(Bundle(url: directory))
    let first = SoftwareUpdater(start: false, bundle: bundle)
    #expect(first.version == "0.6.0")
    #expect(first.automaticallyChecks)
    #expect(!first.automaticallyDownloads)
    #expect(!first.canCheckForUpdates)
    #expect(!first.sessionInProgress)
    first.setAutomaticallyDownloads(true)
    #expect(first.automaticallyDownloads)
    first.setAutomaticallyChecks(false)
    #expect(!first.automaticallyChecks)
    // Sparkle suspends automatic downloads while checks are disabled, but
    // retains the user's choice for when they enable checks again.
    #expect(!first.automaticallyDownloads)
    let restored = SoftwareUpdater(start: false, bundle: bundle)
    #expect(!restored.automaticallyChecks)
    #expect(!restored.automaticallyDownloads)
    restored.setAutomaticallyChecks(true)
    #expect(restored.automaticallyDownloads)
    #expect(restored.lastCheck == nil)
    first.checkForUpdates() // A stopped updater must not start a session or a network check.
    #expect(!first.sessionInProgress)
    #expect(first.lastCheck == nil)
}
