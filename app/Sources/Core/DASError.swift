import Foundation

package enum DASError: Error, CustomStringConvertible {
    case appCannotHandle(app: String, category: String)
    case helperMissing(searched: [String])
    case helperFailed(String)
    case cancelled
    case timedOut(seconds: Double)
    case usage(String)

    package var description: String {
        switch self {
        case .appCannotHandle(let app, let category):
            return """
                \(app) is not registered to open anything in '\(category)', so making
                it the default would leave those files and links unopenable.
                Run `das` and choose a category to see available apps.
                """
        case .helperMissing(let searched):
            return """
                The helper application was not found.
                Searched:
                \(searched.map { "  " + $0 }.joined(separator: "\n"))
                Run the installer again or set DAS_HELPER_PATH.
                """
        case .helperFailed(let message):
            return "Helper failed: \(message)"
        case .cancelled:
            return "Cancelled. The macOS confirmation dialog was dismissed."
        case .timedOut(let seconds):
            return "Timed out after \(Int(seconds)) seconds waiting for the helper."
        case .usage(let message):
            return message
        }
    }

    package var exitCode: Int32 {
        switch self {
        case .usage: return 2
        case .cancelled: return 4
        case .timedOut: return 5
        default: return 1
        }
    }
}
