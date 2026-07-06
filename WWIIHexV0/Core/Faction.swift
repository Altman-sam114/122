import Foundation

enum Faction: String, Codable, Equatable, Hashable, CaseIterable, Identifiable {
    case germany
    case allies
    case france
    case angloAllied
    case prussia
    case austria
    case russia
    case spain
    case neutral

    var id: String {
        rawValue
    }

    @available(*, deprecated, message: "Legacy two-sided helper. Use DiplomacyState.isHostile/isFriendly or hostileFactions(to:) for runtime relations.")
    var opponent: Faction {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        case .france:
            return .angloAllied
        case .angloAllied, .prussia, .austria, .russia, .spain:
            return .france
        case .neutral:
            return .neutral
        }
    }

    var displayName: String {
        switch self {
        case .germany:
            return "Germany"
        case .allies:
            return "Allies"
        case .france:
            return "France"
        case .angloAllied:
            return "Anglo-Allied"
        case .prussia:
            return "Prussia"
        case .austria:
            return "Austria"
        case .russia:
            return "Russia"
        case .spain:
            return "Spain"
        case .neutral:
            return "Neutral"
        }
    }

    var isNeutral: Bool {
        self == .neutral
    }

    var isLegacyWorldWarIIFaction: Bool {
        self == .germany || self == .allies
    }

    var isNapoleonicCoalitionMember: Bool {
        switch self {
        case .angloAllied, .prussia, .austria, .russia, .spain:
            return true
        case .germany, .allies, .france, .neutral:
            return false
        }
    }

    var usesNapoleonicLogisticsVocabulary: Bool {
        self == .france || isNapoleonicCoalitionMember
    }

    var turnOrderPriority: Int {
        switch self {
        case .germany, .france:
            return 10
        case .allies, .angloAllied:
            return 20
        case .prussia:
            return 30
        case .austria:
            return 40
        case .russia:
            return 50
        case .spain:
            return 60
        case .neutral:
            return 900
        }
    }

    static var legacyWorldWarIIFactions: [Faction] {
        [.germany, .allies]
    }

    static var waterlooFactions: [Faction] {
        [.france, .angloAllied, .prussia, .neutral]
    }
}

enum NapoleonicMessageSanitizer {
    static func displayText(_ text: String, for faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return text
        }

        var displayText = text
        for (raw, replacement) in replacements {
            displayText = displayText.replacingOccurrences(of: raw, with: replacement)
        }
        return displayText
    }

    private static let replacements: [(String, String)] = [
        ("Command directive pipeline selected but deployment sectors are missing; legacy pipeline was not invoked.", "Staff dispatch unavailable: corps sectors are missing."),
        ("legacy pipeline was not invoked", "staff dispatch could not continue"),
        ("AI end turn failed", "End Orders failed"),
        ("AI turn requested", "Staff dispatch requested"),
        ("AI turn completed", "Command dispatch completed"),
        ("AI issue", "Command dispatch issue"),
        ("AI note", "Staff note"),
        ("MockAI+MarshalDirective", "Simulated Staff"),
        ("MockAI", "Simulated Staff"),
        ("TheaterDirective JSON", "staff dispatch audit"),
        ("Compiled ZoneDirective JSON", "compiled corps orders audit"),
        ("StrategicPosture JSON", "campaign posture audit"),
        ("generated no executable commands", "produced no field orders"),
        ("Directive", "Corps directive"),
        ("command", "order"),
        ("rejected", "refused"),
        ("Rejected", "Refused"),
        ("Mapping failed", "Order could not be formed"),
        ("mapping failed", "could not form order"),
        ("legacy", "archived"),
        ("Legacy", "Archived"),
        ("Germany", "Archived Force"),
        ("Allies", "Coalition"),
        ("German", "Archived"),
        ("Allied", "Coalition"),
        ("wrongPhase", "orders unavailable in this phase"),
        ("wrongFaction", "formation is not under current command"),
        ("divisionNotFound", "formation not found"),
        ("targetNotFound", "target formation not found"),
        ("alreadyActed", "formation has already spent its orders"),
        ("destinationOutOfBounds", "destination is outside the battle map"),
        ("destinationOccupied", "destination is occupied"),
        ("noPath", "no passable route"),
        ("insufficientMovement", "formation lacks movement"),
        ("targetOutOfRange", "target is out of range"),
        ("invalidTargetFaction", "target is not hostile"),
        ("regionNotFound", "sector not found"),
        ("invalidRegionForHex", "hex is not in a valid sector"),
        ("insufficientResources", "insufficient reserves"),
        ("moraleBroken", "formation morale is broken"),
        ("AI ", "Staff "),
        (" AI", " Staff")
    ]
}
