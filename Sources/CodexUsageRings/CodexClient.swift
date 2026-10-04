import Foundation
import UsageCore

/// One process per account. No shell, token parsing, model calls, or shared login switching.
@MainActor
final class CodexClient {
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var sequence = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var ready = false
    let home: URL?
    private let executableOverride: URL?
    private let timeoutNanoseconds: UInt64
    var notification: ((String, [String: Any]) -> Void)?

    init(home: URL?, executable: URL? = nil, timeout: TimeInterval = 30) {
        self.home = home
        self.executableOverride = executable
        self.timeoutNanoseconds = UInt64(max(0.01, timeout) * 1_000_000_000)
    }

    static func executable() -> URL? {
        let env = ProcessInfo.processInfo.environment
        var candidates = [env["CODEX_CLI_PATH"]].compactMap { $0 }
        candidates += [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ]
        candidates += (env["PATH"] ?? "").split(separator: ":").map { "\($0)/codex" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map(URL.init(fileURLWithPath:))
    }

    func start() async throws {
        if ready, process?.isRunning == true { return }
        stop()
        guard let executable = executableOverride ?? Self.executable() else { throw ClientError.unavailable }
        let child = Process()
        let stdin = Pipe(), stdout = Pipe()
        child.executableURL = executable
        child.arguments = ["app-server", "--listen", "stdio://"]
        var environment = ProcessInfo.processInfo.environment
        if let home {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            environment["CODEX_HOME"] = home.path
            // A separate file store makes account isolation explicit, regardless of keychain behavior.
            child.arguments! += ["-c", "cli_auth_credentials_store=\"file\""]
        }
        child.environment = environment
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        output?.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            Task { @MainActor [weak self] in
                guard self?.process === child else { return }
                self?.receive(bytes)
            }
        }
        child.terminationHandler = { [weak self] child in
            Task { @MainActor [weak self] in
                guard self?.process === child else { return }
                self?.stop()
            }
        }
        process = child
        do {
            try child.run()
            _ = try await request("initialize", params: [
                "clientInfo": ["name": "codex_usage_rings", "title": "Codex Usage Rings",
                               "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"],
                "capabilities": ["experimentalApi": false]
            ])
            try write(["method": "initialized"])
            ready = true
        } catch {
            stop()
            throw error
        }
    }

    func account() async throws -> AccountResponse.Account {
        try await start()
        let result = try await request("account/read", params: ["refreshToken": false])
        let response = try JSONDecoder().decode(AccountResponse.self, from: result)
        guard let account = response.account else { throw ClientError.notLoggedIn }
        guard account.type == "chatgpt" else { throw ClientError.unsupportedAccount }
        return account
    }

    func usage() async throws -> AccountUsage {
        try await start()
        let result = try await request("account/rateLimits/read")
        let response = try JSONDecoder().decode(RateResponse.self, from: result)
        guard let usage = response.usage else { throw ClientError.protocolError }
        return usage
    }

    func beginLogin() async throws -> URL {
        try await start()
        let result = try await request("account/login/start", params: ["type": "chatgpt"])
        guard let object = try JSONSerialization.jsonObject(with: result) as? [String: Any],
              let raw = object["authUrl"] as? String, let url = URL(string: raw),
              url.scheme == "https", let host = url.host,
              ["auth.openai.com", "auth.chatgpt.com", "chatgpt.com"].contains(host) else {
            throw ClientError.protocolError
        }
        return url
    }

    func request(_ method: String, params: [String: Any]? = nil) async throws -> Data {
        sequence += 1
        let id = sequence
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            var message: [String: Any] = ["id": id, "method": method]
            if let params { message["params"] = params }
            do {
                try write(message)
                let timeout = timeoutNanoseconds
                deadlines[id] = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: timeout) } catch { return }
                    guard let self, self.pending[id] != nil else { return }
                    self.stop(error: ClientError.timeout)
                }
            } catch {
                pending.removeValue(forKey: id)?.resume(throwing: error)
            }
        }
    }

    private func write(_ message: [String: Any]) throws {
        guard let input, process?.isRunning == true else { throw ClientError.stopped }
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(10)
        try input.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { stop(); return }
        buffer.append(data)
        guard buffer.count <= 4_194_304 else { stop(error: ClientError.protocolError); return }
        while let end = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<end])
            buffer.removeSubrange(...end)
            guard !line.isEmpty else { continue }
            guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
                stop(error: ClientError.protocolError)
                return
            }
            if let method = message["method"] as? String {
                if let id = message["id"] {
                    try? write(["id": id, "error": ["code": -32601, "message": "Read-only usage client"]])
                } else {
                    notification?(method, message["params"] as? [String: Any] ?? [:])
                }
                continue
            }
            guard let id = message["id"] as? Int, let continuation = pending.removeValue(forKey: id) else { continue }
            deadlines.removeValue(forKey: id)?.cancel()
            if let error = message["error"] as? [String: Any] {
                continuation.resume(throwing: ClientError.server(error["message"] as? String ?? "未知错误"))
            } else if let result = message["result"], JSONSerialization.isValidJSONObject(result),
                      let encoded = try? JSONSerialization.data(withJSONObject: result) {
                continuation.resume(returning: encoded)
            } else {
                continuation.resume(throwing: ClientError.protocolError)
            }
        }
    }

    func stop(error: Error = ClientError.stopped) {
        ready = false
        output?.readabilityHandler = nil
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        try? input?.close()
        try? output?.close()
        input = nil
        output = nil
        process = nil
        buffer.removeAll()
        deadlines.values.forEach { $0.cancel() }
        deadlines.removeAll()
        let waiting = pending.values
        pending.removeAll()
        waiting.forEach { $0.resume(throwing: error) }
    }
}
