import Foundation
import SwiftUI
import Combine

public struct TransientEvent: Identifiable, Equatable {
    public let id: UUID
    public let icon: String
    public let title: String
    public let detail: String?
    public let color: Color
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        icon: String,
        title: String,
        detail: String? = nil,
        color: Color = .blue,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.detail = detail
        self.color = color
        self.timestamp = timestamp
    }
}

@MainActor
public final class TransientCapsuleManager: ObservableObject {
    public static let shared = TransientCapsuleManager()
    
    @Published public var activeEvent: TransientEvent?
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    public func post(
        icon: String,
        title: String,
        detail: String? = nil,
        color: Color = .blue,
        duration: Double = 3.5
    ) {
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.activeEvent = TransientEvent(
                icon: icon,
                title: title,
                detail: detail,
                color: color
            )
        }
        
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    self.activeEvent = nil
                }
            }
        }
    }
    
    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            self.activeEvent = nil
        }
    }
}
