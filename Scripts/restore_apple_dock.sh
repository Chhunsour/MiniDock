#!/usr/bin/env bash
echo "Restoring standard Apple Dock..."
defaults write com.apple.dock autohide -bool false
killall Dock 2>/dev/null || true
echo "Apple Dock restored to visible mode."
