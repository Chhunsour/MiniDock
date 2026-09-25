import AppKit
import SwiftUI
import Combine

public final class MiniDockPanel: NSPanel {
    public static weak var shared: MiniDockPanel?

    private var hostingView: NSHostingView<DockContainerView>?
    private var cancellables = Set<AnyCancellable>()
    private var appliedScale = CGFloat(AppSettings.shared.dockScale)

    // Auto-Hide State Machine
    public private(set) var isDockHidden: Bool = false
    private var isRevealedByMouse: Bool = false
    private var isHoveringDock: Bool = false
    public var isInteracting: Bool = false
    private var pendingHideWorkItem: DispatchWorkItem?
    private var lastTargetFrame: CGRect = .zero

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var edgeTrackingTimer: Timer?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 75),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        Self.shared = self

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        // Level 21: Elevated dock level matching macOS Dock, above standard & floating windows
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) + 1)
        // Ensure presence on all Mission Control spaces and fullscreen applications without desktop locking
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false

        let container = DockContainerView(displayScale: appliedScale)
        let host = NSHostingView(rootView: container)
        host.sizingOptions = [.intrinsicContentSize]
        self.contentView = host
        self.hostingView = host

        // Screen parameters change (multi-monitor plug/unplug or resolution change)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Space/Desktop change (switching virtual desktops via trackpad swipe or Mission Control)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Application activation (switching between apps)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Screen wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        // Keep dock open while context menus are actively being navigated
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidBeginTracking),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidEndTracking),
            name: NSMenu.didEndTrackingNotification,
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

        AppSettings.shared.$dockBehavior
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleBehaviorChange()
            }
            .store(in: &cancellables)

        setupMouseTracking()
        reposition()

        // If configured for Auto-Hide, show initially then smoothly tuck away after 1.2s
        if AppSettings.shared.dockBehavior == "Auto-Hide (macOS Dock)" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self = self else { return }
                let mouse = NSEvent.mouseLocation
                let screen = Self.resolveTargetScreen()
                let target = (self.lastTargetFrame != .zero) ? self.lastTargetFrame : self.frame
                if !DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouse, dockFrame: target) &&
                   !DockFrameCalculator.isMouseInTriggerZone(mouseLocation: mouse, screenFrame: screen.frame) {
                    self.hideDock(animated: true)
                }
            }
        }
    }

    override public var canBecomeKey: Bool {
        return false
    }

    override public var canBecomeMain: Bool {
        return false
    }

    public var canHideDock: Bool {
        guard AppSettings.shared.dockBehavior != "Always Visible" else { return false }
        guard !isInteracting else { return false }
        guard !AppLauncherService.shared.isEditMode else { return false }
        return true
    }

    // MARK: - Auto-Hide & Mouse Tracking

    private func setupMouseTracking() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleMouseMovement(at: NSEvent.mouseLocation)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMovement(at: NSEvent.mouseLocation)
            return event
        }

        // Periodic 0.1s check for instant edge-detection and smooth autohide responsiveness
        edgeTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkPeriodicMousePosition()
            }
        }
    }

    private func handleMouseMovement(at screenPoint: CGPoint) {
        let screen = Self.resolveTargetScreen()
        let behavior = AppSettings.shared.dockBehavior

        guard behavior != "Always Visible" else { return }

        let currentTargetFrame = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame

        if isDockHidden {
            if DockFrameCalculator.isMouseInTriggerZone(mouseLocation: screenPoint, screenFrame: screen.frame, threshold: 4.0) {
                revealDock(animated: true)
            }
        } else {
            if DockFrameCalculator.isMouseInDockBounds(mouseLocation: screenPoint, dockFrame: currentTargetFrame, safetyPadding: 20.0) {
                isHoveringDock = true
                cancelPendingHide()
            } else {
                if isHoveringDock {
                    isHoveringDock = false
                    scheduleHideDock(delay: 0.35)
                } else if behavior == "Auto-Hide (macOS Dock)" {
                    if pendingHideWorkItem == nil && canHideDock {
                        scheduleHideDock(delay: 0.35)
                    }
                } else if behavior == "Auto-Hide on Window Overlap" {
                    if DockFrameCalculator.doesAnyWindowOverlap(dockFrame: currentTargetFrame, screenFrame: screen.frame) {
                        if pendingHideWorkItem == nil && canHideDock {
                            scheduleHideDock(delay: 0.35)
                        }
                    }
                }
            }
        }
    }

    private func checkPeriodicMousePosition() {
        let behavior = AppSettings.shared.dockBehavior
        guard behavior != "Always Visible" else { return }

        let mouse = NSEvent.mouseLocation
        let screen = Self.resolveTargetScreen()
        let currentTargetFrame = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame

        if isDockHidden {
            if DockFrameCalculator.isMouseInTriggerZone(mouseLocation: mouse, screenFrame: screen.frame, threshold: 4.0) {
                revealDock(animated: true)
            }
        } else {
            let inDock = DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouse, dockFrame: currentTargetFrame, safetyPadding: 20.0)
            if inDock {
                isHoveringDock = true
                cancelPendingHide()
            } else {
                if behavior == "Auto-Hide (macOS Dock)" && canHideDock {
                    if pendingHideWorkItem == nil {
                        scheduleHideDock(delay: 0.35)
                    }
                } else if behavior == "Auto-Hide on Window Overlap" && canHideDock {
                    let hasOverlap = DockFrameCalculator.doesAnyWindowOverlap(dockFrame: currentTargetFrame, screenFrame: screen.frame)
                    if hasOverlap && pendingHideWorkItem == nil {
                        scheduleHideDock(delay: 0.35)
                    } else if !hasOverlap && isDockHidden {
                        revealDock(animated: true)
                    }
                }
            }
        }
    }

    public func revealDock(animated: Bool = true) {
        cancelPendingHide()
        guard isDockHidden else { return }
        isDockHidden = false
        isRevealedByMouse = true

        let targetFrame = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                self.animator().setFrame(targetFrame, display: true)
            }
        } else {
            self.setFrame(targetFrame, display: true)
        }
    }

    public func hideDock(animated: Bool = true) {
        guard !isDockHidden else { return }
        guard canHideDock else { return }

        let screen = Self.resolveTargetScreen()
        let currentTargetFrame = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame
        let hiddenFrame = DockFrameCalculator.calculateHiddenFrame(targetFrame: currentTargetFrame, screenFrame: screen.frame, lipHeight: 1.0)

        isDockHidden = true
        isRevealedByMouse = false

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                self.animator().setFrame(hiddenFrame, display: true)
            }
        } else {
            self.setFrame(hiddenFrame, display: true)
        }
    }

    public func scheduleHideDock(delay: TimeInterval = 0.35) {
        cancelPendingHide()
        guard canHideDock else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let mouseLoc = NSEvent.mouseLocation
            let targetFrame = (self.lastTargetFrame != .zero) ? self.lastTargetFrame : self.frame
            if !DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouseLoc, dockFrame: targetFrame, safetyPadding: 20.0) &&
               self.canHideDock {
                self.hideDock(animated: true)
            }
        }
        self.pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    public func cancelPendingHide() {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
    }

    @objc private func handleBehaviorChange() {
        let behavior = AppSettings.shared.dockBehavior
        if behavior == "Always Visible" {
            revealDock(animated: true)
        } else if behavior == "Auto-Hide (macOS Dock)" {
            let mouse = NSEvent.mouseLocation
            let target = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame
            if !DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouse, dockFrame: target) {
                scheduleHideDock(delay: 0.2)
            }
        } else if behavior == "Auto-Hide on Window Overlap" {
            let screen = Self.resolveTargetScreen()
            let target = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame
            let mouse = NSEvent.mouseLocation
            if DockFrameCalculator.doesAnyWindowOverlap(dockFrame: target, screenFrame: screen.frame) &&
               !DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouse, dockFrame: target) {
                scheduleHideDock(delay: 0.2)
            } else {
                revealDock(animated: true)
            }
        }
    }

    @objc private func handleAppActivation() {
        self.orderFrontRegardless()
        if AppSettings.shared.dockBehavior == "Auto-Hide on Window Overlap" {
            let screen = Self.resolveTargetScreen()
            let target = (lastTargetFrame != .zero) ? lastTargetFrame : self.frame
            let mouse = NSEvent.mouseLocation
            if DockFrameCalculator.doesAnyWindowOverlap(dockFrame: target, screenFrame: screen.frame) &&
               !DockFrameCalculator.isMouseInDockBounds(mouseLocation: mouse, dockFrame: target) {
                hideDock(animated: true)
            } else if !DockFrameCalculator.doesAnyWindowOverlap(dockFrame: target, screenFrame: screen.frame) {
                revealDock(animated: true)
            }
        } else {
            self.reposition()
        }
    }

    @objc private func menuDidBeginTracking() {
        isInteracting = true
        cancelPendingHide()
    }

    @objc private func menuDidEndTracking() {
        isInteracting = false
        let behavior = AppSettings.shared.dockBehavior
        if behavior != "Always Visible" {
            scheduleHideDock(delay: 0.45)
        }
    }

    @objc private func handleSpaceOrScreenChange() {
        self.orderFrontRegardless()
        self.reposition()
    }

    public static func resolveTargetScreen() -> NSScreen {
        let settings = AppSettings.shared
        switch settings.displayTarget {
        case "Follow Active Window", "Follow Mouse":
            let mouseLoc = NSEvent.mouseLocation
            if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) {
                return mouseScreen
            }
            if let mainScreen = NSScreen.main {
                return mainScreen
            }
            return NSScreen.screens.first ?? NSScreen()
        case "Display 1":
            return NSScreen.screens.first ?? NSScreen()
        case "Display 2":
            if NSScreen.screens.count > 1 {
                return NSScreen.screens[1]
            }
            return NSScreen.screens.first ?? NSScreen()
        default: // "Primary Display"
            return NSScreen.screens.first ?? NSScreen.main ?? NSScreen()
        }
    }

    @objc public func reposition() {
        let screen = Self.resolveTargetScreen()
        guard let host = hostingView else { return }

        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let bottomInset: CGFloat = 0.0
        let effectiveScale = DockFrameCalculator.effectiveScale(
            contentSize: fitting,
            requestedScale: AppSettings.shared.dockScale,
            visibleFrame: screen.visibleFrame,
            bottomInset: bottomInset
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
            visibleFrame: screen.visibleFrame,
            bottomInset: bottomInset
        )
        self.lastTargetFrame = targetFrame

        let behavior = AppSettings.shared.dockBehavior
        let destinationFrame: CGRect

        if behavior == "Always Visible" {
            isDockHidden = false
            destinationFrame = targetFrame
        } else if behavior == "Auto-Hide on Window Overlap" {
            let overlaps = DockFrameCalculator.doesAnyWindowOverlap(dockFrame: targetFrame, screenFrame: screen.frame)
            if overlaps && !isRevealedByMouse && !isHoveringDock && !isInteracting {
                isDockHidden = true
                destinationFrame = DockFrameCalculator.calculateHiddenFrame(targetFrame: targetFrame, screenFrame: screen.frame, lipHeight: 1.0)
            } else {
                destinationFrame = isDockHidden
                    ? DockFrameCalculator.calculateHiddenFrame(targetFrame: targetFrame, screenFrame: screen.frame, lipHeight: 1.0)
                    : targetFrame
            }
        } else { // "Auto-Hide (macOS Dock)"
            if isDockHidden && !isRevealedByMouse {
                destinationFrame = DockFrameCalculator.calculateHiddenFrame(targetFrame: targetFrame, screenFrame: screen.frame, lipHeight: 1.0)
            } else {
                destinationFrame = targetFrame
            }
        }

        // Do nothing when the target frame is unchanged
        let current = self.frame
        if abs(current.origin.x - destinationFrame.origin.x) < 0.5 &&
           abs(current.origin.y - destinationFrame.origin.y) < 0.5 &&
           abs(current.size.width - destinationFrame.size.width) < 0.5 &&
           abs(current.size.height - destinationFrame.size.height) < 0.5 {
            return
        }

        if current == .zero || abs(current.width - destinationFrame.width) > 300 {
            self.setFrame(destinationFrame, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(destinationFrame, display: true)
            }
        }
    }
}

