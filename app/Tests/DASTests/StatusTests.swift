import DASCore
import Foundation

func runStatusTests(_ t: TestRunner) {
    t.suite("category-status") { t in
        let category = AppCategory(
            id: "test", name: "Test", summary: "s",
            targets: [
                .uti("public.html", primary: true),
                .uti("public.json"),
                .uti("public.plain-text"),
            ]
        )

        let sweep = StubReader(
            defaultAppsByTarget: [
                "public.html": "com.a", "public.json": "com.a", "public.plain-text": "com.a",
            ],
            candidatesByTarget: [
                "public.html": ["com.a", "com.b"],
                "public.json": ["com.a", "com.b"],
                "public.plain-text": ["com.a"],
            ]
        )
        let sweptStatus = CategoryStatus.build(category: category, defaults: sweep.read(category))
        t.equal(sweptStatus.primaryApp?.bundleIdentifier, "com.a", "primary handler is reported")
        t.equal(sweptStatus.apps.first?.state, .complete, "owning every target is .complete")
        t.expect(!sweptStatus.isMixed, "a clean sweep is not mixed")
        t.equal(sweptStatus.apps.count, 2, "both candidates are listed")

        let other = sweptStatus.apps.first { $0.app.bundleIdentifier == "com.b" }
        t.equal(other?.state, DefaultState.none, "a non-default candidate is .none")
        t.equal(other?.supportedTargets.count, 2, "supported targets are counted")

        let split = StubReader(
            defaultAppsByTarget: [
                "public.html": "com.a", "public.json": "com.b", "public.plain-text": "com.b",
            ],
            candidatesByTarget: [
                "public.html": ["com.a", "com.b"],
                "public.json": ["com.a", "com.b"],
                "public.plain-text": ["com.a", "com.b"],
            ]
        )
        let splitStatus = CategoryStatus.build(category: category, defaults: split.read(category))
        t.expect(splitStatus.isMixed, "a split category is mixed")
        t.equal(
            splitStatus.apps.first?.app.bundleIdentifier, "com.a", "the primary owner sorts first")
        t.equal(
            splitStatus.apps.first?.state, .partial(active: 1, total: 3),
            "partial state counts targets")
        t.equal(
            splitStatus.apps.first?.ownsPrimary, true, "ownsPrimary is set for the primary handler")

        let second = splitStatus.apps.first { $0.app.bundleIdentifier == "com.b" }
        t.equal(second?.state, .partial(active: 2, total: 3), "the other owner is partial too")
        t.equal(second?.ownsPrimary, false, "com.b does not own the primary target")

        let empty = CategoryStatus.build(
            category: category,
            defaults: StubReader(
                defaultAppsByTarget: [:], candidatesByTarget: ["public.html": ["com.a"]]
            ).read(
                category))
        t.expect(empty.primaryApp == nil, "no handler means no primary app")
        t.equal(empty.apps.first?.state, DefaultState.none, "unassigned candidate is .none")
        t.expect(!empty.isMixed, "nothing assigned is not mixed")

        let ghost = CategoryStatus.build(
            category: category,
            defaults: StubReader(
                defaultAppsByTarget: ["public.html": "com.ghost"], candidatesByTarget: [:]
            ).read(
                category))
        t.equal(ghost.apps.count, 1, "the current handler is always listed")
        t.equal(ghost.apps.first?.activeTargets.count, 1, "its active target is recorded")
    }

    t.suite("supported-targets") { t in
        let category = AppCategory(
            id: "test", name: "Test", summary: "s",
            targets: [
                .uti("public.html", primary: true),
                .uti("public.json"),
                .uti("public.plain-text"),
            ]
        )
        let reader = StubReader(
            defaultAppsByTarget: ["public.html": "com.a"],
            candidatesByTarget: [
                "public.html": ["com.a", "com.b"],
                "public.json": ["com.a"],
                "public.plain-text": ["com.a"],
            ]
        )
        let status = CategoryStatus.build(category: category, defaults: reader.read(category))

        let a = StubReader.app("com.a", "A")
        t.equal(
            status.supportedTargets(for: a).count, 3,
            "a full candidate supports every target")

        let b = StubReader.app("com.b", "B")
        t.equal(
            status.supportedTargets(for: b).count, 1,
            "a partial candidate supports only its own")

        let stranger = StubReader.app("com.calculator", "Calculator")
        t.equal(
            status.supportedTargets(for: stranger).count, 0,
            "an app registered for nothing supports nothing")
        t.expect(
            status.supportedTargets(for: stranger).isEmpty,
            "an unknown app must never fall back to the full target set")

        let duplicated = CategoryStatus.build(
            category: category,
            defaults: StubReader(
                defaultAppsByTarget: [:],
                candidatesByTarget: ["public.html": ["com.a", "com.a"]]
            ).read(category))
        t.equal(
            duplicated.apps.first?.supportedTargets.count, 1,
            "the same app listed twice for one type still supports one type")
    }

    t.suite("helper-protocol") { t in
        let request = HelperRequest(
            applicationPath: "/Applications/Safari.app",
            targets: [.scheme("https", primary: true), .uti("public.html")],
            responsePath: "/tmp/out.json",
            budget: 115
        )
        let decodedRequest = try JSONDecoder().decode(
            HelperRequest.self, from: JSONEncoder().encode(request))
        t.equal(decodedRequest.applicationPath, request.applicationPath, "request path round trips")
        t.equal(decodedRequest.targets.count, 2, "request targets round trip")
        t.equal(decodedRequest.version, 1, "request carries a version")
        t.equal(decodedRequest.budget, 115, "request carries the helper's time budget")

        let response = HelperResponse(outcomes: [
            .init(target: .scheme("https"), ok: true),
            .init(
                target: .uti("public.html"), ok: false, errorCode: -128, errorMessage: "nope",
                cancelled: true),
        ])
        let decodedResponse = try JSONDecoder().decode(
            HelperResponse.self, from: JSONEncoder().encode(response))
        t.equal(decodedResponse.succeeded.count, 1, "succeeded filters outcomes")
        t.equal(decodedResponse.failed.count, 1, "failed filters outcomes")
        t.expect(decodedResponse.wasCancelled, "cancellation is visible on the response")
        t.equal(kDASUserCancelledCode, -128, "userCanceledErr constant")

        let parsed = try HelperResponse.parse(
            JSONEncoder().encode(
                HelperResponse(outcomes: [
                    .init(target: .uti("public.html"), ok: true)
                ])))
        t.equal(parsed.succeeded.count, 1, "a well-formed response parses")

        do {
            _ = try HelperResponse.parse(Data("{".utf8))
            t.expect(false, "invalid JSON must not parse")
        } catch let error as DASError {
            if case .helperFailed(let message) = error {
                t.expect(
                    message.contains("Could not read"), "decode failure is reported, not swallowed")
            } else {
                t.expect(false, "expected helperFailed, got \(error)")
            }
        }

        do {
            _ = try HelperResponse.parse(
                JSONEncoder().encode(HelperResponse(outcomes: [], helperError: "boom")))
            t.expect(false, "a helperError must not parse as success")
        } catch let error as DASError {
            if case .helperFailed(let message) = error {
                t.equal(message, "boom", "helperError becomes helperFailed")
            } else {
                t.expect(false, "expected helperFailed, got \(error)")
            }
        }
    }
}
