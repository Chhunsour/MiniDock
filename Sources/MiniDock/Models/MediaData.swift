import Foundation
import AppKit

public enum MediaSource: String {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case none = "None"
}

public struct MediaItem {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var duration: Double
    public var position: Double
    public var artwork: NSImage?
    public var source: MediaSource
    
    public init(
        title: String = "Not Playing",
        artist: String = "No Active Player",
        album: String = "",
        isPlaying: Bool = false,
        duration: Double = 0,
        position: Double = 0,
        artwork: NSImage? = nil,
        source: MediaSource = .none
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.position = position
        self.artwork = artwork
        self.source = source
    }
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0.0), 1.0)
    }
}
