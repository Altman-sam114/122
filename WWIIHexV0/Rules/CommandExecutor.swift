import Foundation

struct CommandExecutor {
    private let movementRules = MovementRules()
    private let combatRules = CombatRules()
    private let supplyRules = SupplyRules()
    private let occupationRules = OccupationRules()
    private let strategicSynchronizer = StrategicStateSynchronizer()
    private let retreatLossThreshold = 0.35

    func execute(_ command: Command, in state: GameState) -> GameState {
        var nextState = state

        switch command {
        case .move(let divisionId, let destination):
            executeMove(divisionId: divisionId, destination: destination, in: &nextState)
        case .attack(let attackerId, let targetId):
            executeAttack(attackerId: attackerId, targetId: targetId, in: &nextState)
        case .hold(let divisionId):
            executeHold(divisionId: divisionId, in: &nextState)
        case .allowRetreat(let divisionId):
            executeAllowRetreat(divisionId: divisionId, in: &nextState)
        case .resupply(let divisionId):
            executeResupply(divisionId: divisionId, in: &nextState)
        case .queueProduction(let kind):
            executeQueueProduction(kind: kind, in: &nextState)
        case .endTurn:
            executeEndTurn(in: &nextState)
        }

        return nextState
    }

    private func executeMove(divisionId: String, destination: HexCoord, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        let origin = state.divisions[index].coord
        let sourceZoneId = state.warDeploymentState.zoneId(for: origin, map: state.map)
        let movementPath = movementRules.shortestPath(for: state.divisions[index], to: destination, in: state)
        if let direction = directionForMove(from: origin, to: destination, division: state.divisions[index], in: state) {
            state.divisions[index].facing = direction
        }
        state.divisions[index].coord = destination
        state.divisions[index].hasActed = true
        applyMovementFatigue(path: movementPath, to: index, in: &state)

        if occupationRules.canOccupy(division: state.divisions[index], destination: destination, in: state),
           var tile = state.map.tile(at: destination) {
            tile.controller = state.divisions[index].faction
            state.map.setTile(tile)
            if let destinationRegionId = state.map.region(for: destination),
               let sourceZoneId {
                applyStrategicAdvance(
                    regionId: destinationRegionId,
                    hex: destination,
                    sourceZoneId: sourceZoneId,
                    faction: state.divisions[index].faction,
                    state: &state
                )
            }
            _ = strategicSynchronizer.synchronizeAfterOccupationChange(
                in: &state,
                affectedRegionIds: state.map.region(for: destination).map { [$0] } ?? []
            )
        }

        state.appendEvent("\(state.divisions[index].name) moved to \(destination.q),\(destination.r).")
    }

    private func executeAttack(attackerId: String, targetId: String, in state: inout GameState) {
        guard let attackerIndex = state.divisionIndex(id: attackerId),
              let targetIndex = state.divisionIndex(id: targetId) else {
            return
        }

        let attacker = state.divisions[attackerIndex]
        let defender = state.divisions[targetIndex]
        let damage = combatRules.attackDamage(attacker: attacker, defender: defender, in: state)
        let attackerFacing = attacker.coord.direction(to: defender.coord) ?? attacker.facing

        state.divisions[attackerIndex].hasActed = true
        state.divisions[attackerIndex].facing = attackerFacing
        applyAttackWear(to: attackerId, in: &state)
        applyCombatDamage(damage, to: targetId, in: &state)

        let attackOutcome = resolveCombatResult(for: defender, damage: damage, in: &state)
        state.appendEvent(
            combatLog(
                prefix: "\(attacker.name) attacked \(defender.name)",
                subjectName: defender.name,
                damage: damage,
                outcome: attackOutcome,
                faction: attacker.faction
            )
        )

        if attackOutcome.wasDestroyed {
            return
        }

        if attackOutcome.shouldRetreat {
            supplyRules.resolveRetreat(for: targetId, in: &state)
        }

        guard let updatedDefender = state.division(id: targetId),
              let updatedAttacker = state.division(id: attackerId) else {
            return
        }

        if !attackOutcome.shouldRetreat,
           combatRules.canCounterAttack(defender: updatedDefender, attacker: updatedAttacker) {
            let counterDamage = combatRules.counterAttackDamage(defender: updatedDefender, attacker: updatedAttacker, in: state)
            applyCounterAttackWear(to: targetId, in: &state)
            applyCombatDamage(counterDamage, to: attackerId, in: &state)

            let counterOutcome = resolveCombatResult(for: updatedAttacker, damage: counterDamage, in: &state)
            state.appendEvent(
                combatLog(
                    prefix: "\(updatedDefender.name) counterattacked \(updatedAttacker.name)",
                    subjectName: updatedAttacker.name,
                    damage: counterDamage,
                    outcome: counterOutcome,
                    faction: updatedDefender.faction
                )
            )

            if counterOutcome.shouldRetreat && !counterOutcome.wasDestroyed {
                supplyRules.resolveRetreat(for: attackerId, in: &state)
            }
        }
    }

