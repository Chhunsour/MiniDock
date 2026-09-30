import XCTest
import SwiftUI
@testable import MiniDock

final class AppearanceTests: XCTestCase {

    @MainActor
    func testAppleGlassMaterialStyleProperties() {
        let settings = AppSettings.shared
        let originalStyle = settings.materialStyle

        defer {
            settings.materialStyle = originalStyle
        }

        settings.materialStyle = "Apple Glass"

        XCTAssertTrue(settings.isGlassLike, "Apple Glass must be recognized as glass-like")
        XCTAssertTrue(settings.isAppleGlass, "isAppleGlass must return true when materialStyle is Apple Glass")
        XCTAssertFalse(settings.isFullyTransparent, "Apple Glass is not fully transparent")
    }

    @MainActor
    func testResetToDefaultsSetsAppleGlass() {
        let settings = AppSettings.shared
        let originalStyle = settings.materialStyle

        defer {
            settings.materialStyle = originalStyle
        }

        settings.materialStyle = "Obsidian Vantablack"
        settings.resetToDefaults()

        XCTAssertEqual(settings.materialStyle, "Apple Glass", "Default material style must be Apple Glass")
        XCTAssertTrue(settings.isAppleGlass)
    }

    @MainActor
    func testMaterialStyleToggling() {
        let settings = AppSettings.shared
        let originalStyle = settings.materialStyle

        defer {
            settings.materialStyle = originalStyle
        }

        settings.materialStyle = "Fully Transparent"
        XCTAssertTrue(settings.isFullyTransparent)
        XCTAssertFalse(settings.isAppleGlass)
        XCTAssertTrue(settings.isGlassLike)

        settings.materialStyle = "Apple Glass"
        XCTAssertFalse(settings.isFullyTransparent)
        XCTAssertTrue(settings.isAppleGlass)
        XCTAssertTrue(settings.isGlassLike)

        settings.materialStyle = "Obsidian Black"
        XCTAssertFalse(settings.isFullyTransparent)
        XCTAssertFalse(settings.isAppleGlass)
        XCTAssertTrue(settings.isGlassLike)
    }

    @MainActor
    func testDockContainerViewInstantiationWithAppleGlass() {
        let settings = AppSettings.shared
        let originalStyle = settings.materialStyle

        defer {
            settings.materialStyle = originalStyle
        }

        settings.materialStyle = "Apple Glass"
        let view = DockContainerView(displayScale: 1.0)
        XCTAssertNotNil(view)

        let widgetCard = WidgetCardView {
            Text("Test")
        }
        XCTAssertNotNil(widgetCard)
    }
}
