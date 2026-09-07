import AppKit
import Combine
import SwiftUI

// MARK: - Geometry Calculator (Pure logic, testable)

public struct ScrollGeometryCalculator {
    public static func calculateThumbHeight(
        contentHeight: CGFloat,
        visibleHeight: CGFloat,
        trackHeight: CGFloat,
        minThumbHeight: CGFloat = 28
    ) -> CGFloat {
        guard contentHeight > visibleHeight, visibleHeight > 0, contentHeight > 0, trackHeight > 0 else {
            return 0
        }
        let ratio = visibleHeight / contentHeight
        let rawHeight = trackHeight * ratio
        return min(trackHeight, max(minThumbHeight, rawHeight))
    }

    public static func calculateThumbOffset(
        scrollOffset: CGFloat,
        contentHeight: CGFloat,
        visibleHeight: CGFloat,
        trackHeight: CGFloat,
        thumbHeight: CGFloat
    ) -> CGFloat {
        let maxScroll = max(0, contentHeight - visibleHeight)
        guard maxScroll > 0 else { return 0 }
        let progress = max(0, min(1, scrollOffset / maxScroll))
        let travelDistance = max(0, trackHeight - thumbHeight)
        return progress * travelDistance
    }

    public static func calculateScrollOffset(
        thumbOffset: CGFloat,
        contentHeight: CGFloat,
        visibleHeight: CGFloat,
        trackHeight: CGFloat,
        thumbHeight: CGFloat
    ) -> CGFloat {
        let travelDistance = max(0, trackHeight - thumbHeight)
        guard travelDistance > 0 else { return 0 }
        let progress = max(0, min(1, thumbOffset / travelDistance))
        let maxScroll = max(0, contentHeight - visibleHeight)
        return progress * maxScroll
    }
}

// MARK: - AppKit Scroll View Bridge

@MainActor
public final class SleekScrollBridgeCoordinator: NSObject {
    public var onScrollChanged: ((_ offset: CGFloat, _ contentHeight: CGFloat, _ visibleHeight: CGFloat) -> Void)?
    public private(set) weak var targetScrollView: NSScrollView?

