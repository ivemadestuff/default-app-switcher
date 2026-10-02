import DASCore
import Foundation

enum Out {
    static func stdout(_ text: String = "") {
        FileHandle.standardOutput.write(
            Data(((isatty(STDOUT_FILENO) == 1 ? text : stripANSI(text)) + "\n").utf8))
    }

    static func stderr(_ text: String) {
        FileHandle.standardError.write(
            Data(((isatty(STDERR_FILENO) == 1 ? text : stripANSI(text)) + "\n").utf8))
    }
}

package struct Style: Sendable {
    let enabled: Bool
    let isTerminal: Bool

    package init(enabled: Bool, isTerminal: Bool? = nil) {
        self.enabled = enabled
        self.isTerminal = isTerminal ?? enabled
    }

    static func detect() -> Style {
        let isTerminal =
            isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
        let enabled = isTerminal && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
        return Style(enabled: enabled, isTerminal: isTerminal)
    }

    private func wrap(_ text: String, _ code: String) -> String {
        enabled ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }

    func bold(_ t: String) -> String { wrap(t, "1") }
    func dim(_ t: String) -> String { wrap(t, "2") }
    func green(_ t: String) -> String { wrap(t, "32") }
    func yellow(_ t: String) -> String { wrap(t, "33") }
    func red(_ t: String) -> String { wrap(t, "31") }
    func inverse(_ t: String) -> String { wrap(t, "7") }
}

package struct CommandOutput {
    package var stdout: (String) -> Void
    package var stderr: (String) -> Void

    init() {
        stdout = { Out.stdout($0) }
        stderr = { Out.stderr($0) }
    }

    package init(stdout: @escaping (String) -> Void, stderr: @escaping (String) -> Void) {
        self.stdout = stdout
        self.stderr = stderr
    }
}
