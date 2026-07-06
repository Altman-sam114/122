import Foundation

struct RulerDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: RulerDecisionRecord
}

struct RulerPostureResolution: Equatable {
    let rawStrategicJSON: String?
    let envelope: StrategicPostureEnvelope
    let record: RulerDecisionRecord
    let diagnostics: [String]
}

struct RulerAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let countryId: CountryId?
    let aggression: Int
    let coalitionDiscipline: Int
    let riskTolerance: Int

    init(
        id: String,
        name: String,
        faction: Faction,
        countryId: CountryId?,
        aggression: Int,
        coalitionDiscipline: Int,
        riskTolerance: Int
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.countryId = countryId
        self.aggression = max(0, min(100, aggression))
        self.coalitionDiscipline = max(0, min(100, coalitionDiscipline))
        self.riskTolerance = max(0, min(100, riskTolerance))
    }
}

struct StrategicPostureEnvelope: Codable, Equatable {
    let schemaVersion: Int
    let issuerId: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let posture: RulerStrategicPosture
    let preferredFrontZoneId: FrontZoneId?
    let targetRegionIds: [RegionId]
    let attackThresholdAdjustment: Double
    let reserveBias: Int
    let strategicIntent: String
    let coalitionGuidance: String?
    let rationale: String

    init(
        schemaVersion: Int = 1,
        issuerId: String,
        turn: Int,
        faction: Faction,
        countryId: CountryId?,
        posture: RulerStrategicPosture,
        preferredFrontZoneId: FrontZoneId?,
        targetRegionIds: [RegionId],
        attackThresholdAdjustment: Double,
        reserveBias: Int,
        strategicIntent: String,
        coalitionGuidance: String? = nil,
        rationale: String
    ) {
        self.schemaVersion = schemaVersion
        self.issuerId = issuerId
        self.turn = turn
        self.faction = faction
        self.countryId = countryId
        self.posture = posture
        self.preferredFrontZoneId = preferredFrontZoneId
        self.targetRegionIds = Self.unique(targetRegionIds)
        self.attackThresholdAdjustment = attackThresholdAdjustment
        self.reserveBias = max(0, reserveBias)
        self.strategicIntent = strategicIntent
        self.coalitionGuidance = coalitionGuidance
        self.rationale = rationale
    }

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

enum StrategicPostureDecoderError: Error, Equatable, LocalizedError {
    case invalidUTF8
    case malformedJSON(String)
    case unsupportedSchemaVersion(Int)
    case issuerMismatch(expected: String, actual: String)
    case turnMismatch(expected: Int, actual: Int)
    case factionMismatch(expected: Faction, actual: Faction)
    case missingZone(FrontZoneId)
    case zoneFactionMismatch(zoneId: FrontZoneId, expected: Faction, actual: Faction)
    case missingRegion(RegionId)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Strategic posture JSON is not valid UTF-8."
        case .malformedJSON(let detail):
            return "Malformed strategic posture JSON: \(detail)"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported strategic posture schemaVersion \(version)."
        case .issuerMismatch(let expected, let actual):
            return "Strategic posture issuer mismatch. Expected \(expected), got \(actual)."
        case .turnMismatch(let expected, let actual):
            return "Strategic posture turn mismatch. Expected \(expected), got \(actual)."
        case .factionMismatch(let expected, let actual):
            return "Strategic posture faction mismatch. Expected \(expected.displayName), got \(actual.displayName)."
        case .missingZone(let zoneId):
            return "Strategic posture references missing corps sector \(Self.identifierDisplayText(zoneId.rawValue, fallback: "corps sector", suffix: " sector"))."
        case .zoneFactionMismatch(let zoneId, let expected, let actual):
            return "Strategic posture sector \(Self.identifierDisplayText(zoneId.rawValue, fallback: "corps sector", suffix: " sector")) belongs to \(actual.displayName), expected \(expected.displayName)."
        case .missingRegion(let regionId):
            return "Strategic posture references missing sector \(Self.identifierDisplayText(regionId.rawValue, fallback: "sector", suffix: " sector"))."
        }
    }

    private static func identifierDisplayText(
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
}

struct StrategicPostureDecoder {
    let supportedSchemaVersions: Set<Int>
    private let decoder: JSONDecoder

    init(supportedSchemaVersions: Set<Int> = [1], decoder: JSONDecoder = JSONDecoder()) {
        self.supportedSchemaVersions = supportedSchemaVersions
        self.decoder = decoder
    }

