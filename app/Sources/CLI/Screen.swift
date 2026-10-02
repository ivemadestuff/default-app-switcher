import DASCore
import Foundation

struct Row {
    var marker: String = " "
    var label: String
    var value: String = ""
    var trailing: String = ""
    var id: String = ""

    var searchText: String { "\(label) \(value) \(id)".lowercased() }
}

struct Frame {
    var title: String
    var subtitle: String = ""
    var isTopLevel: Bool = false
    var rows: [Row]
    var selected: Int
    var search: String
    var searching: Bool
    var status: String?
}

enum Screen {
    private static let gutter = "  "
    private static let contentIndent = "    "
    private static let wordmark = [
        "┌────┐  ┌────┐  ┌────┐",
        "│    │  │    │  │     ",
        "│    │  ├────┤  └────┐",
        "│    │  │    │       │",
        "└────┘  ┴    ┴  └────┘",
    ]

    static func render(_ frame: Frame, style: Style, height: Int, width: Int) -> String {
        let showWordmark = frame.isTopLevel && height >= 22
        var lines = headerLines(frame, style: style, showWordmark: showWordmark)

        let attached = frame.status == nil ? 0 : 2
        let capacity = max(3, height - lines.count - attached)
        lines += listLines(frame, capacity: capacity, width: width, style: style)

        if let status = frame.status {
            lines.append("")
            lines.append(contentIndent + status)
        }
        return "\u{1B}[H\u{1B}[2J" + lines.joined(separator: "\n")
    }

    private static func headerLines(_ frame: Frame, style: Style, showWordmark: Bool) -> [String] {
        var lines = [""]
        if showWordmark {
            for line in wordmark {
                lines.append(contentIndent + style.bold(line))
            }
            if !frame.subtitle.isEmpty {
                lines.append(contentIndent + style.dim(frame.subtitle))
            }
        } else {
            lines.append(contentIndent + style.bold(frame.title))
        }

        let filtering = frame.searching || !frame.search.isEmpty
        if filtering {
            let caret = frame.searching ? style.bold("▏") : ""
            let text = frame.search.isEmpty ? "Filter" : frame.search
            lines.append(contentIndent + style.dim("⌕ \(text)") + caret)
        }
        lines.append("")
        return lines
    }

    private static func listLines(
        _ frame: Frame,
        capacity: Int,
        width: Int,
        style: Style
    ) -> [String] {
        guard !frame.rows.isEmpty else {
            return [contentIndent + style.dim("No matches")]
        }

        let inner = frame.rows.count > capacity ? max(1, capacity - 2) : capacity
        var first = 0
        if frame.rows.count > inner {
            first = min(max(0, frame.selected - inner / 2), frame.rows.count - inner)
        }
        let last = min(frame.rows.count, first + inner)

        let contents = layout(frame.rows, width: width)
        let barWidth = min(
            max(0, width - gutter.count), (contents.map(visibleLength).max() ?? 0) + 2)

        var lines: [String] = []
        if first > 0 {
            lines.append(contentIndent + style.dim("↑ \(first) above"))
        }
        for index in first..<last {
            let padding = String(
                repeating: " ", count: max(0, barWidth - visibleLength(contents[index])))
            let body = contents[index] + padding
            if index == frame.selected {
                lines.append(style.inverse(stripANSI(body)))
            } else {
                lines.append(body)
            }
        }
        if last < frame.rows.count {
            lines.append(contentIndent + style.dim("↓ \(frame.rows.count - last) more below"))
        }
        return lines
    }

    private static func layout(_ rows: [Row], width: Int) -> [String] {
        let labelWidth = min(rows.map(\.label.count).max() ?? 0, max(12, width / 3))
        let valueWidth =
            rows.filter { !$0.trailing.isEmpty }
            .map { visibleLength($0.value) }.max() ?? 0
        return rows.map { row in
            var line = "\(gutter)\(row.marker) \(pad(row.label, labelWidth + 2))"
            line += row.trailing.isEmpty ? row.value : pad(row.value, valueWidth + 2)
            return line + row.trailing
        }
    }
}
