import DASCore
import Foundation

package enum CLI {
    package static func run() -> Int32 {
        run(
            arguments: Array(CommandLine.arguments.dropFirst()),
            runtime: Runtime(
                reader: SystemDefaultsReader(), style: Style.detect()
            ))
    }

    package static func run(arguments: [String], runtime: Runtime) -> Int32 {
        let style = runtime.style
        do {
            switch arguments {
            case []:
                guard runtime.isInteractive else {
                    throw DASError.usage("Run `das` in an interactive terminal. Use `das --help`.")
                }
                return try Picker.run(runtime)
            case ["--help"], ["-h"], ["help"]:
                runtime.output.stdout(Help.text(style))
                return 0
            case ["--version"], ["version"]:
                runtime.output.stdout(AppMetadata.version)
                return 0
            default:
                throw DASError.usage("Invalid arguments. Use `das --help`.")
            }
        } catch let error as DASError {
            runtime.output.stderr("das: \(error.description)")
            return error.exitCode
        } catch {
            runtime.output.stderr("das: \(error.localizedDescription)")
            return 1
        }
    }
}
