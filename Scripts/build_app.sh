#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "Building MiniDock with Swift..."
swift build -c release

APP_NAME="MiniDock.app"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Creating application bundle: $APP_NAME..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp ".build/release/MiniDock" "$MACOS/MiniDock"
chmod +x "$MACOS/MiniDock"

cp "Resources/Info.plist" "$CONTENTS/Info.plist"

echo "Creating application icon..."
ICONSET_DIR="/tmp/MiniDock.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate a high-resolution dark dock icon using Python
python3 - << 'PYEOF'
try:
    from PIL import Image, ImageDraw
    size = (512, 512)
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = 48
    draw.rounded_rectangle([margin, 120, size[0] - margin, 392], radius=64, fill=(18, 18, 22, 235), outline=(255, 255, 255, 50), width=4)
    draw.ellipse([80, 200, 190, 310], fill=(40, 40, 48, 255), outline=(0, 220, 130, 240), width=6)
    draw.rounded_rectangle([215, 200, 315, 310], radius=24, fill=(50, 90, 180, 255))
    draw.rounded_rectangle([340, 200, 440, 310], radius=24, fill=(210, 50, 90, 255))

    img.save('/tmp/dock_icon_512.png')
except ImportError:
    import zlib, struct
    width, height = 512, 512
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)
        for x in range(width):
            r, g, b, a = 0, 0, 0, 0
            if 48 <= x <= 464 and 120 <= y <= 392:
                r, g, b, a = 18, 18, 22, 235
                if x in (48, 49, 463, 464) or y in (120, 121, 391, 392):
                    r, g, b, a = 255, 255, 255, 50
            dx, dy = x - 135, y - 255
            if dx*dx + dy*dy <= 55*55:
                if dx*dx + dy*dy >= 49*49:
                    r, g, b, a = 0, 220, 130, 240
                else:
                    r, g, b, a = 40, 40, 48, 255
            if 215 <= x <= 315 and 200 <= y <= 310:
                r, g, b, a = 50, 90, 180, 255
            if 340 <= x <= 440 and 200 <= y <= 310:
                r, g, b, a = 210, 50, 90, 255
            raw_data.extend((r, g, b, a))
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(raw_data), 9)) + chunk(b'IEND', b'')
    with open('/tmp/dock_icon_512.png', 'wb') as f:
        f.write(png)
PYEOF

if [ -f "/tmp/dock_icon_512.png" ]; then
    sips -z 16 16     /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1 || true
    sips -z 32 32     /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1 || true
    sips -z 32 32     /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1 || true
    sips -z 64 64     /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1 || true
    sips -z 128 128   /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1 || true
    sips -z 256 256   /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1 || true
    sips -z 256 256   /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1 || true
    sips -z 512 512   /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1 || true
    sips -z 512 512   /tmp/dock_icon_512.png --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1 || true
    
    if which iconutil >/dev/null 2>&1; then
        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns" || true
    fi
    rm -rf "$ICONSET_DIR" /tmp/dock_icon_512.png
fi

echo "Signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE" || true

echo "MiniDock.app successfully built at $APP_BUNDLE"
