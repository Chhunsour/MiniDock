import AppKit
import Combine
import CryptoKit
import Foundation

public struct ClipboardHistoryItem: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text
        case image
        case file
    }

    public let id: UUID
    public let kind: Kind
    public let text: String?
    public let filePath: String?
    public let createdAt: Date
    public let fingerprint: String

    public var title: String {
        switch kind {
        case .text:
            return text?.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? "Text"
        case .image:
            return "Copied Image"
        case .file:
            return filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        }
    }

    public var detail: String {
        switch kind {
        case .text:
            return "\(text?.count ?? 0) characters"
        case .image:
            return "Image"
        case .file:
            return filePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path } ?? "File"
        }
    }
}

public struct ScreenshotItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let createdAt: Date

    public var url: URL { URL(fileURLWithPath: path) }
    public var name: String { url.deletingPathExtension().lastPathComponent }
}

@MainActor
public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()

    @Published public private(set) var history: [ClipboardHistoryItem] = []
    @Published public private(set) var screenshots: [ScreenshotItem] = []
    @Published public private(set) var isLoadingScreenshots = false
    @Published public var latestText = ""
    @Published public var previewText = "Empty"
    @Published public var characterCount = 0
    @Published public var lastCopiedTime: Date?

    private let historyLimit = 200
    private var lastChangeCount = -1
    private var timer: AnyCancellable?
    private var isFirstPoll = true

    private var historyDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MiniDock/ClipboardHistory", isDirectory: true)
    }

    private var historyFile: URL { historyDirectory.appendingPathComponent("history.json") }

    private init() {
        loadHistory()
        lastChangeCount = NSPasteboard.general.changeCount

        DispatchQueue.main.async { [weak self] in
            self?.pollClipboard()
            self?.isFirstPoll = false
            self?.refreshScreenshots()
        }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.pollClipboard() }
    }

    public func pollClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], let url = urls.first {
            addFile(url)
            return
        }

        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let png = Self.pngData(from: data) {
            addImage(png)
            return
        }

        guard let string = pasteboard.string(forType: .string), !string.isEmpty else { return }
        latestText = string
        characterCount = string.count
        lastCopiedTime = Date()
        previewText = Self.sanitizePreview(string)

        if !(AppSettings.shared.maskSensitiveClipboard && Self.isSensitive(string)) {
            addHistoryItem(
                ClipboardHistoryItem(
                    id: UUID(),
                    kind: .text,
                    text: string,
                    filePath: nil,
                    createdAt: Date(),
                    fingerprint: "text:\(Self.digest(Data(string.utf8)))"
                )
            )
        }

        postCopiedEvent(detail: previewText)
    }

    public func copyAgain() {
        guard !latestText.isEmpty else { return }
        writeString(latestText)
        postRecopiedEvent(detail: previewText)
    }

    public func copy(_ item: ClipboardHistoryItem) {
        switch item.kind {
        case .text:
            guard let text = item.text else { return }
            latestText = text
            previewText = Self.sanitizePreview(text)
            characterCount = text.count
            writeString(text)
        case .image:
            guard let path = item.filePath, let image = NSImage(contentsOfFile: path) else { return }
            writeObjects([image])
        case .file:
            guard let path = item.filePath else { return }
            writeObjects([URL(fileURLWithPath: path) as NSURL])
        }
        postRecopiedEvent(detail: item.title)
    }

    public func copyScreenshot(_ screenshot: ScreenshotItem) {
        guard let image = NSImage(contentsOf: screenshot.url) else { return }
        writeObjects([image])
        postRecopiedEvent(detail: screenshot.name)
    }

    public func open(_ screenshot: ScreenshotItem) {
        NSWorkspace.shared.open(screenshot.url)
    }

    public func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    public func clearHistory() {
        for item in history where item.kind == .image {
            if let path = item.filePath { try? FileManager.default.removeItem(atPath: path) }
        }
        history = []
        saveHistory()
    }

    public func refreshScreenshots() {
        guard !isLoadingScreenshots else { return }
        isLoadingScreenshots = true
        Task {
            screenshots = await Task.detached(priority: .utility) {
                Self.discoverScreenshots()
            }.value
            isLoadingScreenshots = false
        }
    }

    public func setScreenshotsForTesting(_ items: [ScreenshotItem]) {
        self.screenshots = items
        self.isLoadingScreenshots = false
    }

    private func addFile(_ url: URL) {
        addHistoryItem(
            ClipboardHistoryItem(
                id: UUID(),
                kind: .file,
                text: nil,
                filePath: url.path,
                createdAt: Date(),
                fingerprint: "file:\(url.standardizedFileURL.path)"
            )
        )
        postCopiedEvent(detail: url.lastPathComponent)
    }

    private func addImage(_ data: Data) {
        let id = UUID()
        do {
            try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
            let url = historyDirectory.appendingPathComponent("\(id.uuidString).png")
            try data.write(to: url, options: .atomic)
            addHistoryItem(
                ClipboardHistoryItem(
                    id: id,
                    kind: .image,
                    text: nil,
                    filePath: url.path,
                    createdAt: Date(),
                    fingerprint: "image:\(Self.digest(data))"
                )
            )
            postCopiedEvent(detail: "Image")
        } catch {
            return
        }
    }

    private func addHistoryItem(_ item: ClipboardHistoryItem) {
        guard history.first?.fingerprint != item.fingerprint else { return }
        history.insert(item, at: 0)

        // ponytail: bounded local history avoids unbounded private-data storage; paginate before raising this cap.
        if history.count > historyLimit {
            let removed = history.suffix(from: historyLimit)
            for item in removed where item.kind == .image {
                if let path = item.filePath { try? FileManager.default.removeItem(atPath: path) }
            }
            history.removeSubrange(historyLimit...)
        }
        saveHistory()
    }

    private func writeString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func writeObjects(_ objects: [NSPasteboardWriting]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(objects)
        lastChangeCount = pasteboard.changeCount
    }

    private func postCopiedEvent(detail: String) {
        guard !isFirstPoll else { return }
        TransientCapsuleManager.shared.post(
            icon: "doc.on.clipboard.fill",
            title: "Saved to Clipboard History",
            detail: detail,
            color: .purple,
            duration: 2.6
        )
    }

    private func postRecopiedEvent(detail: String) {
        TransientCapsuleManager.shared.post(
            icon: "checkmark",
            title: "Copied",
            detail: detail,
            color: .green,
            duration: 1.8
        )
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFile),
              let saved = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) else { return }
        history = saved.filter { item in
            item.kind == .text || item.filePath.map(FileManager.default.fileExists(atPath:)) == true
        }
    }

    private func saveHistory() {
        do {
            try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(history).write(to: historyFile, options: .atomic)
        } catch {
            return
        }
    }

    public nonisolated static func discoverScreenshots() -> [ScreenshotItem] {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        task.arguments = ["kMDItemIsScreenCapture == 1"]
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return output
                .split(separator: "\n")
                .compactMap { path -> ScreenshotItem? in
                    let url = URL(fileURLWithPath: String(path))
                    guard FileManager.default.fileExists(atPath: url.path),
                          let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) else {
                        return nil
                    }
                    return ScreenshotItem(
                        path: url.path,
                        createdAt: values.creationDate ?? values.contentModificationDate ?? .distantPast
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }

    private nonisolated static func pngData(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func isSensitive(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return trimmed.hasPrefix("ghp_") || trimmed.hasPrefix("sk-") || trimmed.hasPrefix("xoxb-") ||
            lower.contains("bearer ") || lower.contains("private_key") || lower.contains("ssh-rsa")
    }

    nonisolated static func sanitizePreview(_ string: String) -> String {
        if isSensitive(string) { return "Sensitive content (not saved)" }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        if line.count > 38 { return String(line.prefix(38)) + "…" }
        return line.isEmpty ? "\(string.count) characters" : line
    }
}
