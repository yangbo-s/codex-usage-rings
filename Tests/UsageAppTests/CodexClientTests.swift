import Foundation
import Testing
import UsageCore
@testable import CodexUsageRings

func fixture(_ body: String) throws -> (URL, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appendingPathComponent("fake-codex")
    try ("#!/usr/bin/python3\nimport json, sys, time, os\n" + body).write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
    return (directory, script)
}

@Test @MainActor func fragmentedResponsesAndIndependentHomes() async throws {
    let (directory, executable) = try fixture("""
    for line in sys.stdin:
        request = json.loads(line)
        if 'id' not in request: continue
        method = request['method']
        result = {}
        if method == 'account/read':
            result = {'account': {'type': 'chatgpt', 'email': os.environ.get('CODEX_HOME'), 'planType': 'pro'}}
        if method == 'account/rateLimits/read':
            result = {'rateLimits': {'primary': {'usedPercent': 28, 'windowDurationMins': 300}}}
        encoded = json.dumps({'id': request['id'], 'result': result}) + '\\n'
        sys.stdout.write(encoded[:7]); sys.stdout.flush()
        time.sleep(0.01)
        sys.stdout.write(encoded[7:]); sys.stdout.flush()
    """)
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = CodexClient(home: directory.appendingPathComponent("first"), executable: executable)
    let second = CodexClient(home: directory.appendingPathComponent("second"), executable: executable)
    defer { first.stop(); second.stop() }
    let a = try await first.account()
    let b = try await second.account()
    #expect(a.email != b.email)
    #expect(a.email?.hasSuffix("/first") == true)
    #expect(b.email?.hasSuffix("/second") == true)
    #expect(try await first.usage().limits.primary?.remaining == 72)
    #expect(try await second.usage().limits.primary?.remaining == 72)
}

@Test @MainActor func serverErrorsPropagateWithoutHanging() async throws {
    let (directory, executable) = try fixture("""
    for line in sys.stdin:
        r = json.loads(line)
        if 'id' not in r: continue
        if r['method'] == 'initialize': reply = {'id': r['id'], 'result': {}}
        else: reply = {'id': r['id'], 'error': {'code': 401, 'message': 'Session expired'}}
        print(json.dumps(reply), flush=True)
    """)
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = CodexClient(home: nil, executable: executable)
    defer { client.stop() }
    do {
        _ = try await client.account()
        Issue.record("An expired session must fail")
    } catch {
        #expect(error.localizedDescription.contains("Session expired"))
    }
}

@Test @MainActor func timeoutAndProcessExitReleaseRequests() async throws {
    for body in ["time.sleep(10)\n", "sys.exit(1)\n"] {
        let (directory, executable) = try fixture(body)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = CodexClient(home: nil, executable: executable, timeout: 0.2)
        let began = Date()
        do {
            _ = try await client.account()
            Issue.record("A stalled or stopped process must fail")
        } catch {
            #expect(Date().timeIntervalSince(began) < 3)
        }
        client.stop()
    }
}

@Test @MainActor func metadataPersistsAndRemovingLastAccountStaysEmpty() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let profiles = [Profile(id: "real", name: "My account", kind: .local)]
    try JSONEncoder().encode(Settings(profiles: profiles, autoConnectLocal: false))
        .write(to: directory.appendingPathComponent("settings.json"))
    let first = UsageStore(dataDirectory: directory)
    first.update("real") { $0.name = "Work" }
    let restored = UsageStore(dataDirectory: directory)
    #expect(restored.visibleProfiles.first?.name == "Work")
    restored.remove(profiles[0])
    let empty = UsageStore(dataDirectory: directory)
    #expect(empty.visibleProfiles.isEmpty)
    #expect(!empty.settings.autoConnectLocal)
}

@Test @MainActor func unreadableSettingsArePreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("settings.json")
    let original = Data("not-valid-json".utf8)
    try original.write(to: file)
    let store = UsageStore(dataDirectory: directory)
    #expect(store.message != nil)
    #expect(store.visibleProfiles.isEmpty)
    #expect(try Data(contentsOf: file) == original)
}

@Test @MainActor func successfulUsageReadLeavesNoQueryProcess() async throws {
    let (directory, executable) = try fixture("""
    for line in sys.stdin:
        r = json.loads(line)
        if 'id' not in r: continue
        result = {}
        if r['method'] == 'account/read':
            result = {'account': {'type': 'chatgpt', 'email': str(os.getpid()), 'planType': 'pro'}}
        if r['method'] == 'account/rateLimits/read':
            result = {'rateLimits': {'primary': {'usedPercent': 12, 'windowDurationMins': 10080}}, 'rateLimitResetCredits': {'availableCount': 2}}
        print(json.dumps({'id': r['id'], 'result': result}), flush=True)
    """)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = UsageStore(dataDirectory: directory.appendingPathComponent("data"), clientFactory: {
        CodexClient(home: $0, executable: executable)
    })
    await store.connectLocal()
    #expect(store.visibleProfiles.count == 1)
    let profile = try #require(store.visibleProfiles.first)
    let state = try #require(store.states[profile.id])
    #expect(state.rings.percentage == "88%")
    #expect(state.usage?.bankedResetCount == 2)
    let pidString = try #require(state.email)
    let pid = try #require(Int32(pidString))
    for _ in 0..<20 {
        if kill(pid, 0) != 0 { break }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(kill(pid, 0) != 0)
    #expect(!store.isRefreshing)
    store.stop()
}
