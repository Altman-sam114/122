import Foundation

struct VictoryRules {
    private enum WaterlooConditionId {
        static let frenchBreakCenter = "french_break_center"
        static let coalitionHoldUntilPrussia = "coalition_hold_until_prussia"
    }

    private enum WaterlooObjectiveId {
        static let hougoumont = "objective_hougoumont"
        static let montSaintJean = "objective_mont_saint_jean"
        static let prussianArrival = "objective_prussian_arrival"
    }

    func updateVictoryState(in state: inout GameState) {
        guard state.victoryState.winner == nil else {
            return
        }

        if state.scenarioId == "waterloo_1815" {
            updateWaterlooVictoryState(in: &state)
            return
        }

        let bastogneController = state.map.controllerOfObjective(named: "Bastogne")
        let stVithController = state.map.controllerOfObjective(named: "St. Vith")

        if bastogneController == .germany {
            if let heldSince = state.victoryState.germanBastogneHeldSinceTurn,
               state.turn > heldSince {
                state.victoryState.winner = .germany
                state.victoryState.reason = .bastogneHeldByGermany
                return
            } else if state.victoryState.germanBastogneHeldSinceTurn == nil {
                state.victoryState.germanBastogneHeldSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanBastogneHeldSinceTurn = nil
        }

        if bastogneController == .germany && stVithController == .germany {
            state.victoryState.winner = .germany
            state.victoryState.reason = .bastogneAndStVithControlledByGermany
            return
        }

        if state.victoryState.eliminatedAlliedDivisions >= 3 {
            state.victoryState.winner = .germany
            state.victoryState.reason = .alliedUnitsDestroyed
            return
        }

        if state.victoryState.eliminatedGermanDivisions >= 3 {
            state.victoryState.winner = .allies
            state.victoryState.reason = .germanUnitsDestroyed
            return
        }

        let germanArmor = state.divisions.filter { $0.faction == .germany && $0.isArmor }
        if !germanArmor.isEmpty && germanArmor.allSatisfy({ $0.supplyState != .supplied }) {
            if let since = state.victoryState.germanArmorUnsuppliedSinceTurn,
               state.turn > since {
                state.victoryState.winner = .allies
                state.victoryState.reason = .germanArmorUnsupplied
                return
            } else if state.victoryState.germanArmorUnsuppliedSinceTurn == nil {
                state.victoryState.germanArmorUnsuppliedSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanArmorUnsuppliedSinceTurn = nil
        }

        if state.turn >= state.maxTurns && bastogneController == .allies {
            state.victoryState.winner = .allies
            state.victoryState.reason = .bastogneHeldByAlliesAtFinalTurn
        }
    }

    private func updateWaterlooVictoryState(in state: inout GameState) {
        let conditions = waterlooVictoryConditions(in: state)

        if let breakCenter = conditions.first(where: { $0.id == WaterlooConditionId.frenchBreakCenter && $0.isActive }),
           let objectiveId = breakCenter.objectiveId,
           state.map.controllerOfObjective(id: objectiveId) == breakCenter.faction {
            state.victoryState.winner = breakCenter.faction
            state.victoryState.reason = .waterlooFrenchBreakthrough
            return
        }

        guard let holdLine = conditions.first(where: { $0.id == WaterlooConditionId.coalitionHoldUntilPrussia && $0.isActive }) else {
            return
        }

        let decisiveTurn = holdLine.turn ?? state.maxTurns
        guard state.turn >= decisiveTurn else {
            return
        }

        let objectiveIds = holdLine.objectiveIds
        guard !objectiveIds.isEmpty else {
            return
        }

        let coalitionHeldLine: Bool
        if let targetFaction = holdLine.targetFaction {
            let objectiveControllers = objectiveIds.map {
                state.map.controllerOfObjective(id: $0)
            }
            guard objectiveControllers.allSatisfy({ $0 != nil }) else {
                return
            }
            coalitionHeldLine = objectiveControllers.allSatisfy { $0 != targetFaction }
        } else {
            coalitionHeldLine = objectiveIds.allSatisfy {
                state.map.controllerOfObjective(id: $0) == holdLine.faction
            }
        }

        if coalitionHeldLine {
            state.victoryState.winner = holdLine.faction
            state.victoryState.reason = .waterlooCoalitionLineHeld
        }
    }

    private func waterlooVictoryConditions(in state: GameState) -> [ScenarioVictoryCondition] {
        let fallbackConditions = defaultWaterlooVictoryConditions(maxTurns: state.maxTurns)
        guard !state.victoryConditions.isEmpty else {
            return fallbackConditions
        }

        let explicitConditionIds = Set(state.victoryConditions.map(\.id))
        let activeConditions = state.victoryConditions.filter(\.isActive)
        return activeConditions + fallbackConditions.filter { !explicitConditionIds.contains($0.id) }
    }

    private func defaultWaterlooVictoryConditions(maxTurns: Int) -> [ScenarioVictoryCondition] {
        return [
            ScenarioVictoryCondition(
                id: WaterlooConditionId.frenchBreakCenter,
                type: "holdObjective",
                faction: .france,
                objectiveId: WaterlooObjectiveId.montSaintJean,
                objectiveIds: [],
                targetFaction: nil,
                turn: nil,
                status: "active",
                description: "France wins by taking Mont-Saint-Jean before the coalition line stabilizes."
            ),
            ScenarioVictoryCondition(
                id: WaterlooConditionId.coalitionHoldUntilPrussia,
                type: "holdObjectives",
                faction: .angloAllied,
                objectiveId: nil,
                objectiveIds: [
                    WaterlooObjectiveId.hougoumont,
                    WaterlooObjectiveId.montSaintJean,
                    WaterlooObjectiveId.prussianArrival
                ],
                targetFaction: .france,
                turn: maxTurns,
                status: "active",
                description: "Coalition wins by holding the ridge and keeping the Prussian arrival road open."
            )
        ]
    }
}
