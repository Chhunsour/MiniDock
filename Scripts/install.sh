#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo " Installing MiniDock on macOS"
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

# 3. Install CLI helper to ~/.local/bin and /usr/local/bin
echo "Installing minidock command line tool..."
mkdir -p "$HOME/.local/bin"
cp "$PROJECT_DIR/Scripts/minidock" "$HOME/.local/bin/minidock"
chmod +x "$HOME/.local/bin/minidock"

if [ -w "/usr/local/bin" ]; then
    cp "$PROJECT_DIR/Scripts/minidock" "/usr/local/bin/minidock" 2>/dev/null || true
    chmod +x "/usr/local/bin/minidock" 2>/dev/null || true
fi

# 4. Setup auto-start at login
echo "Configuring login item auto-start..."
"$HOME/.local/bin/minidock" autostart enable

echo "========================================="
echo " MiniDock Installed Successfully!"
echo "========================================="
echo "Commands available:"
echo "  minidock enable"
echo "  minidock disable"
echo "  minidock restore-apple-dock"
echo "  minidock status"
echo "  minidock settings"
echo "========================================="
