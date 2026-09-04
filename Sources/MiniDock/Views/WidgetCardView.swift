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
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.09 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.24 : 0.12),
                                Color.white.opacity(isHovered ? 0.08 : 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.15), radius: isHovered ? 5 : 2, x: 0, y: 1)
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
    }
}
