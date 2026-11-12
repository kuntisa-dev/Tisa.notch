//
//  HelperClientRequirementTests.swift
//  SMCKitTests
//

import Security
import XCTest
@testable import SMCKit

final class HelperClientRequirementTests: XCTestCase {
    func testTeamRequirementCompiles() throws {
        let text = try XCTUnwrap(HelperClientRequirement.teamPinned("PG4QURV7Y5"))
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString(text as CFString, [], &requirement), errSecSuccess)
        XCTAssertTrue(text.contains("PG4QURV7Y5"))
        XCTAssertTrue(text.contains("get-task-allow"))
    }

    func testTeamRequirementRejectsBadTeams() {
        for team in ["", "pg4quRV7Y5", "PG4QURV7Y", "PG4QURV7Y55", "PG4QURV7\"5", "PG4 URV7Y5"] {
            XCTAssertNil(HelperClientRequirement.teamPinned(team), team)
        }
    }

    func testHashRequirementStillWorks() throws {
        let text = try XCTUnwrap(HelperClientRequirement.hashPinned(String(repeating: "a", count: 40)))
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString(text as CFString, [], &requirement), errSecSuccess)
        XCTAssertNil(HelperClientRequirement.hashPinned("xyz"))
    }
}
