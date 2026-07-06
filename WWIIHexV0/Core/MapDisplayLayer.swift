import Foundation

enum MapDisplayLayer: String, Codable, Equatable, CaseIterable, Identifiable {
    case hex
    case province
    case initialTheater
    case dynamicTheater
    case frontLine
    case deployment

    var id: String {
        rawValue
    }

    var displayName: String {
        displayName(for: nil)
    }

    func displayName(for faction: Faction?) -> String {
        guard faction?.usesNapoleonicLogisticsVocabulary == true else {
            return legacyDisplayName
        }

        switch self {
        case .hex:
            return "Hex"
        case .province:
            return "Sector"
        case .initialTheater:
            return "Initial Wing"
        case .dynamicTheater:
            return "Active Wing"
        case .frontLine:
            return "Contact"
        case .deployment:
            return "Corps"
        }
    }

    private var legacyDisplayName: String {
        switch self {
        case .hex:
            return "Hex"
        case .province:
            return "Province"
        case .initialTheater:
            return "Initial"
        case .dynamicTheater:
            return "Dynamic"
        case .frontLine:
            return "Front"
        case .deployment:
            return "Deploy"
        }
    }
}
