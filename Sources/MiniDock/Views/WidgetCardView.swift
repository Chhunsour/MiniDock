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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.22 : 0.12),
                                Color.white.opacity(isHovered ? 0.08 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
    }
}
