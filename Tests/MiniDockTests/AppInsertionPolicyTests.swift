import XCTest
@testable import MiniDock

final class AppInsertionPolicyTests: XCTestCase {

    private func makeApp(name: String, bundleId: String) -> LauncherAppItem {
        LauncherAppItem(
            name: name,
            bundleIdentifier: bundleId,
            path: "/Applications/\(name).app"
        )
    }

    func testBelowLimitAppendsWithoutChangingLimit() {
        var apps = [
            makeApp(name: "Finder", bundleId: "com.apple.finder"),
            makeApp(name: "Terminal", bundleId: "com.apple.Terminal"),
            makeApp(name: "Notes", bundleId: "com.apple.Notes")
        ]
        var maxVisible = 6

        let newApp = makeApp(name: "Safari", bundleId: "com.apple.Safari")
        let result = AppInsertionPolicy.apply(item: newApp, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .added)
        XCTAssertEqual(apps.count, 4)
        XCTAssertEqual(maxVisible, 6, "Below limit, maxVisibleApps must remain unchanged")
        XCTAssertEqual(apps.last?.bundleIdentifier, "com.apple.Safari")
    }

    func testAtLimitInsertsAtBoundaryAndIncrementsLimit() {
        var apps = (1...6).map { makeApp(name: "App\($0)", bundleId: "com.example.app\($0)") }
        var maxVisible = 6

        let newApp = makeApp(name: "Activity Monitor", bundleId: "com.apple.ActivityMonitor")
        let result = AppInsertionPolicy.apply(item: newApp, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .added)
        XCTAssertEqual(apps.count, 7)
        XCTAssertEqual(maxVisible, 7, "At limit, maxVisibleApps must increment so the app is visible immediately")
        XCTAssertEqual(apps[6].bundleIdentifier, "com.apple.ActivityMonitor")
    }

    func testHiddenDuplicatePromotesExistingItemWithoutDuplication() {
        var apps = (1...8).map { makeApp(name: "App\($0)", bundleId: "com.example.app\($0)") }
        var maxVisible = 6
        // App7 and App8 are hidden in the saved list (indices 6 and 7)

        let targetApp = makeApp(name: "App8", bundleId: "com.example.app8")
        let result = AppInsertionPolicy.apply(item: targetApp, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .promoted)
        XCTAssertEqual(apps.count, 8, "Promoting an existing hidden item must not increase total count")
        XCTAssertEqual(maxVisible, 7, "Limit must increment once to include the promoted item")
        XCTAssertEqual(apps[6].bundleIdentifier, "com.example.app8", "Promoted item must now sit at visible index")
        XCTAssertEqual(apps[7].bundleIdentifier, "com.example.app7", "Other hidden item remains hidden")
    }

    func testAlreadyVisibleItemIsNoOp() {
        var apps = (1...6).map { makeApp(name: "App\($0)", bundleId: "com.example.app\($0)") }
        var maxVisible = 6

        let visibleApp = makeApp(name: "App3", bundleId: "com.example.app3")
        let result = AppInsertionPolicy.apply(item: visibleApp, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .alreadyVisible)
        XCTAssertEqual(apps.count, 6)
        XCTAssertEqual(maxVisible, 6)
    }

    func testMax14BehaviorPushesPreviousItemToHiddenSegmentWithoutDeletion() {
        var apps = (1...14).map { makeApp(name: "App\($0)", bundleId: "com.example.app\($0)") }
        var maxVisible = 14

        let newApp = makeApp(name: "ExtraApp", bundleId: "com.example.extra")
        let result = AppInsertionPolicy.apply(item: newApp, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .added)
        XCTAssertEqual(apps.count, 15, "No items must be deleted")
        XCTAssertEqual(maxVisible, 14, "Visible limit caps at supported maximum 14")
        XCTAssertEqual(apps[13].bundleIdentifier, "com.example.extra", "New item occupies the last visible position (index 13)")
        XCTAssertEqual(apps[14].bundleIdentifier, "com.example.app14", "Previous 14th item moved into the saved hidden segment")
    }

    func testMax14PromoteHiddenAppMovesToLastVisiblePosition() {
        var apps = (1...16).map { makeApp(name: "App\($0)", bundleId: "com.example.app\($0)") }
        var maxVisible = 14

        let hiddenTarget = makeApp(name: "App16", bundleId: "com.example.app16")
        let result = AppInsertionPolicy.apply(item: hiddenTarget, apps: &apps, maxVisibleApps: &maxVisible)

        XCTAssertEqual(result, .promoted)
        XCTAssertEqual(apps.count, 16)
        XCTAssertEqual(maxVisible, 14)
        XCTAssertEqual(apps[13].bundleIdentifier, "com.example.app16")
        XCTAssertEqual(apps[14].bundleIdentifier, "com.example.app14")
    }

}
