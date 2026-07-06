import Foundation

enum ComponentType: String, Codable, Equatable, CaseIterable {
    case tank
    case motorizedInfantry
    case infantry
    case artillery
    case lineInfantry
    case lightInfantry
    case cavalry
    case guardInfantry = "guard"
    case engineer
    case supplyTrain

    var baseStats: EffectiveStats {
        switch self {
        case .tank:
            return EffectiveStats(attack: 8, defense: 5, movement: 5, range: 1, vision: 2)
        case .motorizedInfantry:
            return EffectiveStats(attack: 5, defense: 4, movement: 5, range: 1, vision: 3)
        case .infantry:
            return EffectiveStats(attack: 4, defense: 5, movement: 3, range: 1, vision: 2)
        case .artillery:
            return EffectiveStats(attack: 7, defense: 2, movement: 2, range: 2, vision: 2)
        case .lineInfantry:
            return EffectiveStats(attack: 4, defense: 5, movement: 3, range: 1, vision: 2)
        case .lightInfantry:
            return EffectiveStats(attack: 3, defense: 4, movement: 4, range: 1, vision: 3)
        case .cavalry:
            return EffectiveStats(attack: 6, defense: 3, movement: 5, range: 1, vision: 3)
        case .guardInfantry:
            return EffectiveStats(attack: 5, defense: 6, movement: 3, range: 1, vision: 2)
        case .engineer:
            return EffectiveStats(attack: 3, defense: 4, movement: 3, range: 1, vision: 2)
        case .supplyTrain:
            return EffectiveStats(attack: 1, defense: 2, movement: 3, range: 1, vision: 2)
        }
    }

    var isInfantryLike: Bool {
        switch self {
        case .infantry, .lineInfantry, .lightInfantry, .guardInfantry, .engineer:
            return true
        case .tank, .motorizedInfantry, .artillery, .cavalry, .supplyTrain:
            return false
        }
    }

    var isArtilleryLike: Bool {
        self == .artillery
    }

    var isCavalryLike: Bool {
        self == .cavalry
    }

    var isMobileLike: Bool {
        switch self {
        case .tank, .motorizedInfantry, .lightInfantry, .cavalry:
            return true
        case .infantry, .artillery, .lineInfantry, .guardInfantry, .engineer, .supplyTrain:
            return false
        }
    }
}

struct DivisionComponent: Codable, Equatable {
    let type: ComponentType
    let weight: Double
}

struct EffectiveStats: Codable, Equatable {
    var attack: Int
    var defense: Int
    var movement: Int
    var range: Int
    var vision: Int
}

enum RetreatMode: String, Codable, Equatable, CaseIterable {
    case retreatable
    case hold
}

