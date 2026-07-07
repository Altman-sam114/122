import Foundation

enum GameSaveSlot: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case slot1
    case slot2
    case slot3

    static let standard: GameSaveSlot = .slot1

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .slot1:
            return "Campaign 1"
        case .slot2:
            return "Campaign 2"
        case .slot3:
            return "Campaign 3"
        }
    }

    var defaultsKey: String {
        "WWIIHexV0.savedGameSnapshot.v1.\(rawValue)"
    }

    var legacyDefaultsKey: String? {
        self == .slot1 ? "WWIIHexV0.savedGameSnapshot.v1" : nil
    }

    var labelDefaultsKey: String {
        "WWIIHexV0.savedGameSlotLabel.v1.\(rawValue)"
    }

    func displayName(using labels: [GameSaveSlot: String]) -> String {
        labels[self] ?? displayName
    }

    static func normalizedLabel(_ label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(32))
    }

    static func loadLabels(from defaults: UserDefaults = .standard) -> [GameSaveSlot: String] {
        var labels: [GameSaveSlot: String] = [:]
        for slot in allCases {
            guard let label = defaults.string(forKey: slot.labelDefaultsKey),
                  let normalizedLabel = normalizedLabel(label) else {
                continue
            }
            labels[slot] = normalizedLabel
        }
        return labels
    }

    @discardableResult
    static func persistLabel(
        _ label: String,
        for slot: GameSaveSlot,
        defaults: UserDefaults = .standard
    ) -> String? {
        guard let normalizedLabel = normalizedLabel(label) else {
            defaults.removeObject(forKey: slot.labelDefaultsKey)
            return nil
        }

        defaults.set(normalizedLabel, forKey: slot.labelDefaultsKey)
        return normalizedLabel
    }
}

struct GameSaveSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    enum LoadResult: Equatable {
        case missing
        case loaded(GameSaveSnapshot)
        case unavailable(String)

        var snapshot: GameSaveSnapshot? {
            guard case let .loaded(snapshot) = self else {
                return nil
            }
            return snapshot
        }

        var recoveryMessage: String? {
            guard case let .unavailable(message) = self else {
                return nil
            }
            return message
        }
    }

    struct Summary: Equatable {
        let scenarioId: String
        let scenarioName: String
        let turn: Int
        let activeFaction: Faction
        let playerFaction: Faction
        let savedAt: Date

        var title: String {
            "\(scenarioName), turn \(turn)"
        }

        var detail: String {
            if activeFaction.usesNapoleonicLogisticsVocabulary || playerFaction.usesNapoleonicLogisticsVocabulary {
                return "Current: \(activeFaction.displayName), Your Power: \(playerFaction.displayName)"
            }

            return "Active: \(activeFaction.displayName), Player: \(playerFaction.displayName)"
        }
    }

    let schemaVersion: Int
    let scenarioId: String
    let playerFaction: Faction
    let startsAtPlayerFaction: Bool
    let savedAt: Date
    let gameState: GameState

    private struct Header: Decodable {
        let schemaVersion: Int?
    }

    init(
        scenarioId: String,
        playerFaction: Faction,
        startsAtPlayerFaction: Bool,
        savedAt: Date = Date(),
        gameState: GameState
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.scenarioId = scenarioId
        self.playerFaction = playerFaction
        self.startsAtPlayerFaction = startsAtPlayerFaction
        self.savedAt = savedAt
        self.gameState = gameState
    }

    func summary(scenarioName: String) -> Summary {
        Summary(
            scenarioId: scenarioId,
            scenarioName: scenarioName,
            turn: gameState.turn,
            activeFaction: gameState.activeFaction,
            playerFaction: playerFaction,
            savedAt: savedAt
        )
    }

    static func load(from defaults: UserDefaults = .standard, slot: GameSaveSlot) -> LoadResult {
        if defaults.data(forKey: slot.defaultsKey) != nil {
            return load(from: defaults, key: slot.defaultsKey)
        }

        if let legacyDefaultsKey = slot.legacyDefaultsKey {
            return load(from: defaults, key: legacyDefaultsKey)
        }

        return .missing
    }

    static func load(from defaults: UserDefaults = .standard, key: String) -> LoadResult {
        guard let data = defaults.data(forKey: key) else {
            return .missing
        }

        do {
            let snapshot = try JSONDecoder().decode(Self.self, from: data)
            guard snapshot.schemaVersion == currentSchemaVersion else {
                return .unavailable(incompatibleSchemaMessage(snapshot.schemaVersion))
            }
            return .loaded(snapshot)
        } catch {
            if let header = try? JSONDecoder().decode(Header.self, from: data),
               let schemaVersion = header.schemaVersion,
               schemaVersion != currentSchemaVersion {
                return .unavailable(incompatibleSchemaMessage(schemaVersion))
            }

            return .unavailable("This saved campaign cannot be read with this version of the game.")
        }
    }

    private static func incompatibleSchemaMessage(_: Int) -> String {
        "This saved campaign was made with a different version of the game and cannot be read here."
    }
}