    func parse(
        _ rawResponse: String,
        expectedIssuerId: String? = nil,
        expectedTurn: Int? = nil,
        expectedFaction: Faction? = nil,
        state: GameState
    ) throws -> StrategicPostureEnvelope {
        let json = extractJSON(from: rawResponse)
        guard let data = json.data(using: .utf8) else {
            throw StrategicPostureDecoderError.invalidUTF8
        }

        let envelope: StrategicPostureEnvelope
        do {
            envelope = try decoder.decode(StrategicPostureEnvelope.self, from: data)
        } catch {
            throw StrategicPostureDecoderError.malformedJSON(error.localizedDescription)
        }

        guard supportedSchemaVersions.contains(envelope.schemaVersion) else {
            throw StrategicPostureDecoderError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
        if let expectedIssuerId, envelope.issuerId != expectedIssuerId {
            throw StrategicPostureDecoderError.issuerMismatch(expected: expectedIssuerId, actual: envelope.issuerId)
        }
        if let expectedTurn, envelope.turn != expectedTurn {
            throw StrategicPostureDecoderError.turnMismatch(expected: expectedTurn, actual: envelope.turn)
        }
        if let expectedFaction, envelope.faction != expectedFaction {
            throw StrategicPostureDecoderError.factionMismatch(expected: expectedFaction, actual: envelope.faction)
        }

        try validate(envelope, state: state)
        return envelope
    }

    func extractJSON(from rawResponse: String) -> String {
        if let fenced = fencedJSON(in: rawResponse, marker: "```json") {
            return fenced
        }
        if let fenced = fencedJSON(in: rawResponse, marker: "```") {
            return fenced
        }
        return rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validate(_ envelope: StrategicPostureEnvelope, state: GameState) throws {
        if let zoneId = envelope.preferredFrontZoneId {
            guard let zone = state.warDeploymentState.frontZones[zoneId] else {
                throw StrategicPostureDecoderError.missingZone(zoneId)
            }
            guard zone.faction == envelope.faction else {
                throw StrategicPostureDecoderError.zoneFactionMismatch(
                    zoneId: zoneId,
                    expected: envelope.faction,
                    actual: zone.faction
                )
            }
        }

        for regionId in envelope.targetRegionIds where state.map.region(id: regionId) == nil {
            throw StrategicPostureDecoderError.missingRegion(regionId)
        }
    }

    private func fencedJSON(in rawResponse: String, marker: String) -> String? {
        guard let start = rawResponse.range(of: marker) else {
            return nil
        }
        let contentStart = start.upperBound
        guard let end = rawResponse[contentStart...].range(of: "```") else {
            return nil
        }
        return String(rawResponse[contentStart..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct RulerAgent {
    let config: RulerAgentConfig
    let decoder: StrategicPostureDecoder

    init(config: RulerAgentConfig, decoder: StrategicPostureDecoder = StrategicPostureDecoder()) {
        self.config = config
        self.decoder = decoder
    }

    func resolvePosture(in state: GameState) -> RulerPostureResolution {
        let snapshot = RulerStrategicSnapshot(faction: config.faction, state: state)
        let fallback = makeStrategicPostureEnvelope(snapshot: snapshot, state: state)
        let raw = Self.fencedJSON(fallback)

        do {
            let envelope = try decoder.parse(
                raw,
                expectedIssuerId: config.id,
                expectedTurn: state.turn,
                expectedFaction: config.faction,
                state: state
            )
            return RulerPostureResolution(
                rawStrategicJSON: raw,
                envelope: envelope,
                record: makeRecord(from: envelope, state: state),
                diagnostics: []
            )
        } catch {
            return RulerPostureResolution(
                rawStrategicJSON: raw,
                envelope: fallback,
                record: makeRecord(from: fallback, state: state),
                diagnostics: ["Strategic posture decode failed: \(error.localizedDescription). Deterministic ruler fallback used."]
            )
        }
    }

    func adjust(envelope: DirectiveEnvelope, in state: GameState) -> RulerDirectiveAdjustment {
        let snapshot = RulerStrategicSnapshot(faction: config.faction, state: state)
        let posture = choosePosture(snapshot: snapshot)
        let directives = envelope.directives.map { adjust(directive: $0, posture: posture, snapshot: snapshot) }
        let preferredZoneId = choosePreferredZoneId(snapshot: snapshot)
        let targetRegionIds = chooseTargetRegionIds(directives: directives, snapshot: snapshot)
        let record = RulerDecisionRecord(
            id: "ruler_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            countryId: config.countryId,
            rulerAgentId: config.id,
            posture: posture,
            preferredFrontZoneId: preferredZoneId,
            targetRegionIds: targetRegionIds,
            attackThresholdAdjustment: thresholdAdjustment(for: posture),
            reserveBias: reserveBias(for: posture),
            diplomacySummary: state.diplomacyState.summary(for: config.faction),
            rationale: rationale(for: posture, snapshot: snapshot)
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendRulerContext(envelope.theaterContext, record: record)
        )
        return RulerDirectiveAdjustment(envelope: adjustedEnvelope, record: record)
    }

    private func makeStrategicPostureEnvelope(
        snapshot: RulerStrategicSnapshot,
        state: GameState
    ) -> StrategicPostureEnvelope {
        let posture = choosePosture(snapshot: snapshot)
        let preferredZoneId = choosePreferredZoneId(snapshot: snapshot)
        let targetRegionIds = chooseTargetRegionIds(directives: [], snapshot: snapshot)
        return StrategicPostureEnvelope(
            issuerId: config.id,
            turn: state.turn,
            faction: config.faction,
            countryId: config.countryId,
            posture: posture,
            preferredFrontZoneId: preferredZoneId,
            targetRegionIds: targetRegionIds,
            attackThresholdAdjustment: thresholdAdjustment(for: posture),
            reserveBias: reserveBias(for: posture),
            strategicIntent: strategicIntent(for: posture, snapshot: snapshot),
            coalitionGuidance: coalitionGuidance(for: posture, state: state),
            rationale: rationale(for: posture, snapshot: snapshot)
        )
    }

    private func makeRecord(from envelope: StrategicPostureEnvelope, state: GameState) -> RulerDecisionRecord {
        RulerDecisionRecord(
            id: "ruler_\(envelope.issuerId)_turn_\(state.turn)_\(envelope.faction.rawValue)",
            turn: state.turn,
            faction: envelope.faction,
            countryId: envelope.countryId,
            rulerAgentId: envelope.issuerId,
            posture: envelope.posture,
            preferredFrontZoneId: envelope.preferredFrontZoneId,
            targetRegionIds: envelope.targetRegionIds,
            attackThresholdAdjustment: envelope.attackThresholdAdjustment,
            reserveBias: envelope.reserveBias,
            diplomacySummary: state.diplomacyState.summary(for: envelope.faction),
            rationale: envelope.rationale
        )
    }

    private func choosePosture(snapshot: RulerStrategicSnapshot) -> RulerStrategicPosture {
        if snapshot.hostileCountryCount > 1 && config.coalitionDiscipline >= 55 {
            return .coalitionMaintenance
        }

        if snapshot.averageZonePressure >= 4 || snapshot.outnumberedFrontZoneCount > snapshot.advantagedFrontZoneCount {
            return .defensive
        }

        if snapshot.staticDefenseStreak >= 2 || snapshot.contestedFriendlyPresenceCount > 0 {
            return .stabilizeFront
        }

        let aggressionScore = config.aggression + config.riskTolerance / 2 + snapshot.advantagedFrontZoneCount * 8
        if aggressionScore >= 95 && snapshot.frontZoneCount > 0 {
            return .offensive
        }

        return snapshot.frontZoneCount > 1 ? .coalitionMaintenance : .stabilizeFront
    }

    private func adjust(
        directive: ZoneDirective,
        posture: RulerStrategicPosture,
        snapshot: RulerStrategicSnapshot
    ) -> ZoneDirective {
        switch (posture, directive.parameters) {
        case (.offensive, .attack(let attack)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: prioritizedRegions(attack.weightedRegions, snapshot: snapshot),
                    intensity: .allOut
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.defensive, .attack):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: 2, stance: .holdLine),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: .theater(TheaterId(directive.zoneId.rawValue))
            )
        case (.coalitionMaintenance, .defend(let defense)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: max(2, defense.targetReserves), stance: defense.stance),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .attack(let attack)) where attack.intensity == .allOut:
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: attack.weightedRegions,
                    intensity: .limitedCounter
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .defend):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: 1, stance: .flexible),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: directive.commandTarget
            )
        default:
            return directive
        }
    }

