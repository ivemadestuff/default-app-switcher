import AppKit
import DASCore
import Foundation

func fail(_ reason: String, respondingAt responsePath: String?) -> Never {
    if let responsePath {
        let response = HelperResponse(outcomes: [], helperError: reason)
        try? JSONEncoder().encode(response).write(
            to: URL(fileURLWithPath: responsePath), options: .atomic)
    }
    FileHandle.standardError.write(Data("das-helper: \(reason)\n".utf8))
    exit(1)
}

func requestPath(in arguments: [String]) -> String? {
    guard let flag = arguments.firstIndex(of: "--request"), flag + 1 < arguments.count else {
        return nil
    }
    return arguments[flag + 1]
}

guard let path = requestPath(in: CommandLine.arguments) else {
    fail("Usage: das-helper --request <path>", respondingAt: nil)
}

let request: HelperRequest
do {
    request = try JSONDecoder().decode(
        HelperRequest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
} catch {
    fail("Could not read the request at \(path): \(error.localizedDescription)", respondingAt: nil)
}

guard request.version == 1 else {
    fail("Unsupported request version: \(request.version).", respondingAt: request.responsePath)
}

guard request.budget.isFinite, request.budget > 0, !request.targets.isEmpty else {
    fail("Invalid assignment targets or time budget.", respondingAt: request.responsePath)
}

let applicationURL = URL(fileURLWithPath: request.applicationPath)
guard FileManager.default.fileExists(atPath: applicationURL.path) else {
    fail("Application not found: \(applicationURL.path).", respondingAt: request.responsePath)
}

_ = NSApplication.shared

let needsForeground = request.targets.contains { $0.kind == .scheme }
if needsForeground {
    DefaultAssignment.becomeForeground()
} else {
    NSApp.setActivationPolicy(.accessory)
}

let outcomes = DefaultAssignment.perform(
    request.targets,
    using: applicationURL,
    startingInForeground: needsForeground,
    deadline: Date().addingTimeInterval(request.budget)
)

do {
    let data = try JSONEncoder().encode(HelperResponse(outcomes: outcomes))
    try data.write(to: URL(fileURLWithPath: request.responsePath), options: .atomic)
} catch {
    fail("Could not write the response: \(error.localizedDescription)", respondingAt: nil)
}

exit(0)