struct Division: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var faction: Faction
    var coord: HexCoord
    var facing: HexDirection
    var strength: Int {
        didSet {
            strength = Self.clamp(strength, min: 0, max: maxStrength)
        }
    }
    var maxStrength: Int {
        didSet {
            maxStrength = max(1, maxStrength)
            strength = Self.clamp(strength, min: 0, max: maxStrength)
        }
    }
    var components: [DivisionComponent]
    var supplyState: SupplyState
    var hasActed: Bool
    var retreatMode: RetreatMode
    var isRetreating: Bool
    var retreatTarget: HexCoord?
    var retreatTurnsRemaining: Int {
        didSet {
            retreatTurnsRemaining = max(0, retreatTurnsRemaining)
        }
    }
    var fatigue: Int {
        didSet {
            fatigue = Self.clamp(fatigue, min: 0, max: Self.maximumFatigue)
        }
    }
    var ammunition: Int {
        didSet {
            ammunition = Self.clamp(ammunition, min: 0, max: maxAmmunition)
        }
    }
    var morale: Int {
        didSet {
            morale = Self.clamp(morale, min: 0, max: Self.maximumMorale)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case faction
        case coord
        case facing
        case hp
        case maxHP
        case strength
        case maxStrength
        case components
        case supplyState
        case hasActed
        case retreatMode
        case isRetreating
        case retreatTarget
        case retreatTurnsRemaining
        case fatigue
        case ammunition
        case morale
    }

    init(
        id: String,
        name: String,
        faction: Faction,
        coord: HexCoord,
        facing: HexDirection = .west,
        hp: Int = 10,
        maxHP: Int = 10,
        strength: Int? = nil,
        maxStrength: Int? = nil,
        components: [DivisionComponent],
        supplyState: SupplyState = .supplied,
        hasActed: Bool = false,
        retreatMode: RetreatMode = .retreatable,
        isRetreating: Bool = false,
        retreatTarget: HexCoord? = nil,
        retreatTurnsRemaining: Int = 0,
        fatigue: Int = 0,
        ammunition: Int? = nil,
        morale: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.coord = coord
        self.facing = facing
        let resolvedMaxStrength = max(1, maxStrength ?? maxHP)
        let resolvedStrength = strength ?? hp
        self.maxStrength = resolvedMaxStrength
        self.strength = Self.clamp(resolvedStrength, min: 0, max: resolvedMaxStrength)
        self.components = components
        self.supplyState = supplyState
        self.hasActed = hasActed
        self.retreatMode = retreatMode
        self.isRetreating = isRetreating
        self.retreatTarget = retreatTarget
        self.retreatTurnsRemaining = max(0, retreatTurnsRemaining)
        self.fatigue = Self.clamp(fatigue, min: 0, max: Self.maximumFatigue)
        self.ammunition = Self.clamp(
            ammunition ?? Self.defaultAmmunition(for: components),
            min: 0,
            max: Self.maximumAmmunition(for: components)
        )
        self.morale = Self.clamp(
            morale ?? Self.defaultMorale(for: components),
            min: 0,
            max: Self.maximumMorale
        )
    }

    var hp: Int {
        get { strength }
        set { strength = Self.clamp(newValue, min: 0, max: maxStrength) }
    }

    var maxHP: Int {
        get { maxStrength }
        set {
            maxStrength = max(1, newValue)
            strength = Self.clamp(strength, min: 0, max: maxStrength)
        }
    }

    var isDestroyed: Bool {
        strength <= 0
    }

    var canAct: Bool {
        !hasActed && !isDestroyed && !isRetreating
    }

    var legacyCoord: HexCoord? {
        coord
    }

    func location(in map: MapState) -> RegionId? {
        map.region(for: coord)
    }

    mutating func receiveStrengthDamage(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        strength = Self.clamp(strength - amount, min: 0, max: maxStrength)
    }

    mutating func reinforceStrength(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        strength = Self.clamp(strength + amount, min: 0, max: maxStrength)
    }

    mutating func beginRetreat(to target: HexCoord?, turns: Int = 1) {
        isRetreating = true
        retreatTarget = target
        retreatTurnsRemaining = max(1, turns)
    }

    mutating func advanceRetreatTurn() {
        guard retreatTurnsRemaining > 0 else {
            isRetreating = false
            retreatTarget = nil
            return
        }

        retreatTurnsRemaining -= 1
        if retreatTurnsRemaining == 0 {
            isRetreating = false
            retreatTarget = nil
        }
    }

    mutating func cancelRetreat() {
        isRetreating = false
        retreatTarget = nil
        retreatTurnsRemaining = 0
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let maxStrength = try container.decodeIfPresent(Int.self, forKey: .maxStrength)
            ?? container.decodeIfPresent(Int.self, forKey: .maxHP)
            ?? 10
        let strength = try container.decodeIfPresent(Int.self, forKey: .strength)
            ?? container.decodeIfPresent(Int.self, forKey: .hp)
            ?? maxStrength

        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            faction: try container.decode(Faction.self, forKey: .faction),
            coord: try container.decode(HexCoord.self, forKey: .coord),
            facing: try container.decodeIfPresent(HexDirection.self, forKey: .facing) ?? .west,
            hp: strength,
            maxHP: maxStrength,
            strength: strength,
            maxStrength: maxStrength,
            components: try container.decode([DivisionComponent].self, forKey: .components),
            supplyState: try container.decodeIfPresent(SupplyState.self, forKey: .supplyState) ?? .supplied,
            hasActed: try container.decodeIfPresent(Bool.self, forKey: .hasActed) ?? false,
            retreatMode: try container.decodeIfPresent(RetreatMode.self, forKey: .retreatMode) ?? .retreatable,
            isRetreating: try container.decodeIfPresent(Bool.self, forKey: .isRetreating) ?? false,
            retreatTarget: try container.decodeIfPresent(HexCoord.self, forKey: .retreatTarget),
            retreatTurnsRemaining: try container.decodeIfPresent(Int.self, forKey: .retreatTurnsRemaining) ?? 0,
            fatigue: try container.decodeIfPresent(Int.self, forKey: .fatigue) ?? 0,
            ammunition: try container.decodeIfPresent(Int.self, forKey: .ammunition),
            morale: try container.decodeIfPresent(Int.self, forKey: .morale)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(faction, forKey: .faction)
        try container.encode(coord, forKey: .coord)
        try container.encode(facing, forKey: .facing)
        try container.encode(strength, forKey: .strength)
        try container.encode(maxStrength, forKey: .maxStrength)
        try container.encode(strength, forKey: .hp)
        try container.encode(maxStrength, forKey: .maxHP)
        try container.encode(components, forKey: .components)
        try container.encode(supplyState, forKey: .supplyState)
        try container.encode(hasActed, forKey: .hasActed)
        try container.encode(retreatMode, forKey: .retreatMode)
        try container.encode(isRetreating, forKey: .isRetreating)
        try container.encodeIfPresent(retreatTarget, forKey: .retreatTarget)
        try container.encode(retreatTurnsRemaining, forKey: .retreatTurnsRemaining)
        try container.encode(fatigue, forKey: .fatigue)
        try container.encode(ammunition, forKey: .ammunition)
        try container.encode(morale, forKey: .morale)
    }

    var componentWeightTotal: Double {
        components.reduce(0) { $0 + $1.weight }
    }

    var hasValidComponentWeights: Bool {
        abs(componentWeightTotal - 1.0) <= 0.001
    }

    var baseStats: EffectiveStats {
        EffectiveStats(
            attack: weightedStat(\.attack),
            defense: weightedStat(\.defense),
            movement: weightedStat(\.movement),
            range: selectedMaxStat(\.range),
            vision: selectedMaxStat(\.vision)
        )
    }

    var effectiveStats: EffectiveStats {
        let stats = baseStats
        let suppliedStats: EffectiveStats

        switch supplyState {
        case .supplied:
            suppliedStats = stats
        case .lowSupply:
            suppliedStats = EffectiveStats(
                attack: max(1, Int(Double(stats.attack) * 0.75)),
                defense: max(1, stats.defense - 1),
                movement: max(1, stats.movement - 1),
                range: stats.range,
                vision: stats.vision
            )
        case .encircled:
            suppliedStats = EffectiveStats(
                attack: max(1, Int(Double(stats.attack) * 0.5)),
                defense: max(1, stats.defense - 2),
                movement: max(1, stats.movement - 2),
                range: stats.range,
                vision: stats.vision
            )
        }

        return EffectiveStats(
            attack: max(1, suppliedStats.attack - fatigueAttackPenalty - moraleAttackPenalty),
            defense: max(1, suppliedStats.defense - fatigueDefensePenalty - moraleDefensePenalty),
            movement: max(1, suppliedStats.movement - fatigueMovementPenalty),
            range: suppliedStats.range,
            vision: suppliedStats.vision
        )
    }

    var attack: Int {
        effectiveStats.attack
    }

    var defense: Int {
        effectiveStats.defense
    }

    var movement: Int {
        effectiveStats.movement
    }

    var range: Int {
        effectiveStats.range
    }

    var vision: Int {
        effectiveStats.vision
    }

    var isArmor: Bool {
        components.contains { $0.type == .tank && $0.weight >= 0.25 }
    }

    var isCavalry: Bool {
        components.contains { $0.type.isCavalryLike && $0.weight >= 0.25 }
    }

    var isArtillery: Bool {
        components.contains { $0.type.isArtilleryLike && $0.weight >= 0.50 }
    }

    var isMobileFormation: Bool {
        isArmor
            || isCavalry
            || movement >= 5
            || components.contains { $0.type.isMobileLike && $0.weight >= 0.25 }
    }

    static let maximumFatigue = 100
    static let maximumMorale = 100
    static let shakenMoraleThreshold = 40
    static let brokenMoraleThreshold = 25

    var maxAmmunition: Int {
        Self.maximumAmmunition(for: components)
    }

    var isAmmunitionSensitive: Bool {
        isArtillery || range > 1
    }

    var isLowAmmunition: Bool {
        ammunition <= max(1, maxAmmunition / 3)
    }

    var isLowMorale: Bool {
        morale <= Self.shakenMoraleThreshold
    }

    mutating func addFatigue(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        fatigue = Self.clamp(fatigue + amount, min: 0, max: Self.maximumFatigue)
    }

    mutating func recoverFatigue(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        fatigue = Self.clamp(fatigue - amount, min: 0, max: Self.maximumFatigue)
    }

    mutating func consumeAmmunition(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        ammunition = Self.clamp(ammunition - amount, min: 0, max: maxAmmunition)
    }

    mutating func recoverAmmunition(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        ammunition = Self.clamp(ammunition + amount, min: 0, max: maxAmmunition)
    }

    mutating func loseMorale(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        morale = Self.clamp(morale - amount, min: 0, max: Self.maximumMorale)
    }

    mutating func recoverMorale(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        morale = Self.clamp(morale + amount, min: 0, max: Self.maximumMorale)
    }

    private var fatigueAttackPenalty: Int {
        if fatigue >= 70 {
            return 2
        }
        if fatigue >= 40 {
            return 1
        }
        return 0
    }

    private var fatigueDefensePenalty: Int {
        fatigue >= 70 ? 1 : 0
    }

    private var fatigueMovementPenalty: Int {
        fatigue >= 60 ? 1 : 0
    }

    private var moraleAttackPenalty: Int {
        if morale <= Self.brokenMoraleThreshold {
            return 2
        }
        if morale <= Self.shakenMoraleThreshold {
            return 1
        }
        return 0
    }

    private var moraleDefensePenalty: Int {
        morale <= Self.brokenMoraleThreshold ? 2 : (morale <= Self.shakenMoraleThreshold ? 1 : 0)
    }

    private func weightedStat(_ keyPath: KeyPath<EffectiveStats, Int>) -> Int {
        let value = components.reduce(0.0) { partial, component in
            partial + Double(component.type.baseStats[keyPath: keyPath]) * component.weight
        }
        return max(1, Int(value.rounded()))
    }

    private func selectedMaxStat(_ keyPath: KeyPath<EffectiveStats, Int>) -> Int {
        let weightedComponents = components.filter { $0.weight >= 0.25 }
        let candidates = weightedComponents.isEmpty ? components : weightedComponents
        return candidates.map { $0.type.baseStats[keyPath: keyPath] }.max() ?? 1
    }

    private static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(value, maximum))
    }

    private static func defaultAmmunition(for components: [DivisionComponent]) -> Int {
        maximumAmmunition(for: components)
    }

    private static func maximumAmmunition(for components: [DivisionComponent]) -> Int {
        let artilleryWeight = components
            .filter { $0.type.isArtilleryLike }
            .reduce(0.0) { $0 + $1.weight }
        return artilleryWeight >= 0.25 ? 6 : 3
    }

    private static func defaultMorale(for components: [DivisionComponent]) -> Int {
        let guardWeight = components
            .filter { $0.type == .guardInfantry }
            .reduce(0.0) { $0 + $1.weight }
        return guardWeight >= 0.25 ? 90 : 80
    }
}

