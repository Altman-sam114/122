import Foundation

enum MapEditorGameResourceBridgeError: Error, CustomStringConvertible {
    case missingTerrain(String)
    case invalidTileController(String, coord: HexCoord)
    case invalidSupplyFaction(String, coord: HexCoord)
    case unknownFaction(String, unitId: String)
    case invalidFacing(String, unitId: String)
    case invalidRetreatMode(String, unitId: String)
    case invalidSupplyState(String, unitId: String)
    case invalidRegionMappingKey(String)
    case missingResource(URL)

    var description: String {
        switch self {
        case .missingTerrain(let terrain):
            return "Unknown terrain in game data: \(terrain)."
        case .invalidTileController(let faction, let coord):
            return "Unknown tile controller \(faction) at \(coord.q),\(coord.r)."
        case .invalidSupplyFaction(let faction, let coord):
            return "Unknown supply faction \(faction) at \(coord.q),\(coord.r)."
        case .unknownFaction(let faction, let unitId):
            return "Unknown faction \(faction) for unit \(unitId)."
        case .invalidFacing(let facing, let unitId):
            return "Unknown facing \(facing) for unit \(unitId)."
        case .invalidRetreatMode(let retreatMode, let unitId):
            return "Unknown retreat mode \(retreatMode) for unit \(unitId)."
        case .invalidSupplyState(let supplyState, let unitId):
            return "Unknown supply state \(supplyState) for unit \(unitId)."
        case .invalidRegionMappingKey(let key):
            return "Invalid region mapping key: \(key)."
        case .missingResource(let url):
            return "Missing resource: \(url.path)."
        }
    }
}

enum MapEditorGameResourceBridge {
    static let legacyArdennesScenarioResourceName = "ardennes_v0_scenario"
    static let legacyArdennesRegionResourceName = "ardennes_v02_regions"

    // Legacy compatibility aliases for older MapEditor callers. The main game default is ScenarioCatalog.defaultPlayable.
    static let scenarioResourceName = legacyArdennesScenarioResourceName
    static let regionResourceName = legacyArdennesRegionResourceName

