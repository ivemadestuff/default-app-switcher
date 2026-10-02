import DASCLI
import DASCore
import Foundation

func runPlumbingTests(_ t: TestRunner) {
    t.suite("text-layout") { t in
        t.equal(visibleLength("plain"), 5, "plain text measures its characters")
        t.equal(visibleLength("\u{1B}[2mdim\u{1B}[0m"), 3, "escape sequences occupy no columns")
        t.equal(
            visibleLength("\u{1B}[7m\u{1B}[2mboth\u{1B}[0m"), 4, "consecutive sequences are skipped"
        )
        t.equal(visibleLength(""), 0, "empty string measures zero")
        t.equal(
            visibleLength("\u{1B}[38;5;120mcolour\u{1B}[0m"), 6,
            "multi-parameter sequences are skipped")

        t.equal(stripANSI("\u{1B}[2mdim\u{1B}[0m"), "dim", "stripping leaves no fragments")
        t.equal(stripANSI("a\u{1B}[31mb\u{1B}[0mc"), "abc", "stripping keeps surrounding text")
        t.equal(stripANSI("no codes"), "no codes", "text without codes is unchanged")
        t.expect(!stripANSI("\u{1B}[2mx\u{1B}[0m").contains("m"), "no stray final bytes survive")

        t.equal(pad("ab", 5), "ab   ", "pad fills to width")
        t.equal(pad("abcdef", 3), "abcdef", "pad never truncates")
        t.equal(
            visibleLength(pad("\u{1B}[2mab\u{1B}[0m", 5)), 5, "styled text pads to visible width")

        t.equal(trimTrailing("a   "), "a", "trailing spaces are dropped")
        t.equal(trimTrailing("a"), "a", "text without trailing spaces is unchanged")
        t.equal(trimTrailing("   "), "", "an all-space string collapses")
    }

    t.suite("errors") { t in
        t.equal(DASError.usage("x").exitCode, 2, "usage errors exit 2")
        t.equal(DASError.cancelled.exitCode, 4, "cancellation exits 4")
        t.equal(DASError.timedOut(seconds: 1).exitCode, 5, "timeout exits 5")
        t.equal(DASError.helperFailed("x").exitCode, 1, "other failures exit 1")
    }
}
