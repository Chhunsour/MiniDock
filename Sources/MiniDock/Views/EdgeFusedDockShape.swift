import SwiftUI

/// Custom shape for the screen-edge integrated FlowDock.
/// Anchored flush against the screen bottom (y = height) with mathematically continuous
/// C¹ cubic bezier curves on left and right that emerge organically from the display edge.
public struct EdgeFusedDockShape: Shape {
    public var flareWidth: CGFloat = 36
    public var cornerRadius: CGFloat = 22
    
    public init(flareWidth: CGFloat = 36, cornerRadius: CGFloat = 22) {
        self.flareWidth = flareWidth
        self.cornerRadius = cornerRadius
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flareWidth, cornerRadius) }
        set {
            flareWidth = newValue.first
            cornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let fw = min(flareWidth, w * 0.16)
        let cr = min(cornerRadius, min(h * 0.42, (w - 2 * fw) / 4))
        let fr = min(fw * 0.72, h * 0.38)
        let alpha: CGFloat = 0.50
        
        // 1. Bottom-left anchor flush on screen boundary (y = h)
        path.move(to: CGPoint(x: 0, y: h))
        
        // 2. Bottom flat line across physical display edge
        path.addLine(to: CGPoint(x: w, y: h))
        
        // 3. Right concave flare rising smoothly from screen edge into vertical side wall
        path.addCurve(
            to: CGPoint(x: w - fw, y: h - fr),
            control1: CGPoint(x: w - fw * alpha, y: h),
            control2: CGPoint(x: w - fw, y: h - fr * (1 - alpha))
        )
        
        // 4. Right vertical wall
        path.addLine(to: CGPoint(x: w - fw, y: cr))
        
        // 5. Right convex shoulder rounding into top horizontal crest
        path.addCurve(
            to: CGPoint(x: w - fw - cr, y: 0),
            control1: CGPoint(x: w - fw, y: cr * (1 - alpha)),
            control2: CGPoint(x: w - fw - cr * (1 - alpha), y: 0)
        )
        
        // 6. Top horizontal crest
        path.addLine(to: CGPoint(x: fw + cr, y: 0))
        
        // 7. Top-left convex shoulder rounding down into left vertical wall
        path.addCurve(
            to: CGPoint(x: fw, y: cr),
            control1: CGPoint(x: fw + cr * (1 - alpha), y: 0),
            control2: CGPoint(x: fw, y: cr * (1 - alpha))
        )
        
        // 8. Left vertical wall
        path.addLine(to: CGPoint(x: fw, y: h - fr))
        
        // 9. Left concave flare curving outward to dissolve tangentially into bottom-left screen edge
        path.addCurve(
            to: CGPoint(x: 0, y: h),
            control1: CGPoint(x: fw, y: h - fr * (1 - alpha)),
            control2: CGPoint(x: fw * alpha, y: h)
        )
        
        path.closeSubpath()
        return path
    }
}

/// Outline path of only the exposed crest and upper shoulders.
/// Strictly omits the bottom boundary and lower flanks so FlowDock visually melts into the bezel.
public struct EdgeFusedDockRim: Shape {
    public var flareWidth: CGFloat = 36
    public var cornerRadius: CGFloat = 22
    
    public init(flareWidth: CGFloat = 36, cornerRadius: CGFloat = 22) {
        self.flareWidth = flareWidth
        self.cornerRadius = cornerRadius
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flareWidth, cornerRadius) }
        set {
            flareWidth = newValue.first
            cornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let fw = min(flareWidth, w * 0.16)
        let cr = min(cornerRadius, min(h * 0.42, (w - 2 * fw) / 4))
        let alpha: CGFloat = 0.50
        
        // Start on left wall slightly below shoulder
        path.move(to: CGPoint(x: fw, y: cr + 4))
        
        // Left vertical micro-lead
        path.addLine(to: CGPoint(x: fw, y: cr))
        
        // Left convex shoulder
        path.addCurve(
            to: CGPoint(x: fw + cr, y: 0),
            control1: CGPoint(x: fw, y: cr * (1 - alpha)),
            control2: CGPoint(x: fw + cr * (1 - alpha), y: 0)
        )
        
        // Top crest
        path.addLine(to: CGPoint(x: w - fw - cr, y: 0))
        
        // Right convex shoulder
        path.addCurve(
            to: CGPoint(x: w - fw, y: cr),
            control1: CGPoint(x: w - fw - cr * (1 - alpha), y: 0),
            control2: CGPoint(x: w - fw, y: cr * (1 - alpha))
        )
        
        // Right vertical micro-lead
        path.addLine(to: CGPoint(x: w - fw, y: cr + 4))
        
        return path
    }
}
