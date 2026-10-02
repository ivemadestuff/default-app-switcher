import DASCore
import Foundation

package enum HelperLocator {
    private static let bundleName = "das-helper.app"

    package static func executableDirectory(path: String? = Bundle.main.executablePath) -> URL? {
        guard let path else { return nil }
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().deletingLastPathComponent()
    }

    package static func searchPaths(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableDirectory: URL? = executableDirectory()
    ) -> [URL] {
        var paths: [URL] = []
        if let override = environment["DAS_HELPER_PATH"], !override.isEmpty {
            paths.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath))
        }
        if let directory = executableDirectory {
            paths.append(directory.appendingPathComponent(bundleName))
        }
        return paths
    }

    package static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableDirectory: URL? = executableDirectory()
    ) throws -> URL {
        let candidates = searchPaths(
            environment: environment, executableDirectory: executableDirectory)
        for path in candidates
        where FileManager.default.isExecutableFile(
            atPath: path.appendingPathComponent("Contents/MacOS/das-helper").path)
        {
            return path
        }
        throw DASError.helperMissing(searched: candidates.map(\.path))
    }
}
