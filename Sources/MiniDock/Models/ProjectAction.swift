import Foundation

public enum ProjectActionType: String, Codable, Sendable {
    case openEditor
    case openTerminal
    case openFinder
    case openGitHub
    case runShellCommand
    case runDevServer
    case runTests
    case buildProject
    case custom
}

public struct ProjectAction: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let actionType: ProjectActionType
    public let command: String?
    public let isDestructive: Bool
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: String,
        actionType: ProjectActionType,
        command: String? = nil,
        isDestructive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.actionType = actionType
        self.command = command
        self.isDestructive = isDestructive
    }
}

public enum ProjectStackType: String, CaseIterable, Identifiable, Sendable {
    case flutter = "Flutter"
    case nextjs = "Next.js / React"
    case nodejs = "Node.js"
    case laravel = "Laravel"
    case rust = "Rust"
    case golang = "Go"
    case docker = "Docker Compose"
    case supabase = "Supabase"
    case general = "Git Project"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .flutter: return "iphone"
        case .nextjs: return "globe"
        case .nodejs: return "shippingbox"
        case .laravel: return "flame"
        case .rust: return "gearshape.2"
        case .golang: return "network"
        case .docker: return "cube.transparent"
        case .supabase: return "bolt"
        case .general: return "folder"
        }
    }
}
