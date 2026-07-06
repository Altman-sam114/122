import Foundation

struct RuleEngine {
    private let validator = CommandValidator()
    private let executor = CommandExecutor()

    func execute(_ command: Command, in state: GameState) -> CommandResult {
        let preparedState = EconomyRules().bootstrapIfNeeded(state)
        let validation = validator.validate(command, in: preparedState)
        guard validation.isValid else {
            let errorMessage = validation.errors
                .map { $0.displayName(for: preparedState.activeFaction) }
                .joined(separator: ", ")
            let prefix = preparedState.activeFaction.usesNapoleonicLogisticsVocabulary ? "Order rejected" : "Command rejected"
            return CommandResult(
                command: command,
                validation: validation,
                state: preparedState,
                message: "\(prefix): \(errorMessage)."
            )
        }

        let nextState = executor.execute(command, in: preparedState)
        let prefix = preparedState.activeFaction.usesNapoleonicLogisticsVocabulary ? "Order executed" : "Command executed"
        return CommandResult(
            command: command,
            validation: validation,
            state: nextState,
            message: "\(prefix): \(command.displayName(for: preparedState.activeFaction))."
        )
    }

    func apply(_ command: Command, to state: GameState) -> GameState {
        execute(command, in: state).state
    }
}
