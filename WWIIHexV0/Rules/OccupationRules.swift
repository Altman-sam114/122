import Foundation

struct OccupationRules {
    func canOccupy(
        division: Division,
        destination: HexCoord,
        in state: GameState
    ) -> Bool {
        guard let tile = state.map.tile(at: destination),
              tile.isCapturable else {
            return false
        }
        if let controller = tile.controller,
           controller == division.faction || state.diplomacyState.isFriendly(division.faction, to: controller) {
            return false
        }

        if let occupying = state.division(at: destination),
           occupying.id != division.id {
            return false
        }

        return true
    }
}
