import Foundation

struct StrategicStateSyncResult: Equatable {
    let affectedRegionIds: [RegionId]
    let changedRegionIds: [RegionId]
    let updatedFrontLineRegionIds: Set<RegionId>
}

struct StrategicStateSynchronizer {
    @discardableResult
    func synchronizeAfterOccupationChange(
        in state: inout GameState,
        affectedRegionIds: [RegionId],
        turn: Int? = nil,
        relatedRecordId: String? = nil,
        emitRegionOwnerEvents: Bool = true
    ) -> StrategicStateSyncResult {
        let changedRegionIds = RegionOccupationRules().aggregateControl(in: &state)
        let affected = stableUnique(affectedRegionIds + changedRegionIds)
        guard !affected.isEmpty else {
            return StrategicStateSyncResult(
                affectedRegionIds: [],
                changedRegionIds: [],
                updatedFrontLineRegionIds: []
            )
        }

        let syncTurn = turn ?? state.turn
        state.theaterState = TheaterSystem().updateTheaters(
            state: state.theaterState,
            map: state.map,
            divisions: state.divisions,
            diplomacyState: state.diplomacyState,
            turn: syncTurn,
            force: true
        )

        let frontEvents = affected.map { regionId in
            changedRegionIds.contains(regionId)
                ? FrontLineEvent.regionControllerChanged(regionId)
                : FrontLineEvent.occupationChanged(regionId)
        }
        state.frontLineState = FrontLineManager().update(
            state: state.frontLineState,
            map: state.map,
            theaterState: state.theaterState,
            divisions: state.divisions,
            diplomacyState: state.diplomacyState,
            turn: syncTurn,
            events: frontEvents
        )

        let deploymentEvents = affected.map(WarDeploymentEvent.regionControllerChanged)
        state.warDeploymentState = WarDeploymentManager().update(
            state: state.warDeploymentState,
            map: state.map,
            divisions: state.divisions,
            diplomacyState: state.diplomacyState,
            turn: syncTurn,
            events: deploymentEvents
        )

        if emitRegionOwnerEvents {
            for regionId in changedRegionIds {
                guard let region = state.map.region(id: regionId) else { continue }
                state.appendEvent(
                    regionControllerChangedMessage(regionId: regionId, controller: region.controller, state: state),
                    category: .regionOwnerChange,
                    relatedRecordId: relatedRecordId
                )
            }
        }

        return StrategicStateSyncResult(
            affectedRegionIds: affected,
            changedRegionIds: changedRegionIds,
            updatedFrontLineRegionIds: state.frontLineState.diagnostics.updatedRegionIds.reduce(into: Set<RegionId>()) {
                $0.insert($1)
            }
        )
    }

    private func stableUnique(_ values: [RegionId]) -> [RegionId] {
        var seen: Set<RegionId> = []
        var result: [RegionId] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result.sorted { $0.rawValue < $1.rawValue }
    }

    private func regionControllerChangedMessage(
        regionId: RegionId,
        controller: Faction,
        state: GameState
    ) -> String {
        if state.activeFaction.usesNapoleonicLogisticsVocabulary {
            let sectorName: String
            if let name = state.map.region(id: regionId)?.name,
               !name.isEmpty {
                sectorName = name
            } else {
                sectorName = identifierDisplayText(regionId.rawValue, fallback: "sector", suffix: " sector")
            }
            return "Sector \(sectorName) control changed to \(controller.displayName)."
        }

        return "Region \(regionId.rawValue) controller changed to \(controller.displayName)."
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
}
