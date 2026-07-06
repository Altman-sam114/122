import Foundation

enum CommandValidationError: String, Codable, Equatable {
    case wrongPhase
    case wrongFaction
    case divisionNotFound
    case targetNotFound
    case alreadyActed
    case destinationOutOfBounds
    case destinationOccupied
    case noPath
    case insufficientMovement
    case targetOutOfRange
    case invalidTargetFaction
    case regionNotFound
    case invalidRegionForHex
    case insufficientResources
    case moraleBroken

    func displayName(for faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        switch self {
        case .wrongPhase:
            return "orders unavailable in this phase"
        case .wrongFaction:
            return "formation is not under current command"
        case .divisionNotFound:
            return "formation not found"
        case .targetNotFound:
            return "target formation not found"
        case .alreadyActed:
            return "formation has already spent its orders"
        case .destinationOutOfBounds:
            return "destination is outside the battle map"
        case .destinationOccupied:
            return "destination is occupied"
        case .noPath:
            return "no passable route"
        case .insufficientMovement:
            return "formation lacks movement"
        case .targetOutOfRange:
            return "target is out of range"
        case .invalidTargetFaction:
            return "target is not hostile"
        case .regionNotFound:
            return "sector not found"
        case .invalidRegionForHex:
            return "hex is not in a valid sector"
        case .insufficientResources:
            return "insufficient reserves"
        case .moraleBroken:
            return "formation morale is broken"
        }
    }
}

struct CommandValidation: Codable, Equatable {
    var errors: [CommandValidationError]

    var isValid: Bool {
        errors.isEmpty
    }

    static let valid = CommandValidation(errors: [])

    static func invalid(_ error: CommandValidationError) -> CommandValidation {
        CommandValidation(errors: [error])
    }
}
