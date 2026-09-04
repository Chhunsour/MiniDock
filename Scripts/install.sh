#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo " Installing FlowDock on macOS"
echo "========================================="

# 1. Build application bundle
"$PROJECT_DIR/Scripts/build_app.sh"

# 2. Install to /Applications
echo "Installing to /Applications/MiniDock.app..."
rm -rf /Applications/MiniDock.app
cp -R "$PROJECT_DIR/MiniDock.app" /Applications/MiniDock.app

# Also maintain copy in ~/Applications as backup
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/MiniDock.app"
cp -R "$PROJECT_DIR/MiniDock.app" "$HOME/Applications/MiniDock.app"

# 3. Install CLI helpers to ~/.local/bin and /usr/local/bin
echo "Installing flowdock and minidock command line tools..."
mkdir -p "$HOME/.local/bin"
cp "$PROJECT_DIR/Scripts/minidock" "$HOME/.local/bin/minidock"
cp "$PROJECT_DIR/Scripts/minidock" "$HOME/.local/bin/flowdock"
chmod +x "$HOME/.local/bin/minidock" "$HOME/.local/bin/flowdock"

if [ -w "/usr/local/bin" ]; then
    cp "$PROJECT_DIR/Scripts/minidock" "/usr/local/bin/minidock" 2>/dev/null || true
    cp "$PROJECT_DIR/Scripts/minidock" "/usr/local/bin/flowdock" 2>/dev/null || true
    chmod +x "/usr/local/bin/minidock" "/usr/local/bin/flowdock" 2>/dev/null || true
fi

# 4. Setup auto-start at login
echo "Configuring login item auto-start..."
"$HOME/.local/bin/flowdock" autostart enable

echo "========================================="
echo " FlowDock Installed Successfully!"
echo "========================================="
echo "Commands available:"
echo "  flowdock command     (Toggle Command Palette ⌥ Space)"
echo "  flowdock settings    (Open FlowDock Preferences)"
echo "  flowdock status      (Check status)"
echo "  flowdock restart     (Restart FlowDock)"
echo "  flowdock disable     (Stop FlowDock and restore Apple Dock)"
echo "  flowdock enable      (Launch FlowDock and hide Apple Dock)"
echo "========================================="
