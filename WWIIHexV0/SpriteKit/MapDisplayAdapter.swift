import SpriteKit

typealias DisplayColor = SKColor

enum VisibilityState: Equatable {
    case unseen
    case explored
    case visible
}

struct HexDisplayState {
    let coord: HexCoord
    let regionId: RegionId?
    let terrain: BaseTerrain
    let controller: Faction?
    let cityName: String?
    let fortressName: String?
    let isRepresentative: Bool
    let visibility: VisibilityState
}

struct UnitDisplayPlacement: Equatable {
    let divisionId: String
    let hex: HexCoord
    let offset: CGPoint
    let stackIndex: Int
    let stackCount: Int
}

extension UnitDisplayPlacement {
    static func == (lhs: UnitDisplayPlacement, rhs: UnitDisplayPlacement) -> Bool {
        lhs.divisionId == rhs.divisionId &&
            lhs.hex == rhs.hex &&
            lhs.offset.x == rhs.offset.x &&
            lhs.offset.y == rhs.offset.y &&
            lhs.stackIndex == rhs.stackIndex &&
            lhs.stackCount == rhs.stackCount
    }
}

struct RegionInspectorState: Equatable {
    let region: RegionNode
    let selectedHex: HexCoord?
    let selectedHexController: Faction?
    let selectedHexDynamicTheaterId: TheaterId?
    let selectedHexDynamicTheaterDisplayName: String
    let selectedHexFrontZoneId: FrontZoneId?
    let selectedHexFrontZoneDisplayName: String
    let theaterId: TheaterId?
    let theaterDisplayName: String
    let frontZoneId: FrontZoneId?
    let frontZoneDisplayName: String
    let frontPressure: Double
    let friendlyDivisions: [Division]
    let visibleEnemyDivisions: [Division]
    let objectiveNames: [String]
    let objectiveStatus: String
    let cityLevel: CityLevel
    let economicOutput: EconomyResources
}

struct UnitInspectorStrategicState: Equatable {
    let coord: HexCoord
    let regionId: RegionId?
    let regionDisplayName: String
    let dynamicTheaterId: TheaterId?
    let dynamicTheaterDisplayName: String
    let frontLineIds: [FrontLineId]
    let frontLineDisplayNames: [String]
    let frontZoneId: FrontZoneId?
    let frontZoneDisplayName: String
    let deploymentRole: UnitDeploymentRole
}

struct MapDisplayAdapter {
    let state: GameState
    let revealAll: Bool

    init(state: GameState, revealAll: Bool = false) {
        self.state = state
        self.revealAll = revealAll
    }

    func regionId(for hex: HexCoord) -> RegionId? {
        state.map.region(for: hex)
    }

    func displayHexes(for regionId: RegionId) -> [HexCoord] {
        state.map.region(id: regionId)?.displayHexes ?? []
    }

    func representativeHex(for regionId: RegionId) -> HexCoord? {
        state.map.representativeHex(for: regionId)
    }

    func terrainColor(for hex: HexCoord) -> DisplayColor {
        TerrainStyle.fillColor(for: terrain(for: hex))
    }

    func controllerColor(for hex: HexCoord) -> DisplayColor {
        TerrainStyle.controllerColor(for: controller(for: hex))
    }

    func unitDisplayHex(for division: Division) -> HexCoord? {
        division.coord
    }

    func visibility(for hex: HexCoord, faction: Faction) -> VisibilityState {
        if revealAll {
            return .visible
        }
        guard !state.map.regions.isEmpty,
              let regionId = regionId(for: hex) else {
            return .visible
        }

        let visibleRegions = RegionVisibilityRules().visibleRegions(for: faction, in: state)
        return visibleRegions.contains(regionId) ? .visible : .unseen
    }

    func hexDisplayState(for hex: HexCoord, viewerFaction: Faction) -> HexDisplayState? {
        guard state.map.contains(hex) else {
            return nil
        }

        let regionId = regionId(for: hex)
        let region = regionId.flatMap { state.map.region(id: $0) }
        let tile = state.map.tile(at: hex)
        let terrain = tile?.baseTerrain ?? region?.terrain ?? .plain
        let cityName = tile?.cityName ?? (hex == region?.representativeHex ? region?.city?.name : nil)
        let fortressName = tile?.fortressName

        return HexDisplayState(
            coord: hex,
            regionId: regionId,
            terrain: terrain,
            controller: tile?.controller ?? region?.controller,
            cityName: cityName,
            fortressName: fortressName,
            isRepresentative: hex == region?.representativeHex,
            visibility: visibility(for: hex, faction: viewerFaction)
        )
    }

