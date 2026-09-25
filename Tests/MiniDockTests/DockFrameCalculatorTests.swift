import XCTest
@testable import MiniDock

final class DockFrameCalculatorTests: XCTestCase {
    func testStandardCenteringAndEdgeAttachment() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1055)
        let content = CGSize(width: 600, height: 56)

        let frame = DockFrameCalculator.calculateTargetFrame(
            contentSize: content,
            scale: 1.0,
            screenFrame: screen,
            visibleFrame: visible
        )

        XCTAssertEqual(frame.width, 600)
        XCTAssertEqual(frame.height, 56)
        XCTAssertEqual(frame.origin.x, (1920 - 600) / 2.0)
        XCTAssertEqual(frame.origin.y, 0)
    }

    func testDockScaleCalculation() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1055)
        let content = CGSize(width: 600, height: 50)

        let frame = DockFrameCalculator.calculateTargetFrame(
            contentSize: content,
            scale: 1.3,
            screenFrame: screen,
            visibleFrame: visible
        )

        XCTAssertEqual(frame.width, ceil(600 * 1.3))
        XCTAssertEqual(frame.height, ceil(50 * 1.3))
        XCTAssertEqual(frame.origin.x, (1920 - ceil(600 * 1.3)) / 2.0)
        XCTAssertEqual(frame.origin.y, 0)
    }

    func testScale1Point3StaysInside1600ScreenWithMargins() {
        let screen = CGRect(x: 0, y: 0, width: 1600, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 875)
        let content = CGSize(width: 1300, height: 60)

        let frame = DockFrameCalculator.calculateTargetFrame(
            contentSize: content,
            scale: 1.3,
            screenFrame: screen,
            visibleFrame: visible
        )
        let effectiveScale = DockFrameCalculator.effectiveScale(
            contentSize: content,
            requestedScale: 1.3,
            visibleFrame: visible
        )

        // The view and window use the same reduced scale, so neither can clip.
        XCTAssertLessThanOrEqual(frame.width, 1600 - 32)
        XCTAssertEqual(frame.width, ceil(content.width * effectiveScale))
        XCTAssertLessThan(effectiveScale, 1.3)
        XCTAssertGreaterThanOrEqual(frame.origin.x, 16)
        XCTAssertLessThanOrEqual(frame.maxX, 1600 - 16)
        XCTAssertEqual(frame.origin.y, 0)
    }

    func testPhysicalScreenEdgeAttachmentIgnoresVisibleDockOffset() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 0, y: 70, width: 1920, height: 985)
        let content = CGSize(width: 500, height: 50)

        let frame = DockFrameCalculator.calculateTargetFrame(
            contentSize: content,
            scale: 1.0,
            screenFrame: screen,
            visibleFrame: visible
        )

        // Uses the physical screen bottom, not the Apple Dock offset.
        XCTAssertEqual(frame.origin.y, screen.origin.y + DockFrameCalculator.defaultBottomInset)
    }

    func testSecondaryScreenPhysicalBottomAttachment() {
        let screen = CGRect(x: 0, y: 1200, width: 1920, height: 1080)
        let visible = CGRect(x: 0, y: 1200, width: 1920, height: 1055)
        let content = CGSize(width: 500, height: 50)

        let frame = DockFrameCalculator.calculateTargetFrame(
            contentSize: content,
            scale: 1.0,
            screenFrame: screen,
            visibleFrame: visible
        )

        XCTAssertEqual(frame.origin.y, 1200)
    }

    func testScreenAttachedDockShapeGeometryClamping() {
        let shape = ScreenAttachedDockShape(flareWidth: 24, flareHeight: 22, cornerRadius: 16, isClosed: true)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 600, height: 52))
        XCTAssertFalse(path.isEmpty)

        // Safe defensive handling for zero or very narrow widths
        let zeroPath = shape.path(in: .zero)
        XCTAssertTrue(zeroPath.isEmpty)

        let narrowPath = shape.path(in: CGRect(x: 0, y: 0, width: 40, height: 30))
        XCTAssertFalse(narrowPath.isEmpty)

        // Open rim shape for stroke (omits bottom edge)
        let rimShape = ScreenAttachedDockShape(flareWidth: 24, flareHeight: 22, cornerRadius: 16, isClosed: false)
        let rimPath = rimShape.path(in: CGRect(x: 0, y: 0, width: 600, height: 52))
        XCTAssertFalse(rimPath.isEmpty)
    }

    func testScreenAttachedDockShapeRefinedDefaults() {
        let shape = ScreenAttachedDockShape()
        XCTAssertEqual(shape.flareWidth, 30.0, "Shallower smoother flare width roughly 28-32 pt")
        XCTAssertEqual(shape.flareHeight, 18.0, "Shallower smoother flare height roughly 16-20 pt")
        XCTAssertEqual(shape.cornerRadius, 16.0, "Continuous radii around 14-18 pt")
        XCTAssertTrue(shape.isClosed)
    }

    func testCalculateHiddenFramePositionsOffscreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let targetFrame = CGRect(x: 320, y: 0, width: 800, height: 70)

        let hiddenFrame = DockFrameCalculator.calculateHiddenFrame(
            targetFrame: targetFrame,
            screenFrame: screen,
            lipHeight: 1.0
        )

        XCTAssertEqual(hiddenFrame.origin.x, 320)
        XCTAssertEqual(hiddenFrame.width, 800)
        XCTAssertEqual(hiddenFrame.height, 70)
        // Hidden Y should be at screen.origin.y - targetHeight + lipHeight: 0 - 70 + 1 = -69
        XCTAssertEqual(hiddenFrame.origin.y, -69.0)
    }

    func testMouseInTriggerZoneAtBottomEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        // Mouse at bottom edge (y = 2) should trigger
        let bottomPoint = CGPoint(x: 720, y: 2)
        XCTAssertTrue(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: bottomPoint, screenFrame: screen, threshold: 4.0))

        // Mouse slightly higher up (y = 20) should NOT trigger
        let highPoint = CGPoint(x: 720, y: 20)
        XCTAssertFalse(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: highPoint, screenFrame: screen, threshold: 4.0))

        // Mouse outside horizontal screen bounds should NOT trigger
        let outsidePoint = CGPoint(x: 1500, y: 2)
        XCTAssertFalse(DockFrameCalculator.isMouseInTriggerZone(mouseLocation: outsidePoint, screenFrame: screen, threshold: 4.0))
    }

    func testMouseInDockBoundsWithSafetyPadding() {
        let dockFrame = CGRect(x: 400, y: 0, width: 640, height: 65)

        // Mouse right in the center of the dock
        let centerPoint = CGPoint(x: 720, y: 30)
        XCTAssertTrue(DockFrameCalculator.isMouseInDockBounds(mouseLocation: centerPoint, dockFrame: dockFrame))

        // Mouse just slightly above the dock crest (within safety padding of 20pt)
        let abovePoint = CGPoint(x: 720, y: 80)
        XCTAssertTrue(DockFrameCalculator.isMouseInDockBounds(mouseLocation: abovePoint, dockFrame: dockFrame, safetyPadding: 20.0))

        // Mouse far away in the application window
        let appPoint = CGPoint(x: 720, y: 250)
        XCTAssertFalse(DockFrameCalculator.isMouseInDockBounds(mouseLocation: appPoint, dockFrame: dockFrame, safetyPadding: 20.0))
    }
}
