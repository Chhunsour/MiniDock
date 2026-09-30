import XCTest
import AppKit
@testable import MiniDock

final class AutoHideTimingTests: XCTestCase {

    @MainActor
    func testAutoHideDelayDefaultValues() {
        let settings = AppSettings.shared
        let originalReveal = settings.autoHideRevealDelay
        let originalHide = settings.autoHideDelay
        let originalBehavior = settings.dockBehavior

        defer {
            settings.autoHideRevealDelay = originalReveal
            settings.autoHideDelay = originalHide
            settings.dockBehavior = originalBehavior
        }

        settings.resetToDefaults()

        XCTAssertEqual(settings.autoHideRevealDelay, 0.6, accuracy: 0.001)
        XCTAssertEqual(settings.autoHideDelay, 3.0, accuracy: 0.001)
        XCTAssertEqual(settings.dockBehavior, "Auto-Hide (macOS Dock)")
    }

    @MainActor
    func testAutoHideCustomValuesPersistence() {
        let settings = AppSettings.shared
        let originalReveal = settings.autoHideRevealDelay
        let originalHide = settings.autoHideDelay

        defer {
            settings.autoHideRevealDelay = originalReveal
            settings.autoHideDelay = originalHide
        }

        settings.autoHideRevealDelay = 2.2
        settings.autoHideDelay = 4.5

        XCTAssertEqual(settings.autoHideRevealDelay, 2.2, accuracy: 0.001)
        XCTAssertEqual(settings.autoHideDelay, 4.5, accuracy: 0.001)

        // Verify UserDefaults persistence
        let defaults = UserDefaults.standard
        XCTAssertEqual(defaults.double(forKey: "autoHideRevealDelay"), 2.2, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: "autoHideDelay"), 4.5, accuracy: 0.001)
    }

    func testTriggerZoneDetectionForHoverReveal() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Mouse right at bottom edge (y = 0.5) must trigger hover reveal timer
        let edgePoint = CGPoint(x: 960, y: 0.5)
        XCTAssertTrue(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: edgePoint, screenFrame: screen, threshold: 4.0))

        // Mouse within 3.5 points of bottom edge must trigger
        let nearEdgePoint = CGPoint(x: 960, y: 3.5)
        XCTAssertTrue(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: nearEdgePoint, screenFrame: screen, threshold: 4.0))

        // Mouse further up into window content (y = 15.0) must NOT trigger
        let contentPoint = CGPoint(x: 960, y: 15.0)
        XCTAssertFalse(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: contentPoint, screenFrame: screen, threshold: 4.0))
    }

    func testDockBoundsExitSchedulesHide() {
        let dockFrame = CGRect(x: 500, y: 0, width: 920, height: 72)

        // Center of dock
        let insidePoint = CGPoint(x: 960, y: 36)
        XCTAssertTrue(DockFrameCalculator.isMouseInDockBounds(mouseLocation: insidePoint, dockFrame: dockFrame, safetyPadding: 20.0))

        // Slightly above top edge within safety padding (y = 85 <= 72 + 20)
        let nearTopPoint = CGPoint(x: 960, y: 85)
        XCTAssertTrue(DockFrameCalculator.isMouseInDockBounds(mouseLocation: nearTopPoint, dockFrame: dockFrame, safetyPadding: 20.0))

        // Outside dock bounds (cursor moved up into window)
        let outsidePoint = CGPoint(x: 960, y: 150)
        XCTAssertFalse(DockFrameCalculator.isMouseInDockBounds(mouseLocation: outsidePoint, dockFrame: dockFrame, safetyPadding: 20.0))
    }

    @MainActor
    func testScheduleRevealAndHideCancellation() {
        let panel = MiniDockPanel()

        // Initially dock can schedule reveal if hidden
        panel.hideDock(animated: false)
        XCTAssertTrue(panel.isDockHidden)

        // Schedule reveal with custom delay
        panel.scheduleRevealDock(delay: 1.5)
        // Immediately cancelling pending reveal before 1.5s should leave dock hidden
        panel.cancelPendingReveal()
        XCTAssertTrue(panel.isDockHidden)

        // Reveal dock
        panel.revealDock(animated: false)
        XCTAssertFalse(panel.isDockHidden)

        // Schedule hide with 3.0s delay
        panel.scheduleHideDock(delay: 3.0)
        // Cancelling pending hide (e.g. cursor returned to dock) prevents dock from hiding
        panel.cancelPendingHide()
        XCTAssertFalse(panel.isDockHidden)
    }
}
