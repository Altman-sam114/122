import Foundation

enum PlaytestGuideCue: String, CaseIterable, Codable, Equatable, Hashable {
    case formationSelected
    case artillerySelected
    case cavalrySelected
    case endingOrders

    func message(for division: Division?, activeFaction: Faction) -> String {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return napoleonicMessage(for: division, activeFaction: activeFaction)
        }
        return legacyMessage(for: division)
    }

    private func napoleonicMessage(for division: Division?, activeFaction: Faction) -> String {
        switch self {
        case .formationSelected:
            let name = displayName(for: division, fallback: "formation", activeFaction: activeFaction)
            if division?.isInfantryHeavy == true {
                return "Staff note: \(name) can receive direct orders while its power holds the orders phase. Hold Contact Line can form a square-ready defense against open-ground cavalry shock."
            }
            return "Staff note: \(name) can receive direct orders while its power holds the orders phase."
        case .artillerySelected:
            let name = displayName(for: division, fallback: "Artillery", activeFaction: activeFaction)
            return "Staff note: \(name) favors prepared fire against exposed targets; rough ground and strongpoints blunt its effect."
        case .cavalrySelected:
            let name = displayName(for: division, fallback: "Cavalry", activeFaction: activeFaction)
            return "Staff note: \(name) is best used for open-ground shock and pursuit; villages, woods, hills, and square-ready Hold Contact Line infantry blunt charges."
        case .endingOrders:
            return "Staff note: ending orders hands initiative to the next power; staff dispatches and rejected orders remain in replay."
        }
    }

    private func displayName(for division: Division?, fallback: String, activeFaction: Faction) -> String {
        NapoleonicMessageSanitizer.displayText(division?.name ?? fallback, for: activeFaction)
    }

    private func legacyMessage(for division: Division?) -> String {
        switch self {
        case .formationSelected:
            let name = division?.name ?? "unit"
            return "Staff note: \(name) can receive direct commands while its faction holds the command phase."
        case .artillerySelected:
            let name = division?.name ?? "Artillery"
            return "Staff note: \(name) can engage at range when a target is inside its fire envelope."
        case .cavalrySelected:
            let name = division?.name ?? "Mobile unit"
            return "Staff note: \(name) is strongest in open terrain and weaker against protected positions."
        case .endingOrders:
            return "Staff note: ending the turn hands initiative to the next faction; AI decisions and rejected commands remain in replay."
        }
    }
}
