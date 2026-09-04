import Foundation
import AppKit
import Combine

@MainActor
public final class MediaService: ObservableObject {
    public static let shared = MediaService()
    
    @Published public var currentMedia = MediaItem()
    private var timer: AnyCancellable?
    
    private init() {
        updateMediaState()
        // Poll every 1.5 seconds for playback state & position updates
        timer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMediaState()
            }
    }
    
    public func updateMediaState() {
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        
        if isMusicRunning {
            if let item = queryAppleMusic() {
                self.currentMedia = item
                return
            }
        }
        
        if isSpotifyRunning {
            if let item = querySpotify() {
                self.currentMedia = item
                return
            }
        }
        
        // Idle state if neither is playing
        self.currentMedia = MediaItem(
            title: "Not Playing",
            artist: "No active music player",
            album: "",
            isPlaying: false,
            duration: 0,
            position: 0,
            artwork: nil,
            source: .none
        )
    }
    
    private func queryAppleMusic() -> MediaItem? {
        let script = """
        tell application "Music"
            try
                set pState to player state
                if pState is playing or pState is paused then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to duration of current track
                    set tPos to player position
                    set stateStr to "paused"
                    if pState is playing then
                        set stateStr to "playing"
                    end if
                    return stateStr & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDur as string) & "|||" & (tPos as string)
                else
                    return "stopped"
                end if
            on error
                return "error"
            end try
        end tell
        """
        
        guard let output = runAppleScript(script), output != "stopped", output != "error" else {
            return nil
        }
        
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0] == "playing"
        let name = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let position = Double(parts[5]) ?? 0.0
        
        return MediaItem(
            title: name.isEmpty ? "Track" : name,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            isPlaying: isPlaying,
            duration: duration,
            position: position,
            artwork: nil,
            source: .appleMusic
        )
    }
    
    private func querySpotify() -> MediaItem? {
        let script = """
        tell application "Spotify"
            try
                set pState to player state
                if pState is playing or pState is paused then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to (duration of current track) / 1000
                    set tPos to player position
                    set stateStr to "paused"
                    if pState is playing then
                        set stateStr to "playing"
                    end if
                    return stateStr & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDur as string) & "|||" & (tPos as string)
                else
                    return "stopped"
                end if
            on error
                return "error"
            end try
        end tell
        """
        
        guard let output = runAppleScript(script), output != "stopped", output != "error" else {
            return nil
        }
        
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0] == "playing"
        let name = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let position = Double(parts[5]) ?? 0.0
        
        return MediaItem(
            title: name.isEmpty ? "Track" : name,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            isPlaying: isPlaying,
            duration: duration,
            position: position,
            artwork: nil,
            source: .spotify
        )
    }
    
    public func togglePlayPause() {
        if currentMedia.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        } else if currentMedia.source == .appleMusic {
            _ = runAppleScript("tell application \"Music\" to playpause")
        } else {
            // Launch Apple Music if nothing is playing
            if let musicApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                NSWorkspace.shared.openApplication(at: musicApp, configuration: NSWorkspace.OpenConfiguration())
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateMediaState()
        }
    }
    
    public func nextTrack() {
        if currentMedia.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to next track")
        } else if currentMedia.source == .appleMusic {
            _ = runAppleScript("tell application \"Music\" to next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateMediaState()
        }
    }
    
    public func previousTrack() {
        if currentMedia.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        } else if currentMedia.source == .appleMusic {
            _ = runAppleScript("tell application \"Music\" to previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateMediaState()
        }
    }
    
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
}
