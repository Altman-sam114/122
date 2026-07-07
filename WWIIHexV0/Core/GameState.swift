import Foundation

struct ScenarioVictoryCondition: Codable, Equatable, Identifiable {
    let id: String
    let type: String
    let faction: Faction
    let objectiveId: String?
    let objectiveIds: [String]
    let targetFaction: Faction?
    let turn: Int?
    let status: String
    let description: String

    var isActive: Bool {
        status == "active"
    }
}

struct GameState: Codable, Equatable {
    var scenarioId: String
    var turn: Int
    var maxTurns: Int
    var activeFaction: Faction
    var phase: GamePhase
    var map: MapState
    var terrainRules: TerrainRuleSet
    var theaterState: TheaterState
    var frontLineState: FrontLineState
    var warDeploymentState: WarDeploymentState
    var economyState: EconomyState
    var reinforcementState: ReinforcementState
    var diplomacyState: DiplomacyState
    var divisions: [Division]
    var victoryConditions: [ScenarioVictoryCondition]
    var victoryState: VictoryState
    var selectedUnitSummary: String?
    var eventLog: [GameLogEntry]
    var warDirectiveRecords: [WarDirectiveRecord]
    var playerCommandState: PlayerCommandState

    init(
        scenarioId: String,
        turn: Int,
        maxTurns: Int,
        activeFaction: Faction,
        phase: GamePhase,
        map: MapState,
        terrainRules: TerrainRuleSet = .legacy,
        theaterState: TheaterState = .empty,
        frontLineState: FrontLineState = .empty,
        warDeploymentState: WarDeploymentState = .empty,
        economyState: EconomyState = .empty,
        reinforcementState: ReinforcementState = .empty,
        diplomacyState: DiplomacyState = .empty,
        divisions: [Division],
        victoryConditions: [ScenarioVictoryCondition] = [],
        victoryState: VictoryState,
        selectedUnitSummary: String?,
        eventLog: [GameLogEntry],
        warDirectiveRecords: [WarDirectiveRecord] = [],
        playerCommandState: PlayerCommandState = .empty
    ) {
        self.scenarioId = scenarioId
        self.turn = turn
        self.maxTurns = maxTurns
        self.activeFaction = activeFaction
        self.phase = phase
        self.map = map
        self.terrainRules = terrainRules
        self.theaterState = theaterState
        self.frontLineState = frontLineState
        self.warDeploymentState = warDeploymentState
        self.economyState = economyState
        self.reinforcementState = reinforcementState
        self.diplomacyState = diplomacyState
        self.divisions = divisions
        self.victoryConditions = victoryConditions
        self.victoryState = victoryState
        self.selectedUnitSummary = selectedUnitSummary
        self.eventLog = eventLog
        self.warDirectiveRecords = warDirectiveRecords
        self.playerCommandState = playerCommandState
    }

