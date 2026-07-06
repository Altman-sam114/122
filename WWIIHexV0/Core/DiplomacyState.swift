import Foundation

struct CountryId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiplomaticBlocId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DiplomaticStatus: String, Codable, Equatable, CaseIterable {
    case allied
    case coBelligerent
    case neutral
    case hostile
    case atWar

    var isHostile: Bool {
        self == .hostile || self == .atWar
    }

    var displayName: String {
        switch self {
        case .allied:
            return "Allied"
        case .coBelligerent:
            return "Co-belligerent"
        case .neutral:
            return "Neutral"
        case .hostile:
            return "Hostile"
        case .atWar:
            return "At war"
        }
    }
}

struct CountryProfile: Identifiable, Codable, Equatable {
    let id: CountryId
    var name: String
    var faction: Faction
    var blocId: DiplomaticBlocId
    var rulerAgentId: String
    var isPrimaryBelligerent: Bool
    var capitalRegionId: RegionId?
    var surrenderProgress: Int
    var warSupport: Int

    init(
        id: CountryId,
        name: String,
        faction: Faction,
        blocId: DiplomaticBlocId,
        rulerAgentId: String,
        isPrimaryBelligerent: Bool = false,
        capitalRegionId: RegionId? = nil,
        surrenderProgress: Int = 0,
        warSupport: Int = 70
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.blocId = blocId
        self.rulerAgentId = rulerAgentId
        self.isPrimaryBelligerent = isPrimaryBelligerent
        self.capitalRegionId = capitalRegionId
        self.surrenderProgress = max(0, min(100, surrenderProgress))
        self.warSupport = max(0, min(100, warSupport))
    }
}

struct DiplomaticBloc: Identifiable, Codable, Equatable {
    let id: DiplomaticBlocId
    var name: String
    var faction: Faction
    var memberCountryIds: [CountryId]

    init(id: DiplomaticBlocId, name: String, faction: Faction, memberCountryIds: [CountryId]) {
        self.id = id
        self.name = name
        self.faction = faction
        self.memberCountryIds = memberCountryIds.sorted { $0.rawValue < $1.rawValue }
    }
}

struct DiplomaticRelation: Identifiable, Codable, Equatable {
    let firstCountryId: CountryId
    let secondCountryId: CountryId
    var status: DiplomaticStatus
    var tension: Int
    var sinceTurn: Int

    var id: String {
        "\(firstCountryId.rawValue):\(secondCountryId.rawValue)"
    }

    init(
        firstCountryId: CountryId,
        secondCountryId: CountryId,
        status: DiplomaticStatus,
        tension: Int = 0,
        sinceTurn: Int = 1
    ) {
        if firstCountryId.rawValue <= secondCountryId.rawValue {
            self.firstCountryId = firstCountryId
            self.secondCountryId = secondCountryId
        } else {
            self.firstCountryId = secondCountryId
            self.secondCountryId = firstCountryId
        }
        self.status = status
        self.tension = max(0, min(100, tension))
        self.sinceTurn = max(1, sinceTurn)
    }

    func contains(_ countryId: CountryId) -> Bool {
        firstCountryId == countryId || secondCountryId == countryId
    }
}

enum RulerStrategicPosture: String, Codable, Equatable, CaseIterable {
    case offensive
    case defensive
    case coalitionMaintenance
    case stabilizeFront

    var displayName: String {
        switch self {
        case .offensive:
            return "Offensive"
        case .defensive:
            return "Defensive"
        case .coalitionMaintenance:
            return "Coalition"
        case .stabilizeFront:
            return "Stabilize"
        }
    }
}

struct RulerDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let rulerAgentId: String
    let posture: RulerStrategicPosture
    let preferredFrontZoneId: FrontZoneId?
    let targetRegionIds: [RegionId]
    let attackThresholdAdjustment: Double
    let reserveBias: Int
    let diplomacySummary: String
    let rationale: String
}

struct DiplomacyState: Codable, Equatable {
    var countries: [CountryProfile]
    var blocs: [DiplomaticBloc]
    var relations: [DiplomaticRelation]
    var rulerRecords: [RulerDecisionRecord]
    var lastUpdatedTurn: Int?

    init(
        countries: [CountryProfile] = [],
        blocs: [DiplomaticBloc] = [],
        relations: [DiplomaticRelation] = [],
        rulerRecords: [RulerDecisionRecord] = [],
        lastUpdatedTurn: Int? = nil
    ) {
        self.countries = countries.sorted { $0.id.rawValue < $1.id.rawValue }
        self.blocs = blocs.sorted { $0.id.rawValue < $1.id.rawValue }
        self.relations = relations.sorted { $0.id < $1.id }
        self.rulerRecords = rulerRecords
        self.lastUpdatedTurn = lastUpdatedTurn
    }

    static var empty: DiplomacyState {
        DiplomacyState()
    }

