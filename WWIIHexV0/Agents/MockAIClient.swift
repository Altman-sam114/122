import Foundation

// DEPRECATED as of v0.352 - kept for regression reference, not invoked by default. See WarPipelineMode.
// Heuristic staff AI: skip acted; low/encircled supply -> resupply;
// in-range vulnerable enemy -> attack; else advance toward the nearest contested objective; else hold.

struct MockAIClient: DecisionProvider {
    func decide(context: AgentContext) async throws -> AgentDecisionEnvelope {
        if !context.frontZones.isEmpty,
           let envelope = frontDeploymentDecision(context: context) {
            return envelope
        }

        var orders: [AgentOrder] = []
        var reservedDestinations = Set(context.friendlyDivisions.compactMap(\.regionId) + context.enemyDivisions.compactMap(\.regionId))
        let objective = preferredObjective(in: context)

        for division in context.friendlyDivisions.sorted(by: orderPriority) {
            guard !division.hasActed else {
                continue
            }

            if division.supplyState == .lowSupply || division.supplyState == .encircled {
                orders.append(
                    AgentOrder(
                        type: .resupply,
                        divisionId: division.id,
                        toRegionId: division.regionId,
                        stance: "recover",
                        reason: supplyRecoveryReason(for: division, context: context)
                    )
                )
                continue
            }

            if let attackTarget = bestAttackTarget(for: division, context: context) {
                orders.append(
                    AgentOrder(
                        type: .attack,
                        divisionId: division.id,
                        targetDivisionId: attackTarget.id,
                        stance: division.isArtillery ? "fireSupport" : "breakthrough",
                        reason: attackReason(attacker: division, target: attackTarget, context: context)
                    )
                )
                continue
            }

            if let objective,
               let objectiveRegionId = objective.regionId,
               let destination = bestMoveDestination(
                for: division,
                toward: objectiveRegionId,
                context: context,
                reservedDestinations: reservedDestinations
               ) {
                if let regionId = division.regionId {
                    reservedDestinations.remove(regionId)
                }
                reservedDestinations.insert(destination)
                orders.append(
                    AgentOrder(
                        type: .move,
                        divisionId: division.id,
                        toRegionId: destination,
                        stance: division.isArmor ? "roadAdvance" : "advance",
                        reason: movementReason(toward: objective, context: context)
                    )
                )
                continue
            }

            orders.append(
                    AgentOrder(
                        type: .hold,
                        divisionId: division.id,
                        toRegionId: division.regionId,
                        stance: "hold",
                    reason: "No useful visible move or attack is available."
                )
            )
        }

        return AgentDecisionEnvelope(
            schemaVersion: context.visibleRegions.isEmpty ? 1 : 2,
            agentId: context.agentId,
            turn: context.turn,
            intent: operationalIntent(context: context, objective: objective),
            orders: orders
        )
    }

