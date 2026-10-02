import Foundation

package struct AppCategory: Codable, Hashable, Sendable, Identifiable {
    package let id: String
    package let name: String
    package let summary: String
    package let targets: [HandlerTarget]

    package init(id: String, name: String, summary: String, targets: [HandlerTarget]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.targets = targets
    }

    package var primaryTarget: HandlerTarget {
        targets.first(where: \.isPrimary) ?? targets[0]
    }

    private enum CodingKeys: String, CodingKey { case id, name, summary, targets }

    package init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        targets = try c.decode([HandlerTarget].self, forKey: .targets)
    }
}
