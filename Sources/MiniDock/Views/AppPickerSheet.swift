import SwiftUI
import AppKit

public struct AppPickerSheet: View {
    @ObservedObject private var scanner = InstalledAppsScanner.shared
    @ObservedObject private var launcherService = AppLauncherService.shared
    
    @State private var searchText = ""
    
    let replacingItem: LauncherAppItem?
    let onSelect: ((LauncherAppItem) -> Void)?
    let onDismiss: (() -> Void)?
    
    public init(
        replacingItem: LauncherAppItem? = nil,
        onSelect: ((LauncherAppItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.replacingItem = replacingItem
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }
    
    private var filteredApps: [LauncherAppItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return scanner.detectedApps
        }
        return scanner.detectedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(replacingItem == nil ? "Add Application to Dock" : "Replace '\(replacingItem?.name ?? "")'")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select from detected applications or browse filesystem")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Button("Browse Finder...") {
                    scanner.promptChooseApplication { chosen in
                        if let item = chosen {
                            handleSelection(item)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Close") {
                    onDismiss?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Search Input Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Search installed applications...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Apps List
            if scanner.isScanning && scanner.detectedApps.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning /Applications...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredApps) { app in
                            AppRowView(
                                app: app,
                                isAlreadyAdded: launcherService.apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }),
                                onSelect: {
                                    handleSelection(app)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 480, height: 420)
        .background(Color.black.opacity(0.94))
    }
    
    private func handleSelection(_ app: LauncherAppItem) {
        if let target = replacingItem {
            launcherService.replaceApp(oldItem: target, with: app)
        } else {
            launcherService.addApp(app)
        }
        onSelect?(app)
    }
}

private struct AppRowView: View {
    let app: LauncherAppItem
    let isAlreadyAdded: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(app.bundleIdentifier.isEmpty ? app.path : app.bundleIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isAlreadyAdded {
                    Text("Added")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