    private func choosePreferredZoneId(snapshot: RulerStrategicSnapshot) -> FrontZoneId? {
        snapshot.zoneScores.sorted {
            if $0.value == $1.value {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.value > $1.value
        }.first?.key
    }

    private func chooseTargetRegionIds(directives: [ZoneDirective], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        let directed = directives.flatMap(\.targetRegionIds)
        if !directed.isEmpty {
            return stableUnique(directed).prefix(4).map { $0 }
        }
        return snapshot.contestedRegionIds.prefix(4).map { $0 }
    }

    private func prioritizedRegions(_ regions: [RegionId], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        stableUnique(regions).sorted {
            let lhs = snapshot.regionPriority[$0, default: 0]
            let rhs = snapshot.regionPriority[$1, default: 0]
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    private func thresholdAdjustment(for posture: RulerStrategicPosture) -> Double {
        switch posture {
        case .offensive:
            return -0.15
        case .defensive:
            return 0.20
        case .coalitionMaintenance:
            return 0.05
        case .stabilizeFront:
            return 0.10
        }
    }

    private func reserveBias(for posture: RulerStrategicPosture) -> Int {
        switch posture {
        case .offensive:
            return 0
        case .defensive:
            return 2
        case .coalitionMaintenance:
            return 2
        case .stabilizeFront:
            return 1
        }
    }

    private func rationale(for posture: RulerStrategicPosture, snapshot: RulerStrategicSnapshot) -> String {
        switch posture {
        case .offensive:
            return "Ruler sees \(snapshot.advantagedFrontZoneCount) advantaged zone(s) and accepts offensive risk."
        case .defensive:
            return "Ruler sees pressure \(snapshot.averageZonePressure) and \(snapshot.outnumberedFrontZoneCount) outnumbered zone(s)."
        case .coalitionMaintenance:
            return "Ruler preserves coalition reserves across \(snapshot.frontZoneCount) active zone(s)."
        case .stabilizeFront:
            return "Ruler avoids overextension while contested forward presence is resolved."
        }
    }

    private func strategicIntent(for posture: RulerStrategicPosture, snapshot: RulerStrategicSnapshot) -> String {
        switch posture {
        case .offensive:
            return "Seek a decisive battle through the preferred front while keeping exhausted or unsupported zones from overcommitting."
        case .defensive:
            return "Preserve the army, hold strongpoints, and accept only local counterattacks until pressure eases."
        case .coalitionMaintenance:
            return "Coordinate coalition fronts, protect reserves, and avoid isolated advances while \(snapshot.hostileCountryCount) hostile country record(s) remain active."
        case .stabilizeFront:
            return "Restore command cohesion across contested fronts before committing reserves to a larger offensive."
        }
    }

    private func coalitionGuidance(for posture: RulerStrategicPosture, state: GameState) -> String? {
        guard posture == .coalitionMaintenance || config.faction.isNapoleonicCoalitionMember else {
            return nil
        }
        let friendlyFactions = Faction.allCases
            .filter { state.diplomacyState.isFriendly(config.faction, to: $0) && $0 != config.faction }
            .map(\.displayName)
            .sorted()
        if friendlyFactions.isEmpty {
            return "Maintain reserve discipline until a friendly coalition front can coordinate."
        }
        return "Coordinate with \(friendlyFactions.joined(separator: ", ")); avoid isolated pursuit beyond supporting distance."
    }

    private func appendRulerContext(_ context: String?, record: RulerDecisionRecord) -> String {
        let rulerContext = "Ruler \(record.rulerAgentId): \(record.posture.displayName), target \(record.preferredFrontZoneId?.rawValue ?? "none")."
        guard let context, !context.isEmpty else {
            return rulerContext
        }
        return "\(context) \(rulerContext)"
    }

    private func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    private static func fencedJSON(_ envelope: StrategicPostureEnvelope) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(envelope)) ?? Data()
        return "```json\n\(String(decoding: data, as: UTF8.self))\n```"
    }
}

struct RulerStrategicSnapshot {
    let frontZoneCount: Int
    let averageZonePressure: Int
    let advantagedFrontZoneCount: Int
    let outnumberedFrontZoneCount: Int
    let contestedFriendlyPresenceCount: Int
    let hostileCountryCount: Int
    let staticDefenseStreak: Int
    let contestedRegionIds: [RegionId]
    let regionPriority: [RegionId: Int]
    let zoneScores: [FrontZoneId: Int]

