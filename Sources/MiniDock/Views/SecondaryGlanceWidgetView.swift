import AppKit
import QuickLookThumbnailing
import SwiftUI

public struct SecondaryGlanceWidgetView: View {
    @ObservedObject private var clipboard = ClipboardService.shared
    @State private var showingLibrary = false

    public init() {}

    public var body: some View {
        WidgetCardView {
            Button {
                showingLibrary.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(width: 16, height: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(clipboard.history.first?.title ?? "Clipboard Library")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)

                        Text("\(clipboard.history.count) copied · \(clipboard.screenshots.count) shots")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }
                    .frame(width: 112, alignment: .leading)
                }
                .frame(width: 136, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clipboard & Screenshots")
            .accessibilityLabel("Clipboard and Screenshots")
            .accessibilityValue("\(clipboard.history.count) copied items and \(clipboard.screenshots.count) screenshots")
            .popover(isPresented: $showingLibrary, arrowEdge: .top) {
                ClipboardLibraryPopover(clipboard: clipboard)
            }
        }
    }
}

private enum LibraryTab: String, CaseIterable, Identifiable {
    case all = "All"
    case clipboard = "Copied"
    case screenshots = "Screenshots"

    var id: Self { self }
}

private struct ClipboardLibraryPopover: View {
    @ObservedObject var clipboard: ClipboardService
    @State private var selectedTab = LibraryTab.all
    @State private var searchText = ""
    @State private var showingClearConfirmation = false

    private var filteredHistory: [ClipboardHistoryItem] {
        guard !searchText.isEmpty else { return clipboard.history }
        return clipboard.history.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.text?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.detail.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredScreenshots: [ScreenshotItem] {
        guard !searchText.isEmpty else { return clipboard.screenshots }
        return clipboard.screenshots.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.35)

            Group {
                switch selectedTab {
                case .all:
                    if filteredHistory.isEmpty {
                        screenshotGrid(columnCount: 3)
                    } else if filteredScreenshots.isEmpty {
                        clipboardList(compact: false)
                    } else {
                        HStack(spacing: 0) {
                            clipboardList(compact: true)
                                .frame(width: 270)
                            Divider().opacity(0.35)
                            screenshotGrid(columnCount: 2)
                        }
                    }
                case .clipboard:
                    clipboardList(compact: false)
                case .screenshots:
                    screenshotGrid(columnCount: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 490)
        .background(.regularMaterial)
        .onAppear { clipboard.refreshScreenshots() }
        .alert("Clear Clipboard History?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) { clipboard.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved copied text, files, and copied images. Your screenshots are not deleted.")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard Library")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(clipboard.history.count) copied items · \(clipboard.screenshots.count) screenshots")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)

                Spacer()

                Button {
                    clipboard.refreshScreenshots()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(clipboard.isLoadingScreenshots)
                .help("Refresh Screenshots")

                Menu {
                    Button("Clear Clipboard History", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(clipboard.history.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            HStack(spacing: 10) {
                Picker("Library", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField("Search copied items and screenshots", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func clipboardList(compact: Bool) -> some View {
        if filteredHistory.isEmpty {
            EmptyLibraryView(
                icon: "doc.on.clipboard",
                title: searchText.isEmpty ? "Nothing copied yet" : "No copied items found",
                message: searchText.isEmpty ? "Anything you copy while MiniDock is running appears here." : "Try a different search."
            )
        } else {
            SleekScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(filteredHistory) { item in
                        ClipboardHistoryRow(item: item, compact: compact) {
                            clipboard.copy(item)
                        } reveal: {
                            if let path = item.filePath { clipboard.reveal(path) }
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func screenshotGrid(columnCount: Int) -> some View {
        if clipboard.isLoadingScreenshots && clipboard.screenshots.isEmpty {
            ProgressView("Finding screenshots…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredScreenshots.isEmpty {
            EmptyLibraryView(
                icon: "photo.on.rectangle.angled",
                title: searchText.isEmpty ? "No screenshots found" : "No screenshots found",
                message: searchText.isEmpty ? "macOS screenshots indexed by Spotlight appear here." : "Try a different search."
            )
        } else {
            SleekScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount),
                    spacing: 10
                ) {
                    ForEach(filteredScreenshots) { screenshot in
                        ScreenshotCard(
                            item: screenshot,
                            thumbnailSize: columnCount == 2
                                ? CGSize(width: 132, height: 78)
                                : CGSize(width: 180, height: 104)
                        ) {
                            clipboard.open(screenshot)
                        } copy: {
                            clipboard.copyScreenshot(screenshot)
                        } reveal: {
                            clipboard.reveal(screenshot.path)
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    let compact: Bool
    let copy: () -> Void
    let reveal: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            HistoryItemPreview(item: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 11, weight: .medium, design: item.kind == .text ? .monospaced : .default))
                    .lineLimit(compact ? 1 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 5) {
                    Text(item.detail)
                    Text("·")
                    Text(item.createdAt, style: .relative)
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }

            Button(action: copy) {
                Image(systemName: "doc.on.doc")
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(isHovered ? 0.09 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(8)
        .background(.white.opacity(isHovered ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy", action: copy)
            if item.kind != .text { Button("Show in Finder", action: reveal) }
        }
    }
}

private struct HistoryItemPreview: View {
    let item: ClipboardHistoryItem

    var body: some View {
        Group {
            if item.kind == .image, let path = item.filePath {
                FileThumbnail(path: path, size: CGSize(width: 44, height: 36))
            } else {
                Image(systemName: item.kind == .file ? "doc" : "text.alignleft")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 36)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct ScreenshotCard: View {
    let item: ScreenshotItem
    let thumbnailSize: CGSize
    let open: () -> Void
    let copy: () -> Void
    let reveal: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    FileThumbnail(path: item.path, size: thumbnailSize)

                    if isHovered {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                    }
                }

                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(7)
            .background(.white.opacity(isHovered ? 0.075 : 0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Open \(item.name)")
        .contextMenu {
            Button("Open", action: open)
            Button("Copy Image", action: copy)
            Button("Show in Finder", action: reveal)
        }
    }
}

private struct FileThumbnail: View {
    let path: String
    let size: CGSize
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.05))
                    .overlay { ProgressView().controlSize(.small) }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: path) {
            let request = QLThumbnailGenerator.Request(
                fileAt: URL(fileURLWithPath: path),
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2,
                representationTypes: .thumbnail
            )
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
    }
}

private struct EmptyLibraryView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }
}
