import Foundation

final class TestRunner {
    private var failures: [String] = []
    private var checks = 0
    private var currentSuite = ""

    func suite(_ name: String, _ body: (TestRunner) throws -> Void) {
        currentSuite = name
        do {
            try body(self)
        } catch {
            failures.append("\(name): threw unexpectedly — \(error)")
        }
    }

    func expect(_ condition: Bool, _ message: String, line: Int = #line) {
        checks += 1
        if !condition {
            failures.append("\(currentSuite):\(line) — \(message)")
        }
    }

    func equal<T: Equatable>(_ actual: T, _ expected: T, _ message: String, line: Int = #line) {
        checks += 1
        if actual != expected {
            failures.append(
                "\(currentSuite):\(line) — \(message)\n      expected: \(expected)\n      actual:   \(actual)"
            )
        }
    }

    func finish() -> Int32 {
        if failures.isEmpty {
            print("Passed \(checks) checks.")
            return 0
        }
        FileHandle.standardError.write(Data("Failed \(failures.count) of \(checks) checks.\n".utf8))
        for failure in failures {
            FileHandle.standardError.write(Data("  \(failure)\n".utf8))
        }
        return 1
    }
}
