import AppKit
import SwiftUI
import Combine

public final class MiniDockPanel: NSPanel {
    private var hostingView: NSHostingView<DockContainerView>?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 90),
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
        
        let container = DockContainerView()
        let host = NSHostingView(rootView: container)
        self.contentView = host
        self.hostingView = host
        
        // Listen to screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Reposition when settings change
        AppSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.reposition()
                }
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
        let width = max(ceil(fitting.width) + 16, 400)
        let height = max(ceil(fitting.height) + 12, 65)
        
        // Center at bottom with 16pt floating margin
        let screenRect = screen.frame
        let x = screenRect.origin.x + (screenRect.width - width) / 2.0
        let y = screenRect.origin.y + 14.0
        
        let targetFrame = NSRect(x: x, y: y, width: width, height: height)
        
        if self.frame == .zero || abs(self.frame.width - targetFrame.width) > 300 {
            self.setFrame(targetFrame, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(targetFrame, display: true)
            }
        }
    }
}
