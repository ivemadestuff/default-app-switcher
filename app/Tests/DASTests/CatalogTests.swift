import DASCLI
import DASCore
import Foundation

func runCatalogTests(_ t: TestRunner) {
    t.suite("catalog") { t in
        let ids = CategoryCatalog.all.map(\.id)
        t.equal(Set(ids).count, ids.count, "category ids must be unique")

        for category in CategoryCatalog.all {
            t.expect(!category.targets.isEmpty, "\(category.id) has no targets")
            let primaries = category.targets.filter(\.isPrimary)
            t.equal(primaries.count, 1, "\(category.id) must declare exactly one primary target")
            t.expect(!category.name.isEmpty, "\(category.id) has no display name")
            t.expect(!category.summary.isEmpty, "\(category.id) has no summary")

            let values = category.targets.map { "\($0.kind):\($0.value)" }
            t.equal(Set(values).count, values.count, "\(category.id) repeats a target")
        }

        let editorTargets = CategoryCatalog.codeEditor.targets.map(\.value)
        t.expect(
            !editorTargets.contains("public.source-code"),
            "code-editor must not include the source-code supertype")
        t.expect(
            !editorTargets.contains("public.script"),
            "code-editor must not include the script supertype")
        t.equal(
            CategoryCatalog.codeEditor.primaryTarget.value, "public.python-script",
            "code-editor reports its owner through a type editors actually declare")

        let browserTargets = CategoryCatalog.browser.targets.map(\.value)
        t.expect(!browserTargets.contains("https"), "browser must not try to assign https")
        t.equal(
            CategoryCatalog.browser.primaryTarget.value, "http", "browser is reached through http")

        for category in CategoryCatalog.all {
            t.expect(
                category.targets.count <= 8,
                "\(category.id) has \(category.targets.count) targets — keep categories small")
        }
    }

    t.suite("handler-target") { t in
        t.equal(HandlerTarget.scheme("https").label, "https://", "scheme label")
        t.equal(HandlerTarget.uti("public.html").label, "public.html", "uti label")
        t.expect(HandlerTarget.uti("public.html").isResolvable, "public.html should resolve")
        t.expect(
            !HandlerTarget.uti("com.example.definitely-not-real-uti").isResolvable,
            "bogus UTI must not resolve")
        t.expect(HandlerTarget.scheme("https").probeURL != nil, "scheme needs a probe URL")

        let json = Data(#"{"kind":"uti","value":"public.html"}"#.utf8)
        let decoded = try JSONDecoder().decode(HandlerTarget.self, from: json)
        t.expect(!decoded.isPrimary, "isPrimary should default to false")
        t.equal(decoded.value, "public.html", "decoded value")
    }

    t.suite("app-category") { t in
        let withoutPrimary = AppCategory(
            id: "x", name: "X", summary: "s",
            targets: [.uti("public.html"), .uti("public.json")]
        )
        t.equal(withoutPrimary.primaryTarget.value, "public.html", "falls back to the first target")

        let withPrimary = AppCategory(
            id: "y", name: "Y", summary: "s",
            targets: [.uti("public.html"), .uti("public.json", primary: true)]
        )
        t.equal(withPrimary.primaryTarget.value, "public.json", "honours the primary flag")

        let mixed = AppCategory(
            id: "z", name: "Z", summary: "s",
            targets: [.uti("public.html", primary: true), .uti("com.example.nope")]
        )
        t.equal(mixed.targets.filter(\.isResolvable).count, 1, "unknown types are filtered out")
    }
}
