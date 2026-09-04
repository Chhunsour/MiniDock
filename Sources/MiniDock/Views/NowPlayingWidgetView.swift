import SwiftUI
import AppKit

public struct NowPlayingWidgetView: View {
    @ObservedObject private var mediaService = MediaService.shared
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            if mediaService.currentMedia.isPlaying {
                // Active Playback Pill
                HStack(spacing: 8) {
                    // Mini artwork or music note
                    ZStack {
                        if let art = mediaService.currentMedia.artwork {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .cornerRadius(5)
                        } else {
                            Circle()
                                .fill(LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                            .frame(maxWidth: 100, alignment: .leading)
                        
                        Text(mediaService.currentMedia.artist)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .frame(maxWidth: 100, alignment: .leading)
                    }
                    
                    Button(action: { mediaService.togglePlayPause() }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Minimal discreet idle button
                Button(action: { mediaService.togglePlayPause() }) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Launch Music")
            }
        }
    }
}
