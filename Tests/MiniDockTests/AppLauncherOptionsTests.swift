import XCTest
@testable import MiniDock

final class AppLauncherOptionsTests: XCTestCase {

    @MainActor
    func testShowRunningIndicatorsToggle() {
        let settings = AppSettings.shared
        let originalIndicators = settings.showRunningIndicators
        let originalStyle = settings.runningIndicatorStyle

        defer {
            settings.showRunningIndicators = originalIndicators
            settings.runningIndicatorStyle = originalStyle
        }

        settings.showRunningIndicators = false
        XCTAssertFalse(settings.showRunningIndicators)

        settings.showRunningIndicators = true
        XCTAssertTrue(settings.showRunningIndicators)
    }

    @MainActor
    func testShowAddAppButtonToggle() {
        let settings = AppSettings.shared
        let original = settings.showAddAppButton

        defer {
            settings.showAddAppButton = original
        }

        settings.showAddAppButton = false
        XCTAssertFalse(settings.showAddAppButton)

        settings.showAddAppButton = true
        XCTAssertTrue(settings.showAddAppButton)
    }

    @MainActor
    func testShowOnlyRunningAppsFilter() {
        let settings = AppSettings.shared
        let launcher = AppLauncherService.shared
        let originalShowOnlyRunning = settings.showOnlyRunningApps

        defer {
            settings.showOnlyRunningApps = originalShowOnlyRunning
        }

        settings.showOnlyRunningApps = false
        let normalVisible = launcher.visibleApps

        settings.showOnlyRunningApps = true
        let runningOnly = launcher.visibleApps

        for app in runningOnly {
            XCTAssertTrue(launcher.isRunning(app), "\(app.name) in running-only list must be running")
        }
        XCTAssertLessThanOrEqual(runningOnly.count, normalVisible.count)
    }
}
