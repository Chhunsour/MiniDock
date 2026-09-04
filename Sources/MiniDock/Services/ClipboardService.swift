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
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        DispatchQueue.main.async { [weak self] in
            self?.pollClipboard()
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
            
            // Generate clean single-line preview
            let singleLine = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            
            if singleLine.count > 28 {
                self.previewText = String(singleLine.prefix(28)) + "…"
            } else if !singleLine.isEmpty {
                self.previewText = singleLine
            } else {
                self.previewText = "\(string.count) chars"
            }
        }
    }
}
