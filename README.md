# MiniDock 🚀

A native Swift & SwiftUI floating desktop Dock replacement for macOS, engineered for Apple Silicon (M-series Macs).

Inspired by modern Apple aesthetic principles: dark frosted glass (`.ultraThinMaterial`), rounded widget cards, live system monitors, live weather, Spotify / Apple Music Now Playing integration, compact app launcher, and complete safety for macOS's built-in Dock.

## Features

- **Large Clock**: Monospaced digits with seconds counter, day, and date (e.g. `10:42 Wed, Jun 17`). Click to open Calendar.
- **Live Weather**: Powered by Open-Meteo REST API (zero API key needed). Displays current temperature, condition icon, city name (defaults to Phnom Penh, Cambodia), daily high/low, and 3-hour micro forecast.
- **2x2 App Launcher**: Compact grid with Safari, Terminal, VS Code, and Finder. Shows active running dot indicators underneath running apps. Spring click animations.
- **System Activity Ring**: Hardware-accelerated circular progress ring (similar to Apple Watch Activity / desktop widget) displaying CPU, RAM, or Disk usage via low-overhead Darwin Mach kernel statistics. Click opens detailed system inspector popover.
- **Now Playing Media**: Connects to Apple Music and Spotify via AppleScript/ScriptingBridge. Displays track title, artist name, dynamic progress bar, previous, play/pause, and next controls. Graceful idle state when paused/inactive.
- **Floating Glass Window**: `NSPanel` floating at the bottom center of the screen, stationary across all macOS Spaces, non-activating (doesn't steal keyboard focus from active apps).
- **Settings & Customization**: Preferences panel to tune dock scale, opacity, corner radius, toggle widgets, change system metrics, and set weather coordinates.
- **Safe Dock Management**: Automatically autohides Apple Dock when active, and includes a one-click / one-command restore mechanism.
- **Auto-Start at Login**: Configured via macOS standard `LaunchAgent`.

## Command Line Interface (`minidock`)

```bash
minidock enable             # Start MiniDock and auto-hide Apple Dock
minidock disable            # Quit MiniDock and restore Apple Dock
minidock restore-apple-dock # Immediately restore Apple Dock to visible mode
minidock status             # Show running status of MiniDock and Apple Dock
minidock settings           # Open configuration panel
minidock autostart enable   # Launch automatically on login
minidock autostart disable  # Remove login item
```

## Quick Restoration

If you ever want to return immediately to the standard Apple Dock:
```bash
./Scripts/restore_apple_dock.sh
```
or
```bash
minidock restore-apple-dock
```
