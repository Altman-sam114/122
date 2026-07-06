import Foundation

struct CombatDamage: Equatable {
    let strengthDamage: Int
    let lossRatio: Double
}

struct CombatRules {
    let movementRules = MovementRules()

    func terrainDefenseBonus(for defender: Division, attackedBy attacker: Division, in state: GameState) -> Int {
        guard let defenderTile = state.map.tile(at: defender.coord) else {
            return 0
        }

        var bonus = state.terrainRules.defenseBonus(for: defenderTile.baseTerrain)
        if hasRiverBetween(attacker.coord, defender.coord, in: state) {
            bonus += state.terrainRules.riverCrossingExtraCost
        }
        return bonus
    }

    func effectiveDefense(for defender: Division, attackedBy attacker: Division, in state: GameState) -> Int {
        var baseDefense = defender.defense + terrainDefenseBonus(for: defender, attackedBy: attacker, in: state)
        if let defenderTile = state.map.tile(at: defender.coord),
           defender.isInfantryHeavy,
           defenderTile.baseTerrain.supportsInfantryDefenseBonus {
            baseDefense = max(1, Int((Double(baseDefense) * 1.3).rounded()))
        }
        guard defender.retreatMode == .hold else {
            return baseDefense
        }
        return max(1, Int((Double(baseDefense) * 1.2).rounded()))
    }

    func flankBonus(attacker: Division, defender: Division) -> Int {
        guard let attackDirection = defender.coord.direction(to: attacker.coord) else {
            return 0
        }

        switch attackDirection.relation(toFacing: defender.facing) {
        case .front:
            return 0
        case .flank:
            return 2
        case .rear:
            return 4
        }
    }

    func damage(attacker: Division, defender: Division, in state: GameState) -> Int {
        let rawDamage = effectiveAttack(for: attacker, against: defender, in: state) -
            effectiveDefense(for: defender, attackedBy: attacker, in: state) / 2
        return clamp(rawDamage + flankBonus(attacker: attacker, defender: defender), min: 1, max: 8)
    }

    func effectiveAttack(for attacker: Division, against defender: Division, in state: GameState) -> Int {
        guard let defenderTile = state.map.tile(at: defender.coord) else {
            return ammunitionAdjustedAttack(for: attacker, baseAttack: attacker.attack)
        }

        var multiplier = 1.0
        if attacker.isArmor && defenderTile.baseTerrain == .plain {
            multiplier += 0.2
        }
        if attacker.isArmor && defenderTile.baseTerrain.armorSlowdownCost > 0 {
            multiplier -= 0.1
        }
        if attacker.isCavalry {
            multiplier += cavalryAttackAdjustment(attackingInto: defenderTile.baseTerrain, defender: defender)
        }
        if attacker.isArtillery {
            multiplier += artilleryAttackAdjustment(
                attackingInto: defenderTile.baseTerrain,
                distance: attacker.coord.distance(to: defender.coord)
            )
        }

        let baseAttack = max(1, Int((Double(attacker.attack) * multiplier).rounded()))
        return ammunitionAdjustedAttack(for: attacker, baseAttack: baseAttack)
    }

    func attackDamage(attacker: Division, defender: Division, in state: GameState) -> CombatDamage {
        let strengthDamage = damage(attacker: attacker, defender: defender, in: state)
        return CombatDamage(
            strengthDamage: strengthDamage,
            lossRatio: lossRatio(strengthDamage: strengthDamage, defender: defender)
        )
    }

    func canCounterAttack(defender: Division, attacker: Division) -> Bool {
        guard defender.hp > 0 else {
            return false
        }

        if defender.isArtillery && defender.coord.distance(to: attacker.coord) == 1 {
            return false
        }

        return defender.coord.distance(to: attacker.coord) <= defender.range
    }

    func counterDamage(defender: Division, attacker: Division, in state: GameState) -> Int {
        max(1, damage(attacker: defender, defender: attacker, in: state) / 2)
    }

    func counterAttackDamage(defender: Division, attacker: Division, in state: GameState) -> CombatDamage {
        let strengthDamage = counterDamage(defender: defender, attacker: attacker, in: state)
        return CombatDamage(
            strengthDamage: strengthDamage,
            lossRatio: lossRatio(strengthDamage: strengthDamage, defender: attacker)
        )
    }

    func hasRiverBetween(_ a: HexCoord, _ b: HexCoord, in state: GameState) -> Bool {
        guard a.distance(to: b) == 1,
              let direction = a.direction(to: b),
              let fromTile = state.map.tile(at: a),
              let toTile = state.map.tile(at: b) else {
            return false
        }

        return movementRules.hasRiverCrossing(from: fromTile, to: toTile, direction: direction)
    }

    private func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func ammunitionAdjustedAttack(for attacker: Division, baseAttack: Int) -> Int {
        guard attacker.isAmmunitionSensitive else {
            return baseAttack
        }

        if attacker.ammunition == 0 {
            return max(1, Int((Double(baseAttack) * 0.55).rounded()))
        }

        if attacker.isLowAmmunition {
            return max(1, Int((Double(baseAttack) * 0.80).rounded()))
        }

        return baseAttack
    }

    private func cavalryAttackAdjustment(attackingInto terrain: BaseTerrain, defender: Division) -> Double {
        switch terrain {
        case .plain:
            return defender.isInfantryHeavy && defender.retreatMode == .hold ? -0.10 : 0.15
        case .hill:
            return -0.10
        case .forest,
             .mountain,
             .city,
             .fortress:
            return -0.25
        }
    }

    private func artilleryAttackAdjustment(attackingInto terrain: BaseTerrain, distance: Int) -> Double {
        guard distance > 1 else {
            return 0
        }

        switch terrain {
        case .plain:
            return 0.10
        case .hill:
            return 0.05
        case .forest,
             .mountain,
             .city,
             .fortress:
            return -0.05
        }
    }

    private func lossRatio(strengthDamage: Int, defender: Division) -> Double {
        guard defender.strength > 0 else {
            return 1
        }
        return Double(strengthDamage) / Double(defender.strength)
    }
}
