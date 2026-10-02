import DASCore
import Foundation

func runPlanningTests(_ t: TestRunner) {
    t.suite("assignment-planning") { t in
        let category = AppCategory(
            id: "test", name: "Test", summary: "s",
            targets: [
                .uti("test.first", primary: true),
                .uti("test.second"),
                .uti("test.third"),
            ]
        )
        let app = StubReader.app("com.a", "A")
        let fullStatus = CategoryStatus.build(
            category: category,
            defaults: category.targets.map {
                TargetDefaults(target: $0, defaultApp: app, candidates: [app])
            })
        let full = try AssignmentPlan(app: app, status: fullStatus)
        t.equal(full.targets, category.targets, "a full candidate is assigned every type in order")
        t.equal(full.skipped.count, 0, "a full candidate skips nothing")
        t.equal(full.app.bundleIdentifier, "com.a", "the plan names the app")

        let partialStatus = CategoryStatus.build(
            category: category,
            defaults: category.targets.map {
                TargetDefaults(target: $0, defaultApp: nil, candidates: $0.isPrimary ? [app] : [])
            })
        let partial = try AssignmentPlan(app: app, status: partialStatus)
        t.equal(partial.targets, [category.targets[0]], "only supported types are assigned")
        t.equal(
            partial.skipped, Array(category.targets.dropFirst()), "unsupported types are skipped")

        let stranger = StubReader.app("com.calculator", "Calculator")
        do {
            _ = try AssignmentPlan(app: stranger, status: fullStatus)
            t.expect(false, "an app outside the snapshot must be refused")
        } catch let error as DASError {
            if case .appCannotHandle(let app, let category) = error {
                t.equal(app, "Calculator", "refusal names the app")
                t.equal(category, "test", "refusal names the category")
            } else {
                t.expect(false, "expected appCannotHandle, got \(error)")
            }
        }

        let unavailable = CategoryStatus.build(category: category, defaults: [])
        t.expect(unavailable.apps.isEmpty, "an empty snapshot has no candidates")
        t.expect(unavailable.primaryApp == nil, "an empty snapshot has no default")
        do {
            _ = try AssignmentPlan(app: app, status: unavailable)
            t.expect(false, "a category without available types must be refused")
        } catch let error as DASError {
            if case .appCannotHandle = error {
                t.expect(true, "empty plans are refused")
            } else {
                t.expect(false, "expected appCannotHandle, got \(error)")
            }
        }
    }
}
