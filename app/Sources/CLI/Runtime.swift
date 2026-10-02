import DASCore
import Foundation

package struct Runtime {
    package let reader: DefaultsReading
    package let style: Style
    package var output = CommandOutput()
    package var isInteractive = RawTerminal.isInteractive
    package var assign: (AppInfo, [HandlerTarget], (() -> Void)?) throws -> HelperResponse = {
        app, targets, onSlow in
        try HelperClient().apply(app: app, targets: targets, onSlow: onSlow)
    }

    package init(reader: DefaultsReading, style: Style) {
        self.reader = reader
        self.style = style
    }

    package func performAssignment(
        status: CategoryStatus,
        app: AppInfo,
        onSlow: (() -> Void)? = nil
    ) throws -> (response: HelperResponse, skipped: [HandlerTarget]) {
        let plan = try AssignmentPlan(app: app, status: status)
        let response = try assign(plan.app, plan.targets, onSlow)
        return (response, plan.skipped)
    }

    package func status(of category: AppCategory) -> CategoryStatus {
        CategoryStatus.build(category: category, defaults: reader.read(category))
    }
}