    func unitPlacements(viewerFaction: Faction) -> [String: UnitDisplayPlacement] {
        let visibleDivisions = state.divisions.filter { isDivisionVisible($0, viewerFaction: viewerFaction) }
        let grouped = Dictionary(grouping: visibleDivisions) { division in
            unitDisplayHex(for: division) ?? division.coord
        }

        var placements: [String: UnitDisplayPlacement] = [:]
        for (hex, divisions) in grouped {
            let sorted = divisions.sorted { lhs, rhs in
                lhs.id < rhs.id
            }
            for (index, division) in sorted.enumerated() {
                placements[division.id] = UnitDisplayPlacement(
                    divisionId: division.id,
                    hex: hex,
                    offset: stackOffset(index: index, count: sorted.count),
                    stackIndex: index,
                    stackCount: sorted.count
                )
            }
        }
        return placements
    }

    func divisions(displayedAt hex: HexCoord, viewerFaction: Faction) -> [Division] {
        let placements = unitPlacements(viewerFaction: viewerFaction)
        return state.divisions
            .filter { placements[$0.id]?.hex == hex }
            .sorted { lhs, rhs in
                if lhs.faction == viewerFaction, rhs.faction != viewerFaction {
                    return true
                }
                if lhs.faction != viewerFaction, rhs.faction == viewerFaction {
                    return false
                }
                return lhs.id < rhs.id
            }
    }

    func isDivisionVisible(_ division: Division, viewerFaction: Faction) -> Bool {
        if division.faction == viewerFaction {
            return true
        }

        guard let displayHex = unitDisplayHex(for: division) else {
            return false
        }
        return visibility(for: displayHex, faction: viewerFaction) == .visible
    }

    func inspectorState(for regionId: RegionId, selectedHex: HexCoord? = nil, viewerFaction: Faction) -> RegionInspectorState? {
        guard let region = state.map.region(id: regionId) else {
            return nil
        }

        let divisions = state.divisions.filter { division in
            division.location(in: state.map) == regionId
        }
        let friendly = divisions.filter { $0.faction == viewerFaction }
        let visibleEnemy = divisions.filter { division in
            division.faction != viewerFaction && isDivisionVisible(division, viewerFaction: viewerFaction)
        }
        let objectiveNames = state.map.objectives
            .filter { objective in
                region.displayHexes.contains(objective.coord)
            }
            .map(\.name)
        let objectiveStatus = objectiveNames.isEmpty
            ? "None"
            : "\(region.controller.displayName) controlled"

        let cityLevel = EconomyRules().cityLevel(for: region, map: state.map)
        let economicOutput = regionalEconomicOutput(for: region, cityLevel: cityLevel)

        let selectedHexDynamicTheaterId = selectedHex.flatMap { state.theaterState.dynamicTheaterId(for: $0, map: state.map) }
        let selectedHexFrontZoneId = selectedHex.flatMap { state.warDeploymentState.zoneId(for: $0, map: state.map) }
        let theaterId = state.theaterState.dominantDynamicTheaterId(for: regionId, map: state.map)
        let frontZoneId = dominantDynamicFrontZoneId(for: regionId)

        return RegionInspectorState(
            region: region,
            selectedHex: selectedHex,
            selectedHexController: selectedHex.flatMap { state.map.tile(at: $0)?.controller },
            selectedHexDynamicTheaterId: selectedHexDynamicTheaterId,
            selectedHexDynamicTheaterDisplayName: theaterDisplayName(selectedHexDynamicTheaterId, for: viewerFaction),
            selectedHexFrontZoneId: selectedHexFrontZoneId,
            selectedHexFrontZoneDisplayName: frontZoneDisplayName(selectedHexFrontZoneId, for: viewerFaction),
            theaterId: theaterId,
            theaterDisplayName: theaterDisplayName(theaterId, for: viewerFaction),
            frontZoneId: frontZoneId,
            frontZoneDisplayName: frontZoneDisplayName(frontZoneId, for: viewerFaction),
            frontPressure: state.frontLineState.regionStates[regionId]?.frontLines
                .flatMap(\.segments)
                .map(\.pressureLevel)
                .max() ?? 0,
            friendlyDivisions: friendly,
            visibleEnemyDivisions: visibleEnemy,
            objectiveNames: objectiveNames,
            objectiveStatus: objectiveStatus,
            cityLevel: cityLevel,
            economicOutput: economicOutput
        )
    }

    func unitInspectorState(for division: Division) -> UnitInspectorStrategicState {
        let regionId = division.location(in: state.map)
        let frontLineIds = regionId
            .flatMap { state.frontLineState.regionStates[$0]?.frontLines.map(\.id) } ?? []
        let dynamicTheaterId = state.theaterState.dynamicTheaterId(for: division.coord, map: state.map)
        let frontZoneId = state.warDeploymentState.zoneId(for: division.coord, map: state.map)
        return UnitInspectorStrategicState(
            coord: division.coord,
            regionId: regionId,
            regionDisplayName: regionDisplayName(regionId, for: division.faction),
            dynamicTheaterId: dynamicTheaterId,
            dynamicTheaterDisplayName: theaterDisplayName(dynamicTheaterId, for: division.faction),
            frontLineIds: frontLineIds.sorted { $0.rawValue < $1.rawValue },
            frontLineDisplayNames: frontLineDisplayNames(frontLineIds, for: division.faction),
            frontZoneId: frontZoneId,
            frontZoneDisplayName: frontZoneDisplayName(frontZoneId, for: division.faction),
            deploymentRole: WarDeploymentManager().deploymentRole(
                for: division,
                in: state.map,
                state: state.warDeploymentState,
                diplomacyState: state.diplomacyState
            )
        )
    }

