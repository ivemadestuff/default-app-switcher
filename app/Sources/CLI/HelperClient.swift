import DASCore
import Foundation

struct HelperClient: Sendable {
    let helperURL: URL
    let timeout: Double

    static let defaultTimeout: Double = 120

    private let confirmationHintDelay: Double = 3.0

    init(helperURL: URL, timeout: Double = HelperClient.defaultTimeout) {
        self.helperURL = helperURL
        self.timeout = timeout
    }

    init(
        timeout: Double = HelperClient.defaultTimeout,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        self.init(helperURL: try HelperLocator.locate(environment: environment), timeout: timeout)
    }

    func apply(app: AppInfo, targets: [HandlerTarget], onSlow: (() -> Void)? = nil) throws
        -> HelperResponse
    {
        let id = UUID().uuidString
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let requestURL = tmp.appendingPathComponent("das-\(id).request.json")
        let responseURL = tmp.appendingPathComponent("das-\(id).response.json")
        defer {
            try? FileManager.default.removeItem(at: requestURL)
            try? FileManager.default.removeItem(at: responseURL)
        }

        let request = HelperRequest(
            applicationPath: app.url.path,
            targets: targets,
            responsePath: responseURL.path,
            budget: max(5, timeout - 5)
        )
        try JSONEncoder().encode(request).write(to: requestURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: requestURL.path)

        try launchNewInstance(requestPath: requestURL.path)

        let start = Date()
        var warned = false
        while Date().timeIntervalSince(start) < timeout {
            if FileManager.default.fileExists(atPath: responseURL.path),
                let data = try? Data(contentsOf: responseURL),
                !data.isEmpty
            {
                return try HelperResponse.parse(data)
            }
            if !warned, Date().timeIntervalSince(start) > confirmationHintDelay {
                warned = true
                onSlow?()
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw DASError.timedOut(seconds: timeout)
    }

    private func launchNewInstance(requestPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", helperURL.path, "--args", "--request", requestPath]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message =
                String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                ?? ""
            throw DASError.helperFailed(
                "could not launch \(helperURL.lastPathComponent): \(message.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }
    }
}
