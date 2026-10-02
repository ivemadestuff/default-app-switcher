import Foundation

package struct AssignmentPlan: Equatable, Sendable {
    package let app: AppInfo
    package let targets: [HandlerTarget]
    package let skipped: [HandlerTarget]

    package init(app: AppInfo, status: CategoryStatus) throws {
        let supported = status.supportedTargets(for: app)
        let targets = status.targets.filter { supported.contains($0) }
        guard !targets.isEmpty else {
            throw DASError.appCannotHandle(app: app.name, category: status.category.id)
        }
        self.app = app
        self.targets = targets
        self.skipped = status.targets.filter { !supported.contains($0) }
    }
}
