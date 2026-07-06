import Foundation

extension GameAgent {
    @available(*, deprecated, message: "Legacy Ardennes/Guderian helper. Use legacyGuderian(from:state:) only behind an Ardennes scenario guard.")
    static func guderian(from loader: DataLoader, state: GameState) -> GameAgent {
        legacyGuderian(from: loader, state: state)
    }

    static func legacyGuderian(from loader: DataLoader, state: GameState) -> GameAgent {
        if let definition = try? loader.loadGeneralAgents().first(where: { $0.id == "guderian" }),
           let agent = GameAgent(definition: definition) {
            return agent
        }

        return legacyGuderianFallback(
            assignedDivisionIds: state.divisions
                .filter { $0.faction == .germany }
                .map(\.id)
                .sorted()
        )
    }

    init?(definition: GeneralAgentDefinition) {
        guard let faction = Faction(rawValue: definition.faction),
              let role = AgentRole(rawValue: definition.role) else {
            return nil
        }

        self.init(
            id: definition.id,
            name: definition.name,
            faction: faction,
            role: role,
            personality: AgentPersonality(
                prompt: definition.personalityPrompt,
                traits: [definition.commandStyle],
                aggression: definition.commandStyle == "breakthrough" ? 80 : 50,
                riskTolerance: definition.commandStyle == "breakthrough" ? 75 : 50,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: definition.assignedDivisionIds
        )
    }

    @available(*, deprecated, message: "Legacy Ardennes/Guderian fallback. Use legacyGuderianFallback only in legacy tests or Ardennes compatibility code.")
    static func guderianFallback(assignedDivisionIds: [String]) -> GameAgent {
        legacyGuderianFallback(assignedDivisionIds: assignedDivisionIds)
    }

    static func legacyGuderianFallback(assignedDivisionIds: [String]) -> GameAgent {
        GameAgent(
            id: "guderian",
            name: "Heinz Guderian",
            faction: .germany,
            role: .armyCommander,
            personality: AgentPersonality(
                prompt: "Prioritize armored breakthrough, road movement, concentration of force, and rapid encirclement.",
                traits: ["breakthrough"],
                aggression: 80,
                riskTolerance: 75,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds.isEmpty
                ? ["ger_panzer_1", "ger_motorized_1", "ger_infantry_1", "ger_artillery_1"]
                : assignedDivisionIds
        )
    }
}
