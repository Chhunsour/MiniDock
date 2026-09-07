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
                .accessibilityLabel("Browse Finder for Application")
                .help("Browse filesystem to choose an application")

                Button("Close") {
                    onDismiss?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Close Application Picker")
                .help("Close without selecting")
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
                            let isVisible = launcherService.visibleApps.contains(where: { AppInsertionPolicy.matches($0, app) })
                            let isSavedHidden = !isVisible && launcherService.apps.contains(where: { AppInsertionPolicy.matches($0, app) })
                            let status: AppRowStatus = isVisible ? .added : (isSavedHidden ? .show : .add)

                            AppRowView(
                                app: app,
                                status: status,
                                isReplacing: replacingItem != nil,
                                onSelect: {
                                    handleSelection(app)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .sleekScrollIndicators()
            }
        }
        .frame(width: 480, height: 420)
        .background(Color.black.opacity(0.94))
    }

    private func handleSelection(_ app: LauncherAppItem) {
        if let target = replacingItem {
            launcherService.replaceApp(oldItem: target, with: app)
            onSelect?(app)
        } else {
            let succeeded = launcherService.addOrPromoteApp(app)
            if succeeded {
                onSelect?(app)
            }
        }
    }
}

public enum AppRowStatus {
    case added
    case show
    case add
}

private struct AppRowView: View {
    let app: LauncherAppItem
    let status: AppRowStatus
    let isReplacing: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var isActionable: Bool {
        if isReplacing { return true }
        return status != .added
    }

    var body: some View {
        Button(action: {
            if isActionable {
                onSelect()
            }
        }) {
            HStack(spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(status == .added && !isReplacing ? .white.opacity(0.45) : .white)

                    Text(app.bundleIdentifier.isEmpty ? app.path : app.bundleIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(status == .added && !isReplacing ? 0.3 : 0.5))
                        .lineLimit(1)
                }

                Spacer()

                if !isReplacing && status == .added {
                    Text("Added")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                        .accessibilityLabel("\(app.name), already added to dock")
                } else if !isReplacing && status == .show {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                        Text("Show")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.blue.opacity(0.85))
                    .cornerRadius(4)
                    .accessibilityLabel("Show \(app.name) in dock")
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .accessibilityLabel(isReplacing ? "Replace with \(app.name)" : "Add \(app.name) to dock")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovered && isActionable ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var helpText: String {
        if isReplacing {
            return "Replace application with \(app.name)"
        }
        switch status {
        case .added:
            return "\(app.name) is already visible in FlowDock"
        case .show:
            return "\(app.name) is saved in FlowDock. Click to show in visible dock."
        case .add:
            return "Add \(app.name) to FlowDock"
        }
    }

    private var accessibilityText: String {
        if isReplacing {
            return "Replace with \(app.name)"
        }
        switch status {
        case .added:
            return "\(app.name), already added to dock"
        case .show:
            return "Show \(app.name) in dock"
        case .add:
            return "Add \(app.name) to dock"
        }
    }
}
