import AppKit
import DASCore
import Foundation
import UniformTypeIdentifiers

package protocol DefaultsReading: Sendable {
    func read(_ category: AppCategory) -> [TargetDefaults]
}

package struct SystemDefaultsReader: DefaultsReading {
    package init() {}

    package func read(_ category: AppCategory) -> [TargetDefaults] {
        category.targets.filter(\.isResolvable).map { target in
            TargetDefaults(
                target: target, defaultApp: defaultApp(for: target),
                candidates: candidates(for: target))
        }
    }

    private func defaultApp(for target: HandlerTarget) -> AppInfo? {
        let workspace = NSWorkspace.shared
        let url: URL?
        switch target.kind {
        case .uti:
            guard let type = target.utType else { return nil }
            url = workspace.urlForApplication(toOpen: type)
        case .scheme:
            guard let probe = target.probeURL else { return nil }
            url = workspace.urlForApplication(toOpen: probe)
        }
        return url.flatMap(AppInfo.init(bundleURL:))
    }

    private func candidates(for target: HandlerTarget) -> [AppInfo] {
        let workspace = NSWorkspace.shared
        let urls: [URL]
        switch target.kind {
        case .uti:
            guard let type = target.utType else { return [] }
            urls = workspace.urlsForApplications(toOpen: type)
        case .scheme:
            guard let probe = target.probeURL else { return [] }
            urls = workspace.urlsForApplications(toOpen: probe)
        }
        return urls.compactMap(AppInfo.init(bundleURL:))
    }
}

extension HandlerTarget {
    package var utType: UTType? {
        kind == .uti ? UTType(value) : nil
    }

    package var probeURL: URL? {
        kind == .scheme ? URL(string: "\(value)://default-app-switcher.invalid") : nil
    }

    package var isResolvable: Bool {
        switch kind {
        case .uti: return utType != nil
        case .scheme: return probeURL != nil
        }
    }
}

extension AppInfo {
    package init?(bundleURL url: URL) {
        guard let bundle = Bundle(url: url),
            let identifier = bundle.bundleIdentifier
        else { return nil }
        let fileName = url.deletingPathExtension().lastPathComponent
        let name =
            fileName.isEmpty
            ? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Unknown")
            : fileName
        self.init(
            bundleIdentifier: identifier, name: name, url: url,
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }
}
