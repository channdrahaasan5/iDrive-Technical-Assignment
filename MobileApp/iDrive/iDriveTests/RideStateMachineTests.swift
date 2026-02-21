import XCTest
@testable import iDrive

final class RideStateMachineTests: XCTestCase {

    func testRequested_to_Accepted_isAllowed() {
        XCTAssertNoThrow(try RideStateMachine.validateTransition(
            from: "REQUESTED", to: "ACCEPTED",
            rideDriverId: nil, actorDriverId: "driver1"))
    }

    func testRequested_to_Completed_throwsInvalidTransition() {
        XCTAssertThrowsError(try RideStateMachine.validateTransition(
            from: "REQUESTED", to: "COMPLETED",
            rideDriverId: nil, actorDriverId: "driver1")) { error in
            guard case RideStateError.invalidTransition(let from, let to) = error else {
                return XCTFail("Expected invalidTransition but got \(error)")
            }
            XCTAssertEqual(from, "REQUESTED")
            XCTAssertEqual(to, "COMPLETED")
        }
    }

    func testAccepted_to_Started_byAssignedDriver_isAllowed() {
        XCTAssertNoThrow(try RideStateMachine.validateTransition(
            from: "ACCEPTED", to: "STARTED",
            rideDriverId: "d1", actorDriverId: "d1"))
    }

    func testAccepted_to_Started_byDifferentDriver_throwsWrongDriver() {
        XCTAssertThrowsError(try RideStateMachine.validateTransition(
            from: "ACCEPTED", to: "STARTED",
            rideDriverId: "d1", actorDriverId: "d2")) { error in
            guard case RideStateError.wrongDriver = error else {
                return XCTFail("Expected wrongDriver but got \(error)")
            }
        }
    }

    func testAccepted_to_Cancelled_byAssignedDriver_isAllowed() {
        XCTAssertNoThrow(try RideStateMachine.validateTransition(
            from: "ACCEPTED", to: "CANCELLED",
            rideDriverId: "d1", actorDriverId: "d1"))
    }

    func testSameState_isIdempotent() {
        XCTAssertNoThrow(try RideStateMachine.validateTransition(
            from: "STARTED", to: "STARTED",
            rideDriverId: "d1", actorDriverId: "d2"))
    }

    func testRequested_to_Cancelled_isAllowed() {
        // canceling a REQUESTED ride is allowed (no driver required)
        XCTAssertNoThrow(try RideStateMachine.validateTransition(
            from: "REQUESTED", to: "CANCELLED",
            rideDriverId: nil, actorDriverId: nil))
    }
}

