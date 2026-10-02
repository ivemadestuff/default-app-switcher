import Foundation

package enum CategoryCatalog {
    package static let browser = AppCategory(
        id: "browser",
        name: "Browser",
        summary: "Web links and HTML files",
        targets: [
            .scheme("http", primary: true),
            .uti("public.html"),
        ]
    )

    package static let codeEditor = AppCategory(
        id: "code-editor",
        name: "Code Editor",
        summary: "Source files",
        targets: [
            .uti("public.python-script", primary: true),
            .uti("public.shell-script"),
            .uti("com.netscape.javascript-source"),
            .uti("public.json"),
            .uti("public.yaml"),
            .uti("net.daringfireball.markdown"),
        ]
    )

    package static let mail = AppCategory(
        id: "mail",
        name: "Mail",
        summary: "mailto: links",
        targets: [.scheme("mailto", primary: true)]
    )

    package static let text = AppCategory(
        id: "text",
        name: "Plain Text",
        summary: "Plain text files",
        targets: [.uti("public.plain-text", primary: true)]
    )

    package static let all: [AppCategory] = [browser, codeEditor, mail, text]

    package static func builtin(id: String) -> AppCategory? {
        all.first { $0.id == id }
    }
}
