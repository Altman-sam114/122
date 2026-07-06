import Foundation

// AI turn orchestrator only; rules still execute through RuleEngine.
// Default path is Ruler/Marshal -> ZoneDirective -> WarCommandExecutor -> RuleEngine.
// Legacy Agent D parser/mapper flow is kept only for explicit legacy mode.

struct AgentTurnOutcome: Equatable {
    let state: GameState
    let record: AgentDecisionRecord
    let directiveRecords: [WarDirectiveRecord]

    init(
        state: GameState,
        record: AgentDecisionRecord,
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.state = state
        self.record = record
        self.directiveRecords = directiveRecords
    }
}

struct TurnManager {
    let agent: GameAgent
    let provider: DecisionProvider
    let providerName: String
    let commandHandler: GameCommandHandling
    let contextBuilder: AgentContextBuilder
    let parser: AgentDecisionParser
    let mapper: AgentCommandMapper
    let commanderPool: TheaterCommanderPool?
    let marshalAgent: MarshalAgent?
    let warCommandExecutor: WarCommandExecutor

    init(
        agent: GameAgent,
        provider: DecisionProvider,
        providerName: String,
        commandHandler: GameCommandHandling,
        contextBuilder: AgentContextBuilder = AgentContextBuilder(),
        parser: AgentDecisionParser = AgentDecisionParser(),
        mapper: AgentCommandMapper = AgentCommandMapper(),
        commanderPool: TheaterCommanderPool? = nil,
        marshalAgent: MarshalAgent? = nil,
        warCommandExecutor: WarCommandExecutor? = nil
    ) {
        self.agent = agent
        self.provider = provider
        self.providerName = providerName
        self.commandHandler = commandHandler
        self.contextBuilder = contextBuilder
        self.parser = parser
        self.mapper = mapper
        self.commanderPool = commanderPool
        self.marshalAgent = marshalAgent
        self.warCommandExecutor = warCommandExecutor ?? WarCommandExecutor(commandHandler: commandHandler)
    }

    func runGermanAITurn(
        state: GameState,
        pipelineMode: WarPipelineMode = .marshalDirective
    ) async -> AgentTurnOutcome {
        await runAITurn(state: state, faction: .germany, pipelineMode: pipelineMode)
    }

