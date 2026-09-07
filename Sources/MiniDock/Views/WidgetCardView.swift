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
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.075 : 0))
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.88), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
    }
}
