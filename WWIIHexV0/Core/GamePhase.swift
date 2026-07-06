import Foundation

enum GamePhase: String, Codable, Equatable, CaseIterable {
    case germanAI
    case alliedPlayer
    case aiCommand
    case playerCommand
    case resolution

    var displayName: String {
        switch self {
        case .germanAI, .aiCommand:
            return "AI Command"
        case .alliedPlayer, .playerCommand:
            return "Player Command"
        case .resolution:
            return "Resolution"
        }
    }

    var allowsCommands: Bool {
        self != .resolution
    }

    var isAICommandPhase: Bool {
        switch self {
        case .germanAI, .aiCommand:
            return true
        case .alliedPlayer, .playerCommand, .resolution:
            return false
        }
    }

    static func commandPhase(for faction: Faction) -> GamePhase {
        switch faction {
        case .allies:
            return .alliedPlayer
        case .germany:
            return .germanAI
        case .neutral:
            return .resolution
        case .france, .angloAllied, .prussia, .austria, .russia, .spain:
            return .aiCommand
        }
    }

    static func legacyCompatibleCommandPhase(for faction: Faction) -> GamePhase {
        commandPhase(for: faction)
    }
}
