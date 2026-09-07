import XCTest
@testable import MiniDock

final class SleekScrollViewTests: XCTestCase {
    func testThumbHeightReturnsZeroWhenContentFits() {
        // Content height smaller than or equal to visible height means no scrolling needed
        let height = ScrollGeometryCalculator.calculateThumbHeight(
            contentHeight: 300,
            visibleHeight: 400,
            trackHeight: 380
        )
        XCTAssertEqual(height, 0)

        let equalHeight = ScrollGeometryCalculator.calculateThumbHeight(
            contentHeight: 400,
            visibleHeight: 400,
            trackHeight: 380
        )
        XCTAssertEqual(equalHeight, 0)
    }

    func testThumbHeightReturnsZeroOnInvalidDimensions() {
        XCTAssertEqual(
            ScrollGeometryCalculator.calculateThumbHeight(contentHeight: 0, visibleHeight: 100, trackHeight: 100),
            0
        )
        XCTAssertEqual(
            ScrollGeometryCalculator.calculateThumbHeight(contentHeight: 100, visibleHeight: 0, trackHeight: 100),
            0
        )
        XCTAssertEqual(
            ScrollGeometryCalculator.calculateThumbHeight(contentHeight: 100, visibleHeight: 50, trackHeight: 0),
            0
        )
    }

    func testThumbHeightCalculatesProportionalHeight() {
        // Content is 1000, visible is 500 (ratio 0.5), track is 400 -> raw height is 200
        let height = ScrollGeometryCalculator.calculateThumbHeight(
            contentHeight: 1000,
            visibleHeight: 500,
            trackHeight: 400
        )
        XCTAssertEqual(height, 200, accuracy: 0.001)
    }

    func testThumbHeightEnforcesMinimumHeight() {
        // Very large content (10,000pt) with 200pt visible would produce a tiny ~6pt thumb,
        // but it must clamp to the minimum height of 28pt so it's always easily clickable/visible
        let height = ScrollGeometryCalculator.calculateThumbHeight(
            contentHeight: 10000,
            visibleHeight: 200,
            trackHeight: 300,
            minThumbHeight: 28
        )
        XCTAssertEqual(height, 28)
    }

    func testThumbOffsetCalculatesCorrectly() {
        let contentHeight: CGFloat = 1000
        let visibleHeight: CGFloat = 400
        let trackHeight: CGFloat = 380
        let thumbHeight: CGFloat = 100

        // At scroll top (offset 0)
        let topOffset = ScrollGeometryCalculator.calculateThumbOffset(
            scrollOffset: 0,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        XCTAssertEqual(topOffset, 0, accuracy: 0.001)

        // At scroll bottom (offset = 600)
        let maxScroll = contentHeight - visibleHeight
        let bottomOffset = ScrollGeometryCalculator.calculateThumbOffset(
            scrollOffset: maxScroll,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        let maxTravel = trackHeight - thumbHeight
        XCTAssertEqual(bottomOffset, maxTravel, accuracy: 0.001)

        // Halfway scroll
        let midOffset = ScrollGeometryCalculator.calculateThumbOffset(
            scrollOffset: maxScroll / 2,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        XCTAssertEqual(midOffset, maxTravel / 2, accuracy: 0.001)
    }

    func testCalculateScrollOffsetFromThumbDrag() {
        let contentHeight: CGFloat = 800
        let visibleHeight: CGFloat = 300
        let trackHeight: CGFloat = 280
        let thumbHeight: CGFloat = 60
        let maxTravel = trackHeight - thumbHeight // 220
        let maxScroll = contentHeight - visibleHeight // 500

        // Drag to top
        let topScroll = ScrollGeometryCalculator.calculateScrollOffset(
            thumbOffset: 0,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        XCTAssertEqual(topScroll, 0, accuracy: 0.001)

        // Drag to bottom
        let bottomScroll = ScrollGeometryCalculator.calculateScrollOffset(
            thumbOffset: maxTravel,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        XCTAssertEqual(bottomScroll, maxScroll, accuracy: 0.001)

        // Drag beyond bounds is clamped
        let overBottom = ScrollGeometryCalculator.calculateScrollOffset(
            thumbOffset: maxTravel + 50,
            contentHeight: contentHeight,
            visibleHeight: visibleHeight,
            trackHeight: trackHeight,
            thumbHeight: thumbHeight
        )
        XCTAssertEqual(overBottom, maxScroll, accuracy: 0.001)
    }
}