    private func frontDeploymentDecision(context: AgentContext) -> AgentDecisionEnvelope? {
        let divisionById = Dictionary(uniqueKeysWithValues: context.friendlyDivisions.map { ($0.id, $0) })
        let regionControllers = Dictionary(uniqueKeysWithValues: context.visibleRegions.map { ($0.id, $0.controller) })
        let frontRegionIds = Set(context.frontZones.flatMap { zone in
            zone.frontSegments.map(\.regionId)
        })
        var orders: [AgentOrder] = []
        var usedDivisionIds: Set<String> = []

        for division in context.friendlyDivisions.sorted(by: orderPriority) {
            guard !division.hasActed else { continue }
            if division.supplyState == .lowSupply || division.supplyState == .encircled {
                orders.append(
                    AgentOrder(
                        type: .resupply,
                        divisionId: division.id,
                        toRegionId: division.regionId,
                        stance: "frontRecovery",
                        reason: deploymentSupplyReason(for: division, context: context)
                    )
                )
                usedDivisionIds.insert(division.id)
            }
        }

        for zone in context.frontZones.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            for segment in zone.frontSegments.sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue }) {
                for unitId in segment.assignedUnitIds.sorted() {
                    guard !usedDivisionIds.contains(unitId),
                          let division = divisionById[unitId],
                          !division.hasActed else {
                        continue
                    }
                    if let target = frontAttackTarget(for: division, segment: segment, context: context) {
                        orders.append(
                            AgentOrder(
                                type: .attack,
                                divisionId: unitId,
                                targetDivisionId: target.id,
                                stance: segment.isEncircled ? "closePocket" : "frontAttack",
                                reason: contactAttackReason(segment: segment, context: context)
                            )
                        )
                    } else {
                        orders.append(
                            AgentOrder(
                                type: .hold,
                                divisionId: unitId,
                                toRegionId: division.regionId,
                                stance: segment.isEncircled ? "containPocket" : "holdFront",
                                reason: contactHoldReason(segment: segment, context: context)
                            )
                        )
                    }
                    usedDivisionIds.insert(unitId)
                }
            }
        }

        for zone in context.frontZones.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            for unitId in zone.depthUnitIds.sorted() {
                guard !usedDivisionIds.contains(unitId),
                      let division = divisionById[unitId],
                      !division.hasActed else {
                    continue
                }
                let targetRegion = reinforcementTarget(for: division, context: context)
                if let targetRegion,
                   division.regionId != targetRegion,
                   regionControllers[targetRegion] == context.faction {
                    orders.append(
                        AgentOrder(
                            type: .move,
                            divisionId: unitId,
                            toRegionId: targetRegion,
                            stance: "depthReinforce",
                            reason: reserveReinforceReason(context: context)
                        )
                    )
                } else {
                    orders.append(
                        AgentOrder(
                            type: .hold,
                            divisionId: unitId,
                            toRegionId: division.regionId,
                            stance: "depthReserve",
                            reason: reserveHoldReason(context: context)
                        )
                    )
                }
                usedDivisionIds.insert(unitId)
            }
        }

        for unitId in context.frontZones.flatMap(\.garrisonUnitIds).sorted() {
            guard !usedDivisionIds.contains(unitId),
                  let division = divisionById[unitId],
                  !division.hasActed else {
                continue
            }
            orders.append(
                AgentOrder(
                    type: .hold,
                    divisionId: unitId,
                    toRegionId: division.regionId,
                    stance: "garrison",
                    reason: garrisonHoldReason(context: context)
                )
            )
            usedDivisionIds.insert(unitId)
        }

        for division in context.friendlyDivisions.sorted(by: orderPriority) {
            guard !usedDivisionIds.contains(division.id),
                  !division.hasActed,
                  let regionId = division.regionId else {
                continue
            }
            let stance = frontRegionIds.contains(regionId) ? "frontUnassigned" : "operationalReserve"
            orders.append(
                AgentOrder(
                    type: .hold,
                    divisionId: division.id,
                    toRegionId: regionId,
                    stance: stance,
                    reason: unassignedHoldReason(context: context)
                )
            )
        }

        guard !orders.isEmpty else { return nil }
        return AgentDecisionEnvelope(
            schemaVersion: 2,
            agentId: context.agentId,
            turn: context.turn,
            intent: deploymentIntent(context: context),
            orders: orders
        )
    }

    private func preferredObjective(in context: AgentContext) -> ObjectiveSummary? {
        context.objectives.first { objective in
            objective.controller != context.faction
        } ?? context.objectives.first
    }

    private func operationalIntent(context: AgentContext, objective: ObjectiveSummary?) -> String {
        guard let objective else {
            return context.faction.usesNapoleonicLogisticsVocabulary
                ? "Keep formations coordinated while seeking a useful local action."
                : "Keep units coordinated while seeking a useful local action."
        }
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Press toward \(objective.name) with coordinated formations and artillery support."
        }
        return "Advance toward \(objective.name) with mobile units and artillery support."
    }

    private func supplyRecoveryReason(for division: DivisionSummary, context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Formation is \(division.supplyState.rawValue); recover supply before renewing the attack."
        }
        return "Unit is \(division.supplyState.rawValue); recover supply before continuing the attack."
    }

    private func movementReason(toward objective: ObjectiveSummary, context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Advance toward \(objective.name), keeping open routes and supporting formations."
        }
        return "Advance toward \(objective.name), preferring open routes and artillery support."
    }

    private func deploymentIntent(context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Use corps deployment: contact formations hold or attack, reserves reinforce, garrisons hold."
        }
        return "Use front deployment: line units hold or attack, reserves reinforce, garrisons hold."
    }

    private func deploymentSupplyReason(for division: DivisionSummary, context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: formation supply is \(division.supplyState.rawValue), recover before renewed contact."
        }
        return "Deployment: unit supply is \(division.supplyState.rawValue), recover before front action."
    }

    private func contactAttackReason(segment: AgentFrontSegmentSnapshot, context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: contact formation acts on sector \(segment.regionId.rawValue)."
        }
        return "Deployment: line unit acts on segment \(segment.regionId.rawValue)."
    }

    private func contactHoldReason(segment: AgentFrontSegmentSnapshot, context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: contact formation holds assigned sector \(segment.regionId.rawValue)."
        }
        return "Deployment: line unit holds assigned segment \(segment.regionId.rawValue)."
    }

    private func reserveReinforceReason(context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: reserve formation reinforces the nearest contact sector."
        }
        return "Deployment: reserve reinforces the nearest line segment."
    }

    private func reserveHoldReason(context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: reserve formation has no adjacent safe contact sector."
        }
        return "Deployment: reserve has no adjacent safe line target."
    }

    private func garrisonHoldReason(context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: garrison formation holds its core or town sector."
        }
        return "Deployment: garrison unit does not leave its core or city region."
    }

    private func unassignedHoldReason(context: AgentContext) -> String {
        if context.faction.usesNapoleonicLogisticsVocabulary {
            return "Deployment: formation outside the current corps assignment holds."
        }
        return "Deployment: unit outside the current deployment pool holds."
    }

    private func frontAttackTarget(
        for division: DivisionSummary,
        segment: AgentFrontSegmentSnapshot,
        context: AgentContext
    ) -> DivisionSummary? {
        context.enemyDivisions
            .filter { target in
                guard let targetRegion = target.regionId,
                      context.visibleRegions.first(where: { $0.id == segment.regionId })?.neighbors.contains(targetRegion) == true else {
                    return false
                }
                return division.coord.distance(to: target.coord) <= division.range
            }
            .sorted { $0.strength < $1.strength }
            .first
    }

    private func reinforcementTarget(
        for division: DivisionSummary,
        context: AgentContext
    ) -> RegionId? {
        guard let currentRegion = division.regionId else { return nil }
        let visibleById = Dictionary(uniqueKeysWithValues: context.visibleRegions.map { ($0.id, $0) })
        let frontRegions = context.frontZones
            .flatMap { $0.frontSegments.map(\.regionId) }
            .filter { regionId in
                visibleById[currentRegion]?.neighbors.contains(regionId) == true
            }
            .sorted { $0.rawValue < $1.rawValue }
        return frontRegions.first
    }

    private func orderPriority(_ lhs: DivisionSummary, _ rhs: DivisionSummary) -> Bool {
        if lhs.isArtillery != rhs.isArtillery {
            return !lhs.isArtillery
        }
        if lhs.isArmor != rhs.isArmor {
            return lhs.isArmor
        }
        return lhs.id < rhs.id
    }

    private func bestAttackTarget(
        for division: DivisionSummary,
        context: AgentContext
    ) -> DivisionSummary? {
        context.enemyDivisions
            .filter { canAttack(attacker: division, target: $0, context: context) }
            .sorted { lhs, rhs in
                let lhsScore = attackScore(attacker: division, target: lhs, context: context)
                let rhsScore = attackScore(attacker: division, target: rhs, context: context)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.strength < rhs.strength
            }
            .first
    }

    private func attackScore(
        attacker: DivisionSummary,
        target: DivisionSummary,
        context: AgentContext
    ) -> Int {
        let targetTile = context.visibleTiles.first { $0.coord == target.coord }
        let objectiveTileBonus = isObjectiveLikeTile(targetTile) ? 20 : 0
        let lowHPBonus = max(0, 12 - target.strength)
        let distanceBonus = max(0, 4 - attacker.coord.distance(to: target.coord))
        let artilleryBonus = attacker.isArtillery ? objectiveTileBonus : 0
        return lowHPBonus + distanceBonus + artilleryBonus
    }

    private func isObjectiveLikeTile(_ tile: HexTileSummary?) -> Bool {
        guard let tile else {
            return false
        }
        return tile.baseTerrain == .city ||
            tile.baseTerrain == .fortress ||
            tile.cityName != nil ||
            tile.fortressName != nil
    }

    private func canAttack(
        attacker: DivisionSummary,
        target: DivisionSummary,
        context: AgentContext
    ) -> Bool {
        if let attackerRegion = attacker.regionId,
           let targetRegion = target.regionId,
           !context.visibleRegions.isEmpty {
            return RegionGraph(
                regions: Dictionary(uniqueKeysWithValues: context.visibleRegions.map {
                    ($0.id, RegionNode(
                        id: $0.id,
                        name: $0.name,
                        owner: $0.controller,
                        controller: $0.controller,
                        terrain: $0.terrain,
                        neighbors: $0.neighbors,
                        displayHexes: [attacker.coord],
                        representativeHex: attacker.coord,
                        city: $0.cityName.map { CityInfo(name: $0) },
                        supplyValue: $0.supplyValue
                    ))
                }),
                edges: []
            ).distance(from: attackerRegion, to: targetRegion).map { $0 <= attacker.range } ?? false
        }

        return attacker.coord.distance(to: target.coord) <= attacker.range
    }

    private func attackReason(
        attacker: DivisionSummary,
        target: DivisionSummary,
        context: AgentContext
    ) -> String {
        let targetTile = context.visibleTiles.first { $0.coord == target.coord }
        if attacker.isArtillery,
           targetTile?.baseTerrain == .city || targetTile?.baseTerrain == .fortress {
            return "Artillery fires on defender in a city or fortress hex."
        }
        return "Target is within range and vulnerable enough for a local attack."
    }

    private func bestMoveDestination(
        for division: DivisionSummary,
        toward objectiveRegion: RegionId,
        context: AgentContext,
        reservedDestinations: Set<RegionId>
    ) -> RegionId? {
        guard let currentRegion = division.regionId else {
            return nil
        }
        let snapshotById = Dictionary(uniqueKeysWithValues: context.visibleRegions.map { ($0.id, $0) })
        let graph = RegionGraph(
            regions: Dictionary(uniqueKeysWithValues: context.visibleRegions.map {
                ($0.id, RegionNode(
                    id: $0.id,
                    name: $0.name,
                    owner: $0.controller,
                    controller: $0.controller,
                    terrain: $0.terrain,
                    neighbors: $0.neighbors,
                    displayHexes: [division.coord],
                    representativeHex: division.coord,
                    city: $0.cityName.map { CityInfo(name: $0) },
                    supplyValue: $0.supplyValue
                ))
            }),
            edges: []
        )
        let currentDistance = graph.distance(from: currentRegion, to: objectiveRegion) ?? Int.max

        return graph.neighbors(of: currentRegion)
            .compactMap { regionId -> RegionSnapshot? in
                guard let snapshot = snapshotById[regionId],
                      snapshot.visible,
                      !reservedDestinations.contains(regionId),
                      (graph.distance(from: regionId, to: objectiveRegion) ?? Int.max) <= currentDistance else {
                    return nil
                }
                return snapshot
            }
            .sorted { lhs, rhs in
                let lhsDistance = graph.distance(from: lhs.id, to: objectiveRegion) ?? Int.max
                let rhsDistance = graph.distance(from: rhs.id, to: objectiveRegion) ?? Int.max
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return terrainMoveCost(lhs.terrain) < terrainMoveCost(rhs.terrain)
            }
            .first?
            .id
    }

    private func terrainMoveCost(_ terrain: BaseTerrain) -> Int {
        terrain.movementCost
    }
}
