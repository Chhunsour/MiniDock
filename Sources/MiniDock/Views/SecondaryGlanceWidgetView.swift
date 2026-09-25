import AppKit
import QuickLookThumbnailing
import SwiftUI

public struct SecondaryGlanceWidgetView: View {
    @ObservedObject private var clipboard = ClipboardService.shared
    @State private var showingLibrary = false
    @State private var isHovered = false

    public init() {}

    public var body: some View {
        let isLiquidGlass = AppSettings.shared.isGlassLike
        WidgetCardView(onHoverChanged: { isHovered = $0 }) {
            Button {
                showingLibrary.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isHovered ? .white : .white.opacity(0.80))
                        .scaleEffect(isHovered ? 1.14 : 1.0)
                        .offset(y: isHovered ? -0.8 : 0)
                        .shadow(color: Color.white.opacity(isHovered ? 0.35 : 0), radius: 2)
                        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
                        .frame(width: 14, height: 14)

                    if isLiquidGlass {
                        Text("\(clipboard.history.count)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isHovered ? .white : .white.opacity(0.85))
                            .monospacedDigit()
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.08))
                            )
                            .scaleEffect(isHovered ? 1.06 : 1.0)
                            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
                    } else {
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
                }
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clipboard & Screenshots (\(clipboard.history.count) copied · \(clipboard.screenshots.count) shots)")
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

private enum UnifiedLibraryItem: Identifiable {
    case clipboard(ClipboardHistoryItem)
    case screenshot(ScreenshotItem)

    var id: String {
        switch self {
        case .clipboard(let item): return "clip_\(item.id.uuidString)"
        case .screenshot(let item): return "shot_\(item.id)"
        }
    }

    var createdAt: Date {
        switch self {
        case .clipboard(let item): return item.createdAt
        case .screenshot(let item): return item.createdAt
        }
    }
}

public struct ClipboardLibraryPopover: View {
    @ObservedObject var clipboard: ClipboardService
    @State private var selectedTab = LibraryTab.all
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @State private var copiedItemId: String? = nil

    public init(
        clipboard: ClipboardService = .shared,
        initialTab: String = "All",
        initialSearch: String = ""
    ) {
        self.clipboard = clipboard
        self._selectedTab = State(initialValue: LibraryTab(rawValue: initialTab) ?? .all)
        self._searchText = State(initialValue: initialSearch)
    }

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

    private var unifiedItems: [UnifiedLibraryItem] {
        let clips = filteredHistory.map { UnifiedLibraryItem.clipboard($0) }
        let shots = filteredScreenshots.map { UnifiedLibraryItem.screenshot($0) }
        return (clips + shots).sorted { $0.createdAt > $1.createdAt }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            // Horizon Specular Gradient Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.12),
                            .init(color: Color.white.opacity(0.28), location: 0.50),
                            .init(color: Color.white.opacity(0.12), location: 0.88),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.75)

