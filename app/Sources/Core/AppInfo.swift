import Foundation

package struct AppInfo: Codable, Hashable, Sendable {
    package let bundleIdentifier: String
    package let name: String
    package let url: URL
    package let version: String?

    package init(bundleIdentifier: String, name: String, url: URL, version: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.url = url
        self.version = version
    }
}
