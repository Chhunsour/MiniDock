import XCTest
@testable import MiniDock

final class DevStackScannerTests: XCTestCase {

    func testLsofParsingFilteringAndDeduplication() {
        let fixtureOutput = """
        COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      13676   m4   23u  IPv6 0x12345678      0t0  TCP *:3000 (LISTEN)
        node      13676   m4   24u  IPv4 0x12345679      0t0  TCP *:3000 (LISTEN)
        mysqld     1234   m4   30u  IPv4 0x1234567a      0t0  TCP *:3306 (LISTEN)
        ControlCe   456   m4    8u  IPv4 0x1234567b      0t0  TCP *:5000 (LISTEN)
        adb       78901   m4   12u  IPv4 0x1234567c      0t0  TCP 127.0.0.1:5037 (LISTEN)
        rapportd    345   m4    5u  IPv4 0x1234567d      0t0  TCP *:54321 (LISTEN)
        Python       542   m4    6u  IPv4 0x1234567e      0t0  TCP *:61208 (LISTEN)
        language_   2005   m4    7u  IPv4 0x1234567f      0t0  TCP 127.0.0.1:64003 (LISTEN)
        """

        let services = DevStackService.parseLsofOutput(
            fixtureOutput,
            cwdResolver: nil,
            commandLineResolver: { pid in
                pid == 542 ? "/opt/homebrew/bin/python /opt/homebrew/bin/glances -w -p 61208" : nil
            }
        )

        // 1. Only Node :3000 and MySQL :3306 should be included (2 total services)
        // ControlCenter, ADB, and high ephemeral listener rapportd must be excluded.
        // Duplicate IPv4/IPv6 lines for Node :3000 must NOT duplicate the service.
        XCTAssertEqual(services.count, 3, "Expected Node, MySQL, and the explicit Glances web server")

        // 2. Verify Node service on :3000
        guard let nodeService = services.first(where: { $0.port == 3000 }) else {
            XCTFail("Expected Node service on port 3000 to be discovered")
            return
        }
        XCTAssertEqual(nodeService.processName, "node")
        XCTAssertEqual(nodeService.pid, 13676)
        XCTAssertEqual(nodeService.urlString, "http://localhost:3000", "Node :3000 must be assigned a browser URL")

        // 3. Verify MySQL service on :3306
        guard let mysqlService = services.first(where: { $0.port == 3306 }) else {
            XCTFail("Expected MySQL service on port 3306 to be discovered")
            return
        }
        XCTAssertEqual(mysqlService.name, "MySQL")
        XCTAssertEqual(mysqlService.processName, "mysqld")
        XCTAssertEqual(mysqlService.stack, "Database")
        XCTAssertNil(mysqlService.urlString, "MySQL database service must NOT have a browser HTTP URL")

        XCTAssertEqual(services.first(where: { $0.port == 61208 })?.name, "Glances")
        XCTAssertEqual(services.first(where: { $0.port == 61208 })?.urlString, "http://localhost:61208")

        // 4. Verify explicit exclusions
        XCTAssertFalse(services.contains(where: { $0.port == 5000 }), "ControlCenter on 5000 must be excluded")
        XCTAssertFalse(services.contains(where: { $0.port == 5037 }), "ADB on 5037 must be excluded")
        XCTAssertFalse(services.contains(where: { $0.port == 54321 }), "High ephemeral port 54321 must be excluded")
        XCTAssertFalse(services.contains(where: { $0.port == 64003 }), "Language-server sockets must be excluded")
    }

    func testNextJsProjectClassificationAndLabeling() {
        let fixtureOutput = """
        COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      13676   m4   23u  IPv6 0x12345678      0t0  TCP *:3000 (LISTEN)
        node      13676   m4   24u  IPv6 0x12345679      0t0  TCP *:45000 (LISTEN)
        java      13766   m4  315u  IPv6 0x1234567a      0t0  TCP 127.0.0.1:17233 (LISTEN)
        """

        let targetPath = "/Users/m4/AttendKH-Website-Landing-Page"

        let services = DevStackService.parseLsofOutput(
            fixtureOutput,
            cwdResolver: { pid in
                if pid == 13676 { return targetPath }
                if pid == 13766 { return "/Users/m4/.gradle/daemon" }
                return nil
            },
            commandLineResolver: { pid in
                return pid == 13676 ? "next-server (v16.3.2)" : nil
            },
            fileChecker: { path in
                // Simulate package.json and next.config.js present in project directory
                if path.hasPrefix(targetPath) && (path.hasSuffix("package.json") || path.hasSuffix("next.config.js")) {
                    return true
                }
                return false
            }
        )

        XCTAssertEqual(services.count, 2, "Project servers may use custom high ports, while unmarked runtime listeners stay hidden")
        guard let nextService = services.first(where: { $0.port == 3000 }) else {
            XCTFail("Expected service to be returned")
            return
        }

        XCTAssertEqual(nextService.name, "AttendKH-Website-Landing-Page", "Should identify the project name from nearest root")
        XCTAssertEqual(nextService.stack, "Next.js", "Should identify Next.js stack from command line and markers")
        XCTAssertEqual(nextService.port, 3000)
        XCTAssertEqual(nextService.urlString, "http://localhost:3000")
        XCTAssertEqual(nextService.id, "3000:13676:node", "Service must have stable deterministic ID across scans")
        XCTAssertEqual(services.first(where: { $0.port == 45000 })?.urlString, "http://localhost:45000")
        XCTAssertFalse(services.contains(where: { $0.pid == 13766 }), "An unmarked Java/IDE listener must not be mislabeled as a project")
    }
}