            Group {
                switch selectedTab {
                case .all:
                    unifiedList
                case .clipboard:
                    clipboardList
                case .screenshots:
                    screenshotGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 660, height: 520)
        .background {
            ZStack {
                // Pitch-black obsidian glass
                Color(red: 0.03, green: 0.03, blue: 0.05).opacity(0.96)
                Rectangle().fill(.ultraThinMaterial)

                // Luminous ambient top-down light wash
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.cyan.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .overlay {
            // Radiant Specular Rim Light
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.42), location: 0.0),
                            .init(color: Color.white.opacity(0.22), location: 0.18),
                            .init(color: Color.white.opacity(0.09), location: 0.55),
                            .init(color: Color.white.opacity(0.04), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.85
                )
        }
        .overlay(alignment: .top) {
            // Micro Specular Light Flare at the top edge
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.65), Color.cyan.opacity(0.45), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 260, height: 1.5)
                .blur(radius: 0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.white.opacity(0.06), radius: 30, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
        .onAppear { clipboard.refreshScreenshots() }
        .alert("Clear Clipboard History?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) { clipboard.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved copied text, files, and copied images. Your screenshots are not deleted.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // Top Bar: Title, Stats, Refresh, Clear
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.14)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.75
                                    )
                            )
                            .shadow(color: Color.white.opacity(0.14), radius: 6, x: 0, y: 0)
                            .frame(width: 28, height: 28)

                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.white.opacity(0.40), radius: 3)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipboard Library")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))

                        HStack(spacing: 4) {
                            Text("\(clipboard.history.count) copied")
                            Text("·")
                            Text("\(clipboard.screenshots.count) screenshots")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        clipboard.refreshScreenshots()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.80))
                            .rotationEffect(.degrees(clipboard.isLoadingScreenshots ? 360 : 0))
                            .animation(
                                clipboard.isLoadingScreenshots
                                    ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                                    : .default,
                                value: clipboard.isLoadingScreenshots
                            )
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
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
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.80))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            }

            // Controls Bar: Frosted Switcher + Spotlight Search Bar
            HStack(spacing: 12) {
                FrostedTabPicker(selectedTab: $selectedTab)

                SpotlightSearchBar(text: $searchText)
            }
        }
        .padding(14)
    }

    // MARK: - Views for Tabs

    @ViewBuilder
    private var unifiedList: some View {
        if unifiedItems.isEmpty {
            EmptyLibraryView(
                icon: "doc.on.clipboard",
                title: searchText.isEmpty ? "Clipboard is empty" : "No items found",
                message: searchText.isEmpty ? "Items you copy or screenshots you take will appear in this unified stream." : "Try a different keyword."
            )
        } else {
            SleekScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(unifiedItems) { unified in
                        switch unified {
                        case .clipboard(let item):
                            ClipboardHistoryRow(
                                item: item,
                                copiedId: $copiedItemId,
                                copy: { copyWithFeedback(id: unified.id) { clipboard.copy(item) } },
                                reveal: { if let path = item.filePath { clipboard.reveal(path) } }
                            )
                        case .screenshot(let shot):
                            ScreenshotUnifiedRow(
                                item: shot,
                                copiedId: $copiedItemId,
                                open: { clipboard.open(shot) },
                                copy: { copyWithFeedback(id: unified.id) { clipboard.copyScreenshot(shot) } },
                                reveal: { clipboard.reveal(shot.path) }
                            )
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private var clipboardList: some View {
        if filteredHistory.isEmpty {
            EmptyLibraryView(
                icon: "doc.on.clipboard",
                title: searchText.isEmpty ? "Nothing copied yet" : "No copied items found",
                message: searchText.isEmpty ? "Anything you copy while MiniDock is running appears here." : "Try a different search."
            )
        } else {
            SleekScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredHistory) { item in
                        ClipboardHistoryRow(
                            item: item,
                            copiedId: $copiedItemId,
                            copy: { copyWithFeedback(id: "clip_\(item.id.uuidString)") { clipboard.copy(item) } },
                            reveal: { if let path = item.filePath { clipboard.reveal(path) } }
                        )
                    }
                }
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private var screenshotGrid: some View {
        if clipboard.isLoadingScreenshots && clipboard.screenshots.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Finding screenshots…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredScreenshots.isEmpty {
            EmptyLibraryView(
                icon: "photo.on.rectangle.angled",
                title: searchText.isEmpty ? "No screenshots found" : "No screenshots found",
                message: searchText.isEmpty ? "macOS screenshots indexed by Spotlight appear here." : "Try searching by file name."
            )
        } else {
            SleekScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(filteredScreenshots) { screenshot in
                        ScreenshotCard(
                            item: screenshot,
                            copiedId: $copiedItemId,
                            open: { clipboard.open(screenshot) },
                            copy: { copyWithFeedback(id: "shot_\(screenshot.id)") { clipboard.copyScreenshot(screenshot) } },
                            reveal: { clipboard.reveal(screenshot.path) }
                        )
                    }
                }
                .padding(14)
            }
        }
    }

    private func copyWithFeedback(id: String, action: () -> Void) {
        action()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            copiedItemId = id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            if copiedItemId == id {
                withAnimation(.easeOut(duration: 0.25)) {
                    copiedItemId = nil
                }
            }
        }
    }
}

// MARK: - Frosted Tab Picker

private struct FrostedTabPicker: View {
    @Binding var selectedTab: LibraryTab
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.16)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.75
                                            )
                                    )
                                    .shadow(color: Color.white.opacity(0.20), radius: 5, y: 1)
                                    .matchedGeometryEffect(id: "ActiveTabIndicator", in: tabAnimation)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.6
                        )
                )
        )
    }
}

// MARK: - Spotlight Search Bar

private struct SpotlightSearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFocused ? Color.cyan.opacity(0.9) : .white.opacity(0.45))
                .shadow(color: isFocused ? Color.cyan.opacity(0.5) : .clear, radius: 4)

            TextField("Search snippets, links, files, shots…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(.white)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.60))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isFocused ? 0.10 : 0.05),
                            Color.white.opacity(isFocused ? 0.05 : 0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isFocused ? 0.45 : 0.18),
                                    Color.white.opacity(isFocused ? 0.20 : 0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: isFocused ? 0.85 : 0.5
                        )
                )
        )
        .shadow(color: isFocused ? Color.white.opacity(0.12) : Color.clear, radius: 6)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Content Badge Helper

