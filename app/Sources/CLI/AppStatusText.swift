import DASCore

enum AppStatusText {
    static func marker(_ status: AppStatus, style: Style) -> String {
        switch status.state {
        case .complete: return style.isTerminal ? style.green("✓") : "Default"
        case .partial: return style.isTerminal ? style.yellow("◐") : "Partial"
        case .none: return " "
        }
    }

    static func summary(_ status: AppStatus, total: Int, style: Style) -> String {
        switch status.state {
        case .complete:
            return style.dim("Default for all \(total)")
        case .partial(let active, let total):
            return style.dim("\(active)/\(total)")
        case .none:
            let supported = status.supportedTargets.count
            return style.dim(
                supported >= total ? "Handles all \(total)" : "Handles \(supported)/\(total)")
        }
    }
}
