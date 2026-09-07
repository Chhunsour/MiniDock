import XCTest
@testable import MiniDock

final class ClipboardServiceTests: XCTestCase {
    func testSensitiveClipboardContentIsDetectedAndMasked() {
        let secret = "Authorization: Bearer private-token"

        XCTAssertTrue(ClipboardService.isSensitive(secret))
        XCTAssertEqual(ClipboardService.sanitizePreview(secret), "Sensitive content (not saved)")
    }

    func testOrdinaryClipboardPreviewIsReadableAndBounded() {
        XCTAssertEqual(ClipboardService.sanitizePreview("First line\nSecond line"), "First line")
        XCTAssertLessThanOrEqual(ClipboardService.sanitizePreview(String(repeating: "a", count: 80)).count, 39)
    }
}
