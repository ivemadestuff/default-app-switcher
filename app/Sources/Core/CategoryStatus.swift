import Foundation

package struct TargetDefaults: Sendable {
    package let target: HandlerTarget
    package let defaultApp: AppInfo?
    package let candidates: [AppInfo]

    package init(target: HandlerTarget, defaultApp: AppInfo?, candidates: [AppInfo]) {
        self.target = target
        self.defaultApp = defaultApp
        self.candidates = candidates
    }
}

package enum DefaultState: Equatable, Sendable {
    case complete
    case partial(active: Int, total: Int)
    case none

    package var isActive: Bool { self != .none }
}

package struct AppStatus: Sendable, Equatable {
    package let app: AppInfo
    package let supportedTargets: [HandlerTarget]
    package let activeTargets: [HandlerTarget]
    package let state: DefaultState
    package let ownsPrimary: Bool

    package init(
        app: AppInfo, supportedTargets: [HandlerTarget], activeTargets: [HandlerTarget],
        totalTargets: Int, primaryTarget: HandlerTarget
    ) {
        self.app = app
        self.supportedTargets = supportedTargets
        self.activeTargets = activeTargets
        self.ownsPrimary = activeTargets.contains(primaryTarget)
        if activeTargets.isEmpty {
            self.state = .none
        } else if activeTargets.count >= totalTargets {
            self.state = .complete
        } else {
            self.state = .partial(active: activeTargets.count, total: totalTargets)
        }
    }
}

package struct CategoryStatus: Sendable {
    package let category: AppCategory
    package let apps: [AppStatus]
    package let primaryApp: AppInfo?
    package let targets: [HandlerTarget]

    package var isMixed: Bool {
        let activeCount = apps.filter { $0.state.isActive }.count
        let hasPartial = apps.contains {
            if case .partial = $0.state { return true } else { return false }
        }
        return activeCount > 1 && hasPartial
    }

    package static func build(category: AppCategory, defaults: [TargetDefaults]) -> CategoryStatus {
        let targets = defaults.map(\.target)
        var supported: [String: [HandlerTarget]] = [:]
        var active: [String: [HandlerTarget]] = [:]
        var infoByID: [String: AppInfo] = [:]

        func remember(
            _ target: HandlerTarget, for id: String, in table: inout [String: [HandlerTarget]]
        ) {
            if table[id]?.contains(target) != true {
                table[id, default: []].append(target)
            }
        }

        for entry in defaults {
            let target = entry.target
            for app in entry.candidates {
                remember(target, for: app.bundleIdentifier, in: &supported)
                infoByID[app.bundleIdentifier] = app
            }
            if let current = entry.defaultApp {
                remember(target, for: current.bundleIdentifier, in: &active)
                infoByID[current.bundleIdentifier] = current
                remember(target, for: current.bundleIdentifier, in: &supported)
            }
        }

        let primaryApp = defaults.first { $0.target == category.primaryTarget }?.defaultApp
        let statuses = infoByID.values.map { app in
            AppStatus(
                app: app,
                supportedTargets: supported[app.bundleIdentifier] ?? [],
                activeTargets: active[app.bundleIdentifier] ?? [],
                totalTargets: targets.count,
                primaryTarget: category.primaryTarget
            )
        }

        return CategoryStatus(
            category: category,
            apps: statuses.sorted(by: Self.displayOrder),
            primaryApp: primaryApp,
            targets: targets
        )
    }

    package func supportedTargets(for app: AppInfo) -> [HandlerTarget] {
        apps.first { $0.app.bundleIdentifier == app.bundleIdentifier }?.supportedTargets ?? []
    }

    private static func displayOrder(_ a: AppStatus, _ b: AppStatus) -> Bool {
        if a.ownsPrimary != b.ownsPrimary { return a.ownsPrimary && !b.ownsPrimary }
        if a.activeTargets.count != b.activeTargets.count {
            return a.activeTargets.count > b.activeTargets.count
        }
        return a.app.name.localizedCaseInsensitiveCompare(b.app.name) == .orderedAscending
    }
}