    static var gameDataDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "WWIIHexV0")
            .appending(path: "Data")
    }

    /// Legacy wrapper. MapEditor's editable bundled resources are Ardennes compatibility data, not the main playable default.
    static func loadDefaultDocument() throws -> MapEditorDocument {
        try loadLegacyArdennesDocument()
    }

    static func loadLegacyArdennesDocument() throws -> MapEditorDocument {
        let scenarioURL = gameDataDirectory.appending(path: legacyArdennesScenarioResourceName).appendingPathExtension("json")
        let regionURL = gameDataDirectory.appending(path: legacyArdennesRegionResourceName).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: scenarioURL.path) else {
            throw MapEditorGameResourceBridgeError.missingResource(scenarioURL)
        }
        guard FileManager.default.fileExists(atPath: regionURL.path) else {
            throw MapEditorGameResourceBridgeError.missingResource(regionURL)
        }

        let decoder = JSONDecoder()
        let scenario = try decoder.decode(ScenarioDefinition.self, from: Data(contentsOf: scenarioURL))
        let regionData = try decoder.decode(RegionDataSet.self, from: Data(contentsOf: regionURL))
        return try makeDocument(scenario: scenario, regionData: regionData)
    }

    /// Legacy wrapper. Writes the archived Ardennes resources only.
    static func overwriteDefaultGameResources(document: MapEditorDocument) throws -> MapEditorExportResult {
        try overwriteLegacyArdennesGameResources(document: document)
    }

    static func overwriteLegacyArdennesGameResources(document: MapEditorDocument) throws -> MapEditorExportResult {
        let result = try MapEditorExporter.export(
            document: document,
            scenarioFileName: legacyArdennesScenarioResourceName,
            regionFileName: legacyArdennesRegionResourceName
        )
        try MapEditorExporter.write(result, to: gameDataDirectory)
        return result
    }

    private static func makeDocument(
        scenario: ScenarioDefinition,
        regionData: RegionDataSet
    ) throws -> MapEditorDocument {
        let regionMapping = try makeRegionMapping(regionData)
        var hexes: [HexCoord: MapEditorHex] = [:]
        for tile in scenario.map.tiles {
            let coord = HexCoord(q: tile.q, r: tile.r)
            guard let terrain = BaseTerrain(rawValue: tile.terrain) else {
                throw MapEditorGameResourceBridgeError.missingTerrain(tile.terrain)
            }
            guard let controller = Faction(rawValue: tile.controller) else {
                throw MapEditorGameResourceBridgeError.invalidTileController(tile.controller, coord: coord)
            }
            let supplyFaction: Faction?
            if let supplyFactionId = tile.supplyFaction {
                guard let parsedSupplyFaction = Faction(rawValue: supplyFactionId) else {
                    throw MapEditorGameResourceBridgeError.invalidSupplyFaction(supplyFactionId, coord: coord)
                }
                supplyFaction = parsedSupplyFaction
            } else {
                supplyFaction = nil
            }
            hexes[coord] = MapEditorHex(
                coord: coord,
                terrain: terrain,
                hasRoad: tile.hasRoad,
                controller: controller,
                cityName: tile.cityName,
                fortressName: tile.fortressName,
                isSupplySource: tile.isSupplySource,
                supplyFaction: supplyFaction,
                objectiveId: tile.objectiveId,
                regionId: regionMapping[coord] ?? tile.regionId.map { RegionId($0) }
            )
        }

        let regions = Dictionary(uniqueKeysWithValues: regionData.regions.map { definition in
            (
                definition.id,
                MapEditorRegionDraft(
                    id: definition.id,
                    name: definition.name,
                    owner: definition.owner,
                    controller: definition.controller,
                    infrastructure: definition.infrastructure,
                    supplyValue: definition.supplyValue,
                    factories: definition.factories,
                    coreOf: definition.coreOf,
                    assignedGeneralId: definition.assignedGeneralId
                )
            )
        })
        let regionTheaterAssignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.theaterId.map { (definition.id, $0) }
        })
        let theaters = Dictionary(uniqueKeysWithValues: Set(regionTheaterAssignments.values).map { theaterId in
            (theaterId, MapEditorTheaterDraft(id: theaterId))
        })
        let units = try scenario.initialUnits.map { unit in
            guard let faction = Faction(rawValue: unit.faction) else {
                throw MapEditorGameResourceBridgeError.unknownFaction(unit.faction, unitId: unit.id)
            }
            guard let facing = HexDirection(rawValue: unit.facing) else {
                throw MapEditorGameResourceBridgeError.invalidFacing(unit.facing, unitId: unit.id)
            }
            let retreatMode: RetreatMode
            if let retreatModeId = unit.retreatMode {
                guard let parsedRetreatMode = RetreatMode(rawValue: retreatModeId) else {
                    throw MapEditorGameResourceBridgeError.invalidRetreatMode(retreatModeId, unitId: unit.id)
                }
                retreatMode = parsedRetreatMode
            } else {
                retreatMode = .retreatable
            }
            guard let supplyState = SupplyState(rawValue: unit.supplyState) else {
                throw MapEditorGameResourceBridgeError.invalidSupplyState(unit.supplyState, unitId: unit.id)
            }
            return MapEditorUnitDraft(
                id: unit.id,
                name: unit.name,
                faction: faction,
                templateId: unit.templateId,
                coord: HexCoord(q: unit.coord.q, r: unit.coord.r),
                facing: facing,
                hp: unit.hp,
                retreatMode: retreatMode,
                supplyState: supplyState,
                assignedAgentId: unit.assignedAgentId
            )
        }

        return MapEditorDocument(
            id: scenario.id,
            displayName: scenario.displayName,
            width: scenario.map.width,
            height: scenario.map.height,
            hexes: hexes,
            regions: regions,
            theaters: theaters,
            regionTheaterAssignments: regionTheaterAssignments,
            initialUnits: units
        )
    }

    private static func makeRegionMapping(_ regionData: RegionDataSet) throws -> [HexCoord: RegionId] {
        var result: [HexCoord: RegionId] = [:]
        for (key, regionId) in regionData.hexToRegion {
            let parts = key.split(separator: ",")
            guard parts.count == 2,
                  let q = Int(parts[0]),
                  let r = Int(parts[1]) else {
                throw MapEditorGameResourceBridgeError.invalidRegionMappingKey(key)
            }
            result[HexCoord(q: q, r: r)] = regionId
        }
        return result
    }
}