    private func dominantDynamicFrontZoneId(for regionId: RegionId) -> FrontZoneId? {
        guard let region = state.map.region(id: regionId) else {
            return state.warDeploymentState.regionToFrontZone[regionId]
        }
        var counts: [FrontZoneId: Int] = [:]
        for hex in region.displayHexes {
            if let zoneId = state.warDeploymentState.zoneId(for: hex, map: state.map) {
                counts[zoneId, default: 0] += 1
            }
        }
        return counts.max {
            $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value
        }?.key ?? state.warDeploymentState.regionToFrontZone[regionId]
    }

    private func regionDisplayName(_ regionId: RegionId?, for faction: Faction) -> String {
        guard let regionId else {
            return "None"
        }
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return regionId.rawValue
        }
        if let name = state.map.region(id: regionId)?.name,
           !name.isEmpty {
            return name
        }
        return identifierDisplayText(regionId.rawValue, fallback: "Sector", suffix: " sector")
    }

    private func theaterDisplayName(_ theaterId: TheaterId?, for faction: Faction) -> String {
        guard let theaterId else {
            return "None"
        }
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return theaterId.rawValue
        }
        if let name = state.theaterState.theaters[theaterId]?.name,
           !name.isEmpty {
            return name
        }
        return identifierDisplayText(theaterId.rawValue, fallback: "Active Wing", suffix: " wing")
    }

    private func frontZoneDisplayName(_ zoneId: FrontZoneId?, for faction: Faction) -> String {
        guard let zoneId else {
            return "None"
        }
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return zoneId.rawValue
        }
        if let name = state.warDeploymentState.frontZones[zoneId]?.name,
           !name.isEmpty {
            return name
        }
        return identifierDisplayText(zoneId.rawValue, fallback: "Corps Sector", suffix: " sector")
    }

    private func frontLineDisplayNames(_ ids: [FrontLineId], for faction: Faction) -> [String] {
        let sortedIds = ids.sorted { $0.rawValue < $1.rawValue }
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return sortedIds.map(\.rawValue)
        }
        return sortedIds.enumerated().map { index, _ in
            "Contact Line \(index + 1)"
        }
    }

    private func identifierDisplayText(
        _ rawValue: String,
        fallback: String,
        suffix: String? = nil
    ) -> String {
        let stopWords: Set<String> = [
            "region", "front", "frontzone", "zone", "theater", "sector",
            "legacy", "mock", "ai", "commander", "marshal", "directive",
            "power", "faction", "global", "ruler"
        ]
        let words = rawValue
            .replacingOccurrences(of: "-", with: "_")
            .split(separator: "_")
            .map { String($0) }
            .filter { !stopWords.contains($0.lowercased()) }

        guard !words.isEmpty else {
            return fallback
        }

        let display = words
            .map { word in
                word.count <= 3 ? word.uppercased() : word.capitalized
            }
            .joined(separator: " ")

        if let suffix,
           !display.lowercased().hasSuffix(suffix.trimmingCharacters(in: .whitespaces).lowercased()) {
            return display + suffix
        }
        return display
    }

    private func terrain(for hex: HexCoord) -> BaseTerrain {
        if let regionId = regionId(for: hex),
           let region = state.map.region(id: regionId) {
            return region.terrain
        }
        return state.map.tile(at: hex)?.baseTerrain ?? .plain
    }

    private func controller(for hex: HexCoord) -> Faction? {
        if let regionId = regionId(for: hex),
           let region = state.map.region(id: regionId) {
            return region.controller
        }
        return state.map.tile(at: hex)?.controller
    }

    private func regionalEconomicOutput(for region: RegionNode, cityLevel: CityLevel) -> EconomyResources {
        let coreBonus = region.coreOf.isEmpty || region.coreOf.contains(region.controller) ? 1 : 0
        return EconomyResources(
            manpower: max(1, cityLevel.manpowerGrowth + coreBonus * 4 + region.infrastructure),
            industry: max(0, region.factories + cityLevel.industryValue + region.infrastructure / 3),
            supplies: max(1, region.supplyValue * 3 + region.factories + region.infrastructure / 2)
        )
    }

    private func stackOffset(index: Int, count: Int) -> CGPoint {
        guard count > 1 else {
            return .zero
        }

        let offsets: [CGPoint] = [
            CGPoint(x: -10, y: 8),
            CGPoint(x: 10, y: -8),
            CGPoint(x: -10, y: -8),
            CGPoint(x: 10, y: 8)
        ]
        return offsets[index % offsets.count]
    }
}