private enum ClipboardBadge {
    case color(Color, hex: String)
    case url(URL, host: String)
    case code(lineCount: Int)
    case file(name: String, ext: String)
    case image
    case text(charCount: Int)

    static func detect(for item: ClipboardHistoryItem) -> ClipboardBadge {
        if item.kind == .image { return .image }
        if item.kind == .file {
            let ext = item.filePath.map { URL(fileURLWithPath: $0).pathExtension.uppercased() } ?? "FILE"
            return .file(name: item.title, ext: ext.isEmpty ? "FILE" : ext)
        }
        guard let text = item.text else { return .text(charCount: 0) }

        // 1. Detect Hex Color
        if let col = parseHexColor(text) {
            let hex = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return .color(col, hex: hex)
        }

        // 2. Detect URL
        if let (url, host) = parseURL(text) {
            return .url(url, host: host)
        }

        // 3. Detect Code
        if isLikelyCode(text) {
            let lines = text.components(separatedBy: .newlines).count
            return .code(lineCount: lines)
        }

        return .text(charCount: text.count)
    }

    private static func parseHexColor(_ raw: String) -> Color? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.hasPrefix("#") else { return nil }
        hex.removeFirst()
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        var intVal: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&intVal) else { return nil }
        let r, g, b, a: Double
        if hex.count == 3 {
            r = Double((intVal >> 8) * 17) / 255.0
            g = Double(((intVal >> 4) & 0xF) * 17) / 255.0
            b = Double((intVal & 0xF) * 17) / 255.0
            a = 1.0
        } else if hex.count == 6 {
            r = Double((intVal >> 16) & 0xFF) / 255.0
            g = Double((intVal >> 8) & 0xFF) / 255.0
            b = Double(intVal & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((intVal >> 24) & 0xFF) / 255.0
            g = Double((intVal >> 16) & 0xFF) / 255.0
            b = Double((intVal >> 8) & 0xFF) / 255.0
            a = Double(intVal & 0xFF) / 255.0
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private static func parseURL(_ raw: String) -> (URL, String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
              let url = URL(string: trimmed),
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return (url, host.replacingOccurrences(of: "www.", with: ""))
    }

    private static func isLikelyCode(_ text: String) -> Bool {
        let codeMarkers = [
            "func ", "def ", "class ", "struct ", "var ", "let ", "const ",
            "import ", "return ", "if (", "if let", "guard let", "<div>",
            "console.log", "SELECT ", "public ", "private ", "extension ",
            "function ", "=>", "{", "}"
        ]
        let lines = text.components(separatedBy: .newlines)
        let markerMatches = codeMarkers.filter { text.contains($0) }.count
        if lines.count >= 2 && markerMatches >= 2 { return true }
        if lines.count >= 3 && (text.contains("  ") || text.contains("\t")) { return true }
        return false
    }
}

// MARK: - Clipboard History Row

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    @Binding var copiedId: String?
    let copy: () -> Void
    let reveal: () -> Void

    @State private var isHovered = false

    private var badge: ClipboardBadge {
        ClipboardBadge.detect(for: item)
    }

    private var isCopied: Bool {
        copiedId == "clip_\(item.id.uuidString)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Leading Badge / Icon
            badgeIconView
                .frame(width: 36, height: 36)

            // Content Hierarchy
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    badgePillView

                    Text(item.title)
                        .font(.system(size: 11.5, weight: .semibold, design: titleDesign))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                }

                if let previewSnippet = previewSnippet, !previewSnippet.isEmpty {
                    Text(previewSnippet)
                        .font(.system(size: 10, design: titleDesign))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(item.detail)
                    Text("·")
                    Text(item.createdAt, style: .relative)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 6) {
                if item.kind == .file {
                    Button(action: reveal) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.45))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(isHovered ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }

                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: isCopied ? .bold : .medium))
                        if isCopied {
                            Text("Copied")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(isCopied ? Color(red: 0.35, green: 0.90, blue: 0.50) : (isHovered ? .white : .white.opacity(0.70)))
                    .padding(.horizontal, isCopied ? 8 : 6)
                    .frame(height: 26)
                    .background(
                        isCopied
                            ? Color(red: 0.20, green: 0.70, blue: 0.35).opacity(0.20)
                            : Color.white.opacity(isHovered ? 0.10 : 0.04),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isCopied ? Color.green.opacity(0.35) : Color.white.opacity(isHovered ? 0.12 : 0.05),
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Copy to Clipboard")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.085 : 0.035),
                                Color.white.opacity(isHovered ? 0.035 : 0.012)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isHovered ? 0.40 : 0.15), location: 0.0),
                                .init(color: Color.white.opacity(isHovered ? 0.20 : 0.07), location: 0.35),
                                .init(color: Color.white.opacity(isHovered ? 0.08 : 0.02), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHovered ? 0.75 : 0.5
                    )
            }
        )
        .shadow(color: isHovered ? Color.white.opacity(0.08) : Color.clear, radius: 8, y: 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy", action: copy)
            if item.kind != .text { Button("Show in Finder", action: reveal) }
        }
    }

    private var titleDesign: Font.Design {
        switch badge {
        case .code, .color: return .monospaced
        default: return .default
        }
    }

    private var previewSnippet: String? {
        guard let text = item.text else { return nil }
        let lines = text.components(separatedBy: .newlines)
        if lines.count > 1 {
            return lines.dropFirst().first?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    @ViewBuilder
    private var badgeIconView: some View {
        switch badge {
        case .color(let color, _):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75))
                    .shadow(color: color.opacity(0.45), radius: 4)
            }
        case .url:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.22), Color.blue.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.35), lineWidth: 0.5)
                    )
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.40, green: 0.75, blue: 1.0))
                    .shadow(color: Color.blue.opacity(0.4), radius: 3)
            }
        case .code:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color.purple.opacity(0.22), Color.purple.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.purple.opacity(0.35), lineWidth: 0.5)
                    )
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.80, green: 0.60, blue: 1.0))
                    .shadow(color: Color.purple.opacity(0.4), radius: 3)
            }
        case .file(_, let ext):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color.orange.opacity(0.20), Color.orange.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.5)
                    )
                Text(ext.prefix(3).uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.35))
                    .shadow(color: Color.orange.opacity(0.4), radius: 3)
            }
        case .image:
            if let path = item.filePath {
                FileThumbnail(path: path, size: CGSize(width: 36, height: 36))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color.green.opacity(0.20), Color.green.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.35), lineWidth: 0.5)
                        )
                    Image(systemName: "photo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.40, green: 0.90, blue: 0.55))
                        .shadow(color: Color.green.opacity(0.4), radius: 3)
                }
            }
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
            }
        }
    }

    @ViewBuilder
    private var badgePillView: some View {
        switch badge {
        case .color(_, let hex):
            Text(hex)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.35))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.38), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.orange.opacity(0.25), radius: 3)
        case .url(_, let host):
            Text(host)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.40, green: 0.75, blue: 1.0))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.blue.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.40), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.blue.opacity(0.25), radius: 3)
        case .code(let lines):
            Text("\(lines) lines")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.78, green: 0.55, blue: 1.0))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.purple.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.purple.opacity(0.40), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.purple.opacity(0.25), radius: 3)
        case .file(_, let ext):
            Text(ext.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.35))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.38), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.orange.opacity(0.25), radius: 3)
        case .image:
            Text("IMAGE")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.40, green: 0.90, blue: 0.55))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.green.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.38), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.green.opacity(0.25), radius: 3)
        case .text:
            EmptyView()
        }
    }
}

