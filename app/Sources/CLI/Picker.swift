import DASCore
import Foundation

enum Picker {
    private static let exitID = "exit"

    static func run(_ runtime: Runtime) throws -> Int32 {
        RawTerminal.enterRawMode()
        defer { RawTerminal.restore() }
        return try chooseCategory(runtime)
    }

    private static func chooseCategory(_ runtime: Runtime) throws -> Int32 {
        let style = runtime.style
        var selected = 0
        var search = ""
        var searching = false
        var message: String?
        var statuses: [String: CategoryStatus] = [:]

        func status(of category: AppCategory) -> CategoryStatus {
            if let known = statuses[category.id] { return known }
            let built = runtime.status(of: category)
            statuses[category.id] = built
            return built
        }

        while true {
            let rows = CategoryCatalog.all.map { category in
                let current = status(of: category)
                return Row(
                    label: category.name,
                    value: current.primaryApp?.name ?? style.dim("None"),
                    trailing: current.isMixed ? style.yellow("Mixed") : "",
                    id: category.id
                )
            }
            var shown = matchesPreferringNames(rows, search.lowercased())
            shown.append(Row(label: style.dim("Exit"), id: exitID))
            selected = min(selected, shown.count - 1)

            draw(
                Frame(
                    title: "das  \(style.dim("· Default App Switcher"))",
                    subtitle: AppMetadata.description,
                    isTopLevel: true,
                    rows: shown,
                    selected: selected,
                    search: search,
                    searching: searching,
                    status: message
                ), style: style)

            switch RawTerminal.readKey(searching: searching) {
            case .up:
                selected = moveSelection(selected: selected, from: .up, count: shown.count)
                message = nil
            case .down:
                selected = moveSelection(selected: selected, from: .down, count: shown.count)
                message = nil
            case .search:
                searching = true
            case .character(let character):
                search.append(character)
            case .backspace:
                if searching, !search.isEmpty { search.removeLast() }
            case .back:
                if searching {
                    searching = false
                    search = ""
                } else if !search.isEmpty {
                    search = ""
                } else {
                    return 0
                }
            case .enter:
                if searching {
                    searching = false
                    break
                }
                guard !shown.isEmpty else { break }
                if shown[selected].id == exitID { return 0 }
                guard let category = CategoryCatalog.builtin(id: shown[selected].id) else { break }
                switch try chooseAppFor(category, runtime: runtime, status: status(of: category)) {
                case .assigned(let outcome):
                    statuses.removeValue(forKey: category.id)
                    message = outcome
                case .back:
                    break
                case .quit:
                    return 0
                }
            case .quit:
                return 0
            case .other:
                break
            }
        }
    }

    private enum AppPick {
        case assigned(String)
        case back
        case quit
    }

    private static func chooseAppFor(
        _ category: AppCategory,
        runtime: Runtime,
        status initial: CategoryStatus
    ) throws -> AppPick {
        let style = runtime.style
        var status = initial
        var selected = status.apps.firstIndex { $0.ownsPrimary } ?? 0
        var search = ""
        var searching = false

        while true {
            let rows = status.apps.map { app in
                Row(
                    marker: AppStatusText.marker(app, style: style),
                    label: app.app.name,
                    value: AppStatusText.summary(
                        app, total: status.targets.count, style: style),
                    id: app.app.bundleIdentifier
                )
            }
            let shown = matchesPreferringNames(rows, search.lowercased())
            selected = shown.isEmpty ? 0 : min(selected, shown.count - 1)

            draw(
                Frame(
                    title:
                        "das \(style.dim("›")) \(category.name)  \(style.dim("· \(status.targets.count) \(status.targets.count == 1 ? "type" : "types")"))",
                    rows: shown,
                    selected: selected,
                    search: search,
                    searching: searching,
                    status: nil
                ), style: style)

            switch RawTerminal.readKey(searching: searching) {
            case .up:
                selected = moveSelection(selected: selected, from: .up, count: shown.count)
            case .down:
                selected = moveSelection(selected: selected, from: .down, count: shown.count)
            case .search:
                searching = true
            case .character(let character):
                search.append(character)
            case .backspace:
                if searching, !search.isEmpty { search.removeLast() }
            case .back:
                if searching {
                    searching = false
                    search = ""
                } else if !search.isEmpty {
                    search = ""
                } else {
                    return .back
                }
            case .enter:
                if searching {
                    searching = false
                    break
                }
                guard !shown.isEmpty,
                    let chosen = status.apps.first(where: {
                        $0.app.bundleIdentifier == shown[selected].id
                    })
                else { break }
                return .assigned(
                    makeDefault(
                        chosen.app, in: category, status: &status, runtime: runtime,
                        rows: shown, selected: selected, search: search))
            case .quit:
                return .quit
            case .other:
                break
            }
        }
    }

    private static func makeDefault(
        _ app: AppInfo,
        in category: AppCategory,
        status: inout CategoryStatus,
        runtime: Runtime,
        rows: [Row],
        selected: Int,
        search: String
    ) -> String {
        let style = runtime.style

        func waitingFrame(_ message: String) {
            draw(
                Frame(
                    title: "das \(style.dim("›")) \(category.name)",
                    rows: rows, selected: selected,
                    search: search, searching: false,
                    status: message
                ), style: style)
        }

        waitingFrame(style.dim("Setting \(app.name) as the default for \(category.name)..."))

        do {
            let (response, skipped) = try runtime.performAssignment(
                status: status, app: app,
                onSlow: {
                    waitingFrame(
                        style.yellow("Check for a macOS confirmation dialog."))
                }
            )
            status = runtime.status(of: category)

            let applied = response.succeeded.count
            let typeCount = "\(applied) \(applied == 1 ? "type" : "types")"
            if response.wasCancelled {
                return style.yellow(
                    "Cancelled. \(typeCount) changed; check the current defaults."
                )
            }
            guard response.failed.isEmpty else {
                return style.yellow(
                    "◐ \(app.name) set for \(response.succeeded.count)/\(response.outcomes.count) of \(category.name)"
                )
            }
            var line = style.green("✓ \(app.name) is now the default for \(category.name).")
            if !skipped.isEmpty {
                line += style.dim(
                    "  (skipped \(skipped.count) type\(skipped.count == 1 ? "" : "s") it cannot open)"
                )
            }
            return line
        } catch let error as DASError {
            let firstLine =
                stripANSI(error.description).split(separator: "\n").first.map(String.init)
                ?? "Assignment failed."
            return style.red("✗ ") + firstLine
        } catch {
            return style.red("✗ ") + error.localizedDescription
        }
    }

    private static func draw(_ frame: Frame, style: Style) {
        let (height, width) = RawTerminal.size
        RawTerminal.emit(Screen.render(frame, style: style, height: height, width: width))
    }

    private static func matchesPreferringNames(_ rows: [Row], _ needle: String) -> [Row] {
        guard !needle.isEmpty else { return rows }
        var byName: [Row] = []
        var byIdentifier: [Row] = []
        for row in rows where row.searchText.contains(needle) {
            if row.label.lowercased().contains(needle) {
                byName.append(row)
            } else {
                byIdentifier.append(row)
            }
        }
        return byName + byIdentifier
    }

    private static func moveSelection(selected: Int, from key: Key, count: Int) -> Int {
        guard count > 0 else { return 0 }
        switch key {
        case .up: return selected == 0 ? count - 1 : selected - 1
        case .down: return (selected + 1) % count
        default: return selected
        }
    }
}
