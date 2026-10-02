import Foundation

package struct HandlerTarget: Codable, Hashable, Sendable {
    package enum Kind: String, Codable, Sendable {
        case uti
        case scheme
    }

    package let kind: Kind
    package let value: String
    package let isPrimary: Bool

    package init(kind: Kind, value: String, isPrimary: Bool = false) {
        self.kind = kind
        self.value = value
        self.isPrimary = isPrimary
    }

    package static func uti(_ value: String, primary: Bool = false) -> HandlerTarget {
        HandlerTarget(kind: .uti, value: value, isPrimary: primary)
    }

    package static func scheme(_ value: String, primary: Bool = false) -> HandlerTarget {
        HandlerTarget(kind: .scheme, value: value, isPrimary: primary)
    }

    package var label: String {
        switch kind {
        case .uti: return value
        case .scheme: return "\(value)://"
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, value, isPrimary }

    package init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        value = try c.decode(String.self, forKey: .value)
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    }
}
