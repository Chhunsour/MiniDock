import SwiftUI
import AppKit

public struct NowPlayingWidgetView: View {
    @ObservedObject private var mediaService = MediaService.shared

    public init() {}

    private var isPlaying: Bool {
        mediaService.currentMedia.isPlaying
    }

    private var hasActiveTrack: Bool {
        mediaService.currentMedia.source != .none &&
        !mediaService.currentMedia.title.isEmpty &&
        mediaService.currentMedia.title != "Not Playing"
    }

    private var displayTitle: String {
        hasActiveTrack ? mediaService.currentMedia.title : "Music"
    }

    private var displaySubtitle: String {
        hasActiveTrack ? mediaService.currentMedia.artist : "Nothing playing"
    }

    private var supportsTrackControls: Bool {
        mediaService.currentMedia.source != .none
    }

    public var body: some View {
        WidgetCardView {
            HStack(spacing: 8) {
                // Mini artwork or music note/waveform
                artworkOrIcon

                // Track Title & Artist (fixed width with tail truncation)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayTitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(displaySubtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 100, alignment: .leading)

                // Playback Controls (fixed width)
                playbackControls
            }
            .frame(width: 196, height: 24)
        }
    }

    @ViewBuilder
    private var artworkOrIcon: some View {
        ZStack {
            if let artwork = mediaService.currentMedia.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else if isPlaying {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    )
            }
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private var playbackControls: some View {
        HStack(spacing: 5) {
            if supportsTrackControls {
                Button(action: {
                    mediaService.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Previous Track")
            }

            Button(action: {
                mediaService.togglePlayPause()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(isPlaying ? "Pause" : (supportsTrackControls ? "Play" : "Launch Music"))

            if supportsTrackControls {
                Button(action: {
                    mediaService.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Next Track")
            }
        }
        .frame(width: 58, alignment: .trailing)
    }
}
