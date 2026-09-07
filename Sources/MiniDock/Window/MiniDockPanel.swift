import AppKit
import SwiftUI
import Combine

public final class MiniDockPanel: NSPanel {
    private var hostingView: NSHostingView<DockContainerView>?
    private var cancellables = Set<AnyCancellable>()
    private var appliedScale = CGFloat(AppSettings.shared.dockScale)

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 75),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isMovableByWindowBackground = false

        let container = DockContainerView(displayScale: appliedScale)
        let host = NSHostingView(rootView: container)
        host.sizingOptions = [.intrinsicContentSize]
        self.contentView = host
        self.hostingView = host

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Coalesce publisher-driven reposition requests into a single debounced pipeline
        Publishers.Merge4(
            AppSettings.shared.objectWillChange.map { _ in () },
            TransientCapsuleManager.shared.objectWillChange.map { _ in () },
            AppLauncherService.shared.objectWillChange.map { _ in () },
            ProjectContextService.shared.objectWillChange.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .debounce(for: .milliseconds(20), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.reposition()
        }
        .store(in: &cancellables)

        reposition()
    }

    override public var canBecomeKey: Bool {
        return false
    }

    override public var canBecomeMain: Bool {
        return false
    }

    @objc public func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let host = hostingView else { return }

        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let effectiveScale = DockFrameCalculator.effectiveScale(
            contentSize: fitting,
            requestedScale: AppSettings.shared.dockScale,
            visibleFrame: screen.visibleFrame
        )

        if abs(appliedScale - effectiveScale) > 0.001 {
            appliedScale = effectiveScale
            host.rootView = DockContainerView(displayScale: effectiveScale)
            host.layoutSubtreeIfNeeded()
        }

        let targetFrame = DockFrameCalculator.calculateTargetFrame(
            contentSize: fitting,
            scale: Double(effectiveScale),
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )

        // Do nothing when the target frame is unchanged
        let current = self.frame
        if abs(current.origin.x - targetFrame.origin.x) < 0.5 &&
           abs(current.origin.y - targetFrame.origin.y) < 0.5 &&
           abs(current.size.width - targetFrame.size.width) < 0.5 &&
           abs(current.size.height - targetFrame.size.height) < 0.5 {
            return
        }

        if current == .zero || abs(current.width - targetFrame.width) > 300 {
            self.setFrame(targetFrame, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(targetFrame, display: true)
            }
        }
    }
}

/// Pure layout calculator for FlowDock window positioning and sizing.
/// Ensures the dock remains horizontally centered, attached to the screen bottom,
/// bounded by screen margins, and fully accounts for dockScale without clipping.
public struct DockFrameCalculator: Sendable {
    public static let defaultSafeMargin: CGFloat = 16.0
    public static let defaultBottomInset: CGFloat = 0.0
    public static let minDockWidth: CGFloat = 320.0
    public static let minDockHeight: CGFloat = 48.0

    public static func effectiveScale(
        contentSize: CGSize,
        requestedScale: Double,
        visibleFrame: CGRect,
        bottomInset: CGFloat = defaultBottomInset,
        safeMargin: CGFloat = defaultSafeMargin
    ) -> CGFloat {
        let baseWidth = max(contentSize.width, minDockWidth)
        let baseHeight = max(contentSize.height, minDockHeight)
        let widthScale = max(visibleFrame.width - safeMargin * 2.0, 1.0) / baseWidth
        let heightScale = max(visibleFrame.height - bottomInset - safeMargin, 1.0) / baseHeight
        return max(min(CGFloat(requestedScale), widthScale, heightScale), 0.01)
    }

    public static func calculateTargetFrame(
        contentSize: CGSize,
        scale: Double,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        bottomInset: CGFloat = defaultBottomInset,
        safeMargin: CGFloat = defaultSafeMargin
    ) -> CGRect {
        // Base content dimensions bounded by minimum dock dimensions
        let baseWidth = max(contentSize.width, minDockWidth)
        let baseHeight = max(contentSize.height, minDockHeight)

        let clampedScale = effectiveScale(
            contentSize: contentSize,
            requestedScale: scale,
            visibleFrame: visibleFrame,
            bottomInset: bottomInset,
            safeMargin: safeMargin
        )

        // Scaled dimensions to respect dockScale and prevent window clipping
        let scaledWidth = ceil(baseWidth * CGFloat(clampedScale))
        let scaledHeight = ceil(baseHeight * CGFloat(clampedScale))

        // Clamp width to visible screen width minus safe margins on both sides
        let maxAllowedWidth = max(visibleFrame.width - (safeMargin * 2.0), 1.0)
        let targetWidth = min(scaledWidth, maxAllowedWidth)

        // Clamp height so dock fits comfortably within visible area
        let maxAllowedHeight = max(visibleFrame.height - bottomInset - safeMargin, 1.0)
        let targetHeight = min(scaledHeight, maxAllowedHeight)

        // Horizontally centered within the screen's visible area
        let x = round(visibleFrame.origin.x + (visibleFrame.width - targetWidth) / 2.0)

        // Fuses with the physical screen bottom, independent of the Apple Dock's visible frame.
        let y = round(screenFrame.origin.y + bottomInset)

        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }
}
