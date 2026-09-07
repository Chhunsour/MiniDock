import SwiftUI

public struct TransientCapsuleView: View {
    @ObservedObject private var manager = TransientCapsuleManager.shared

    public init() {}

    public var body: some View {
        if let event = manager.activeEvent {
            Button(action: {
                manager.dismiss()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: event.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(event.color)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let detail = event.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: 120, alignment: .leading)

                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.leading, 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(event.color.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }
    }
}