extension Division {
    static func panzer(id: String, name: String, faction: Faction, coord: HexCoord) -> Division {
        Division(
            id: id,
            name: name,
            faction: faction,
            coord: coord,
            facing: faction == .germany ? .west : .east,
            components: [
                DivisionComponent(type: .tank, weight: 0.55),
                DivisionComponent(type: .motorizedInfantry, weight: 0.25),
                DivisionComponent(type: .infantry, weight: 0.05),
                DivisionComponent(type: .artillery, weight: 0.15)
            ]
        )
    }

    static func motorized(id: String, name: String, faction: Faction, coord: HexCoord) -> Division {
        Division(
            id: id,
            name: name,
            faction: faction,
            coord: coord,
            facing: faction == .germany ? .west : .east,
            components: [
                DivisionComponent(type: .tank, weight: 0.15),
                DivisionComponent(type: .motorizedInfantry, weight: 0.55),
                DivisionComponent(type: .infantry, weight: 0.15),
                DivisionComponent(type: .artillery, weight: 0.15)
            ]
        )
    }

    static func infantry(id: String, name: String, faction: Faction, coord: HexCoord) -> Division {
        Division(
            id: id,
            name: name,
            faction: faction,
            coord: coord,
            facing: faction == .germany ? .west : .east,
            components: [
                DivisionComponent(type: .motorizedInfantry, weight: 0.10),
                DivisionComponent(type: .infantry, weight: 0.70),
                DivisionComponent(type: .artillery, weight: 0.20)
            ]
        )
    }

    static func artillery(id: String, name: String, faction: Faction, coord: HexCoord) -> Division {
        Division(
            id: id,
            name: name,
            faction: faction,
            coord: coord,
            facing: faction == .germany ? .west : .east,
            components: [
                DivisionComponent(type: .motorizedInfantry, weight: 0.10),
                DivisionComponent(type: .infantry, weight: 0.30),
                DivisionComponent(type: .artillery, weight: 0.60)
            ]
        )
    }
}