    init(faction: Faction, state: GameState) {
        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == faction && !$0.frontSegments.isEmpty }
        frontZoneCount = zones.count
        averageZonePressure = zones.isEmpty ? 0 : zones.reduce(0) { $0 + $1.pressure } / zones.count
        hostileCountryCount = state.diplomacyState.hostileCountryIds(to: faction).count

        var advantaged = 0
        var outnumbered = 0
        var contestedPresence = 0
        var contestedRegions: [RegionId] = []
        var priorities: [RegionId: Int] = [:]
        var scores: [FrontZoneId: Int] = [:]

        for zone in zones {
            let friendlyStrength = Self.strength(for: zone.unitsFront + zone.unitsDepth, faction: faction, state: state)
            let enemyStrength = Self.enemyStrength(adjacentTo: zone, state: state)
            if friendlyStrength >= enemyStrength + 2 {
                advantaged += 1
            } else if enemyStrength > friendlyStrength {
                outnumbered += 1
            }

            let zoneScore = max(0, friendlyStrength - enemyStrength) + zone.pressure + zone.frontSegments.count
            scores[zone.id] = zoneScore

            for segment in zone.frontSegments {
                contestedRegions.append(segment.regionId)
                priorities[segment.regionId, default: 0] += zoneScore + segment.strength
                if segment.isEncircled {
                    priorities[segment.regionId, default: 0] += 6
                }
                if state.map.regions[segment.regionId]?.controller != faction {
                    contestedPresence += 1
                    priorities[segment.regionId, default: 0] += 4
                }
            }
        }