// MARK: - Screenshot Unified Row (for "All" timeline)

private struct ScreenshotUnifiedRow: View {
    let item: ScreenshotItem
    @Binding var copiedId: String?
    let open: () -> Void
    let copy: () -> Void
    let reveal: () -> Void

    @State private var isHovered = false

    private var isCopied: Bool {
        copiedId == "shot_\(item.id)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail preview
            FileThumbnail(path: item.path, size: CGSize(width: 60, height: 40))

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("SHOT")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.35, green: 0.90, blue: 1.0))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.cyan.opacity(0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Color.cyan.opacity(0.42), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: Color.cyan.opacity(0.30), radius: 3)

                    Text(item.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 8.5))
                    Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    Text("·")
                    Text(item.createdAt, style: .relative)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 6) {
                Button(action: open) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.45))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(isHovered ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Open Screenshot")

                Button(action: reveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.45))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(isHovered ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show in Finder")

                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: isCopied ? .bold : .medium))
                        if isCopied {
                            Text("Copied")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(isCopied ? Color(red: 0.35, green: 0.90, blue: 0.50) : (isHovered ? .white : .white.opacity(0.70)))
                    .padding(.horizontal, isCopied ? 8 : 6)
                    .frame(height: 26)
                    .background(
                        isCopied
                            ? Color(red: 0.20, green: 0.70, blue: 0.35).opacity(0.20)
                            : Color.white.opacity(isHovered ? 0.10 : 0.04),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isCopied ? Color.green.opacity(0.35) : Color.white.opacity(isHovered ? 0.12 : 0.05),
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Copy Image")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.085 : 0.035),
                                Color.white.opacity(isHovered ? 0.035 : 0.012)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isHovered ? 0.40 : 0.15), location: 0.0),
                                .init(color: Color.white.opacity(isHovered ? 0.20 : 0.07), location: 0.35),
                                .init(color: Color.white.opacity(isHovered ? 0.08 : 0.02), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHovered ? 0.75 : 0.5
                    )
            }
        )
        .shadow(color: isHovered ? Color.white.opacity(0.08) : Color.clear, radius: 8, y: 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open", action: open)
            Button("Copy Image", action: copy)
            Button("Show in Finder", action: reveal)
        }
    }
}

