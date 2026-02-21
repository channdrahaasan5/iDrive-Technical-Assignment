import Foundation

enum RideStateError: Error {
    case invalidTransition(from: String, to: String)
    case wrongDriver
}

struct RideStateMachine {
    // Allowed transitions
    static let allowed: [String: [String]] = [
        "IDLE": ["REQUESTED"],
        "REQUESTED": ["ACCEPTED", "CANCELLED"],
        "ACCEPTED": ["STARTED", "CANCELLED"],
        "STARTED": ["COMPLETED"],
        "COMPLETED": [],
        "CANCELLED": []
    ]

    static func validateTransition(from: String, to: String, rideDriverId: String?, actorDriverId: String?) throws {
        if from == to { return }
        let allowedTo = allowed[from] ?? []
        if !allowedTo.contains(to) {
            throw RideStateError.invalidTransition(from: from, to: to)
        }
        // start/complete must be by assigned driver
        if (to == "STARTED" || to == "COMPLETED") {
            if let assigned = rideDriverId, let actor = actorDriverId, assigned != actor {
                throw RideStateError.wrongDriver
            }
        }
        if to == "CANCELLED" && from == "ACCEPTED" {
            if let assigned = rideDriverId, let actor = actorDriverId, assigned != actor {
                throw RideStateError.wrongDriver
            }
        }
    }
}