    static func initial(for factions: [Faction], turn: Int) -> DiplomacyState {
        var countries: [CountryProfile] = []
        var blocs: [DiplomaticBloc] = []

        if factions.contains(.germany) {
            countries.append(
                CountryProfile(
                    id: "germany",
                    name: "German Reich",
                    faction: .germany,
                    blocId: "axis",
                    rulerAgentId: "ruler_germany",
                    isPrimaryBelligerent: true,
                    warSupport: 82
                )
            )
            blocs.append(DiplomaticBloc(id: "axis", name: "Axis", faction: .germany, memberCountryIds: ["germany"]))
        }

        if factions.contains(.allies) {
            countries.append(
                CountryProfile(
                    id: "united_states",
                    name: "United States",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_allies",
                    isPrimaryBelligerent: true,
                    warSupport: 78
                )
            )
            countries.append(
                CountryProfile(
                    id: "united_kingdom",
                    name: "United Kingdom",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_uk",
                    warSupport: 74
                )
            )
            countries.append(
                CountryProfile(
                    id: "belgium",
                    name: "Belgium",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_belgium",
                    warSupport: 68
                )
            )
            blocs.append(
                DiplomaticBloc(
                    id: "allied_coalition",
                    name: "Allied Coalition",
                    faction: .allies,
                    memberCountryIds: ["belgium", "united_kingdom", "united_states"]
                )
            )
        }

        if factions.contains(.france) {
            countries.append(
                CountryProfile(
                    id: "france",
                    name: "France",
                    faction: .france,
                    blocId: "french_empire",
                    rulerAgentId: "ruler_napoleon",
                    isPrimaryBelligerent: true,
                    warSupport: 84
                )
            )
            blocs.append(DiplomaticBloc(id: "french_empire", name: "French Empire", faction: .france, memberCountryIds: ["france"]))
        }

        if factions.contains(.angloAllied) {
            countries.append(
                CountryProfile(
                    id: "anglo_allied_army",
                    name: "Anglo-Allied Army",
                    faction: .angloAllied,
                    blocId: "seventh_coalition",
                    rulerAgentId: "ruler_wellington",
                    isPrimaryBelligerent: true,
                    warSupport: 76
                )
            )
        }

        if factions.contains(.prussia) {
            countries.append(
                CountryProfile(
                    id: "prussia",
                    name: "Prussia",
                    faction: .prussia,
                    blocId: "seventh_coalition",
                    rulerAgentId: "ruler_prussia",
                    isPrimaryBelligerent: true,
                    warSupport: 79
                )
            )
        }

        if factions.contains(.austria) {
            countries.append(
                CountryProfile(
                    id: "austria",
                    name: "Austria",
                    faction: .austria,
                    blocId: "seventh_coalition",
                    rulerAgentId: "ruler_austria",
                    warSupport: 72
                )
            )
        }

        if factions.contains(.russia) {
            countries.append(
                CountryProfile(
                    id: "russia",
                    name: "Russia",
                    faction: .russia,
                    blocId: "seventh_coalition",
                    rulerAgentId: "ruler_russia",
                    warSupport: 73
                )
            )
        }

        if factions.contains(.spain) {
            countries.append(
                CountryProfile(
                    id: "spain",
                    name: "Spain",
                    faction: .spain,
                    blocId: "seventh_coalition",
                    rulerAgentId: "ruler_spain",
                    warSupport: 64
                )
            )
        }

        let coalitionMembers = countries
            .filter { $0.faction.isNapoleonicCoalitionMember }
            .map(\.id)
        if !coalitionMembers.isEmpty {
            blocs.append(
                DiplomaticBloc(
                    id: "seventh_coalition",
                    name: "Seventh Coalition",
                    faction: coalitionMembers.contains("anglo_allied_army") ? .angloAllied : (countries.first { $0.faction.isNapoleonicCoalitionMember }?.faction ?? .angloAllied),
                    memberCountryIds: coalitionMembers
                )
            )
        }

        if factions.contains(.neutral) {
            countries.append(
                CountryProfile(
                    id: "neutral",
                    name: "Neutral Powers",
                    faction: .neutral,
                    blocId: "neutral_powers",
                    rulerAgentId: "ruler_neutral",
                    warSupport: 50
                )
            )
            blocs.append(DiplomaticBloc(id: "neutral_powers", name: "Neutral Powers", faction: .neutral, memberCountryIds: ["neutral"]))
        }

        return DiplomacyState(
            countries: countries,
            blocs: blocs,
            relations: makeInitialRelations(countries: countries, turn: turn),
            lastUpdatedTurn: turn
        )
    }

    static func initial(from factionStrings: [String], turn: Int) -> DiplomacyState {
        let factions = factionStrings.compactMap(Faction.init(rawValue:))
        return initial(for: factions.isEmpty ? Faction.legacyWorldWarIIFactions : factions, turn: turn)
    }

    var latestRulerRecord: RulerDecisionRecord? {
        rulerRecords.last
    }

    func countries(for faction: Faction) -> [CountryProfile] {
        countries.filter { $0.faction == faction }
    }

    func primaryCountry(for faction: Faction) -> CountryProfile? {
        countries(for: faction).first(where: \.isPrimaryBelligerent) ?? countries(for: faction).first
    }

