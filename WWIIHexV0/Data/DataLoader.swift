import Foundation

struct ScenarioCatalogEntry: Equatable, Hashable, Identifiable {
    let id: String
    let runtimeScenarioIds: Set<String>
    let displayName: String
    let scenarioName: String
    let regionName: String
    let terrainRulesName: String
    let unitTemplateName: String
    let generalCatalogName: String
    let defaultPlayerFaction: Faction
    let migrationStage: String
}

enum ScenarioCatalog {
    static let ardennesLegacy = ScenarioCatalogEntry(
        id: "ardennes_v0",
        runtimeScenarioIds: ["mapeditor_scenario"],
        displayName: "Ardennes Legacy",
        scenarioName: "ardennes_v0_scenario",
        regionName: "ardennes_v02_regions",
        terrainRulesName: "terrain_rules",
        unitTemplateName: "unit_templates",
        generalCatalogName: "generals",
        defaultPlayerFaction: .allies,
        migrationStage: "legacy_wwii"
    )

    static let waterloo1815DataSlice = ScenarioCatalogEntry(
        id: "waterloo_1815",
        runtimeScenarioIds: [],
        displayName: "Waterloo 1815",
        scenarioName: "waterloo_1815_scenario",
        regionName: "waterloo_1815_regions",
        terrainRulesName: "napoleonic_terrain_rules",
        unitTemplateName: "napoleonic_unit_templates",
        generalCatalogName: "napoleonic_generals",
        defaultPlayerFaction: .france,
        migrationStage: "v3.2_data_slice"
    )

    static let defaultPlayable = waterloo1815DataSlice
    static let napoleonicTarget = waterloo1815DataSlice

    static let all: [ScenarioCatalogEntry] = [
        waterloo1815DataSlice,
        ardennesLegacy
    ]

    static func entry(for scenarioId: String) -> ScenarioCatalogEntry? {
        all.first { $0.matches(scenarioId) }
    }

    static func displayName(for scenarioId: String) -> String {
        if let entry = entry(for: scenarioId) {
            return entry.displayName
        }

        return scenarioId
            .split(separator: "_")
            .map { String($0).capitalized }
            .joined(separator: " ")
    }
}

extension ScenarioCatalogEntry {
    func matches(_ scenarioId: String) -> Bool {
        id == scenarioId || runtimeScenarioIds.contains(scenarioId)
    }
}

