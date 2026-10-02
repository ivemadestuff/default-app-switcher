import DASCore
import Foundation

let t = TestRunner()
runCatalogTests(t)
runStatusTests(t)
runPlanningTests(t)
runPlumbingTests(t)
runCLITests(t)
exit(t.finish())
