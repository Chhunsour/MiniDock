import SwiftUI
import AppKit

public struct SecondaryGlanceWidgetView: View {
    @ObservedObject private var mediaService = MediaService.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    @State private var showingClipboardPopover = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            if mediaService.currentMedia.isPlaying {
                nowPlayingContent
            } else {
                clipboardContent
            }
        }
    }
    
    // MARK: - Now Playing Active State
    @ViewBuilder
    private var nowPlayingContent: some View {
        HStack(spacing: 8) {
            // Mini artwork or music waveform
            ZStack {
                if let art = mediaService.currentMedia.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .cornerRadius(5)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "waveform")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(mediaService.currentMedia.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
                
                Text(mediaService.currentMedia.artist)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
            }
            
            Button(action: { mediaService.togglePlayPause() }) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Clipboard Glance State
    @ViewBuilder
    private var clipboardContent: some View {
        Button(action: {
            showingClipboardPopover.toggle()
        }) {
            HStack(spacing: 7) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.85))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(clipboard.latestText.isEmpty ? "Clipboard" : clipboard.previewText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .frame(maxWidth: 95, alignment: .leading)
                    
                    Text("Clipboard")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingClipboardPopover, arrowEdge: .top) {
            ClipboardDetailPopover(clipboard: clipboard)
        }
    }
}

private struct ClipboardDetailPopover: View {
    @ObservedObject var clipboard: ClipboardService
    @State private var copiedAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Clipboard Content", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if clipboard.characterCount > 0 {
                    Text("\(clipboard.characterCount) characters")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            if clipboard.latestText.isEmpty {
                Text("Clipboard is currently empty.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    Text(clipboard.latestText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(maxHeight: 140)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
            }
            
            HStack {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(clipboard.latestText, forType: .string)
                    copiedAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copiedAlert = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedAlert ? "checkmark" : "doc.on.doc")
                        Text(copiedAlert ? "Copied!" : "Copy Again")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(clipboard.latestText.isEmpty)
                
                Spacer()
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Color.black.opacity(0.92))
    }
}
