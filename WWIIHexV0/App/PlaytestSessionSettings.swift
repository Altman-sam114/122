import Foundation

enum PlaytestTextSize: String, CaseIterable, Codable, Equatable, Identifiable {
    case compact
    case standard
    case large

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .large:
            return "Large"
        }
    }
}

enum PlaytestAIControlMode: String, CaseIterable, Codable, Equatable, Identifiable {
    case simulatedStaff
    case manualAdvance

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .simulatedStaff:
            return "Staff"
        case .manualAdvance:
            return "Manual"
        }
    }

    func shouldRunAI(
        for activeFaction: Faction,
        phase: GamePhase,
        playerFaction: Faction,
        observerModeEnabled: Bool
    ) -> Bool {
        guard phase.allowsCommands, !activeFaction.isNeutral else {
            return false
        }

        switch self {
        case .simulatedStaff:
            return observerModeEnabled || activeFaction != playerFaction
        case .manualAdvance:
            return false
        }
    }
}

struct PlaytestSessionSettings: Codable, Equatable {
    static let defaultsKey = "WWIIHexV0.playtestSessionSettings.v1"
    static let standard = PlaytestSessionSettings()

    enum LoadResult: Equatable {
        case missing
        case loaded(PlaytestSessionSettings)
        case resetToStandard(String)

        var settings: PlaytestSessionSettings {
            switch self {
            case .missing:
                return .standard
            case let .loaded(settings):
                return settings
            case .resetToStandard:
                return .standard
            }
        }

        var recoveryMessage: String? {
            guard case let .resetToStandard(message) = self else {
                return nil
            }
            return message
        }
    }

    var observerModeEnabled: Bool = false
    var mapDisplayLayer: MapDisplayLayer = .hex
    var replayDetailLevel: ReplayDetailLevel = .standard
    var aiCommandPace: AICommandPace = .balanced
    var aiControlMode: PlaytestAIControlMode = .simulatedStaff
    var playtestGuideCuesEnabled: Bool = true
    var playtestTextSize: PlaytestTextSize = .standard
    var reduceMotionEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case observerModeEnabled
        case mapDisplayLayer
        case replayDetailLevel
        case aiCommandPace
        case aiControlMode
        case playtestGuideCuesEnabled
        case playtestTextSize
        case reduceMotionEnabled
    }

    init(
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex,
        replayDetailLevel: ReplayDetailLevel = .standard,
        aiCommandPace: AICommandPace = .balanced,
        aiControlMode: PlaytestAIControlMode = .simulatedStaff,
        playtestGuideCuesEnabled: Bool = true,
        playtestTextSize: PlaytestTextSize = .standard,
        reduceMotionEnabled: Bool = false
    ) {
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
        self.replayDetailLevel = replayDetailLevel
        self.aiCommandPace = aiCommandPace
        self.aiControlMode = aiControlMode
        self.playtestGuideCuesEnabled = playtestGuideCuesEnabled
        self.playtestTextSize = playtestTextSize
        self.reduceMotionEnabled = reduceMotionEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        observerModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .observerModeEnabled) ?? false
        mapDisplayLayer = try container.decodeIfPresent(MapDisplayLayer.self, forKey: .mapDisplayLayer) ?? .hex
        replayDetailLevel = try container.decodeIfPresent(ReplayDetailLevel.self, forKey: .replayDetailLevel) ?? .standard
        aiCommandPace = try container.decodeIfPresent(AICommandPace.self, forKey: .aiCommandPace) ?? .balanced
        aiControlMode = try container.decodeIfPresent(PlaytestAIControlMode.self, forKey: .aiControlMode) ?? .simulatedStaff
        playtestGuideCuesEnabled = try container.decodeIfPresent(Bool.self, forKey: .playtestGuideCuesEnabled) ?? true
        playtestTextSize = try container.decodeIfPresent(PlaytestTextSize.self, forKey: .playtestTextSize) ?? .standard
        reduceMotionEnabled = try container.decodeIfPresent(Bool.self, forKey: .reduceMotionEnabled) ?? false
    }

    static func load(from defaults: UserDefaults = .standard) -> PlaytestSessionSettings {
        loadResult(from: defaults).settings
    }

    static func loadResult(from defaults: UserDefaults = .standard) -> LoadResult {
        guard let data = defaults.data(forKey: defaultsKey) else {
            return .missing
        }

        do {
            return .loaded(try JSONDecoder().decode(PlaytestSessionSettings.self, from: data))
        } catch {
            defaults.removeObject(forKey: defaultsKey)
            return .resetToStandard("Campaign settings were restored to standard values.")
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
