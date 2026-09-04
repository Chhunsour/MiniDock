import SwiftUI
import AppKit

public struct NowPlayingWidgetView: View {
    @ObservedObject private var mediaService = MediaService.shared
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            HStack(spacing: 12) {
                // Album Art or Music Icon
                ZStack {
                    if let artwork = mediaService.currentMedia.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 38, height: 38)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: mediaService.currentMedia.isPlaying ? "waveform" : "music.note")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                
                // Track Info & Progress
                VStack(alignment: .leading, spacing: 3) {
                    Text(mediaService.currentMedia.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(minWidth: 90, maxWidth: 140, alignment: .leading)
                    
                    Text(mediaService.currentMedia.source == .none ? "Music / Spotify" : mediaService.currentMedia.artist)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .frame(minWidth: 90, maxWidth: 140, alignment: .leading)
                    
                    // Progress bar
                    if mediaService.currentMedia.duration > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 2.5)
                                Capsule()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: max(geo.size.width * CGFloat(mediaService.currentMedia.progress), 2), height: 2.5)
                            }
                        }
                        .frame(height: 2.5)
                    }
                }
                
                // Playback Control Buttons
                HStack(spacing: 6) {
                    Button(action: { mediaService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { mediaService.togglePlayPause() }) {
                        Image(systemName: mediaService.currentMedia.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { mediaService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
