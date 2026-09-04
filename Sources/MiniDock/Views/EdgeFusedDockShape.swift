import SwiftUI

/// Custom shape for the screen-edge integrated dock.
/// Anchored flush against the screen bottom (y = height) with smooth
/// concave flare fillets on left and right that merge into the display edge.
public struct EdgeFusedDockShape: Shape {
    public var flareWidth: CGFloat = 26
    public var filletRadius: CGFloat = 20
    public var cornerRadius: CGFloat = 24
    
    public init(flareWidth: CGFloat = 26, filletRadius: CGFloat = 20, cornerRadius: CGFloat = 24) {
        self.flareWidth = flareWidth
        self.filletRadius = filletRadius
        self.cornerRadius = cornerRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let fw = min(flareWidth, w * 0.15)
        let fr = min(filletRadius, h * 0.4)
        let cr = min(cornerRadius, (w - 2 * fw) / 4)
        
        // 1. Bottom-left anchor on screen edge
        path.move(to: CGPoint(x: 0, y: h))
        
        // 2. Bottom flat edge across the screen boundary
        path.addLine(to: CGPoint(x: w, y: h))
        
        // 3. Right concave flare rising from screen edge into the right dock wall
        path.addCurve(
            to: CGPoint(x: w - fw, y: h - fr),
            control1: CGPoint(x: w - fw * 0.45, y: h),
            control2: CGPoint(x: w - fw, y: h - fr * 0.45)
        )
        
        // 4. Right vertical wall
        path.addLine(to: CGPoint(x: w - fw, y: cr))
        
        // 5. Top-right continuous corner
        path.addArc(
            center: CGPoint(x: w - fw - cr, y: cr),
            radius: cr,
            startAngle: .degrees(0),
            endAngle: .degrees(-90),
            clockwise: true
        )
        
        // 6. Top horizontal crest
        path.addLine(to: CGPoint(x: fw + cr, y: 0))
        
        // 7. Top-left continuous corner
        path.addArc(
            center: CGPoint(x: fw + cr, y: cr),
            radius: cr,
            startAngle: .degrees(-90),
            endAngle: .degrees(-180),
            clockwise: true
        )
        
        // 8. Left vertical wall
        path.addLine(to: CGPoint(x: fw, y: h - fr))
        
        // 9. Left concave flare curving outward to dissolve into bottom-left screen edge
        path.addCurve(
            to: CGPoint(x: 0, y: h),
            control1: CGPoint(x: fw, y: h - fr * 0.45),
            control2: CGPoint(x: fw * 0.45, y: h)
        )
        
        path.closeSubpath()
        return path
    }
}

/// Outline path of only the exposed crest and sides (excluding the bottom edge that sits on the bezel)
public struct EdgeFusedDockRim: Shape {
    public var flareWidth: CGFloat = 26
    public var filletRadius: CGFloat = 20
    public var cornerRadius: CGFloat = 24
    
    public init(flareWidth: CGFloat = 26, filletRadius: CGFloat = 20, cornerRadius: CGFloat = 24) {
        self.flareWidth = flareWidth
        self.filletRadius = filletRadius
        self.cornerRadius = cornerRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let fw = min(flareWidth, w * 0.15)
        let fr = min(filletRadius, h * 0.4)
        let cr = min(cornerRadius, (w - 2 * fw) / 4)
        
        // Start on bottom-left screen edge
        path.move(to: CGPoint(x: 0, y: h))
        
        // Left concave flare rising up
        path.addCurve(
            to: CGPoint(x: fw, y: h - fr),
            control1: CGPoint(x: fw * 0.45, y: h),
            control2: CGPoint(x: fw, y: h - fr * 0.45)
        )
        
        // Left vertical wall
        path.addLine(to: CGPoint(x: fw, y: cr))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: fw + cr, y: cr),
            radius: cr,
            startAngle: .degrees(-180),
            endAngle: .degrees(-90),
            clockwise: false
        )
        
        // Top horizontal crest
        path.addLine(to: CGPoint(x: w - fw - cr, y: 0))
        
        // Top-right corner
        path.addArc(
            center: CGPoint(x: w - fw - cr, y: cr),
            radius: cr,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right vertical wall
        path.addLine(to: CGPoint(x: w - fw, y: h - fr))
        
        // Right concave flare going down to screen edge
        path.addCurve(
            to: CGPoint(x: w, y: h),
            control1: CGPoint(x: w - fw, y: h - fr * 0.45),
            control2: CGPoint(x: w - fw * 0.45, y: h)
        )
        
        return path
    }
}
