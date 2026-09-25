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
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                ZStack {
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
            )
            .scaleEffect(isHovered && isLiquidGlass ? 1.025 : 1.0)
            .offset(y: isHovered && isLiquidGlass ? -0.8 : 0)
            .shadow(
                color: Color.black.opacity(isHovered && isLiquidGlass ? 0.35 : 0),
                radius: 4,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.76), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
    }
}