        advantagedFrontZoneCount = advantaged
        outnumberedFrontZoneCount = outnumbered
        contestedFriendlyPresenceCount = contestedPresence
        contestedRegionIds = Self.stableUnique(contestedRegions).sorted { $0.rawValue < $1.rawValue }
        regionPriority = priorities
        zoneScores = scores
        staticDefenseStreak = Self.staticDefenseStreak(for: faction, records: state.warDirectiveRecords)
    }

    private static func strength(for unitIds: [String], faction: Faction, state: GameState) -> Int {
        let ids = Set(unitIds)
        return state.divisions
            .filter { ids.contains($0.id) && $0.faction == faction && !$0.isDestroyed }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.attack) }
    }

    private static func enemyStrength(adjacentTo zone: FrontZone, state: GameState) -> Int {
        let visibleEnemyRegions = Set(zone.frontSegments.map(\.regionId))
        return state.divisions
            .filter { state.diplomacyState.isHostile(zone.faction, to: $0.faction) && !$0.isDestroyed }
            .filter { division in
                guard let regionId = division.location(in: state.map) else {
                    return false
                }
                return visibleEnemyRegions.contains(regionId)
            }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.defense) }
    }

    private static func staticDefenseStreak(for faction: Faction, records: [WarDirectiveRecord]) -> Int {
        var streak = 0
        for record in records.reversed() where record.faction == faction {
            if record.directiveType == .defend {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

extension RulerAgent {
    static func automatic(for faction: Faction, in state: GameState) -> RulerAgent {
        let country = state.diplomacyState.primaryCountry(for: faction)
        let config: RulerAgentConfig
        switch faction {
        case .germany:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_germany",
                name: "German Ruler",
                faction: faction,
                countryId: country?.id,
                aggression: 82,
                coalitionDiscipline: 45,
                riskTolerance: 68
            )
        case .allies:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_allies",
                name: "Allied Supreme Council",
                faction: faction,
                countryId: country?.id,
                aggression: 58,
                coalitionDiscipline: 82,
                riskTolerance: 48
            )
        case .france:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_napoleon",
                name: "Napoleon",
                faction: faction,
                countryId: country?.id,
                aggression: 88,
                coalitionDiscipline: 62,
                riskTolerance: 76
            )
        case .angloAllied:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_wellington",
                name: "Anglo-Allied Command",
                faction: faction,
                countryId: country?.id,
                aggression: 56,
                coalitionDiscipline: 84,
                riskTolerance: 44
            )
        case .prussia:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_prussia",
                name: "Prussian Command",
                faction: faction,
                countryId: country?.id,
                aggression: 74,
                coalitionDiscipline: 78,
                riskTolerance: 66
            )
        case .austria, .russia, .spain, .neutral:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_\(faction.rawValue)",
                name: "\(faction.displayName) Command",
                faction: faction,
                countryId: country?.id,
                aggression: faction.isNeutral ? 20 : 58,
                coalitionDiscipline: faction.isNeutral ? 50 : 72,
                riskTolerance: faction.isNeutral ? 20 : 50
            )
        }
        return RulerAgent(config: config)
    }
}
