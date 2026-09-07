import SwiftUI

/// Compact screen-attached dock silhouette with short symmetric concave flares
/// that visually merge into the display edge, smooth rounded top shoulders, and a flat top crest.
public struct ScreenAttachedDockShape: Shape, Sendable {
    public var flareWidth: CGFloat
    public var flareHeight: CGFloat
    public var cornerRadius: CGFloat
    public var isClosed: Bool

    public init(
        flareWidth: CGFloat = 30.0,
        flareHeight: CGFloat = 18.0,
        cornerRadius: CGFloat = 16.0,
        isClosed: Bool = true
    ) {
        self.flareWidth = flareWidth
        self.flareHeight = flareHeight
        self.cornerRadius = cornerRadius
        self.isClosed = isClosed
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        // Defensive clamping for narrow or short dimensions
        let fw = max(0, min(flareWidth, rect.width / 4.0))
        let fh = max(0, min(flareHeight, rect.height / 2.0))
        let maxRadius = max(0, min((rect.width - 2.0 * fw) / 2.0, rect.height - fh))
        let r = max(0, min(cornerRadius, maxRadius))

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        // 1. Start at the bottom-left corner flush with the display edge
        path.move(to: CGPoint(x: minX, y: maxY))

        // 2. Left concave flare: smooth inward curve from horizontal display edge into vertical side wall
        path.addCurve(
            to: CGPoint(x: minX + fw, y: maxY - fh),
            control1: CGPoint(x: minX + fw * 0.5, y: maxY),
            control2: CGPoint(x: minX + fw, y: maxY - fh * 0.5)
        )

        // 3. Left vertical side wall
        path.addLine(to: CGPoint(x: minX + fw, y: minY + r))

        // 4. Top-left convex rounded shoulder
        if r > 0 {
            path.addCurve(
                to: CGPoint(x: minX + fw + r, y: minY),
                control1: CGPoint(x: minX + fw, y: minY + r * 0.4477),
                control2: CGPoint(x: minX + fw + r * 0.4477, y: minY)
            )
        }

        // 5. Flat top crest
        path.addLine(to: CGPoint(x: maxX - fw - r, y: minY))

        // 6. Top-right convex rounded shoulder
        if r > 0 {
            path.addCurve(
                to: CGPoint(x: maxX - fw, y: minY + r),
                control1: CGPoint(x: maxX - fw - r * 0.4477, y: minY),
                control2: CGPoint(x: maxX - fw, y: minY + r * 0.4477)
            )
        }

        // 7. Right vertical side wall
        path.addLine(to: CGPoint(x: maxX - fw, y: maxY - fh))

        // 8. Right concave flare: smooth outward curve from vertical side wall to horizontal display edge
        path.addCurve(
            to: CGPoint(x: maxX, y: maxY),
            control1: CGPoint(x: maxX - fw, y: maxY - fh * 0.5),
            control2: CGPoint(x: maxX - fw * 0.5, y: maxY)
        )

        // 9. If closed, span the bottom boundary to close the filled silhouette;
        //    if open (for exposed contour / rim stroke), omit the physical bottom edge.
        if isClosed {
            path.addLine(to: CGPoint(x: minX, y: maxY))
            path.closeSubpath()
        }

        return path
    }
}