struct DataLoader {
    private let bundle: Bundle
    private let resourceDirectory: URL?
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, resourceDirectory: URL? = nil) {
        self.bundle = bundle
        self.resourceDirectory = resourceDirectory
        self.decoder = JSONDecoder()
    }

    init(resourceDirectory: URL) {
        self.init(bundle: .main, resourceDirectory: resourceDirectory)
    }

    func loadInitialGameState() -> GameState {
        if let state = try? loadGameState(ScenarioCatalog.ardennesLegacy) {
            return state
        }

        var state = GameState.initial()

        // v0.2: 叠加省份数据。加载失败时 fallback 纯 hex（不破现有行为）。
        // 省份是战略层叠加，hex 仍是战术层权威；tiles/objectives/supplySources 不变。
        if let regionData = try? loadArdennesV02Regions() {
            state.map.regions = regionData.toRegions()
            state.map.hexToRegion = regionData.toHexToRegion()
            state.map.regionEdges = regionData.toRegionEdges()
            // 反向填 HexTile.regionId，让 tile.regionId == hexToRegion[tile.coord]
            for (coord, regionId) in state.map.hexToRegion {
                if var tile = state.map.tile(at: coord) {
                    tile.regionId = regionId
                    state.map.setTile(tile)
                }
            }
            state.map = RegionOccupationRules().mapByAggregatingControllers(in: state.map)
            state.theaterState = makeTheaterState(
                map: state.map,
                regionData: regionData,
                divisions: state.divisions,
                diplomacyState: state.diplomacyState,
                turn: state.turn
            )
            state.frontLineState = FrontLineManager().makeInitialState(
                map: state.map,
                theaterState: state.theaterState,
                divisions: state.divisions,
                diplomacyState: state.diplomacyState,
                turn: state.turn
            )
            let deploymentState = WarDeploymentManager().makeInitialState(
                map: state.map,
                theaterState: state.theaterState,
                divisions: state.divisions,
                diplomacyState: state.diplomacyState,
                turn: state.turn
            )
            let generalRegistry = (try? loadGeneralRegistry()) ?? .empty
            state.warDeploymentState = assignGenerals(
                to: deploymentState,
                map: state.map,
                regionData: regionData,
                registry: generalRegistry
            )
        }

        return state
    }

    func loadArdennesDataSet() throws -> ScenarioDataSet {
        let dataSet = ScenarioDataSet(
            scenario: try loadScenarioDefinition(),
            terrainRules: try loadTerrainRules(),
            unitTemplates: try loadUnitTemplates(),
            generalAgents: try loadGeneralAgents()
        )
        try validate(dataSet)
        return dataSet
    }

    func loadScenarioDefinition() throws -> ScenarioDefinition {
        try loadJSON(ScenarioDefinition.self, named: "ardennes_v0_scenario")
    }

    func loadScenarioDefinition(named resourceName: String) throws -> ScenarioDefinition {
        try loadJSON(ScenarioDefinition.self, named: resourceName)
    }

    func loadRegionDataSet(named resourceName: String) throws -> RegionDataSet {
        try loadJSON(RegionDataSet.self, named: resourceName)
    }

    func loadGameState(_ scenario: ScenarioCatalogEntry) throws -> GameState {
        var state = try loadGameState(
            scenarioName: scenario.scenarioName,
            regionName: scenario.regionName,
            unitTemplateName: scenario.unitTemplateName,
            generalCatalogName: scenario.generalCatalogName,
            terrainRulesName: scenario.terrainRulesName
        )
        state.scenarioId = scenario.id
        return state
    }

    /// v0.34: 加载 MapEditor 直接导出的 ScenarioDefinition + RegionDataSet。
    /// 这是编辑器输出的主验收路径，不要求走旧 Ardennes 数据集的 agent/胜利条件强校验。
    func loadGameState(
        scenarioName: String,
        regionName: String,
        unitTemplateName: String = "unit_templates",
        generalCatalogName: String = "generals",
        terrainRulesName: String? = nil
    ) throws -> GameState {
        let scenario = try loadScenarioDefinition(named: scenarioName)
        let initialRuntimeFields = try initialRuntimeFields(for: scenario)
        let regionData = try loadRegionDataSet(named: regionName)
        let unitTemplates = try loadUnitTemplates(named: unitTemplateName)
        let generalRegistry = try loadGeneralRegistry(named: generalCatalogName)
        let resolvedTerrainRulesName = terrainRulesName ?? inferredCatalogEntry(
            scenarioName: scenarioName,
            regionName: regionName
        )?.terrainRulesName
        let terrainRules = try resolvedTerrainRulesName
            .map { try makeTerrainRuleSet(from: loadTerrainRules(named: $0)) } ?? .legacy
        try validateScenarioResources(
            scenario: scenario,
            regionData: regionData,
            unitTemplates: unitTemplates,
            generalRegistry: generalRegistry
        )
        var map = try makeMapState(from: scenario)
        try apply(regionData, to: &map)
        map = RegionOccupationRules().mapByAggregatingControllers(in: map)
        let divisions = try makeDivisions(
            from: scenario.initialUnits,
            unitTemplateName: unitTemplateName
        )
        let reinforcementState = try makeReinforcements(
            from: scenario.reinforcements ?? [],
            unitTemplateName: unitTemplateName,
            map: map
        )
        let turn = scenario.initialTurn
        let diplomacyState = DiplomacyState.initial(from: scenario.factions, turn: turn)

        let theaterState = makeTheaterState(
            map: map,
            regionData: regionData,
            divisions: divisions,
            diplomacyState: diplomacyState,
            turn: turn
        )
        let frontLineState = FrontLineManager().makeInitialState(
            map: map,
            theaterState: theaterState,
            divisions: divisions,
            diplomacyState: diplomacyState,
            turn: turn
        )
        let deploymentState = WarDeploymentManager().makeInitialState(
            map: map,
            theaterState: theaterState,
            divisions: divisions,
            diplomacyState: diplomacyState,
            turn: turn
        )
        let warDeploymentState = assignGenerals(
            to: deploymentState,
            map: map,
            regionData: regionData,
            registry: generalRegistry
        )

        let initialPhase = initialRuntimeFields.phase
        let activeFaction = initialRuntimeFields.activeFaction
        let victoryConditions = try makeVictoryConditions(from: scenario.victoryConditions)

        return GameState(
            scenarioId: scenario.id,
            turn: turn,
            maxTurns: scenario.maxTurns,
            activeFaction: activeFaction,
            phase: initialPhase,
            map: map,
            terrainRules: terrainRules,
            theaterState: theaterState,
            frontLineState: frontLineState,
            warDeploymentState: warDeploymentState,
            reinforcementState: reinforcementState,
            diplomacyState: diplomacyState,
            divisions: divisions,
            victoryConditions: victoryConditions,
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: [
                GameLogEntry(
                    turn: turn,
                    faction: activeFaction,
                    phase: initialPhase,
                    message: ScenarioCatalog.ardennesLegacy.matches(scenario.id)
                        ? "Archived campaign loaded."
                        : "Campaign loaded."
                )
            ]
        )
    }

    private func makeVictoryConditions(
        from definitions: [VictoryConditionDefinition]
    ) throws -> [ScenarioVictoryCondition] {
        var conditions: [ScenarioVictoryCondition] = []
        var errors: [DataValidationError] = []

        for definition in definitions {
            guard let faction = Faction(rawValue: definition.faction) else {
                errors.append(DataValidationError(message: "Victory condition \(definition.id) has unknown faction \(definition.faction)."))
                continue
            }

            var targetFaction: Faction?
            if let targetFactionId = definition.targetFaction {
                guard let parsedTargetFaction = Faction(rawValue: targetFactionId) else {
                    errors.append(DataValidationError(message: "Victory condition \(definition.id) has unknown targetFaction \(targetFactionId)."))
                    continue
                }
                targetFaction = parsedTargetFaction
            }

            conditions.append(
                ScenarioVictoryCondition(
                    id: definition.id,
                    type: definition.type,
                    faction: faction,
                    objectiveId: definition.objectiveId,
                    objectiveIds: definition.objectiveIds ?? [],
                    targetFaction: targetFaction,
                    turn: definition.turn,
                    status: definition.status,
                    description: definition.description
                )
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        return conditions
    }

    private func inferredCatalogEntry(
        scenarioName: String,
        regionName: String
    ) -> ScenarioCatalogEntry? {
        ScenarioCatalog.all.first {
            $0.scenarioName == scenarioName && $0.regionName == regionName
        }
    }

    private func makeTerrainRuleSet(from definition: TerrainRuleDefinition) throws -> TerrainRuleSet {
        var errors: [DataValidationError] = []
        var terrainEntries: [String: TerrainRuleEntry] = [:]

        for (terrainId, entry) in definition.terrain {
            guard BaseTerrain(rawValue: terrainId) != nil else {
                errors.append(DataValidationError(message: "Terrain rules contain unknown terrain \(terrainId)."))
                continue
            }
            if entry.movementCost < 1 {
                errors.append(DataValidationError(message: "Terrain \(terrainId) movementCost must be at least 1."))
            }
            if entry.defenseBonus < 0 {
                errors.append(DataValidationError(message: "Terrain \(terrainId) defenseBonus must not be negative."))
            }
            terrainEntries[terrainId] = TerrainRuleEntry(
                movementCost: entry.movementCost,
                defenseBonus: entry.defenseBonus
            )
        }

        for terrain in BaseTerrain.allCases where terrainEntries[terrain.rawValue] == nil {
            errors.append(DataValidationError(message: "Terrain rules are missing \(terrain.rawValue)."))
        }

        if definition.roadMovementCost < 1 {
            errors.append(DataValidationError(message: "roadMovementCost must be at least 1."))
        }
        if definition.riverCrossingExtraCost < 0 {
            errors.append(DataValidationError(message: "riverCrossingExtraCost must not be negative."))
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        return TerrainRuleSet(
            terrain: terrainEntries,
            roadMovementCost: definition.roadMovementCost,
            riverCrossingExtraCost: definition.riverCrossingExtraCost
        )
    }

    private func initialRuntimeFields(for scenario: ScenarioDefinition) throws -> (phase: GamePhase, activeFaction: Faction) {
        var errors: [DataValidationError] = []
        let declaredFactionIds = Set(scenario.factions)

        for factionId in scenario.factions where Faction(rawValue: factionId) == nil {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) declares unknown faction \(factionId)."))
        }

        guard let phase = GamePhase(rawValue: scenario.initialPhase) else {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) has unknown initialPhase \(scenario.initialPhase)."))
            throw DataLoaderError.validationFailed(errors)
        }

        let playerFaction = Faction(rawValue: scenario.playerFaction)
        if playerFaction == nil {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) has unknown playerFaction \(scenario.playerFaction)."))
        } else if !declaredFactionIds.contains(scenario.playerFaction) {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) playerFaction \(scenario.playerFaction) is not declared in factions."))
        }

        let aiFaction = Faction(rawValue: scenario.aiFaction)
        if aiFaction == nil {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) has unknown aiFaction \(scenario.aiFaction)."))
        } else if !declaredFactionIds.contains(scenario.aiFaction) {
            errors.append(DataValidationError(message: "Scenario \(scenario.id) aiFaction \(scenario.aiFaction) is not declared in factions."))
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        switch phase {
        case .alliedPlayer, .playerCommand:
            return (phase, playerFaction!)
        case .germanAI, .aiCommand:
            return (phase, aiFaction!)
        case .resolution:
            return (phase, playerFaction!)
        }
    }

    func loadTerrainRules() throws -> TerrainRuleDefinition {
        try loadTerrainRules(named: "terrain_rules")
    }

    func loadTerrainRules(_ scenario: ScenarioCatalogEntry) throws -> TerrainRuleDefinition {
        try loadTerrainRules(named: scenario.terrainRulesName)
    }

    func loadTerrainRules(named resourceName: String) throws -> TerrainRuleDefinition {
        try loadJSON(TerrainRuleDefinition.self, named: resourceName)
    }

    func loadUnitTemplates() throws -> [UnitTemplateDefinition] {
        try loadUnitTemplates(named: "unit_templates")
    }

    func loadUnitTemplates(named resourceName: String) throws -> [UnitTemplateDefinition] {
        try loadJSON(UnitTemplateCatalogDefinition.self, named: resourceName).templates
    }

    func loadGeneralAgents() throws -> [GeneralAgentDefinition] {
        try loadJSON(GeneralAgentCatalogDefinition.self, named: "general_agents").agents
    }

    func loadGeneralRegistry() throws -> GeneralRegistry {
        try loadGeneralRegistry(named: "generals")
    }

    func loadGeneralRegistry(_ scenario: ScenarioCatalogEntry) throws -> GeneralRegistry {
        try loadGeneralRegistry(named: scenario.generalCatalogName)
    }

    func loadGeneralRegistry(named resourceName: String) throws -> GeneralRegistry {
        let catalog = try loadJSON(GeneralCatalogDefinition.self, named: resourceName)
        try validateGeneralCatalog(catalog)
        return GeneralRegistry(generals: catalog.generals)
    }

    /// v0.2: 加载阿登省份图数据。失败时抛 DataLoaderError。
    /// 返回的 RegionDataSet 可通过 toRegions()/toRegionEdges()/toHexToRegion() 映射到 MapState 叠加层。
    func loadArdennesV02Regions() throws -> RegionDataSet {
        try loadJSON(RegionDataSet.self, named: "ardennes_v02_regions")
    }

    /// v0.2: 校验省份数据集一致性。复用 RegionGraph.validate + hexToRegion/overlap 检查。
    /// 错误聚合为 DataLoaderError.validationFailed，便于 Agent 5 测试断言。
    func validate(_ regionData: RegionDataSet) throws {
        let regions = regionData.toRegions()
        let hexToRegion = regionData.toHexToRegion()
        let regionEdges = regionData.toRegionEdges()

        // 构临时 MapState 跑 validateRegionGraph（含 hexToRegion + overlap 检查）
        let probe = MapState(
            width: 11,
            height: 9,
            tiles: [:],
            supplySources: [],
            objectives: [],
            regions: regions,
            hexToRegion: hexToRegion,
            regionEdges: regionEdges
        )
        let errors = probe.validateRegionGraph().map { DataValidationError(message: $0.description) }
        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    func validate(_ dataSet: ScenarioDataSet) throws {
        var errors: [DataValidationError] = []
        let scenario = dataSet.scenario

        if !scenario.map.isSparse {
            let expectedTileCount = scenario.map.width * scenario.map.height
            if scenario.map.tiles.count != expectedTileCount {
                errors.append(
                    DataValidationError(
                        message: "Map tile count \(scenario.map.tiles.count) does not match width * height \(expectedTileCount)."
                    )
                )
            }
        }

        let tileCoords: Set<HexCoord> = Set(scenario.map.tiles.map { HexCoord(q: $0.q, r: $0.r) })
        if tileCoords.count != scenario.map.tiles.count {
            errors.append(DataValidationError(message: "Map contains duplicate tile coordinates."))
        }

        let unitIds = scenario.initialUnits.map(\.id)
        appendDuplicateErrors(unitIds, label: "initial unit id", to: &errors)

        let occupiedCoords = scenario.initialUnits.map(\.coord)
        if Set(occupiedCoords).count != occupiedCoords.count {
            errors.append(DataValidationError(message: "Initial units contain overlapping coordinates."))
        }

        for unit in scenario.initialUnits where !tileCoords.contains(HexCoord(q: unit.coord.q, r: unit.coord.r)) {
            errors.append(
                DataValidationError(
                    message: "Initial unit \(unit.id) references missing tile (\(unit.coord.q),\(unit.coord.r))."
                )
            )
        }

        let templateIds = Set(dataSet.unitTemplates.map(\.id))
        appendDuplicateErrors(dataSet.unitTemplates.map(\.id), label: "unit template id", to: &errors)
        for unit in scenario.initialUnits where !templateIds.contains(unit.templateId) {
            errors.append(
                DataValidationError(
                    message: "Initial unit \(unit.id) references unknown template \(unit.templateId)."
                )
            )
        }

        for template in dataSet.unitTemplates {
            let componentWeight = template.components.reduce(0.0) { $0 + $1.weight }
            if abs(componentWeight - 1.0) > 0.0001 {
                errors.append(
                    DataValidationError(
                        message: "Unit template \(template.id) component weights sum to \(componentWeight), expected 1.0."
                    )
                )
            }
        }

        let germanSupplySources = scenario.map.tiles.filter {
            $0.isSupplySource && $0.supplyFaction == "germany"
        }
        let alliedSupplySources = scenario.map.tiles.filter {
            $0.isSupplySource && $0.supplyFaction == "allies"
        }
        if germanSupplySources.isEmpty {
            errors.append(DataValidationError(message: "Scenario is missing a German supply source."))
        }
        if alliedSupplySources.isEmpty {
            errors.append(DataValidationError(message: "Scenario is missing an Allied supply source."))
        }

        let objectiveIds = scenario.objectives.map(\.id)
        appendDuplicateErrors(objectiveIds, label: "objective id", to: &errors)
        let objectiveIdSet = Set(objectiveIds)

        let tileObjectiveIds = scenario.map.tiles.compactMap(\.objectiveId)
        appendDuplicateErrors(tileObjectiveIds, label: "tile objective id", to: &errors)
        for objectiveId in tileObjectiveIds where !objectiveIdSet.contains(objectiveId) {
            errors.append(
                DataValidationError(
                    message: "Tile objective \(objectiveId) is not declared in scenario objectives."
                )
            )
        }

        for condition in scenario.victoryConditions {
            validateVictoryConditionShape(condition, errors: &errors)

            if let targetFaction = condition.targetFaction, !scenario.factions.contains(targetFaction) {
                errors.append(
                    DataValidationError(
                        message: "Victory condition \(condition.id) targetFaction \(targetFaction) is not declared in scenario factions."
                    )
                )
            }

            if let objectiveId = condition.objectiveId, !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "Victory condition \(condition.id) references unknown objective \(objectiveId)."
                    )
                )
            }

            for objectiveId in condition.objectiveIds ?? [] where !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "Victory condition \(condition.id) references unknown objective \(objectiveId)."
                    )
                )
            }
        }

        let agentIds = dataSet.generalAgents.map(\.id)
        appendDuplicateErrors(agentIds, label: "general agent id", to: &errors)

        if ScenarioCatalog.ardennesLegacy.matches(scenario.id) {
            let unitIdSet = Set(unitIds)
            for agent in dataSet.generalAgents {
                for divisionId in agent.assignedDivisionIds where !unitIdSet.contains(divisionId) {
                    errors.append(
                        DataValidationError(
                            message: "Agent \(agent.id) references unknown division \(divisionId)."
                        )
                    )
                }
            }

            if let guderian = dataSet.generalAgents.first(where: { $0.id == "guderian" }) {
                let germanUnitIds = Set(scenario.initialUnits.filter { $0.faction == "germany" }.map(\.id))
                let assignedDivisionIds = Set(guderian.assignedDivisionIds)
                if assignedDivisionIds != germanUnitIds {
                    errors.append(
                        DataValidationError(
                            message: "guderian.assignedDivisionIds must exactly cover German initial units."
                        )
                    )
                }
            } else {
                errors.append(DataValidationError(message: "Scenario is missing guderian agent configuration."))
            }
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func validateScenarioResources(
        scenario: ScenarioDefinition,
        regionData: RegionDataSet,
        unitTemplates: [UnitTemplateDefinition],
        generalRegistry: GeneralRegistry
    ) throws {
        var errors: [DataValidationError] = []
        let declaredFactionIds = Set(scenario.factions)
        let declaredFactions = Set(scenario.factions.compactMap(Faction.init(rawValue:)))
        let tileCoords = Set(scenario.map.tiles.map(\.coord))
        let regionIds = Set(regionData.regions.map(\.id))
        let regionHexToRegion = regionData.toHexToRegion()
        var parsedRegionCoords: Set<HexCoord> = []

        for (key, regionId) in regionData.hexToRegion {
            guard let coord = Self.parseHexToRegionKey(key) else {
                errors.append(
                    DataValidationError(
                        message: "Region data hexToRegion key \(key) is not a valid q,r coordinate."
                    )
                )
                continue
            }

            if !parsedRegionCoords.insert(coord).inserted {
                errors.append(
                    DataValidationError(
                        message: "Region data hexToRegion contains duplicate coordinate \(coord.q),\(coord.r)."
                    )
                )
            }

            if !regionIds.contains(regionId) {
                errors.append(
                    DataValidationError(
                        message: "Region data maps \(coord.q),\(coord.r) to unknown region \(regionId.rawValue)."
                    )
                )
            }
        }

        if !scenarioIdsMatch(scenario.id, regionData.scenarioId) {
            errors.append(
                DataValidationError(
                    message: "Region data scenarioId \(regionData.scenarioId) does not match scenario \(scenario.id)."
                )
            )
        }

        if !scenario.map.isSparse {
            let expectedTileCount = scenario.map.width * scenario.map.height
            if scenario.map.tiles.count != expectedTileCount {
                errors.append(
                    DataValidationError(
                        message: "Map tile count \(scenario.map.tiles.count) does not match width * height \(expectedTileCount)."
                    )
                )
            }
        }

        if tileCoords.count != scenario.map.tiles.count {
            errors.append(DataValidationError(message: "Map contains duplicate tile coordinates."))
        }

        for tile in scenario.map.tiles {
            guard let controller = Faction(rawValue: tile.controller) else {
                errors.append(DataValidationError(message: "Tile \(tile.q),\(tile.r) has unknown controller \(tile.controller)."))
                continue
            }
            if !declaredFactions.contains(controller) {
                errors.append(DataValidationError(message: "Tile \(tile.q),\(tile.r) controller \(controller.rawValue) is not declared in scenario factions."))
            }

            if tile.isSupplySource {
                guard let supplyFactionId = tile.supplyFaction else {
                    errors.append(DataValidationError(message: "Supply tile \(tile.q),\(tile.r) is missing supplyFaction."))
                    continue
                }
                guard let supplyFaction = Faction(rawValue: supplyFactionId) else {
                    errors.append(DataValidationError(message: "Supply tile \(tile.q),\(tile.r) has unknown supplyFaction \(supplyFactionId)."))
                    continue
                }
                if !declaredFactions.contains(supplyFaction) {
                    errors.append(DataValidationError(message: "Supply tile \(tile.q),\(tile.r) supplyFaction \(supplyFaction.rawValue) is not declared in scenario factions."))
                }
            }

            for riverEdge in tile.riverEdges where HexDirection(rawValue: riverEdge) == nil {
                errors.append(
                    DataValidationError(
                        message: "Tile \(tile.q),\(tile.r) has unknown river edge \(riverEdge)."
                    )
                )
            }

            let coord = HexCoord(q: tile.q, r: tile.r)
            if let regionId = tile.regionId.map({ RegionId(rawValue: $0) }) {
                if !regionIds.contains(regionId) {
                    errors.append(
                        DataValidationError(
                            message: "Tile \(tile.q),\(tile.r) references unknown regionId \(regionId.rawValue)."
                        )
                    )
                }

                guard let mappedRegionId = regionHexToRegion[coord] else {
                    errors.append(
                        DataValidationError(
                            message: "Tile \(tile.q),\(tile.r) regionId \(regionId.rawValue) is missing from region data hexToRegion."
                        )
                    )
                    continue
                }

                if mappedRegionId != regionId {
                    errors.append(
                        DataValidationError(
                            message: "Tile \(tile.q),\(tile.r) regionId \(regionId.rawValue) does not match region data \(mappedRegionId.rawValue)."
                        )
                    )
                }
            }
        }

        for (coord, regionId) in regionHexToRegion where !tileCoords.contains(coord) {
            errors.append(
                DataValidationError(
                    message: "Region data maps missing tile \(coord.q),\(coord.r) to region \(regionId.rawValue)."
                )
            )
        }

        for region in regionData.regions {
            for coord in region.displayHexes where !tileCoords.contains(coord) {
                errors.append(
                    DataValidationError(
                        message: "Region \(region.id.rawValue) displayHexes references missing tile \(coord.q),\(coord.r)."
                    )
                )
            }
            if !tileCoords.contains(region.representativeHex) {
                errors.append(
                    DataValidationError(
                        message: "Region \(region.id.rawValue) representativeHex references missing tile \(region.representativeHex.q),\(region.representativeHex.r)."
                    )
                )
            }
            if let assignedGeneralId = region.assignedGeneralId,
               generalRegistry.general(id: assignedGeneralId) == nil {
                errors.append(
                    DataValidationError(
                        message: "Region \(region.id.rawValue) references unknown assignedGeneralId \(assignedGeneralId)."
                    )
                )
            }
        }

        let theaterIds = Set(regionData.regions.compactMap(\.theaterId))
        validateGeneralRegistry(
            generalRegistry,
            declaredFactionIds: declaredFactionIds,
            regionIds: regionIds,
            theaterIds: theaterIds,
            errors: &errors
        )

        var templatesById: [String: UnitTemplateDefinition] = [:]
        for template in unitTemplates where templatesById[template.id] == nil {
            templatesById[template.id] = template
        }
        let templateIds = Set(templatesById.keys)
        appendDuplicateErrors(unitTemplates.map(\.id), label: "unit template id", to: &errors)
        for template in unitTemplates {
            if template.maxHP <= 0 {
                errors.append(DataValidationError(message: "Unit template \(template.id) maxHP must be positive."))
            }
            if template.components.isEmpty {
                errors.append(DataValidationError(message: "Unit template \(template.id) must contain at least one component."))
            }
            let componentWeight = template.components.reduce(0.0) { $0 + $1.weight }
            if abs(componentWeight - 1.0) > 0.0001 {
                errors.append(
                    DataValidationError(
                        message: "Unit template \(template.id) component weights sum to \(componentWeight), expected 1.0."
                    )
                )
            }
            for component in template.components {
                if component.weight <= 0 {
                    errors.append(
                        DataValidationError(
                            message: "Unit template \(template.id) component \(component.type) weight must be positive."
                        )
                    )
                }
                if ComponentType(rawValue: component.type) == nil {
                    errors.append(
                        DataValidationError(
                            message: "Unit template \(template.id) contains unknown component type \(component.type)."
                        )
                    )
                }
            }
        }

        validateKeyLocations(
            scenario.keyLocations,
            declaredFactionIds: declaredFactionIds,
            tileCoords: tileCoords,
            objectiveIds: Set(scenario.objectives.map(\.id)),
            errors: &errors
        )

        validateUnits(
            scenario.initialUnits,
            declaredFactionIds: declaredFactionIds,
            tileCoords: tileCoords,
            templatesById: templatesById,
            generalRegistry: generalRegistry,
            errors: &errors
        )

        let reinforcementIds = scenario.reinforcements?.map(\.id) ?? []
        appendDuplicateErrors(reinforcementIds, label: "reinforcement id", to: &errors)

        let objectiveIds = scenario.objectives.map(\.id)
        appendDuplicateErrors(objectiveIds, label: "objective id", to: &errors)
        let objectiveIdSet = Set(objectiveIds)

        let tileObjectiveIds = scenario.map.tiles.compactMap(\.objectiveId)
        appendDuplicateErrors(tileObjectiveIds, label: "tile objective id", to: &errors)
        for objectiveId in tileObjectiveIds where !objectiveIdSet.contains(objectiveId) {
            errors.append(
                DataValidationError(
                    message: "Tile objective \(objectiveId) is not declared in scenario objectives."
                )
            )
        }

        for objective in scenario.objectives {
            let coord = HexCoord(q: objective.coord.q, r: objective.coord.r)
            if !tileCoords.contains(coord) {
                errors.append(
                    DataValidationError(
                        message: "Objective \(objective.id) references missing tile \(coord.q),\(coord.r)."
                    )
                )
            }
            if ObjectiveType(rawValue: objective.kind) == nil {
                errors.append(DataValidationError(message: "Objective \(objective.id) has unknown kind \(objective.kind)."))
            }
        }

        for condition in scenario.victoryConditions {
            validateVictoryConditionShape(condition, errors: &errors)

            if !declaredFactionIds.contains(condition.faction) {
                errors.append(DataValidationError(message: "Victory condition \(condition.id) faction \(condition.faction) is not declared in scenario factions."))
            }
            if let targetFaction = condition.targetFaction, !declaredFactionIds.contains(targetFaction) {
                errors.append(DataValidationError(message: "Victory condition \(condition.id) targetFaction \(targetFaction) is not declared in scenario factions."))
            }
            if let objectiveId = condition.objectiveId, !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "Victory condition \(condition.id) references unknown objective \(objectiveId)."
                    )
                )
            }
            for objectiveId in condition.objectiveIds ?? [] where !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "Victory condition \(condition.id) references unknown objective \(objectiveId)."
                    )
                )
            }
        }

        for reinforcement in scenario.reinforcements ?? [] {
            validateReinforcement(
                reinforcement,
                declaredFactionIds: declaredFactionIds,
                tileCoords: tileCoords,
                templatesById: templatesById,
                objectiveIds: objectiveIdSet,
                generalRegistry: generalRegistry,
                errors: &errors
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func validateVictoryConditionShape(
        _ condition: VictoryConditionDefinition,
        errors: inout [DataValidationError]
    ) {
        switch condition.type {
        case "holdObjective":
            if condition.objectiveId == nil {
                errors.append(DataValidationError(message: "Victory condition \(condition.id) type holdObjective requires objectiveId."))
            }
        case "holdObjectives":
            if condition.objectiveIds?.isEmpty != false {
                errors.append(DataValidationError(message: "Victory condition \(condition.id) type holdObjectives requires non-empty objectiveIds."))
            }
        default:
            errors.append(DataValidationError(message: "Victory condition \(condition.id) has unsupported type \(condition.type)."))
        }

        switch condition.id {
        case "french_break_center":
            if condition.type != "holdObjective" {
                errors.append(DataValidationError(message: "Victory condition french_break_center must use type holdObjective."))
            }
            if condition.targetFaction != nil {
                errors.append(DataValidationError(message: "Victory condition french_break_center must not set targetFaction."))
            }
        case "coalition_hold_until_prussia":
            if condition.type != "holdObjectives" {
                errors.append(DataValidationError(message: "Victory condition coalition_hold_until_prussia must use type holdObjectives."))
            }
            if condition.turn == nil {
                errors.append(DataValidationError(message: "Victory condition coalition_hold_until_prussia requires turn."))
            }
            if condition.targetFaction == nil {
                errors.append(DataValidationError(message: "Victory condition coalition_hold_until_prussia requires targetFaction."))
            }
        default:
            break
        }
    }

    private func validateGeneralCatalog(_ catalog: GeneralCatalogDefinition) throws {
        var errors: [DataValidationError] = []
        appendDuplicateErrors(catalog.generals.map(\.id), label: "general id", to: &errors)
        for general in catalog.generals {
            if general.id.isEmpty {
                errors.append(DataValidationError(message: "General id must not be empty."))
            }
            if general.name.isEmpty {
                errors.append(DataValidationError(message: "General \(general.id) name must not be empty."))
            }
            if general.baseLoyalty < 0 || general.baseLoyalty > 100 {
                errors.append(DataValidationError(message: "General \(general.id) baseLoyalty must be between 0 and 100."))
            }
            if general.baseSatisfaction < 0 || general.baseSatisfaction > 100 {
                errors.append(DataValidationError(message: "General \(general.id) baseSatisfaction must be between 0 and 100."))
            }
        }
        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func validateGeneralRegistry(
        _ registry: GeneralRegistry,
        declaredFactionIds: Set<String>,
        regionIds: Set<RegionId>,
        theaterIds: Set<TheaterId>,
        errors: inout [DataValidationError]
    ) {
        for general in registry.allGenerals {
            if !declaredFactionIds.contains(general.faction.rawValue) {
                errors.append(DataValidationError(message: "General \(general.id) faction \(general.faction.rawValue) is not declared in scenario factions."))
            }
            for regionId in general.preferredRegionIds where !regionIds.contains(regionId) {
                errors.append(DataValidationError(message: "General \(general.id) preferredRegionIds references unknown region \(regionId.rawValue)."))
            }
            for theaterId in general.preferredTheaterIds where !theaterIds.contains(theaterId) {
                errors.append(DataValidationError(message: "General \(general.id) preferredTheaterIds references unknown theater \(theaterId.rawValue)."))
            }
        }
    }

    private func validateKeyLocations(
        _ keyLocations: [KeyLocationDefinition],
        declaredFactionIds: Set<String>,
        tileCoords: Set<HexCoord>,
        objectiveIds: Set<String>,
        errors: inout [DataValidationError]
    ) {
        let allowedKinds: Set<String> = [
            "bridge",
            "farm",
            "reinforcement_entry",
            "ridge",
            "road",
            "strongpoint",
            "town",
            "village",
            "wood"
        ]
        appendDuplicateErrors(keyLocations.map(\.id), label: "key location id", to: &errors)
        for location in keyLocations {
            if !allowedKinds.contains(location.kind) {
                errors.append(DataValidationError(message: "Key location \(location.id) has unsupported kind \(location.kind)."))
            }
            let coord = HexCoord(q: location.coord.q, r: location.coord.r)
            if !tileCoords.contains(coord) {
                errors.append(DataValidationError(message: "Key location \(location.id) references missing tile \(coord.q),\(coord.r)."))
            }
            if let faction = location.faction {
                if Faction(rawValue: faction) == nil {
                    errors.append(DataValidationError(message: "Key location \(location.id) has unknown faction \(faction)."))
                } else if !declaredFactionIds.contains(faction) {
                    errors.append(DataValidationError(message: "Key location \(location.id) faction \(faction) is not declared in scenario factions."))
                }
            }
            if let objectiveId = location.objectiveId, !objectiveIds.contains(objectiveId) {
                errors.append(DataValidationError(message: "Key location \(location.id) references unknown objectiveId \(objectiveId)."))
            }
        }
    }

    private func validateUnits(
        _ units: [InitialUnitDefinition],
        declaredFactionIds: Set<String>,
        tileCoords: Set<HexCoord>,
        templatesById: [String: UnitTemplateDefinition],
        generalRegistry: GeneralRegistry,
        errors: inout [DataValidationError]
    ) {
        appendDuplicateErrors(units.map(\.id), label: "initial unit id", to: &errors)

        let occupiedCoords = units.map { HexCoord(q: $0.coord.q, r: $0.coord.r) }
        if Set(occupiedCoords).count != occupiedCoords.count {
            errors.append(DataValidationError(message: "Initial units contain overlapping coordinates."))
        }

        for unit in units {
            if Faction(rawValue: unit.faction) == nil {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) has unknown faction \(unit.faction)."))
            } else if !declaredFactionIds.contains(unit.faction) {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) faction \(unit.faction) is not declared in scenario factions."))
            }

            if let template = templatesById[unit.templateId] {
                if unit.hp <= 0 || unit.hp > template.maxHP {
                    errors.append(DataValidationError(message: "Initial unit \(unit.id) hp \(unit.hp) must be between 1 and template maxHP \(template.maxHP)."))
                }
            } else {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) references unknown template \(unit.templateId)."))
            }

            if HexDirection(rawValue: unit.facing) == nil {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) has unknown facing \(unit.facing)."))
            }
            if SupplyState(rawValue: unit.supplyState) == nil {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) has unknown supplyState \(unit.supplyState)."))
            }
            if let retreatMode = unit.retreatMode, RetreatMode(rawValue: retreatMode) == nil {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) has unknown retreatMode \(retreatMode)."))
            }

            let coord = HexCoord(q: unit.coord.q, r: unit.coord.r)
            if !tileCoords.contains(coord) {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) references missing tile \(coord.q),\(coord.r)."))
            }

            if let assignedAgentId = unit.assignedAgentId,
               generalRegistry.general(id: assignedAgentId) == nil {
                errors.append(DataValidationError(message: "Initial unit \(unit.id) references unknown assignedAgentId \(assignedAgentId)."))
            }
        }
    }

    private func validateReinforcement(
        _ reinforcement: ReinforcementDefinition,
        declaredFactionIds: Set<String>,
        tileCoords: Set<HexCoord>,
        templatesById: [String: UnitTemplateDefinition],
        objectiveIds: Set<String>,
        generalRegistry: GeneralRegistry,
        errors: inout [DataValidationError]
    ) {
        if Faction(rawValue: reinforcement.faction) == nil {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) has unknown faction \(reinforcement.faction)."))
        } else if !declaredFactionIds.contains(reinforcement.faction) {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) faction \(reinforcement.faction) is not declared in scenario factions."))
        }

        if let template = templatesById[reinforcement.templateId] {
            if reinforcement.hp <= 0 || reinforcement.hp > template.maxHP {
                errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) hp \(reinforcement.hp) must be between 1 and template maxHP \(template.maxHP)."))
            }
        } else {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) references unknown template \(reinforcement.templateId)."))
        }

        if HexDirection(rawValue: reinforcement.facing) == nil {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) has unknown facing \(reinforcement.facing)."))
        }
        if SupplyState(rawValue: reinforcement.supplyState) == nil {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) has unknown supplyState \(reinforcement.supplyState)."))
        }
        if let retreatMode = reinforcement.retreatMode, RetreatMode(rawValue: retreatMode) == nil {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) has unknown retreatMode \(retreatMode)."))
        }

        let entryCoord = HexCoord(q: reinforcement.entryCoord.q, r: reinforcement.entryCoord.r)
        if !tileCoords.contains(entryCoord) {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) references missing entry tile \(entryCoord.q),\(entryCoord.r)."))
        }

        if let triggerObjectiveId = reinforcement.triggerObjectiveId,
           !objectiveIds.contains(triggerObjectiveId) {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) references unknown triggerObjectiveId \(triggerObjectiveId)."))
        }

        if let triggerController = reinforcement.triggerController {
            if Faction(rawValue: triggerController) == nil {
                errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) has unknown trigger controller \(triggerController)."))
            } else if !declaredFactionIds.contains(triggerController) {
                errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) trigger controller \(triggerController) is not declared in scenario factions."))
            }
        }

        if let assignedAgentId = reinforcement.assignedAgentId,
           generalRegistry.general(id: assignedAgentId) == nil {
            errors.append(DataValidationError(message: "Reinforcement \(reinforcement.id) references unknown assignedAgentId \(assignedAgentId)."))
        }
    }

    private func scenarioIdsMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs {
            return true
        }
        if let entry = ScenarioCatalog.entry(for: lhs), entry.matches(rhs) {
            return true
        }
        if let entry = ScenarioCatalog.entry(for: rhs), entry.matches(lhs) {
            return true
        }
        return false
    }

    private static func parseHexToRegionKey(_ key: String) -> HexCoord? {
        let parts = key.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let q = Int(parts[0]),
              let r = Int(parts[1]) else {
            return nil
        }
        return HexCoord(q: q, r: r)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, named resourceName: String) throws -> T {
        let url = try resourceURL(named: resourceName)
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func makeMapState(from scenario: ScenarioDefinition) throws -> MapState {
        var errors: [DataValidationError] = []
        var tiles: [HexCoord: HexTile] = [:]
        var supplySources: [SupplySource] = []
        var objectives: [Objective] = []

        for tileDefinition in scenario.map.tiles {
            let coord = HexCoord(q: tileDefinition.q, r: tileDefinition.r)
            guard tiles[coord] == nil else {
                errors.append(DataValidationError(message: "Duplicate tile coordinate \(coord.q),\(coord.r)."))
                continue
            }

            guard let terrain = BaseTerrain(rawValue: tileDefinition.terrain) else {
                errors.append(DataValidationError(message: "Unknown terrain \(tileDefinition.terrain) at \(coord.q),\(coord.r)."))
                continue
            }

            let controller = Faction(rawValue: tileDefinition.controller)
            let riverEdges = Set(tileDefinition.riverEdges.compactMap(HexDirection.init(rawValue:)))
            let regionId = tileDefinition.regionId.map { RegionId($0) }
            let tile = HexTile(
                coord: coord,
                baseTerrain: terrain,
                hasRoad: tileDefinition.hasRoad,
                riverEdges: riverEdges,
                controller: controller,
                cityName: tileDefinition.cityName,
                fortressName: tileDefinition.fortressName,
                isPassable: true,
                regionId: regionId
            )
            tiles[coord] = tile

            if tileDefinition.isSupplySource,
               let supplyFactionString = tileDefinition.supplyFaction,
               let supplyFaction = Faction(rawValue: supplyFactionString) {
                supplySources.append(
                    SupplySource(
                        id: "supply_\(coord.q)_\(coord.r)",
                        faction: supplyFaction,
                        coord: coord
                    )
                )
            }
        }

        for objectiveDefinition in scenario.objectives {
            guard let type = ObjectiveType(rawValue: objectiveDefinition.kind) else {
                errors.append(DataValidationError(message: "Unknown objective type \(objectiveDefinition.kind)."))
                continue
            }
            objectives.append(
                Objective(
                    id: objectiveDefinition.id,
                    name: objectiveDefinition.name,
                    coord: HexCoord(q: objectiveDefinition.coord.q, r: objectiveDefinition.coord.r),
                    type: type
                )
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        return MapState(
            width: scenario.map.width,
            height: scenario.map.height,
            tiles: tiles,
            supplySources: supplySources,
            objectives: objectives
        )
    }

    private func apply(_ regionData: RegionDataSet, to map: inout MapState) throws {
        map.regions = regionData.toRegions()
        map.hexToRegion = regionData.toHexToRegion()
        map.regionEdges = regionData.toRegionEdges()

        for (coord, regionId) in map.hexToRegion {
            guard var tile = map.tile(at: coord) else { continue }
            tile.regionId = regionId
            map.setTile(tile)
        }

        let errors = map.validateRegionGraph().map { DataValidationError(message: $0.description) }
        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func assignGenerals(
        to deploymentState: WarDeploymentState,
        map: MapState,
        regionData: RegionDataSet,
        registry: GeneralRegistry = .empty
    ) -> WarDeploymentState {
        let seedAssignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.assignedGeneralId.map { (definition.id, $0) }
        })
        return GeneralDispatcher(registry: registry).assignGenerals(
            to: deploymentState,
            map: map,
            seedAssignments: seedAssignments
        )
    }

    private func makeDivisions(
        from definitions: [InitialUnitDefinition],
        unitTemplateName: String = "unit_templates"
    ) throws -> [Division] {
        let templates = try loadUnitTemplates(named: unitTemplateName)
        let usesLegacyFallback = unitTemplateName == "unit_templates"
        var errors: [DataValidationError] = []
        let divisions = definitions.compactMap { definition -> Division? in
            guard let faction = Faction(rawValue: definition.faction) else {
                errors.append(DataValidationError(message: "Unknown unit faction \(definition.faction)."))
                return nil
            }

            let components: [DivisionComponent]
            let maxHP: Int
            if let template = templates.first(where: { $0.id == definition.templateId }) {
                maxHP = usesLegacyFallback ? 10 : template.maxHP
                var parsedComponents: [DivisionComponent] = []
                for component in template.components {
                    guard let type = ComponentType(rawValue: component.type) else {
                        errors.append(
                            DataValidationError(
                                message: "Unit template \(template.id) contains unknown component type \(component.type)."
                            )
                        )
                        continue
                    }
                    parsedComponents.append(DivisionComponent(type: type, weight: component.weight))
                }
                components = parsedComponents
            } else if usesLegacyFallback {
                maxHP = 10
                components = fallbackComponents(for: definition.templateId)
            } else {
                errors.append(DataValidationError(message: "Unit \(definition.id) references unknown template \(definition.templateId)."))
                return nil
            }

            guard !components.isEmpty else {
                errors.append(DataValidationError(message: "Unit \(definition.id) references unknown template \(definition.templateId)."))
                return nil
            }

            return Division(
                id: definition.id,
                name: definition.name,
                faction: faction,
                coord: HexCoord(q: definition.coord.q, r: definition.coord.r),
                facing: HexDirection(rawValue: definition.facing) ?? .west,
                hp: definition.hp,
                maxHP: maxHP,
                components: components,
                supplyState: SupplyState(rawValue: definition.supplyState) ?? .supplied,
                retreatMode: definition.retreatMode.flatMap(RetreatMode.init(rawValue:)) ?? .retreatable
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
        return divisions
    }

    private func makeReinforcements(
        from definitions: [ReinforcementDefinition],
        unitTemplateName: String = "unit_templates",
        map: MapState
    ) throws -> ReinforcementState {
        guard !definitions.isEmpty else {
            return .empty
        }

        let templates = try loadUnitTemplates(named: unitTemplateName)
        let usesLegacyFallback = unitTemplateName == "unit_templates"
        var errors: [DataValidationError] = []
        appendDuplicateErrors(definitions.map(\.id), label: "reinforcement id", to: &errors)

        let scheduled = definitions.compactMap { definition -> ScheduledReinforcement? in
            guard let faction = Faction(rawValue: definition.faction) else {
                errors.append(DataValidationError(message: "Unknown reinforcement faction \(definition.faction)."))
                return nil
            }

            let entryCoord = HexCoord(q: definition.entryCoord.q, r: definition.entryCoord.r)
            guard map.tile(at: entryCoord) != nil else {
                errors.append(
                    DataValidationError(
                        message: "Reinforcement \(definition.id) references missing entry tile \(entryCoord.q),\(entryCoord.r)."
                    )
                )
                return nil
            }

            let components: [DivisionComponent]
            let maxHP: Int
            if let template = templates.first(where: { $0.id == definition.templateId }) {
                maxHP = usesLegacyFallback ? 10 : template.maxHP
                var parsedComponents: [DivisionComponent] = []
                for component in template.components {
                    guard let type = ComponentType(rawValue: component.type) else {
                        errors.append(
                            DataValidationError(
                                message: "Reinforcement template \(template.id) contains unknown component type \(component.type)."
                            )
                        )
                        continue
                    }
                    parsedComponents.append(DivisionComponent(type: type, weight: component.weight))
                }
                components = parsedComponents
            } else if usesLegacyFallback {
                maxHP = 10
                components = fallbackComponents(for: definition.templateId)
            } else {
                errors.append(DataValidationError(message: "Reinforcement \(definition.id) references unknown template \(definition.templateId)."))
                return nil
            }

            guard !components.isEmpty else {
                errors.append(DataValidationError(message: "Reinforcement \(definition.id) references empty template \(definition.templateId)."))
                return nil
            }

            let triggerController = definition.triggerController.flatMap(Faction.init(rawValue:))
            if definition.triggerController != nil && triggerController == nil {
                errors.append(DataValidationError(message: "Reinforcement \(definition.id) has unknown trigger controller \(definition.triggerController ?? "")."))
                return nil
            }

            let division = Division(
                id: definition.id,
                name: definition.name,
                faction: faction,
                coord: entryCoord,
                facing: HexDirection(rawValue: definition.facing) ?? .west,
                hp: definition.hp,
                maxHP: maxHP,
                components: components,
                supplyState: SupplyState(rawValue: definition.supplyState) ?? .supplied,
                retreatMode: definition.retreatMode.flatMap(RetreatMode.init(rawValue:)) ?? .retreatable
            )

            return ScheduledReinforcement(
                id: definition.id,
                arrivalTurn: max(1, definition.arrivalTurn),
                entryCoord: entryCoord,
                division: division,
                triggerObjectiveId: definition.triggerObjectiveId,
                triggerController: triggerController
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        return ReinforcementState(pending: scheduled)
    }

    private func fallbackComponents(for templateId: String) -> [DivisionComponent] {
        switch templateId {
        case "tank_division", "panzer_division":
            return [DivisionComponent(type: .tank, weight: 0.7), DivisionComponent(type: .motorizedInfantry, weight: 0.3)]
        case "motorized_division":
            return [DivisionComponent(type: .motorizedInfantry, weight: 1.0)]
        case "artillery_division":
            return [DivisionComponent(type: .artillery, weight: 1.0)]
        default:
            return [DivisionComponent(type: .infantry, weight: 1.0)]
        }
    }

    private func makeTheaterState(
        map: MapState,
        regionData: RegionDataSet,
        divisions: [Division],
        diplomacyState: DiplomacyState = .empty,
        turn: Int
    ) -> TheaterState {
        let assignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.theaterId.map { (definition.id, $0) }
        })

        guard !assignments.isEmpty else {
            return TheaterSystem().makeInitialFixedTheaters(
                map: map,
                divisions: divisions,
                diplomacyState: diplomacyState,
                turn: turn
            )
        }

        var groupedRegions: [TheaterId: [RegionId]] = [:]
        for regionId in map.regions.keys {
            let theaterId = assignments[regionId] ?? TheaterId("unassigned")
            groupedRegions[theaterId, default: []].append(regionId)
        }

        let theaters = Dictionary(uniqueKeysWithValues: groupedRegions.map { theaterId, regionIds in
            let sortedRegionIds = regionIds.sorted { $0.rawValue < $1.rawValue }
            let controllingFaction = majorityController(regionIds: sortedRegionIds, map: map)
            return (
                theaterId,
                TheaterNode(
                    id: theaterId,
                    name: theaterId.rawValue,
                    status: .active,
                    regionIds: sortedRegionIds,
                    controllingFaction: controllingFaction
                )
            )
        })

        let regionToTheater = Dictionary(uniqueKeysWithValues: groupedRegions.flatMap { theaterId, regionIds in
            regionIds.map { ($0, theaterId) }
        })
        let state = TheaterState(theaters: theaters, regionToTheater: regionToTheater)
        var updated = TheaterSystem().updateTheaters(
            state: state,
            map: map,
            divisions: divisions,
            diplomacyState: diplomacyState,
            turn: turn
        )
        updated.initialSnapshot = TheaterInitialSnapshot.capture(from: updated)
        return updated
    }

    private func majorityController(regionIds: [RegionId], map: MapState) -> Faction? {
        let counts = Dictionary(grouping: regionIds.compactMap { map.regions[$0]?.controller }) { $0 }
            .mapValues(\.count)
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }.first?.key
    }

    private func resourceURL(named resourceName: String) throws -> URL {
        if let resourceDirectory {
            return resourceDirectory
                .appendingPathComponent(resourceName)
                .appendingPathExtension("json")
        }

        #if DEBUG
        if let sourceURL = sourceDataURL(named: resourceName) {
            return sourceURL
        }
        #endif

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw DataLoaderError.missingResource(resourceName)
        }
        return url
    }

    #if DEBUG
    private func sourceDataURL(named resourceName: String) -> URL? {
        let fileURL = URL(fileURLWithPath: #filePath)
        let dataDirectory = fileURL.deletingLastPathComponent()
        let url = dataDirectory
            .appendingPathComponent(resourceName)
            .appendingPathExtension("json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    #endif

    private func appendDuplicateErrors(
        _ values: [String],
        label: String,
        to errors: inout [DataValidationError]
    ) {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for value in values where !seen.insert(value).inserted {
            duplicates.insert(value)
        }

        for duplicate in duplicates.sorted() {
            errors.append(DataValidationError(message: "Duplicate \(label): \(duplicate)."))
        }
    }
}
