import SwiftUI

public struct WidgetCardView<Content: View>: View {
    let content: Content
    let onHoverChanged: ((Bool) -> Void)?

    @State private var isHovered = false

    public init(onHoverChanged: ((Bool) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onHoverChanged = onHoverChanged
        self.content = content()
    }

    public var body: some View {
        let isLiquidGlass = AppSettings.shared.isGlassLike
        let isAppleGlass = AppSettings.shared.isAppleGlass
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if isAppleGlass {
                        // Apple Design: Restful at rest (no box clutter), subtle frosted pill on hover
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(isHovered ? 0.10 : 0.0))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(isHovered ? 0.24 : 0.0), location: 0.0),
                                        .init(color: Color.white.opacity(isHovered ? 0.08 : 0.0), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.60
                            )
                    } else {
                        // 1. Double-Bezel Outer Glass Capsule Base
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.14 : (isLiquidGlass ? 0.052 : 0)),
                                        Color.white.opacity(isHovered ? 0.05 : (isLiquidGlass ? 0.016 : 0))
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // 2. Specular Top Rim Glint
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(isHovered ? 0.42 : (isLiquidGlass ? 0.18 : 0)), location: 0.0),
                                        .init(color: Color.white.opacity(isHovered ? 0.14 : (isLiquidGlass ? 0.05 : 0)), location: 0.45),
                                        .init(color: Color.clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.65
                            )
                    }
                }
            )
            .scaleEffect(isHovered && isLiquidGlass ? 1.02 : 1.0)
            .offset(y: isHovered && isLiquidGlass ? -0.5 : 0)
            .shadow(
                color: Color.black.opacity(isHovered && !isAppleGlass ? 0.35 : (isHovered && isAppleGlass ? 0.12 : 0)),
                radius: isAppleGlass ? 2 : 4,
                x: 0,
                y: 1
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.80), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
    }
}