/// Pure layout calculator for FlowDock window positioning and sizing.
/// Ensures the dock remains horizontally centered, attached or floating above screen bottom,
/// bounded by screen margins, and fully accounts for dockScale without clipping.
public struct DockFrameCalculator: Sendable {
    public static let defaultSafeMargin: CGFloat = 16.0
    public static let defaultBottomInset: CGFloat = 0.0
    public static let minDockWidth: CGFloat = 240.0
    public static let minDockHeight: CGFloat = 48.0

    public static func effectiveScale(
        contentSize: CGSize,
        requestedScale: Double,
        visibleFrame: CGRect,
        bottomInset: CGFloat? = nil,
        safeMargin: CGFloat = defaultSafeMargin
    ) -> CGFloat {
        let inset = bottomInset ?? defaultBottomInset
        let baseWidth = max(contentSize.width, minDockWidth)
        let baseHeight = max(contentSize.height, minDockHeight)
        let widthScale = max(visibleFrame.width - safeMargin * 2.0, 1.0) / baseWidth
        let heightScale = max(visibleFrame.height - inset - safeMargin, 1.0) / baseHeight
        return max(min(CGFloat(requestedScale), widthScale, heightScale), 0.01)
    }

    public static func calculateTargetFrame(
        contentSize: CGSize,
        scale: Double,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        bottomInset: CGFloat? = nil,
        safeMargin: CGFloat = defaultSafeMargin
    ) -> CGRect {
        let inset = bottomInset ?? defaultBottomInset
        // Base content dimensions bounded by minimum dock dimensions
        let baseWidth = max(contentSize.width, minDockWidth)
        let baseHeight = max(contentSize.height, minDockHeight)

        let clampedScale = effectiveScale(
            contentSize: contentSize,
            requestedScale: scale,
            visibleFrame: visibleFrame,
            bottomInset: inset,
            safeMargin: safeMargin
        )

        // Scaled dimensions to respect dockScale and prevent window clipping
        let scaledWidth = ceil(baseWidth * CGFloat(clampedScale))
        let scaledHeight = ceil(baseHeight * CGFloat(clampedScale))

        // Clamp width to visible screen width minus safe margins on both sides
        let maxAllowedWidth = max(visibleFrame.width - (safeMargin * 2.0), 1.0)
        let targetWidth = min(scaledWidth, maxAllowedWidth)

        // Clamp height so dock fits comfortably within visible area
        let maxAllowedHeight = max(visibleFrame.height - inset - safeMargin, 1.0)
        let targetHeight = min(scaledHeight, maxAllowedHeight)

        // Horizontally centered within the screen's visible area
        let x = round(visibleFrame.origin.x + (visibleFrame.width - targetWidth) / 2.0)

        // Fuses with the physical screen bottom, independent of the Apple Dock's visible frame.
        let y = round(screenFrame.origin.y + inset)

        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    public static func calculateHiddenFrame(
        targetFrame: CGRect,
        screenFrame: CGRect,
        lipHeight: CGFloat = 1.0
    ) -> CGRect {
        let hiddenY = screenFrame.origin.y - targetFrame.height + lipHeight
        return CGRect(x: targetFrame.origin.x, y: hiddenY, width: targetFrame.width, height: targetFrame.height)
    }

    public static func isMouseInTriggerZone(
        mouseLocation: CGPoint,
        screenFrame: CGRect,
        threshold: CGFloat = 4.0
    ) -> Bool {
        return mouseLocation.x >= screenFrame.minX &&
               mouseLocation.x <= screenFrame.maxX &&
               mouseLocation.y >= (screenFrame.minY - 5.0) &&
               mouseLocation.y <= (screenFrame.minY + threshold)
    }

    public static func isMouseInDockBounds(
        mouseLocation: CGPoint,
        dockFrame: CGRect,
        safetyPadding: CGFloat = 20.0
    ) -> Bool {
        let interactiveRect = CGRect(
            x: dockFrame.origin.x - 15,
            y: dockFrame.origin.y - 5,
            width: dockFrame.width + 30,
            height: dockFrame.height + safetyPadding + 5
        )
        return interactiveRect.contains(mouseLocation)
    }

    public static func doesAnyWindowOverlap(
        dockFrame: CGRect,
        screenFrame: CGRect,
        ignoreProcessIDs: Set<pid_t> = [ProcessInfo.processInfo.processIdentifier]
    ) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

        for win in list {
            guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let pid = win[kCGWindowOwnerPID as String] as? pid_t, ignoreProcessIDs.contains(pid) {
                continue
            }
            guard let boundsDict = win[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let width = boundsDict["Width"], let height = boundsDict["Height"] else {
                continue
            }
            // Ignore small utility / status windows
            if width < 150 || height < 150 { continue }

            // Quartz Y (from top) -> Cocoa Y (from bottom)
            let cocoaY = primaryHeight - (y + height)
            let winRect = CGRect(x: x, y: cocoaY, width: width, height: height)

            if winRect.intersects(dockFrame) {
                return true
            }
        }
        return false
    }
}
