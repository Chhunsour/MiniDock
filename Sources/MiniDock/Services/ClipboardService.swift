import Foundation
import AppKit
import Combine

@MainActor
public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()
    
    @Published public var latestText: String = ""
    @Published public var previewText: String = "Empty"
    @Published public var characterCount: Int = 0
    @Published public var lastCopiedTime: Date? = nil
    
    private var lastChangeCount: Int = -1
    private var timer: AnyCancellable?
    private var isFirstPoll: Bool = true
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        DispatchQueue.main.async { [weak self] in
            self?.pollClipboard()
            self?.isFirstPoll = false
        }
        
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollClipboard()
            }
    }
    
    public func pollClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            self.latestText = string
            self.characterCount = string.count
            self.lastCopiedTime = Date()
            
            let preview = Self.sanitizePreview(string)
            self.previewText = preview
            
            // On subsequent copies, show transient capsule
            if !isFirstPoll {
                TransientCapsuleManager.shared.post(
                    icon: "doc.on.clipboard.fill",
                    title: "Copied to Clipboard",
                    detail: preview,
                    color: .purple,
                    duration: 3.2
                )
            }
        }
    }
    
    public func copyAgain() {
        guard !latestText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestText, forType: .string)
        TransientCapsuleManager.shared.post(
            icon: "checkmark",
            title: "Re-copied to Clipboard",
            detail: previewText,
            color: .green,
            duration: 2.0
        )
    }
    
    private static func sanitizePreview(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Privacy check: mask secrets, keys, and tokens
        let lower = trimmed.lowercased()
        if trimmed.hasPrefix("ghp_") || trimmed.hasPrefix("sk-") || trimmed.hasPrefix("xoxb-") ||
           lower.contains("bearer ") || lower.contains("private_key") || lower.contains("ssh-rsa") {
            return "Sensitive token (masked)"
        }
        
        let singleLine = trimmed
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        
        if singleLine.count > 26 {
            return String(singleLine.prefix(26)) + "…"
        } else if !singleLine.isEmpty {
            return singleLine
        } else {
            return "\(string.count) characters"
        }
    }
}
