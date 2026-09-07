import XCTest
@testable import MiniDock

final class DevServiceShutdownTests: XCTestCase {

    func testEligibilityRejectsDifferentUser() {
        let service = DevServiceItem(
            name: "Nginx",
            port: 80,
            processName: "nginx",
            pid: 400,
            user: "root"
        )
        let eligibility = DevStackService.validateShutdownEligibility(
            service: service,
            currentUser: "m4",
            currentPid: 999
        )
        XCTAssertEqual(eligibility, .ineligibleUser(owner: "root", currentUser: "m4"))
    }

    func testEligibilityRejectsSystemPid() {
        let service = DevServiceItem(
            name: "Launchd",
            port: 80,
            processName: "launchd",
            pid: 1,
            user: "m4"
        )
        let eligibility = DevStackService.validateShutdownEligibility(
            service: service,
            currentUser: "m4",
            currentPid: 999
        )
        XCTAssertEqual(eligibility, .ineligibleSystemPid(pid: 1))
    }

    func testEligibilityRejectsMiniDockSelfPid() {
        let service = DevServiceItem(
            name: "MiniDock",
            port: 3000,
            processName: "MiniDock",
            pid: 999,
            user: "m4"
        )
        let eligibility = DevStackService.validateShutdownEligibility(
            service: service,
            currentUser: "m4",
            currentPid: 999
        )
        XCTAssertEqual(eligibility, .ineligibleSelfPid(pid: 999))
    }

    func testEligibilityRejectsInternalAndProtectedProcesses() {
        let protectedCommands = ["rapportd", "controlcenter", "dockerd", "finder", "language_server"]
        for cmd in protectedCommands {
            let service = DevServiceItem(
                name: cmd.capitalized,
                port: 5000,
                processName: cmd,
                pid: 1234,
                user: "m4"
            )
            let eligibility = DevStackService.validateShutdownEligibility(
                service: service,
                currentUser: "m4",
                currentPid: 999
            )
            if case .ineligibleProtectedProcess = eligibility {
                // Expected
            } else {
                XCTFail("Expected \(cmd) to be recognized as an ineligible protected process, got \(eligibility)")
            }
        }
    }

    func testEligibilityAcceptsValidSameUserDevService() {
        let service = DevServiceItem(
            name: "Node Dev",
            port: 3000,
            processName: "node",
            pid: 13676,
            user: "m4"
        )
        let eligibility = DevStackService.validateShutdownEligibility(
            service: service,
            currentUser: "m4",
            currentPid: 999
        )
        XCTAssertEqual(eligibility, .eligible)
    }

    func testListenerRevalidationSuccess() {
        let lsofFixture = """
        COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      13676   m4   23u  IPv6 0x12345678      0t0  TCP *:3000 (LISTEN)
        """
        let isValid = DevStackService.parseAndValidateListener(
            lsofOutput: lsofFixture,
            expectedPid: 13676,
            expectedPort: 3000,
            expectedProcessName: "node",
            expectedUser: "m4"
        )
        XCTAssertTrue(isValid, "Exact PID, port, and command in LISTEN state must validate successfully")
    }

    func testListenerRevalidationRejectsStalePidOrPort() {
        let lsofFixture = """
        COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        python    13676   m4   23u  IPv6 0x12345678      0t0  TCP *:3000 (LISTEN)
        node      99999   m4   23u  IPv6 0x12345678      0t0  TCP *:3000 (LISTEN)
        node      13676   m4   23u  IPv6 0x12345678      0t0  TCP *:8080 (LISTEN)
        """

        // Mismatched command name
        XCTAssertFalse(
            DevStackService.parseAndValidateListener(
                lsofOutput: lsofFixture,
                expectedPid: 13676,
                expectedPort: 3000,
                expectedProcessName: "ruby",
                expectedUser: "m4"
            )
        )

        // Mismatched PID
        XCTAssertFalse(
            DevStackService.parseAndValidateListener(
                lsofOutput: lsofFixture,
                expectedPid: 12345,
                expectedPort: 3000,
                expectedProcessName: "node",
                expectedUser: "m4"
            )
        )

        // Mismatched Port
        XCTAssertFalse(
            DevStackService.parseAndValidateListener(
                lsofOutput: lsofFixture,
                expectedPid: 13676,
                expectedPort: 4000,
                expectedProcessName: "node",
                expectedUser: "m4"
            )
        )

        // Mismatched owner
        XCTAssertFalse(
            DevStackService.parseAndValidateListener(
                lsofOutput: lsofFixture,
                expectedPid: 13676,
                expectedPort: 3000,
                expectedProcessName: "node",
                expectedUser: "root"
            )
        )
    }

}
