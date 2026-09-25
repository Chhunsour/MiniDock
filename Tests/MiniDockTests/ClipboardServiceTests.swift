import AppKit
import SwiftUI
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

    @MainActor
    private func renderViewToPNG<V: View>(_ view: V, filename: String) {
        let hosting = NSHostingView(rootView: view.preferredColorScheme(.dark))
        hosting.frame = NSRect(x: 0, y: 0, width: 660, height: 520)
        
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 520), styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = hosting
        win.layoutIfNeeded()
        win.displayIfNeeded()
        
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return }
        let dest = URL(fileURLWithPath: "/Users/macbook/.gemini/antigravity/brain/c1c7ee70-b966-4b4d-ada9-5dfc38c5caa1/\(filename)")
        try? data.write(to: dest)
        print("Rendered preview to:", dest.path)
    }

    @MainActor
    func testRenderClipboardPopoverPreview() {
        let service = ClipboardService.shared
        let shots = ClipboardService.discoverScreenshots()
        service.setScreenshotsForTesting(shots)
        let view = ClipboardLibraryPopover(clipboard: service, initialTab: "All")
        renderViewToPNG(view, filename: "clipboard_all.png")
    }

    @MainActor
    func testRenderScreenshotsTab() {
        let service = ClipboardService.shared
        let shots = ClipboardService.discoverScreenshots()
        service.setScreenshotsForTesting(shots)
        let view = ClipboardLibraryPopover(clipboard: service, initialTab: "Screenshots")
        renderViewToPNG(view, filename: "clipboard_screenshots.png")
    }

    @MainActor
    func testRenderCopiedTab() {
        let service = ClipboardService.shared
        let view = ClipboardLibraryPopover(clipboard: service, initialTab: "Copied")
        renderViewToPNG(view, filename: "clipboard_copied.png")
    }

    @MainActor
    func testRenderSearchFilter() {
        let service = ClipboardService.shared
        let shots = ClipboardService.discoverScreenshots()
        service.setScreenshotsForTesting(shots)
        let view = ClipboardLibraryPopover(clipboard: service, initialTab: "All", initialSearch: "Screenshot")
        renderViewToPNG(view, filename: "clipboard_search.png")
    }
}
