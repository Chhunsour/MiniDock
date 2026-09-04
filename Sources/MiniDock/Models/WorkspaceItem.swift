import Foundation

public struct WorkspaceItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var projectPath: String?
    public var appBundleIDs: [String]
    public var urls: [String]
    public var initialFocusMinutes: Int?
    public var terminalCommand: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "briefcase.fill",
        projectPath: String? = nil,
        appBundleIDs: [String] = [],
        urls: [String] = [],
        initialFocusMinutes: Int? = nil,
        terminalCommand: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.projectPath = projectPath
        self.appBundleIDs = appBundleIDs
        self.urls = urls
        self.initialFocusMinutes = initialFocusMinutes
        self.terminalCommand = terminalCommand
    }
}
