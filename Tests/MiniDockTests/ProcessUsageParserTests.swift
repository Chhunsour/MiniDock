import XCTest
@testable import MiniDock

final class ProcessUsageParserTests: XCTestCase {

    func testValidPsOutputParsing() {
        let validPs = """
          PID  %CPU %MEM
          101   2.5  1.2
        13676  45.0  8.5
          500   0.0  0.1
        """

        let samples = SystemMonitorService.parsePsOutput(validPs)

        XCTAssertEqual(samples.count, 3)
        XCTAssertEqual(samples[101]?.cpu, 2.5)
        XCTAssertEqual(samples[101]?.mem, 1.2)
        XCTAssertEqual(samples[13676]?.cpu, 45.0)
        XCTAssertEqual(samples[13676]?.mem, 8.5)
        XCTAssertEqual(samples[500]?.cpu, 0.0)
        XCTAssertEqual(samples[500]?.mem, 0.1)
    }

    func testMalformedPsOutputHandling() {
        let malformedPs = """
          PID  %CPU %MEM
          not_a_pid  1.0  2.0
          200   invalid_cpu  3.0
          300   4.0   missing_mem
          400
          
          500   12.5  3.2   extra_column_is_fine
        """

        let samples = SystemMonitorService.parsePsOutput(malformedPs)

        // Only PID 500 has valid 3 numeric tokens
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[500]?.cpu, 12.5)
        XCTAssertEqual(samples[500]?.mem, 3.2)
    }

    func testEmptyPsOutputReturnsEmptyDictionary() {
        XCTAssertTrue(SystemMonitorService.parsePsOutput("").isEmpty)
        XCTAssertTrue(SystemMonitorService.parsePsOutput("   \n\n  \t  ").isEmpty)
        XCTAssertTrue(SystemMonitorService.parsePsOutput("  PID  %CPU %MEM  \n").isEmpty)
    }

    func testStableSortingByCpuThenMemoryThenName() {
        let appLowCpu = RunningApplicationUsage(
            pid: 1,
            name: "App Low CPU",
            bundleIdentifier: "com.test.low",
            cpuUsage: 1.5,
            memoryUsage: 10.0
        )
        let appHighCpu = RunningApplicationUsage(
            pid: 2,
            name: "App High CPU",
            bundleIdentifier: "com.test.high",
            cpuUsage: 85.0,
            memoryUsage: 4.0
        )
        let appTieCpuHighMem = RunningApplicationUsage(
            pid: 3,
            name: "App Tie High Mem",
            bundleIdentifier: "com.test.tie1",
            cpuUsage: 20.0,
            memoryUsage: 15.0
        )
        let appTieCpuLowMem = RunningApplicationUsage(
            pid: 4,
            name: "App Tie Low Mem",
            bundleIdentifier: "com.test.tie2",
            cpuUsage: 20.0,
            memoryUsage: 5.0
        )
        let appTieCpuTieMemAlphaA = RunningApplicationUsage(
            pid: 5,
            name: "Alpha App",
            bundleIdentifier: "com.test.alpha",
            cpuUsage: 10.0,
            memoryUsage: 5.0
        )
        let appTieCpuTieMemAlphaZ = RunningApplicationUsage(
            pid: 6,
            name: "Zulu App",
            bundleIdentifier: "com.test.zulu",
            cpuUsage: 10.0,
            memoryUsage: 5.0
        )

        let input = [
            appLowCpu,
            appTieCpuLowMem,
            appTieCpuTieMemAlphaZ,
            appHighCpu,
            appTieCpuTieMemAlphaA,
            appTieCpuHighMem
        ]

        let sorted = SystemMonitorService.sortApplicationUsages(input)

        XCTAssertEqual(sorted[0].pid, 2, "Highest CPU (85%) first")
        XCTAssertEqual(sorted[1].pid, 3, "CPU tie (20%) broken by higher memory (15%)")
        XCTAssertEqual(sorted[2].pid, 4, "CPU tie (20%) with lower memory (5%)")
        XCTAssertEqual(sorted[3].pid, 5, "CPU (10%) tie broken by alphabetical name ('Alpha App' before 'Zulu App')")
        XCTAssertEqual(sorted[4].pid, 6, "CPU (10%) tie alphabetical ('Zulu App')")
        XCTAssertEqual(sorted[5].pid, 1, "Lowest CPU (1.5%) last")
    }

    func testApplicationIdentityRequiresSamePidAndBundle() {
        let selected = RunningApplicationUsage(
            pid: 42,
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            cpuUsage: 1,
            memoryUsage: 1
        )

        XCTAssertTrue(SystemMonitorService.matchesApplicationIdentity(
            selected,
            livePid: 42,
            liveBundleIdentifier: "com.apple.calculator"
        ))
        XCTAssertFalse(SystemMonitorService.matchesApplicationIdentity(
            selected,
            livePid: 43,
            liveBundleIdentifier: "com.apple.calculator"
        ))
        XCTAssertFalse(SystemMonitorService.matchesApplicationIdentity(
            selected,
            livePid: 42,
            liveBundleIdentifier: "com.example.other"
        ))
    }

    @MainActor
    func testQuitApplicationRejectsNonRunningPid() {
        let missing = RunningApplicationUsage(
            pid: 999999,
            name: "Missing",
            bundleIdentifier: "com.apple.nonexistent",
            cpuUsage: 0,
            memoryUsage: 0
        )
        let result = SystemMonitorService.shared.quitApplication(missing, force: false)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("no longer running"))
    }
}