    static func initial() -> GameState {
        let map = MapState.ardennesV0()

        return GameState(
            scenarioId: "ardennes_v0",
            turn: 1,
            maxTurns: 8,
            activeFaction: .germany,
            phase: .germanAI,
            map: map,
            theaterState: .empty,
            frontLineState: .empty,
            warDeploymentState: .empty,
            economyState: .empty,
            diplomacyState: DiplomacyState.initial(for: Faction.legacyWorldWarIIFactions, turn: 1),
            divisions: [
                .panzer(
                    id: "ger_panzer_1",
                    name: "1st Panzer Division",
                    faction: .germany,
                    coord: HexCoord(q: 9, r: 3)
                ),
                .motorized(
                    id: "ger_motorized_1",
                    name: "2nd Motorized Division",
                    faction: .germany,
                    coord: HexCoord(q: 9, r: 4)
                ),
                .infantry(
                    id: "ger_infantry_1",
                    name: "26th Infantry Division",
                    faction: .germany,
                    coord: HexCoord(q: 10, r: 5)
                ),
                .artillery(
                    id: "ger_artillery_1",
                    name: "7th Artillery Division",
                    faction: .germany,
                    coord: HexCoord(q: 10, r: 3)
                ),
                .infantry(
                    id: "all_infantry_1",
                    name: "101st Infantry Division",
                    faction: .allies,
                    coord: HexCoord(q: 4, r: 5)
                ),
                .infantry(
                    id: "all_anti_tank_1",
                    name: "9th Anti-Tank Battalion",
                    faction: .allies,
                    coord: HexCoord(q: 5, r: 5)
                ),
                .artillery(
                    id: "all_artillery_1",
                    name: "4th Allied Artillery Group",
                    faction: .allies,
                    coord: HexCoord(q: 3, r: 5)
                ),
                .infantry(
                    id: "all_garrison_1",
                    name: "Bastogne Garrison",
                    faction: .allies,
                    coord: HexCoord(q: 5, r: 6)
                )
            ],
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: [
                GameLogEntry(
                    turn: 1,
                    faction: .germany,
                    phase: .germanAI,
                    message: "Archived scenario initialized."
                )
            ]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case scenarioId
        case turn
        case maxTurns
        case activeFaction
        case phase
        case map
        case terrainRules
        case theaterState
        case frontLineState
        case warDeploymentState
        case economyState
        case reinforcementState
        case diplomacyState
        case divisions
        case victoryConditions
        case victoryState
        case selectedUnitSummary
        case eventLog
        case warDirectiveRecords
        case playerCommandState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            scenarioId: try container.decode(String.self, forKey: .scenarioId),
            turn: try container.decode(Int.self, forKey: .turn),
            maxTurns: try container.decode(Int.self, forKey: .maxTurns),
            activeFaction: try container.decode(Faction.self, forKey: .activeFaction),
            phase: try container.decode(GamePhase.self, forKey: .phase),
            map: try container.decode(MapState.self, forKey: .map),
            terrainRules: try container.decodeIfPresent(TerrainRuleSet.self, forKey: .terrainRules) ?? .legacy,
            theaterState: try container.decodeIfPresent(TheaterState.self, forKey: .theaterState) ?? .empty,
            frontLineState: try container.decodeIfPresent(FrontLineState.self, forKey: .frontLineState) ?? .empty,
            warDeploymentState: try container.decodeIfPresent(WarDeploymentState.self, forKey: .warDeploymentState) ?? .empty,
            economyState: try container.decodeIfPresent(EconomyState.self, forKey: .economyState) ?? .empty,
            reinforcementState: try container.decodeIfPresent(ReinforcementState.self, forKey: .reinforcementState) ?? .empty,
            diplomacyState: try container.decodeIfPresent(DiplomacyState.self, forKey: .diplomacyState) ?? .empty,
            divisions: try container.decode([Division].self, forKey: .divisions),
            victoryConditions: try container.decodeIfPresent([ScenarioVictoryCondition].self, forKey: .victoryConditions) ?? [],
            victoryState: try container.decode(VictoryState.self, forKey: .victoryState),
            selectedUnitSummary: try container.decodeIfPresent(String.self, forKey: .selectedUnitSummary),
            eventLog: try container.decode([GameLogEntry].self, forKey: .eventLog),
            warDirectiveRecords: try container.decodeIfPresent([WarDirectiveRecord].self, forKey: .warDirectiveRecords) ?? [],
            playerCommandState: try container.decodeIfPresent(PlayerCommandState.self, forKey: .playerCommandState) ?? .empty
        )
    }

    func division(id: String) -> Division? {
        divisions.first { $0.id == id }
    }

    func divisionIndex(id: String) -> Int? {
        divisions.firstIndex { $0.id == id }
    }

    func division(at coord: HexCoord) -> Division? {
        divisions.first { $0.coord == coord }
    }

    mutating func updateDivision(_ division: Division) {
        guard let index = divisionIndex(id: division.id) else {
            return
        }
        divisions[index] = division
    }

    mutating func removeDivision(id: String) {
        divisions.removeAll { $0.id == id }
    }

    mutating func appendEvent(
        _ message: String,
        category: GameLogCategory = .event,
        relatedRecordId: String? = nil
    ) {
        eventLog.append(
            GameLogEntry(
                turn: turn,
                faction: activeFaction,
                phase: phase,
                category: category,
                relatedRecordId: relatedRecordId,
                message: message
            )
        )
    }

    var participatingFactions: [Faction] {
        let mapControllers = map.tiles.values.compactMap(\.controller)
        let regionControllers = map.regions.values.flatMap { [$0.owner, $0.controller] }
        let supplyFactions = map.supplySources.map(\.faction)
        let factions = [activeFaction] + divisions.map(\.faction) + mapControllers + regionControllers + supplyFactions
        return Self.sortedUniqueFactions(factions)
    }

    var turnOrderFactions: [Faction] {
        let factions = participatingFactions.filter { !$0.isNeutral }
        return factions.isEmpty ? [activeFaction].filter { !$0.isNeutral } : factions
    }

    private static func sortedUniqueFactions(_ factions: [Faction]) -> [Faction] {
        Array(Set(factions)).sorted {
            if $0.turnOrderPriority == $1.turnOrderPriority {
                return $0.rawValue < $1.rawValue
            }
            return $0.turnOrderPriority < $1.turnOrderPriority
        }
    }
}
