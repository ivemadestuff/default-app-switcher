import DASCore

enum Help {
    static func text(_ style: Style) -> String {
        let b = style.bold
        let d = style.dim
        return """
            \(b("das")) — \(AppMetadata.description)

            \(b("Usage"))
              das            \(d("Default App Switcher"))
              das --help     \(d("Help"))
              das --version  \(d("Version"))

            \(b("Notes"))
              das changes defaults only for file types and links the selected app can open.
              das reports skipped types. macOS may ask you to confirm a change.
            """
    }
}