    private func executeHold(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].retreatMode = .hold
        state.divisions[index].hasActed = true
        state.divisions[index].recoverFatigue(2)
        state.divisions[index].recoverMorale(3)
        state.appendEvent(holdStanceMessage(for: state.divisions[index], in: state))
    }

    private func executeAllowRetreat(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].retreatMode = .retreatable
        state.divisions[index].hasActed = true
        state.appendEvent(retreatableStanceMessage(for: state.divisions[index], in: state))
    }

    private func executeResupply(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        supplyRules.applyResupplyRest(to: divisionId, in: &state)
        state.divisions[index].hasActed = true
    }

    private func executeQueueProduction(kind: ProductionKind, in state: inout GameState) {
        _ = EconomyRules().queueProduction(kind: kind, faction: state.activeFaction, in: &state)
    }

    private func executeEndTurn(in state: inout GameState) {
        let supplyRules = SupplyRules()
        let victoryRules = VictoryRules()
        let economyRules = EconomyRules()

        supplyRules.updateSupplyStates(in: &state)
        economyRules.resolveFactionTurn(for: state.activeFaction, in: &state)
        supplyRules.advanceRetreats(in: &state)
        supplyRules.applyEncirclementAttrition(in: &state)
        victoryRules.updateVictoryState(in: &state)

        let turnOrder = state.turnOrderFactions
        if let currentIndex = turnOrder.firstIndex(of: state.activeFaction), !turnOrder.isEmpty {
            let nextIndex = (currentIndex + 1) % turnOrder.count
            state.activeFaction = turnOrder[nextIndex]
            state.phase = GamePhase.commandPhase(for: state.activeFaction)
            if nextIndex == 0 {
                state.turn += 1
            }
        } else {
            state.phase = .resolution
        }

        resetActionsForActiveFaction(in: &state)
        state = StrategicStateBootstrapper().refreshRuntimeState(state)
        state.appendEvent(turnAdvancedMessage(in: state))
    }

    private func resetActionsForActiveFaction(in state: inout GameState) {
        for index in state.divisions.indices where state.divisions[index].faction == state.activeFaction {
            state.divisions[index].hasActed = false
        }
    }

    private func directionForMove(
        from origin: HexCoord,
        to destination: HexCoord,
        division: Division,
        in state: GameState
    ) -> HexDirection? {
        if let path = movementRules.shortestPath(for: division, to: destination, in: state),
           path.coords.count >= 2 {
            let previous = path.coords[path.coords.count - 2]
            return previous.direction(to: destination)
        }

        return origin.direction(to: destination)
    }

    private func applyCombatDamage(_ damage: CombatDamage, to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].receiveStrengthDamage(damage.strengthDamage)
        state.divisions[index].loseMorale(moraleDamage(for: damage.strengthDamage))
    }

    private func applyMovementFatigue(path: MovementPath?, to index: Int, in state: inout GameState) {
        let pathCost = path?.cost ?? 1
        var fatigueGain = max(1, pathCost)
        switch state.divisions[index].supplyState {
        case .supplied:
            break
        case .lowSupply:
            fatigueGain += 2
        case .encircled:
            fatigueGain += 4
        }

        state.divisions[index].addFatigue(fatigueGain)
    }

    private func applyAttackWear(to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        var fatigueGain = state.divisions[index].isCavalry ? 8 : 6
        if state.divisions[index].isArtillery {
            fatigueGain = 4
        }
        state.divisions[index].addFatigue(fatigueGain)

        if state.divisions[index].isAmmunitionSensitive {
            state.divisions[index].consumeAmmunition(1)
        }
    }

    private func applyCounterAttackWear(to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].addFatigue(3)
        if state.divisions[index].isAmmunitionSensitive {
            state.divisions[index].consumeAmmunition(1)
        }
    }

    private func resolveCombatResult(
        for originalDivision: Division,
        damage: CombatDamage,
        in state: inout GameState
    ) -> CombatResultSummary {
        guard let index = state.divisionIndex(id: originalDivision.id) else {
            return CombatResultSummary(shouldRetreat: false, wasDestroyed: true, extraStrengthDamage: 0)
        }

        let lowMoraleRetreat = damage.strengthDamage > 0
            && state.divisions[index].morale <= Division.brokenMoraleThreshold
        let shouldRetreat = state.divisions[index].retreatMode == .retreatable &&
            !state.divisions[index].isDestroyed &&
            (damage.lossRatio >= retreatLossThreshold || lowMoraleRetreat)
        var extraStrengthDamage = 0

        if state.divisions[index].retreatMode == .hold && !state.divisions[index].isDestroyed {
            extraStrengthDamage += max(1, Int((Double(damage.strengthDamage) * 0.2).rounded()))
            state.divisions[index].receiveStrengthDamage(extraStrengthDamage)
            state.divisions[index].loseMorale(moraleDamage(for: extraStrengthDamage))
        }

        if shouldRetreat && state.divisions[index].supplyState == .encircled && !state.divisions[index].isDestroyed {
            extraStrengthDamage = max(1, damage.strengthDamage / 2)
            state.divisions[index].receiveStrengthDamage(extraStrengthDamage)
            state.divisions[index].loseMorale(moraleDamage(for: extraStrengthDamage))
        }

        if state.divisions[index].isDestroyed {
            eliminateDivision(originalDivision, in: &state)
            return CombatResultSummary(
                shouldRetreat: shouldRetreat,
                wasDestroyed: true,
                extraStrengthDamage: extraStrengthDamage
            )
        }

        if shouldRetreat {
            state.divisions[index].hasActed = true
        }

        return CombatResultSummary(
            shouldRetreat: shouldRetreat,
            wasDestroyed: false,
            extraStrengthDamage: extraStrengthDamage
        )
    }

    private func eliminateDivision(_ division: Division, in state: inout GameState) {
        state.victoryState.recordEliminatedDivision(faction: division.faction)
        state.removeDivision(id: division.id)
    }

    private func applyStrategicAdvance(
        regionId: RegionId,
        hex: HexCoord,
        sourceZoneId: FrontZoneId,
        faction: Faction,
        state: inout GameState
    ) {
        let advancingTheaterId = TheaterId(sourceZoneId.rawValue)
        guard state.theaterState.theaters[advancingTheaterId] != nil,
              state.theaterState.dynamicTheaterId(for: hex, map: state.map) != advancingTheaterId else {
            return
        }
        guard shouldAdvanceDynamicTheater(
            hex: hex,
            sourceZoneId: sourceZoneId,
            faction: faction,
            state: state
        ) else {
            return
        }

        state.theaterState = TheaterSystem().expandDynamicTheater(
            state: state.theaterState,
            map: state.map,
            divisions: state.divisions,
            breakthroughHex: hex,
            advancingTheaterId: advancingTheaterId,
            faction: faction,
            diplomacyState: state.diplomacyState
        ).state

        let oldZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if oldZoneId != sourceZoneId {
            state.warDeploymentState = WarDeploymentManager().advanceHex(
                hex,
                from: oldZoneId,
                to: sourceZoneId,
                state: state.warDeploymentState,
                map: state.map,
                divisions: state.divisions,
                diplomacyState: state.diplomacyState,
                turn: state.turn
            )
        }

        state.appendEvent(
            theaterAdvanceMessage(hex: hex, theaterId: advancingTheaterId, in: state),
            category: .theaterChange,
            relatedRecordId: nil
        )
    }

    private func shouldAdvanceDynamicTheater(
        hex: HexCoord,
        sourceZoneId: FrontZoneId,
        faction: Faction,
        state: GameState
    ) -> Bool {
        let destinationZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if let destinationZoneId,
           destinationZoneId != sourceZoneId,
           let destinationFaction = state.warDeploymentState.frontZones[destinationZoneId]?.faction {
            return !state.diplomacyState.isFriendly(faction, to: destinationFaction)
        }

        if let controller = state.map.tile(at: hex)?.controller {
            return !state.diplomacyState.isFriendly(faction, to: controller)
        }

        return false
    }

    private func combatLog(
        prefix: String,
        subjectName: String,
        damage: CombatDamage,
        outcome: CombatResultSummary,
        faction: Faction
    ) -> String {
        var parts = [
            "\(prefix): strength -\(damage.strengthDamage)"
        ]

        if outcome.shouldRetreat {
            let retreatText = faction.usesNapoleonicLogisticsVocabulary ? "automatic withdrawal" : "automatic retreat"
            parts.append("\(subjectName) triggered \(retreatText)")
        }

        if outcome.extraStrengthDamage > 0 {
            parts.append("extra strength -\(outcome.extraStrengthDamage)")
        }

        if outcome.wasDestroyed {
            parts.append("\(subjectName) was destroyed")
        }

        return parts.joined(separator: "; ") + "."
    }

    private func holdStanceMessage(for division: Division, in state: GameState) -> String {
        if state.activeFaction.usesNapoleonicLogisticsVocabulary {
            if division.isInfantryHeavy {
                return "\(division.name) formed a square-ready Hold Line: no withdrawal, +20% defense, cavalry charges blunted, +20% losses."
            }
            return "\(division.name) formed a Hold Line order: no withdrawal, +20% defense, +20% losses."
        }

        return "\(division.name) set stance to HOLD: no retreat, +20% defense, +20% losses."
    }

    private func retreatableStanceMessage(for division: Division, in state: GameState) -> String {
        if state.activeFaction.usesNapoleonicLogisticsVocabulary {
            return "\(division.name) received withdrawal orders: auto-withdraw after severe losses."
        }

        return "\(division.name) set stance to RETREATABLE: auto-retreat after severe losses."
    }

    private func turnAdvancedMessage(in state: GameState) -> String {
        if state.activeFaction.usesNapoleonicLogisticsVocabulary {
            return "Orders advanced to turn \(state.turn), \(state.activeFaction.displayName) active."
        }

        return "Turn advanced to \(state.turn), \(state.activeFaction.displayName) active."
    }

    private func theaterAdvanceMessage(hex: HexCoord, theaterId: TheaterId, in state: GameState) -> String {
        if state.activeFaction.usesNapoleonicLogisticsVocabulary {
            let wingName = state.theaterState.theaters[theaterId]?.name ?? identifierDisplayText(
                theaterId.rawValue,
                fallback: "active wing",
                suffix: " wing"
            )
            return "Hex \(hex.q),\(hex.r) reassigned to active wing \(wingName)."
        }

        return "Hex \(hex.q),\(hex.r) reassigned to dynamic theater \(theaterId.rawValue)."
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

    private func moraleDamage(for strengthDamage: Int) -> Int {
        guard strengthDamage > 0 else {
            return 0
        }
        return max(3, strengthDamage * 4)
    }
}

private struct CombatResultSummary: Equatable {
    let shouldRetreat: Bool
    let wasDestroyed: Bool
    let extraStrengthDamage: Int
}