    func runAITurn(
        state: GameState,
        faction: Faction,
        pipelineMode: WarPipelineMode = .marshalDirective
    ) async -> AgentTurnOutcome {
        let context = contextBuilder.agentContext(for: agent, state: state, playerDirective: nil)
        let contextSummary = Self.contextSummary(context, agentName: agent.name)

        guard agent.faction == faction else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["Staff dispatch requested for \(faction.displayName), but the assigned staff belongs to \(agent.faction.displayName)."]
                )
            )
        }

        guard isAITurn(faction: faction, state: state) else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["\(faction.displayName) staff dispatch requested outside its command phase."]
                )
            )
        }

        switch pipelineMode {
        case .marshalDirective:
            return runMarshalDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
        case .zoneDirective:
            return runDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
        case .legacyAgentOrder:
            return await runLegacyAgentOrderTurn(state: state, context: context, contextSummary: contextSummary)
        }
    }

    private func runLegacyAgentOrderTurn(
        state: GameState,
        context: AgentContext,
        contextSummary: String
    ) async -> AgentTurnOutcome {
        do {
            let envelope = try await provider.decide(context: context)
            let rawJSON = try Self.canonicalJSON(envelope)
            let parsedDecision = try parser.parse(rawJSON, expectedAgentId: agent.id, expectedTurn: state.turn)
            var nextState = state
            var commandResults: [CommandResultSummary] = []
            var errors: [String] = parsedDecision.orders.isEmpty ? ["Staff returned no field orders."] : []

            for (index, order) in parsedDecision.orders.enumerated() {
                do {
                    let issuedCommand = try mapper.map(order, agentId: parsedDecision.agentId, state: nextState)
                    let result = commandHandler.execute(issuedCommand.command, in: nextState)
                    nextState = result.state
                    commandResults.append(
                        .mapped(
                            orderIndex: index,
                            order: order,
                            command: issuedCommand.command,
                            result: result,
                            faction: agent.faction
                        )
                    )

                    if !result.succeeded {
                        errors.append("Order \(index) rejected: \(result.validation.errors.map(\.rawValue).joined(separator: ", ")).")
                    }
                } catch {
                    errors.append("Order \(index) mapping failed: \(error.localizedDescription)")
                    commandResults.append(.mappingFailed(orderIndex: index, order: order, error: error))
                }
            }

            let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
            nextState = endTurnResult.state
            commandResults.append(.endTurn(result: endTurnResult, faction: agent.faction))
            if !endTurnResult.succeeded {
                errors.append("End Orders failed: \(validationSummary(endTurnResult.validation.errors, faction: agent.faction)).")
            }

            let record = AgentDecisionRecord(
                id: "agent_\(agent.id)_turn_\(state.turn)",
                turn: state.turn,
                agentId: agent.id,
                provider: providerName,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedDecision.intent,
                commandResults: commandResults,
                errors: errors
            )
            return AgentTurnOutcome(state: nextState, record: record)
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: [error.localizedDescription]
                )
            )
        }
    }

    private func runDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let envelope = makeZoneDirectiveEnvelope(state: state, faction: faction, issuerId: agent.id)
            let rawJSON = try Self.canonicalDirectiveJSON(envelope)
            return executeDirectiveEnvelope(
                envelope,
                state: state,
                faction: faction,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: "zone directives",
                providerSuffix: "Directive",
                additionalDiagnostics: diagnostics
            )
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: [error.localizedDescription]
                )
            )
        }
    }

    private func runMarshalDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let ruler = RulerAgent.automatic(for: faction, in: state)
            let postureResolution = ruler.resolvePosture(in: state)
            var strategicState = state
            strategicState.diplomacyState.appendRulerRecord(postureResolution.record)

            let fallbackPool = commanderPool ?? TheaterCommanderPool.automatic(for: state)
            let marshal = marshalAgent ?? MarshalAgent(
                config: MarshalAgentConfig.automatic(for: faction, state: state)
            )
            let resolution = marshal.resolve(
                for: faction,
                in: strategicState,
                fallbackPool: fallbackPool,
                issuerId: agent.id,
                strategicPosture: postureResolution.envelope
            )
            let compiledJSON = try Self.canonicalDirectiveJSON(resolution.directiveEnvelope)
            let postureJSON = postureResolution.rawStrategicJSON.map {
                "StrategicPosture JSON:\n\($0)"
            }
            let theaterJSON = resolution.rawTheaterJSON.map {
                "TheaterDirective JSON:\n\($0)"
            }
            let rawJSON = ([postureJSON, theaterJSON].compactMap { $0 } + ["Compiled ZoneDirective JSON:\n\(compiledJSON)"])
                .joined(separator: "\n\n")

            return executeDirectiveEnvelope(
                resolution.directiveEnvelope,
                state: strategicState,
                faction: faction,
                contextSummary: "\(contextSummary) Strategic posture: \(postureResolution.envelope.posture.displayName).",
                rawJSON: rawJSON,
                parsedIntent: resolution.theaterEnvelope?.strategicIntent ?? postureResolution.envelope.strategicIntent,
                providerSuffix: "MarshalDirective",
                additionalDiagnostics: diagnostics + postureResolution.diagnostics + resolution.diagnostics
            )
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: [error.localizedDescription]
                )
            )
        }
    }

    private func makeZoneDirectiveEnvelope(
        state: GameState,
        faction: Faction,
        issuerId: String
    ) -> DirectiveEnvelope {
        if state.warDeploymentState.frontZones.isEmpty {
            return DirectiveEnvelope(issuerId: issuerId, turn: state.turn, directives: [])
        }
        if let commanderPool {
            return commanderPool.envelope(for: faction, in: state, issuerId: issuerId)
        }
        return TheaterCommanderPool.automatic(for: state).envelope(for: faction, in: state, issuerId: issuerId)
    }

    private func executeDirectiveEnvelope(
        _ envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        contextSummary: String,
        rawJSON: String,
        parsedIntent: String,
        providerSuffix: String,
        additionalDiagnostics: [String]
    ) -> AgentTurnOutcome {
        var nextState = state
        var commandResults: [CommandResultSummary] = []
        var directiveRecords: [WarDirectiveRecord] = []
        var errors = additionalDiagnostics
        if envelope.directives.isEmpty {
            errors.append("Command staff returned no corps orders.")
        }

        for (directiveIndex, directive) in envelope.directives.enumerated() {
            let execution = warCommandExecutor.execute(directive, in: nextState)
            nextState = execution.finalState
            var perDirectiveResults: [CommandResultSummary] = []
            var perDirectiveDiagnostics: [String] = []

            if execution.generatedCommands.isEmpty {
                let diagnostic = "Corps directive \(directiveIndex) produced no field orders."
                errors.append(diagnostic)
                perDirectiveDiagnostics.append(diagnostic)
            }

            for (commandIndex, pair) in zip(execution.generatedCommands, execution.commandResults).enumerated() {
                let summary = CommandResultSummary.directiveCommand(
                    directiveIndex: directiveIndex,
                    commandIndex: commandIndex,
                    directive: directive,
                    command: pair.0,
                    result: pair.1,
                    faction: faction
                )
                commandResults.append(summary)
                perDirectiveResults.append(summary)
                if !pair.1.succeeded {
                    let diagnostic = "Corps directive \(directiveIndex) order \(commandIndex) refused: \(validationSummary(pair.1.validation.errors, faction: faction))."
                    errors.append(diagnostic)
                    perDirectiveDiagnostics.append(diagnostic)
                }
            }

            let record = WarDirectiveRecord(
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_\(directiveIndex)",
                issuerId: envelope.issuerId,
                turn: state.turn,
                faction: faction,
                zoneId: directive.zoneId,
                directiveType: directive.type,
                targetRegionIds: directive.targetRegionIds,
                commandResults: perDirectiveResults,
                diagnostics: perDirectiveDiagnostics,
                category: directive.category,
                tactic: directive.tactic,
                commanderAgentId: envelope.commanderAgentId,
                commandTarget: directive.commandTarget
            )
            nextState.warDirectiveRecords.append(record)
            directiveRecords.append(record)
        }

        let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
        nextState = endTurnResult.state
        commandResults.append(.endTurn(result: endTurnResult, faction: faction))
        var endTurnDiagnostics: [String] = []
        if !endTurnResult.succeeded {
            let diagnostic = "End Orders failed: \(validationSummary(endTurnResult.validation.errors, faction: faction))."
            errors.append(diagnostic)
            endTurnDiagnostics.append(diagnostic)
        }

        if envelope.directives.isEmpty || !additionalDiagnostics.isEmpty || !endTurnDiagnostics.isEmpty {
            let record = WarDirectiveRecord(
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_diagnostic",
                issuerId: envelope.issuerId,
                turn: state.turn,
                faction: faction,
                zoneId: nil,
                directiveType: nil,
                commandResults: [],
                diagnostics: errors,
                commanderAgentId: envelope.commanderAgentId
            )
            nextState.warDirectiveRecords.append(record)
            directiveRecords.append(record)
        }

        return AgentTurnOutcome(
            state: nextState,
            record: AgentDecisionRecord(
                id: "agent_\(envelope.issuerId)_turn_\(state.turn)_directives",
                turn: state.turn,
                agentId: envelope.issuerId,
                provider: "\(providerName)+\(providerSuffix)",
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedIntent,
                commandResults: commandResults,
                errors: errors
            ),
            directiveRecords: directiveRecords
        )
    }

    private func isAITurn(faction: Faction, state: GameState) -> Bool {
        state.activeFaction == faction &&
            state.phase.allowsCommands &&
            !faction.isNeutral
    }

    private func directiveDiagnostics(for faction: Faction, state: GameState) -> [String] {
        var diagnostics: [String] = []
        if state.warDeploymentState.frontZones.isEmpty {
            diagnostics.append("Staff dispatch unavailable: corps sectors are missing.")
        }

        for division in state.divisions where division.faction == faction && !division.isDestroyed {
            guard let regionId = division.location(in: state.map),
                  state.warDeploymentState.regionToFrontZone[regionId] != nil else {
                diagnostics.append("Formation \(division.name) is not assigned to any corps sector; no staff order was issued.")
                continue
            }
        }

        return diagnostics
    }

    private func validationSummary(_ errors: [CommandValidationError], faction: Faction) -> String {
        errors.map { $0.displayName(for: faction) }.joined(separator: ", ")
    }

    private func failureRecord(
        state: GameState,
        contextSummary: String,
        rawJSON: String?,
        parsedIntent: String?,
        errors: [String]
    ) -> AgentDecisionRecord {
        AgentDecisionRecord(
            id: "agent_\(agent.id)_turn_\(state.turn)_failed",
            turn: state.turn,
            agentId: agent.id,
            provider: providerName,
            contextSummary: contextSummary,
            rawJSON: rawJSON,
            parsedIntent: parsedIntent,
            commandResults: [],
            errors: errors
        )
    }

    static func contextSummary(_ context: AgentContext, agentName: String? = nil) -> String {
        let displayName = agentName?.isEmpty == false ? agentName! : context.agentId
        return "\(displayName) turn \(context.turn): \(context.friendlyDivisions.count) friendly formations, \(context.enemyDivisions.count) known enemy formations, \(context.objectives.count) objectives visible."
    }

    static func canonicalJSON(_ envelope: AgentDecisionEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }

    static func canonicalDirectiveJSON(_ envelope: DirectiveEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }
}
