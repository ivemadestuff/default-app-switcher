import Foundation

package struct HelperRequest: Codable, Sendable {
    package var version: Int
    package var applicationPath: String
    package var targets: [HandlerTarget]
    package var responsePath: String
    package var budget: Double

    package init(
        applicationPath: String, targets: [HandlerTarget], responsePath: String, budget: Double,
        version: Int = 1
    ) {
        self.version = version
        self.applicationPath = applicationPath
        self.targets = targets
        self.responsePath = responsePath
        self.budget = budget
    }
}

package struct HelperResponse: Codable, Sendable {
    package struct Outcome: Codable, Sendable, Equatable {
        package let target: HandlerTarget
        package let ok: Bool
        package let errorCode: Int?
        package let errorMessage: String?
        package let cancelled: Bool

        package init(
            target: HandlerTarget, ok: Bool, errorCode: Int? = nil, errorMessage: String? = nil,
            cancelled: Bool = false
        ) {
            self.target = target
            self.ok = ok
            self.errorCode = errorCode
            self.errorMessage = errorMessage
            self.cancelled = cancelled
        }
    }

    package var version: Int
    package var outcomes: [Outcome]
    package var helperError: String?

    package init(outcomes: [Outcome], helperError: String? = nil, version: Int = 1) {
        self.version = version
        self.outcomes = outcomes
        self.helperError = helperError
    }

    package var succeeded: [Outcome] { outcomes.filter(\.ok) }
    package var failed: [Outcome] { outcomes.filter { !$0.ok } }
    package var wasCancelled: Bool { outcomes.contains(where: \.cancelled) }

    package static func parse(_ data: Data) throws -> HelperResponse {
        let response: HelperResponse
        do {
            response = try JSONDecoder().decode(HelperResponse.self, from: data)
        } catch {
            throw DASError.helperFailed(
                "Could not read the response: \(error.localizedDescription)")
        }
        guard response.version == 1 else {
            throw DASError.helperFailed("Unsupported response version: \(response.version).")
        }
        if let error = response.helperError {
            throw DASError.helperFailed(error)
        }
        return response
    }
}

package let kDASUserCancelledCode = -128
