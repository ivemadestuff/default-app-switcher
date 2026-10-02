import DASCLI
import DASCore
import Foundation

struct StubReader: DefaultsReading {
    var defaultAppsByTarget: [String: String] = [:]
    var unavailableTargets: Set<String> = []
    var candidatesByTarget: [String: [String]] = [:]

    static func app(_ bundleID: String, _ name: String) -> AppInfo {
        AppInfo(
            bundleIdentifier: bundleID,
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }

    private func app(_ bundleID: String) -> AppInfo {
        let name = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        return Self.app(bundleID, name)
    }

    func read(_ category: AppCategory) -> [TargetDefaults] {
        category.targets.filter { !unavailableTargets.contains($0.value) }.map { target in
            TargetDefaults(
                target: target,
                defaultApp: defaultAppsByTarget[target.value].map(app),
                candidates: (candidatesByTarget[target.value] ?? []).map(app))
        }
    }
}