// MARK: - Screenshot Card (for 3-Column Gallery)

private struct ScreenshotCard: View {
    let item: ScreenshotItem
    @Binding var copiedId: String?
    let open: () -> Void
    let copy: () -> Void
    let reveal: () -> Void

    @State private var isHovered = false

    private var isCopied: Bool {
        copiedId == "shot_\(item.id)"
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail with Hover Action Bar
                ZStack(alignment: .bottomTrailing) {
                    FileThumbnail(
                        path: item.path,
                        size: CGSize(width: 194, height: 120)
                    )

                    // Floating Glass Actions Pill
                    if isHovered || isCopied {
                        HStack(spacing: 4) {
                            Button(action: copy) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9.5, weight: isCopied ? .bold : .semibold))
                                    .foregroundStyle(isCopied ? Color(red: 0.35, green: 0.90, blue: 0.50) : .white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.75), in: Circle())
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Copy Image")

                            Button(action: reveal) {
                                Image(systemName: "folder")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.75), in: Circle())
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Show in Finder")

                            Button(action: open) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.75), in: Circle())
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Open in Preview")
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color.white.opacity(0.40), location: 0.0),
                                                    .init(color: Color.white.opacity(0.15), location: 1.0)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .shadow(color: Color.black.opacity(0.40), radius: 6, y: 2)
                        .padding(6)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                // Footer Metadata with Zero Collision Guaranteed
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8.5))
                        Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        Spacer(minLength: 4)
                        Text("PNG")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.40, green: 0.90, blue: 0.55))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .strokeBorder(Color.green.opacity(0.35), lineWidth: 0.5)
                                    )
                            )
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
            .padding(8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.09 : 0.035),
                                    Color.white.opacity(isHovered ? 0.035 : 0.012)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(isHovered ? 0.45 : 0.16), location: 0.0),
                                    .init(color: Color.white.opacity(isHovered ? 0.22 : 0.08), location: 0.35),
                                    .init(color: Color.white.opacity(isHovered ? 0.08 : 0.02), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: isHovered ? 0.75 : 0.5
                        )
                }
            )
            .shadow(color: isHovered ? Color.white.opacity(0.08) : Color.clear, radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .help("Open \(item.name)")
        .contextMenu {
            Button("Open", action: open)
            Button("Copy Image", action: copy)
            Button("Show in Finder", action: reveal)
        }
    }
}

// MARK: - File Thumbnail & Cache

@MainActor
private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func set(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}

private struct FileThumbnail: View {
    let path: String
    let size: CGSize
    @State private var image: NSImage?

    init(path: String, size: CGSize) {
        self.path = path
        self.size = size
        if let cached = ThumbnailCache.shared.image(for: path) {
            self._image = State(initialValue: cached)
        } else if let direct = NSImage(contentsOfFile: path) {
            ThumbnailCache.shared.set(direct, for: path)
            self._image = State(initialValue: direct)
        } else {
            self._image = State(initialValue: nil)
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.32), location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.4),
                            .init(color: Color.white.opacity(0.04), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .task(id: path) {
            guard image == nil else { return }
            let request = QLThumbnailGenerator.Request(
                fileAt: URL(fileURLWithPath: path),
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2,
                representationTypes: .thumbnail
            )
            if let best = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage {
                ThumbnailCache.shared.set(best, for: path)
                image = best
            } else if let fallback = NSImage(contentsOfFile: path) {
                ThumbnailCache.shared.set(fallback, for: path)
                image = fallback
            }
        }
    }
}

// MARK: - Empty Library View

private struct EmptyLibraryView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))

                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