    func relation(between lhs: CountryId, and rhs: CountryId) -> DiplomaticRelation? {
        let key = DiplomaticRelation(firstCountryId: lhs, secondCountryId: rhs, status: .neutral).id
        return relations.first { $0.id == key }
    }

    func isHostile(_ lhs: Faction, to rhs: Faction) -> Bool {
        guard lhs != rhs else {
            return false
        }
        guard !lhs.isNeutral, !rhs.isNeutral else {
            return false
        }

        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        guard !lhsCountries.isEmpty, !rhsCountries.isEmpty else {
            return fallbackHostility(lhs, rhs)
        }

        var sawRelation = false
        for lhsCountry in lhsCountries {
            for rhsCountry in rhsCountries {
                guard let status = relation(between: lhsCountry.id, and: rhsCountry.id)?.status else {
                    continue
                }
                sawRelation = true
                if status.isHostile {
                    return true
                }
            }
        }
        return sawRelation ? false : fallbackHostility(lhs, rhs)
    }

    func isFriendly(_ lhs: Faction, to rhs: Faction) -> Bool {
        if lhs == rhs {
            return true
        }

        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        guard !lhsCountries.isEmpty, !rhsCountries.isEmpty else {
            return fallbackFriendliness(lhs, rhs)
        }

        for lhsCountry in lhsCountries {
            for rhsCountry in rhsCountries {
                guard let status = relation(between: lhsCountry.id, and: rhsCountry.id)?.status else {
                    continue
                }
                if status == .allied || status == .coBelligerent {
                    return true
                }
            }
        }
        return fallbackFriendliness(lhs, rhs)
    }

    private func fallbackHostility(_ lhs: Faction, _ rhs: Faction) -> Bool {
        guard lhs != rhs else {
            return false
        }
        guard !lhs.isNeutral, !rhs.isNeutral else {
            return false
        }
        if lhs.isNapoleonicCoalitionMember && rhs.isNapoleonicCoalitionMember {
            return false
        }
        if lhs == .france && rhs.isNapoleonicCoalitionMember {
            return true
        }
        if rhs == .france && lhs.isNapoleonicCoalitionMember {
            return true
        }
        return lhs != rhs
    }

    private func fallbackFriendliness(_ lhs: Faction, _ rhs: Faction) -> Bool {
        lhs == rhs || (lhs.isNapoleonicCoalitionMember && rhs.isNapoleonicCoalitionMember)
    }

    func hostileFactions(to faction: Faction, among candidates: [Faction] = Faction.allCases) -> [Faction] {
        candidates
            .filter { $0 != faction && isHostile(faction, to: $0) }
            .sorted { $0.rawValue < $1.rawValue }
    }

    func hostileCountryIds(to faction: Faction) -> [CountryId] {
        let ownCountryIds = Set(countries(for: faction).map(\.id))
        var hostileCountryIds: Set<CountryId> = []
        for relation in relations where relation.status.isHostile {
            let touchesOwnCountry = ownCountryIds.contains(relation.firstCountryId) ||
                ownCountryIds.contains(relation.secondCountryId)
            guard touchesOwnCountry else {
                continue
            }
            if !ownCountryIds.contains(relation.firstCountryId) {
                hostileCountryIds.insert(relation.firstCountryId)
            }
            if !ownCountryIds.contains(relation.secondCountryId) {
                hostileCountryIds.insert(relation.secondCountryId)
            }
        }
        return hostileCountryIds.sorted { $0.rawValue < $1.rawValue }
    }

    func summary(for faction: Faction) -> String {
        let countryNames = countries(for: faction).map(\.name).joined(separator: ", ")
        let hostileCount = hostileCountryIds(to: faction).count
        return "\(faction.displayName): \(countryNames.isEmpty ? "no countries" : countryNames); \(hostileCount) hostile relation(s)."
    }

    mutating func appendRulerRecord(_ record: RulerDecisionRecord) {
        rulerRecords.append(record)
        if rulerRecords.count > 40 {
            rulerRecords.removeFirst(rulerRecords.count - 40)
        }
        lastUpdatedTurn = record.turn
    }

    private static func makeInitialRelations(countries: [CountryProfile], turn: Int) -> [DiplomaticRelation] {
        var relations: [DiplomaticRelation] = []
        for lhsIndex in countries.indices {
            for rhsIndex in countries.indices where rhsIndex > lhsIndex {
                let lhs = countries[lhsIndex]
                let rhs = countries[rhsIndex]
                let status = defaultInitialStatus(between: lhs.faction, and: rhs.faction)
                relations.append(
                    DiplomaticRelation(
                        firstCountryId: lhs.id,
                        secondCountryId: rhs.id,
                        status: status,
                        tension: status == .atWar ? 100 : 10,
                        sinceTurn: turn
                    )
                )
            }
        }
        return relations
    }

    private static func defaultInitialStatus(between lhs: Faction, and rhs: Faction) -> DiplomaticStatus {
        if lhs == rhs {
            return .allied
        }
        if lhs.isNeutral || rhs.isNeutral {
            return .neutral
        }
        if lhs.isNapoleonicCoalitionMember && rhs.isNapoleonicCoalitionMember {
            return .coBelligerent
        }
        return .atWar
    }
}
