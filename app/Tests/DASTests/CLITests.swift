import DASCLI
import DASCore
import Foundation

func runCLITests(_ t: TestRunner) {
    t.suite("cli-output") { t in
        let reader = StubReader(
            defaultAppsByTarget: ["http": "com.Safari", "public.html": "com.Safari"],
            candidatesByTarget: ["http": ["com.Safari"], "public.html": ["com.Safari"]]
        )
        var stdout: [String] = []
        var stderr: [String] = []
        var assignments = 0
        var runtime = Runtime(reader: reader, style: Style(enabled: false))
        runtime.isInteractive = false
        runtime.output = CommandOutput(stdout: { stdout.append($0) }, stderr: { stderr.append($0) })
        runtime.assign = { _, targets, _ in
            assignments += 1
            return HelperResponse(outcomes: targets.map { .init(target: $0, ok: true) })
        }

        for argument in ["--help", "-h", "help"] {
            t.equal(CLI.run(arguments: [argument], runtime: runtime), 0, "help succeeds")
            let help = stdout.last ?? ""
            t.expect(help.contains(AppMetadata.description), "help uses the shared description")
            t.expect(help.contains("Default App Switcher"), "help documents the picker")
            t.expect(help.contains("das --version"), "help documents version")
            for removed in ["das get", "das set", "das list", "Exit codes:", "Examples", "error"] {
                t.expect(!help.contains(removed), "help omits \(removed)")
            }
        }
        for argument in ["--version", "version"] {
            t.equal(CLI.run(arguments: [argument], runtime: runtime), 0, "version succeeds")
            t.equal(stdout.last, AppMetadata.version, "version uses the release metadata")
        }
        t.expect(
            stdout.allSatisfy { !$0.contains("\u{1B}") }, "redirected output has no ANSI codes")
        t.equal(stderr.count, 0, "help and version do not write diagnostics")

        let invalidArguments = [
            ["get", "browser"], ["set", "browser", "Safari"], ["list", "browser"],
            ["ls", "browser"], ["--invalid"], ["unknown"], ["help", "extra"],
            ["version", "extra"], ["--help", "extra"], ["--version", "extra"],
            ["set", "browser", "Safari", "--help"], ["get", "browser", "--version"],
        ]
        let resultCount = stdout.count
        for arguments in invalidArguments {
            t.equal(
                CLI.run(arguments: arguments, runtime: runtime), 2, "unsupported arguments fail")
            t.expect(stderr.last?.contains("das --help") == true, "usage errors point to help")
        }
        t.equal(CLI.run(arguments: [], runtime: runtime), 2, "the picker requires a terminal")
        t.expect(
            stderr.last?.contains("interactive terminal") == true,
            "redirected invocation explains how to open the picker")
        t.equal(stdout.count, resultCount, "usage errors leave stdout empty")
        t.equal(stderr.count, invalidArguments.count + 1, "usage errors go to stderr")
        t.equal(assignments, 0, "CLI arguments never assign defaults")
    }

    t.suite("runtime-status") { t in
        let runtime = Runtime(
            reader: StubReader(
                defaultAppsByTarget: ["http": "com.Safari"],
                unavailableTargets: ["public.html"],
                candidatesByTarget: ["http": ["com.Safari"]]),
            style: Style(enabled: false))
        let status = runtime.status(of: CategoryCatalog.browser)
        t.equal(status.targets.map(\.value), ["http"], "the reader determines available types")
        t.equal(
            status.primaryApp?.bundleIdentifier, "com.Safari", "the snapshot supplies the default")
        t.equal(
            status.apps.first?.state, .complete, "unavailable types do not count against an app")
    }

    t.suite("picker-assignment") { t in
        let reader = StubReader(
            defaultAppsByTarget: ["http": "com.Safari"],
            candidatesByTarget: ["http": ["com.Safari"]]
        )
        var runtime = Runtime(reader: StubReader(), style: Style(enabled: false))
        var assignedTargets: [HandlerTarget] = []
        var assignments = 0
        var slowNotified = false
        runtime.assign = { app, targets, onSlow in
            assignments += 1
            t.equal(app.bundleIdentifier, "com.Safari", "the selected app reaches the helper")
            assignedTargets = targets
            onSlow?()
            return HelperResponse(outcomes: targets.map { .init(target: $0, ok: true) })
        }
        let category = CategoryCatalog.browser
        let status = CategoryStatus.build(category: category, defaults: reader.read(category))
        let result = try runtime.performAssignment(
            status: status, app: StubReader.app("com.Safari", "Safari"),
            onSlow: { slowNotified = true })
        t.equal(assignedTargets.map(\.value), ["http"], "only supported types reach the helper")
        t.equal(result.skipped.map(\.value), ["public.html"], "unsupported types are reported")
        t.equal(result.response.succeeded.count, 1, "the picker receives the helper result")
        t.expect(slowNotified, "the picker receives slow assignment notifications")
        do {
            _ = try runtime.performAssignment(
                status: status, app: StubReader.app("com.unknown", "Unknown"))
            t.expect(false, "an app outside the displayed candidates must be refused")
        } catch let error as DASError {
            if case .appCannotHandle = error {
                t.equal(assignments, 1, "a refused plan never reaches the helper")
            } else {
                t.expect(false, "expected appCannotHandle, got \(error)")
            }
        }
    }

    t.suite("app-bundle") { t in
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let appURL = root.appendingPathComponent("Visual Studio Code.app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = [
            "CFBundleIdentifier": "com.test.editor",
            "CFBundleName": "Code",
            "CFBundleShortVersionString": "1.2.3",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        let app = AppInfo(bundleURL: appURL)
        t.equal(
            app?.name, "Visual Studio Code", "bundle names match Finder rather than plist names")
        t.equal(app?.bundleIdentifier, "com.test.editor", "bundle identifiers are preserved")
        t.equal(app?.version, "1.2.3", "bundle versions are preserved")
        t.expect(
            AppInfo(bundleURL: root.appendingPathComponent("Missing.app")) == nil,
            "missing bundles are omitted")
    }

    t.suite("helper-response") { t in
        let invalid = try JSONEncoder().encode(HelperResponse(outcomes: [], version: 99))
        do {
            _ = try HelperResponse.parse(invalid)
            t.expect(false, "unsupported protocol versions must fail")
        } catch let error as DASError {
            t.expect(
                error.description.contains("99"),
                "protocol failures identify the incompatible version")
        }
        do {
            _ = try HelperResponse.parse(Data("broken".utf8))
            t.expect(false, "malformed responses must fail")
        } catch let error as DASError {
            t.expect(
                error.description.contains("Could not read"),
                "malformed responses retain decoding context")
        }
    }

    t.suite("helper-location") { t in
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        let directory = root.appendingPathComponent("release")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let adjacent = directory.appendingPathComponent("das-helper.app")
        let override = root.appendingPathComponent("custom/das-helper.app")
        let paths = HelperLocator.searchPaths(environment: [:], executableDirectory: directory)
        t.equal(
            paths.map(\.path), [adjacent.path], "only the adjacent helper is searched by default")
        t.equal(
            HelperLocator.searchPaths(
                environment: ["DAS_HELPER_PATH": ""], executableDirectory: directory
            ).map(\.path),
            paths.map(\.path), "an empty override uses the adjacent helper")

        let bare = directory.appendingPathComponent("das-helper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: bare)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bare.path)
        do {
            _ = try HelperLocator.locate(environment: [:], executableDirectory: directory)
            t.expect(false, "a bare helper must not be packaged at runtime")
        } catch DASError.helperMissing(let searched) {
            t.equal(searched, [adjacent.path], "missing helpers report the searched locations")
        }
        t.expect(!fm.fileExists(atPath: adjacent.path), "lookup does not create a helper bundle")

        func installHelper(at app: URL) throws {
            let executable = app.appendingPathComponent("Contents/MacOS/das-helper")
            try fm.createDirectory(
                at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: bare, to: executable)
        }

        try installHelper(at: adjacent)
        t.equal(
            try HelperLocator.locate(environment: [:], executableDirectory: directory).path,
            adjacent.path, "the installer layout resolves the adjacent helper")

        let environment = ["DAS_HELPER_PATH": override.path]
        t.equal(
            HelperLocator.searchPaths(environment: environment, executableDirectory: directory)
                .map(\.path),
            [override.path, adjacent.path], "the explicit override is searched first")
        t.equal(
            try HelperLocator.locate(environment: environment, executableDirectory: directory).path,
            adjacent.path, "an unavailable override falls back to the adjacent helper")
        try installHelper(at: override)
        t.equal(
            try HelperLocator.locate(environment: environment, executableDirectory: directory).path,
            override.path, "an executable override takes precedence")
        try fm.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: override.appendingPathComponent("Contents/MacOS/das-helper").path)
        t.equal(
            try HelperLocator.locate(environment: environment, executableDirectory: directory).path,
            adjacent.path, "a non-executable override is skipped")

        let binary = directory.appendingPathComponent("das")
        let current = root.appendingPathComponent("current")
        let command = root.appendingPathComponent("das")
        try Data().write(to: binary)
        try fm.createSymbolicLink(at: current, withDestinationURL: directory)
        try fm.createSymbolicLink(
            at: command, withDestinationURL: current.appendingPathComponent("das"))
        t.equal(
            HelperLocator.executableDirectory(path: command.path)?.path, directory.path,
            "the installed command resolves both links to the release directory")
    }
}