    public func attach(to view: NSView) {
        guard let sv = findScrollView(from: view) else { return }
        if targetScrollView === sv { return }
        detach()
        targetScrollView = sv

        // Disable standard macOS bulky scrollers completely
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        if let scroller = sv.verticalScroller {
            scroller.isHidden = true
        }

        sv.contentView.postsBoundsChangedNotifications = true
        sv.contentView.postsFrameChangedNotifications = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBoundsOrFrameChange),
            name: NSView.boundsDidChangeNotification,
            object: sv.contentView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBoundsOrFrameChange),
            name: NSView.frameDidChangeNotification,
            object: sv.contentView
        )

        if let doc = sv.documentView {
            doc.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBoundsOrFrameChange),
                name: NSView.frameDidChangeNotification,
                object: doc
            )
        }

        notify()
    }

    public func detach() {
        NotificationCenter.default.removeObserver(self)
        targetScrollView = nil
    }

    @objc private func handleBoundsOrFrameChange() {
        notify()
    }

    public func notify() {
        guard let sv = targetScrollView, let doc = sv.documentView else { return }
        let docHeight = doc.bounds.height
        let visibleHeight = sv.contentView.bounds.height
        let isFlipped = doc.isFlipped
        let originY = sv.contentView.bounds.origin.y
        let scrollOffset = isFlipped ? originY : max(0, docHeight - visibleHeight - originY)
        onScrollChanged?(scrollOffset, docHeight, visibleHeight)
    }

    public func scrollTo(offset: CGFloat) {
        guard let sv = targetScrollView, let doc = sv.documentView else { return }
        let docHeight = doc.bounds.height
        let visibleHeight = sv.contentView.bounds.height
        let maxScroll = max(0, docHeight - visibleHeight)
        let clampedOffset = max(0, min(maxScroll, offset))
        let isFlipped = doc.isFlipped
        let actualY = isFlipped ? clampedOffset : (docHeight - visibleHeight - clampedOffset)

        let newPoint = NSPoint(x: sv.contentView.bounds.origin.x, y: actualY)
        sv.contentView.scroll(to: newPoint)
        sv.reflectScrolledClipView(sv.contentView)
        notify()
    }

    private func findScrollView(from view: NSView) -> NSScrollView? {
        if let sv = view.enclosingScrollView { return sv }
        var current = view.superview
        while let v = current {
            if let sv = v as? NSScrollView { return sv }
            if let sv = v.subviews.compactMap({ $0 as? NSScrollView }).first { return sv }
            current = v.superview
        }
        return nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@MainActor
private final class SleekScrollBridgeCoordinatorWrapper: ObservableObject {
    let coordinator = SleekScrollBridgeCoordinator()
}

public struct SleekScrollBridgeView: NSViewRepresentable {
    public let coordinator: SleekScrollBridgeCoordinator

    public init(coordinator: SleekScrollBridgeCoordinator) {
        self.coordinator = coordinator
    }

    public func makeNSView(context: Context) -> NSView {
        let view = BridgeNSView()
        view.onLayout = { [weak coordinator] v in
            coordinator?.attach(to: v)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        coordinator.attach(to: nsView)
    }
}

private final class BridgeNSView: NSView {
    var onLayout: ((NSView) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onLayout?(self)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        onLayout?(self)
    }

    override func layout() {
        super.layout()
        onLayout?(self)
    }
}

// MARK: - Sleek Scroll Modifier & Indicator Overlay

public struct SleekScrollModifier: ViewModifier {
    @StateObject private var coordinatorWrapper = SleekScrollBridgeCoordinatorWrapper()
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var isScrolling = false
    @State private var hideWorkItem: DispatchWorkItem?

    private let topInset: CGFloat = 6
    private let bottomInset: CGFloat = 6
    private let trailingInset: CGFloat = 3

    public init() {}

    public func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .background(SleekScrollBridgeView(coordinator: coordinatorWrapper.coordinator))
            .overlay(alignment: .trailing) {
                indicatorOverlay
            }
            .onAppear {
                coordinatorWrapper.coordinator.onScrollChanged = { offset, docHeight, visHeight in
                    scrollOffset = offset
                    contentHeight = docHeight
                    visibleHeight = visHeight
                    triggerScrolling()
                }
            }
    }

    private var isIndicatorVisible: Bool {
        contentHeight > visibleHeight + 1 && (isScrolling || isHovered || isDragging)
    }

    private func triggerScrolling() {
        isScrolling = true
        hideWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.35)) {
                isScrolling = false
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    @ViewBuilder
    private var indicatorOverlay: some View {
        GeometryReader { geo in
            let effectiveVisibleHeight = visibleHeight > 0 ? visibleHeight : geo.size.height
            let trackHeight = max(0, effectiveVisibleHeight - topInset - bottomInset)
            let thumbHeight = ScrollGeometryCalculator.calculateThumbHeight(
                contentHeight: contentHeight,
                visibleHeight: effectiveVisibleHeight,
                trackHeight: trackHeight
            )
            let thumbOffset = ScrollGeometryCalculator.calculateThumbOffset(
                scrollOffset: scrollOffset,
                contentHeight: contentHeight,
                visibleHeight: effectiveVisibleHeight,
                trackHeight: trackHeight,
                thumbHeight: thumbHeight
            )

            if contentHeight > effectiveVisibleHeight + 1 {
                ZStack(alignment: .topTrailing) {
                    // Transparent interactive track gutter for clicking and dragging
                    Color.clear
                        .frame(width: isHovered || isDragging ? 14 : 10)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let targetThumbCenter = value.location.y - topInset
                                    let targetThumbOffset = targetThumbCenter - (thumbHeight / 2)
                                    let newScrollOffset = ScrollGeometryCalculator.calculateScrollOffset(
                                        thumbOffset: targetThumbOffset,
                                        contentHeight: contentHeight,
                                        visibleHeight: effectiveVisibleHeight,
                                        trackHeight: trackHeight,
                                        thumbHeight: thumbHeight
                                    )
                                    coordinatorWrapper.coordinator.scrollTo(offset: newScrollOffset)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    triggerScrolling()
                                }
                        )

                    // Refined, slim capsule thumb
                    Capsule(style: .continuous)
                        .fill(
                            Color.white.opacity(isDragging ? 0.52 : (isHovered ? 0.38 : 0.22))
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .frame(
                            width: isHovered || isDragging ? 6 : 4,
                            height: max(thumbHeight, 8)
                        )
                        .offset(
                            x: -trailingInset,
                            y: topInset + thumbOffset
                        )
                        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isHovered)
                        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isDragging)
                }
                .opacity(isIndicatorVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isIndicatorVisible)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        triggerScrolling()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .allowsHitTesting(isIndicatorVisible)
    }
}

// MARK: - View Extension & SleekScrollView Container

public extension View {
    func sleekScrollIndicators() -> some View {
        modifier(SleekScrollModifier())
    }
}

public struct SleekScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let content: Content

    public init(_ axes: Axis.Set = .vertical, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.content = content()
    }

    public var body: some View {
        ScrollView(axes, showsIndicators: false) {
            content
        }
        .sleekScrollIndicators()
    }
}
