import Combine
import Foundation

final class AppContainer: ObservableObject {
    @Published private(set) var gameState: GameState
    @Published private(set) var selectedUnitId: String?
    @Published private(set) var selectedHex: HexCoord?
    @Published private(set) var selectedRegionId: RegionId?
    @Published private(set) var movementHighlights: Set<HexCoord>
    @Published private(set) var attackHighlights: Set<HexCoord>
    @Published private(set) var interactionLog: [GameLogEntry]
    @Published private(set) var lastCommandMessage: String?
    @Published private(set) var lastAgentDecisionRecord: AgentDecisionRecord?
    @Published private(set) var lastWarDirectiveRecords: [WarDirectiveRecord]
    @Published private(set) var observerModeEnabled: Bool
    @Published private(set) var mapDisplayLayer: MapDisplayLayer
    @Published private(set) var currentScenario: ScenarioCatalogEntry
    @Published private(set) var generalRegistry: GeneralRegistry
    @Published private(set) var playerFaction: Faction
    @Published private(set) var startsNewGameAtPlayerFaction: Bool
    @Published private(set) var selectedSaveSlot: GameSaveSlot
    @Published private(set) var savedGameSummaries: [GameSaveSlot: GameSaveSnapshot.Summary]
    @Published private(set) var savedGameRecoveryMessages: [GameSaveSlot: String]
    @Published private(set) var savedGameSummary: GameSaveSnapshot.Summary?
    @Published private(set) var savedGameRecoveryMessage: String?
    @Published private(set) var saveSlotLabels: [GameSaveSlot: String]
    @Published private(set) var replayDetailLevel: ReplayDetailLevel
    @Published private(set) var aiCommandPace: AICommandPace
    @Published private(set) var aiControlMode: PlaytestAIControlMode
    @Published private(set) var playtestGuideCuesEnabled: Bool
    @Published private(set) var playtestTextSize: PlaytestTextSize
    @Published private(set) var reduceMotionEnabled: Bool
    @Published private(set) var sessionSettingsRecoveryMessage: String?

    let commandHandler: GameCommandHandling
    let dataLoader: DataLoader
    let warPipelineMode: WarPipelineMode
    let turnManager: TurnManager?
    private var isRunningAI = false
    private var deliveredPlaytestCues: Set<PlaytestGuideCue>

    init(
        gameState: GameState,
        commandHandler: GameCommandHandling,
        dataLoader: DataLoader,
        scenario: ScenarioCatalogEntry = ScenarioCatalog.defaultPlayable,
        generalRegistry: GeneralRegistry = .empty,
        playerFaction: Faction = ScenarioCatalog.defaultPlayable.defaultPlayerFaction,
        startsNewGameAtPlayerFaction: Bool = true,
        selectedSaveSlot: GameSaveSlot = .standard,
        turnManager: TurnManager? = nil,
        warPipelineMode: WarPipelineMode = .marshalDirective,
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex,
        replayDetailLevel: ReplayDetailLevel = .standard,
        aiCommandPace: AICommandPace = .balanced,
        aiControlMode: PlaytestAIControlMode = .simulatedStaff,
        playtestGuideCuesEnabled: Bool = true,
        playtestTextSize: PlaytestTextSize = .standard,
        reduceMotionEnabled: Bool = false,
        sessionSettingsRecoveryMessage: String? = nil,
        startupRecoveryMessage: String? = nil
    ) {
        let savedGameSlotStatuses = Self.loadSavedGameSlotSummaryStatuses()
        let saveSlotLabels = GameSaveSlot.loadLabels()
        let bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        self.gameState = Self.refreshGeneralAssignments(in: bootstrappedState, registry: generalRegistry)
        self.commandHandler = commandHandler
        self.dataLoader = dataLoader
        self.currentScenario = scenario
        self.generalRegistry = generalRegistry
        self.playerFaction = playerFaction
        self.startsNewGameAtPlayerFaction = startsNewGameAtPlayerFaction
        self.selectedSaveSlot = selectedSaveSlot
        self.savedGameSummaries = savedGameSlotStatuses.summaries
        self.savedGameRecoveryMessages = savedGameSlotStatuses.recoveryMessages
        self.savedGameSummary = savedGameSlotStatuses.summaries[selectedSaveSlot]
        self.savedGameRecoveryMessage = savedGameSlotStatuses.recoveryMessages[selectedSaveSlot]
        self.saveSlotLabels = saveSlotLabels
        self.warPipelineMode = warPipelineMode
        self.turnManager = turnManager
        self.selectedUnitId = nil
        self.selectedHex = nil
        self.selectedRegionId = nil
        self.movementHighlights = []
        self.attackHighlights = []
        self.interactionLog = []
        self.lastCommandMessage = nil
        self.lastAgentDecisionRecord = nil
        self.lastWarDirectiveRecords = []
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
        self.replayDetailLevel = replayDetailLevel
        self.aiCommandPace = aiCommandPace
        self.aiControlMode = aiControlMode
        self.playtestGuideCuesEnabled = playtestGuideCuesEnabled
        self.playtestTextSize = playtestTextSize
        self.reduceMotionEnabled = reduceMotionEnabled
        self.sessionSettingsRecoveryMessage = sessionSettingsRecoveryMessage
        self.deliveredPlaytestCues = []
        self.gameState = normalizeCommandPhase(self.gameState)
        if let recoveryMessage = savedGameRecoveryMessage {
            lastCommandMessage = recoveryMessage
            appendInteractionEvent("Saved campaign unavailable: \(recoveryMessage)")
        }
        if let startupRecoveryMessage {
            lastCommandMessage = startupRecoveryMessage
            appendInteractionEvent(startupRecoveryMessage)
        }
        if let sessionSettingsRecoveryMessage {
            lastCommandMessage = sessionSettingsRecoveryMessage
            appendInteractionEvent(sessionSettingsRecoveryMessage)
        }
    }

    static func bootstrap() -> AppContainer {
        let dataLoader = DataLoader()
        let startup = loadStartupGame(dataLoader: dataLoader)
        let commandHandler = RuleEngine()
        let registryLoad = loadGeneralRegistry(
            dataLoader: dataLoader,
            scenario: startup.scenario,
            operation: "Startup"
        )
        let generalRegistry = registryLoad.registry
        let bootstrappedState = Self.refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(startup.state),
            registry: generalRegistry
        )
        let sessionSettingsResult = PlaytestSessionSettings.loadResult()
        let sessionSettings = sessionSettingsResult.settings
        let startupRecoveryMessage = [startup.recoveryMessage, registryLoad.recoveryMessage]
            .compactMap { $0 }
            .joined(separator: " ")
        return AppContainer(
            gameState: bootstrappedState,
            commandHandler: commandHandler,
            dataLoader: dataLoader,
            scenario: startup.scenario,
            generalRegistry: generalRegistry,
            playerFaction: startup.playerFaction,
            warPipelineMode: .marshalDirective,
            observerModeEnabled: sessionSettings.observerModeEnabled,
            mapDisplayLayer: sessionSettings.mapDisplayLayer,
            replayDetailLevel: sessionSettings.replayDetailLevel,
            aiCommandPace: sessionSettings.aiCommandPace,
            aiControlMode: sessionSettings.aiControlMode,
            playtestGuideCuesEnabled: sessionSettings.playtestGuideCuesEnabled,
            playtestTextSize: sessionSettings.playtestTextSize,
            reduceMotionEnabled: sessionSettings.reduceMotionEnabled,
            sessionSettingsRecoveryMessage: sessionSettingsResult.recoveryMessage,
            startupRecoveryMessage: startupRecoveryMessage.isEmpty ? nil : startupRecoveryMessage
        )
    }

    private static func loadGeneralRegistry(
        dataLoader: DataLoader,
        scenario: ScenarioCatalogEntry,
        operation: String
    ) -> (registry: GeneralRegistry, recoveryMessage: String?) {
        do {
            return (try dataLoader.loadGeneralRegistry(scenario), nil)
        } catch {
            let message = "\(operation) commander catalog \(scenario.generalCatalogName).json failed to load. Campaign continues without assigned commanders. \(error.localizedDescription)"
            return (.empty, message)
        }
    }

    private static func loadStartupGame(
        dataLoader: DataLoader
    ) -> (state: GameState, scenario: ScenarioCatalogEntry, playerFaction: Faction, recoveryMessage: String?) {
        let defaultScenario = ScenarioCatalog.defaultPlayable
        do {
            let state = try dataLoader.loadGameState(defaultScenario)
            return (state, defaultScenario, defaultScenario.defaultPlayerFaction, nil)
        } catch {
            let recoveryMessage = "Default scenario \(defaultScenario.displayName) failed to load. Open New Campaign to choose a playable scenario. \(error.localizedDescription)"
            return (
                recoveryState(for: defaultScenario, errorMessage: recoveryMessage),
                defaultScenario,
                defaultScenario.defaultPlayerFaction,
                recoveryMessage
            )
        }
    }

    private static func recoveryState(
        for scenario: ScenarioCatalogEntry,
        errorMessage: String
    ) -> GameState {
        GameState(
            scenarioId: scenario.id,
            turn: 1,
            maxTurns: 1,
            activeFaction: scenario.defaultPlayerFaction,
            phase: GamePhase.legacyCompatibleCommandPhase(for: scenario.defaultPlayerFaction),
            map: recoveryMap(),
            terrainRules: .legacy,
            theaterState: .empty,
            frontLineState: .empty,
            warDeploymentState: .empty,
            economyState: .empty,
            reinforcementState: .empty,
            diplomacyState: DiplomacyState.initial(for: [scenario.defaultPlayerFaction], turn: 1),
            divisions: [],
            victoryConditions: [],
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: [
                GameLogEntry(
                    turn: 1,
                    faction: scenario.defaultPlayerFaction,
                    phase: GamePhase.legacyCompatibleCommandPhase(for: scenario.defaultPlayerFaction),
                    message: errorMessage
                )
            ],
            warDirectiveRecords: [],
            playerCommandState: .empty
        )
    }

    private static func recoveryMap() -> MapState {
        let coord = HexCoord(q: 0, r: 0)
        return MapState(
            width: 1,
            height: 1,
            tiles: [
                coord: HexTile(
                    coord: coord,
                    baseTerrain: .plain,
                    controller: nil,
                    isPassable: false
                )
            ],
            supplySources: [],
            objectives: []
        )
    }

    func submit(_ command: Command) {
        guard !observerModeEnabled else {
            let message = observerCommandRejectedMessage(for: command)
            lastCommandMessage = message
            appendInteractionEvent(message)
            return
        }

        let stateBeforeCommand = gameState
        let result = commandHandler.execute(command, in: gameState)
        var nextState = StrategicStateBootstrapper().bootstrapIfNeeded(result.state)
        if result.succeeded {
            nextState = applyPlayerCommandBookkeeping(
                command,
                to: nextState,
                previousState: stateBeforeCommand
            )
        }
        gameState = refreshGeneralAssignments(in: nextState)
        lastCommandMessage = result.message

        let status = result.succeeded ? "accepted" : "rejected"
        appendInteractionEvent(commandInteractionMessage(status: status, command: command, resultMessage: result.message))
        refreshSelectionAfterStateChange()
        runAIIfNeeded()
    }

    func runAIIfNeeded() {
        guard !isRunningAI else {
            return
        }

        gameState = refreshedRuntimeState(gameState)
        guard shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) else {
            return
        }

        isRunningAI = true
        let stateSnapshot = gameState
        let pipelineMode = warPipelineMode
        let observerEnabled = observerModeEnabled
        let commandPace = aiCommandPace
        let controlMode = aiControlMode
        let controlledFaction = playerFaction
        let reduceMotion = reduceMotionEnabled

        Task {
            let outcome = await self.runAISequence(
                from: stateSnapshot,
                pipelineMode: pipelineMode,
                observerEnabled: observerEnabled,
                playerFaction: controlledFaction,
                aiControlMode: controlMode,
                commandPace: commandPace,
                reduceMotionEnabled: reduceMotion
            )
            await MainActor.run {
                self.gameState = self.refreshedRuntimeState(outcome.state)
                self.lastAgentDecisionRecord = outcome.record
                self.lastWarDirectiveRecords = outcome.directiveRecords
                self.lastCommandMessage = self.aiTurnMessage(errorCount: outcome.record.errors.count)
                self.appendInteractionEvent(self.aiInteractionMessage(provider: outcome.record.provider, resultCount: outcome.record.commandResults.count))
                let diagnosticMessages = self.aiDiagnosticFeedbackMessages(for: outcome.record)
                diagnosticMessages.forEach { self.appendInteractionEvent($0) }
                if let noActionMessage = self.aiNoActionFeedbackMessage(
                    for: outcome.record,
                    includeFirstError: diagnosticMessages.isEmpty
                ) {
                    self.appendInteractionEvent(noActionMessage)
                }
                self.isRunningAI = false
                self.refreshSelectionAfterStateChange()
            }
        }
    }

    func handleBoardTap(_ coord: HexCoord) {
        guard gameState.map.contains(coord) else {
            return
        }

        selectedHex = coord
        selectedRegionId = mapDisplayAdapter.regionId(for: coord)
        appendInteractionEvent(selectionMessage(for: coord))

        let displayedDivisions = mapDisplayAdapter.divisions(displayedAt: coord, viewerFaction: playerFaction)
        if let attacker = selectedActionDivision,
           let enemy = displayedDivisions.first(where: {
               gameState.diplomacyState.isHostile(attacker.faction, to: $0.faction)
           }) {
            submit(.attack(attackerId: attacker.id, targetId: enemy.id))
            return
        }

        if let tappedDivision = displayedDivisions.first {
            handleDivisionTap(tappedDivision)
            return
        }

        if let division = selectedActionDivision {
            submitMove(division: division, tappedHex: coord)
        } else {
            selectedUnitId = nil
            clearHighlights()
        }
    }

    func holdSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent(rejectedUnitCommandMessage(action: "Hold"))
            return
        }

        submit(.hold(divisionId: division.id))
    }

    func allowRetreatSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent(rejectedUnitCommandMessage(action: interactionUsesNapoleonicVocabulary ? "Withdraw" : "Allow retreat"))
            return
        }

        submit(.allowRetreat(divisionId: division.id))
    }

    func resupplySelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent(rejectedUnitCommandMessage(action: interactionUsesNapoleonicVocabulary ? "Rest & Supply" : "Resupply"))
            return
        }

        submit(.resupply(divisionId: division.id))
    }

    func orderSelectedGeneralHoldLine() {
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent(generalOrderRejectedMessage("no friendly corps sector selected.", legacy: "no allied front zone selected."))
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            defense: DefenseParameters(
                targetReserves: max(1, min(2, zone.unitsDepth.count)),
                stance: .holdLine
            ),
            category: .defense,
            tactic: .holdPosition
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: nil),
            targetRegionId: nil
        )
    }

    func orderSelectedGeneralAttackRegion() {
        guard let target = selectedAttackTarget else {
            appendInteractionEvent(generalOrderRejectedMessage("select an enemy contact sector to attack.", legacy: "select an enemy front region to attack."))
            return
        }
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent(generalOrderRejectedMessage("no friendly source corps sector available.", legacy: "no allied source front zone available."))
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            attack: AttackParameters(
                targetTheaterId: TheaterId(target.zone.id.rawValue),
                weightedRegions: [target.region.id],
                intensity: .limitedCounter,
                focusRegionId: target.region.id,
                maxCommittedUnits: max(1, min(3, zone.unitsFront.count + zone.unitsDepth.count))
            ),
            category: .offense,
            tactic: .standardAttack,
            commandTarget: .region(target.region.id)
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: target.zone.id),
            targetRegionId: target.region.id
        )
    }

    func queueProduction(_ kind: ProductionKind) {
        guard !observerModeEnabled else {
            appendInteractionEvent(interactionUsesNapoleonicVocabulary ? "Reserve order rejected: observer mode is read-only." : "Production rejected: observer mode is read-only.")
            return
        }

        submit(.queueProduction(kind: kind))
    }

    func endTurn() {
        guard !observerModeEnabled else {
            appendInteractionEvent(interactionUsesNapoleonicVocabulary ? "End Orders unavailable: observer mode is read-only." : "End Turn unavailable: observer mode is read-only.")
            return
        }
        if gameState.phase.allowsCommands && gameState.activeFaction == playerFaction {
            appendPlaytestCueIfNeeded(.endingOrders)
        }
        submit(.endTurn)
    }

    func advanceOrRunAI() {
        if shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) {
            runAIIfNeeded()
        } else {
            endTurn()
        }
    }

    func setObserverModeEnabled(_ enabled: Bool) {
        let aiEligibilityMayHaveChanged = observerModeEnabled != enabled
        observerModeEnabled = enabled
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
        if aiEligibilityMayHaveChanged {
            runAIIfNeeded()
        }
    }

    func setMapDisplayLayer(_ layer: MapDisplayLayer) {
        mapDisplayLayer = layer
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func setReplayDetailLevel(_ level: ReplayDetailLevel) {
        replayDetailLevel = level
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func setAICommandPace(_ pace: AICommandPace) {
        aiCommandPace = pace
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func setAIControlMode(_ mode: PlaytestAIControlMode) {
        let aiEligibilityMayHaveChanged = aiControlMode != mode
        aiControlMode = mode
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
        if aiEligibilityMayHaveChanged {
            runAIIfNeeded()
        }
    }

    func setPlaytestGuideCuesEnabled(_ enabled: Bool) {
        playtestGuideCuesEnabled = enabled
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func setPlaytestTextSize(_ textSize: PlaytestTextSize) {
        playtestTextSize = textSize
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func setReduceMotionEnabled(_ enabled: Bool) {
        reduceMotionEnabled = enabled
        sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
    }

    func applySessionSettings(
        observerModeEnabled: Bool,
        mapDisplayLayer: MapDisplayLayer,
        replayDetailLevel: ReplayDetailLevel,
        aiCommandPace: AICommandPace,
        aiControlMode: PlaytestAIControlMode,
        playtestGuideCuesEnabled: Bool,
        playtestTextSize: PlaytestTextSize,
        reduceMotionEnabled: Bool
    ) {
        let aiEligibilityMayHaveChanged = self.observerModeEnabled != observerModeEnabled ||
            self.aiControlMode != aiControlMode
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
        self.replayDetailLevel = replayDetailLevel
        self.aiCommandPace = aiCommandPace
        self.aiControlMode = aiControlMode
        self.playtestGuideCuesEnabled = playtestGuideCuesEnabled
        self.playtestTextSize = playtestTextSize
        self.reduceMotionEnabled = reduceMotionEnabled
        self.sessionSettingsRecoveryMessage = nil
        persistPlaytestSessionSettings()
        if aiEligibilityMayHaveChanged {
            runAIIfNeeded()
        }
    }

    func resetGame() {
        _ = startNewGame(
            scenario: currentScenario,
            playerFaction: playerFaction,
            startsAtPlayerFaction: startsNewGameAtPlayerFaction
        )
    }

    @discardableResult
    func saveCurrentGame(to slot: GameSaveSlot? = nil) -> Bool {
        let targetSlot = slot ?? selectedSaveSlot
        var snapshotState = normalizeCommandPhase(gameState)
        snapshotState.scenarioId = currentScenario.id
        let snapshot = GameSaveSnapshot(
            scenarioId: currentScenario.id,
            playerFaction: playerFaction,
            startsAtPlayerFaction: startsNewGameAtPlayerFaction,
            gameState: snapshotState
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: targetSlot.defaultsKey)
            if let legacyDefaultsKey = targetSlot.legacyDefaultsKey {
                UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            }
            setSavedGameStatus(
                summary: snapshot.summary(scenarioName: currentScenario.displayName),
                recoveryMessage: nil,
                for: targetSlot
            )
            let message = "Campaign saved to \(saveSlotDisplayName(targetSlot)): \(currentScenario.displayName), turn \(gameState.turn)."
            lastCommandMessage = message
            appendInteractionEvent(message)
            return true
        } catch {
            let message = "Save failed: \(error.localizedDescription)"
            lastCommandMessage = message
            appendInteractionEvent(message)
            return false
        }
    }

    @discardableResult
    func continueSavedGame(from slot: GameSaveSlot? = nil) -> Bool {
        let targetSlot = slot ?? selectedSaveSlot
        let savedGameStatus = Self.loadSavedGameSnapshot(slot: targetSlot)
        guard let snapshot = savedGameStatus.snapshot else {
            let message = Self.continueFailureMessage(for: savedGameStatus)
            lastCommandMessage = message
            appendInteractionEvent(message)
            setSavedGameStatus(
                summary: nil,
                recoveryMessage: savedGameStatus.recoveryMessage,
                for: targetSlot
            )
            return false
        }

        guard let scenario = ScenarioCatalog.entry(for: snapshot.scenarioId) else {
            let recoveryMessage = Self.unavailableScenarioMessage(snapshot.scenarioId)
            let message = "Continue failed: \(recoveryMessage)"
            lastCommandMessage = message
            appendInteractionEvent(message)
            setSavedGameStatus(
                summary: nil,
                recoveryMessage: recoveryMessage,
                for: targetSlot
            )
            return false
        }
        let nextRegistry: GeneralRegistry
        do {
            nextRegistry = try dataLoader.loadGeneralRegistry(scenario)
        } catch {
            let recoveryMessage = "Commander catalog \(scenario.generalCatalogName).json failed to load. Saved campaign was not opened. \(error.localizedDescription)"
            let message = "Continue failed: \(recoveryMessage)"
            lastCommandMessage = message
            appendInteractionEvent(message)
            setSavedGameStatus(
                summary: snapshot.summary(scenarioName: scenario.displayName),
                recoveryMessage: recoveryMessage,
                for: targetSlot
            )
            return false
        }
        var bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(snapshot.gameState)
        bootstrappedState.scenarioId = scenario.id

        isRunningAI = false
        selectedSaveSlot = targetSlot
        currentScenario = scenario
        generalRegistry = nextRegistry
        playerFaction = snapshot.playerFaction
        startsNewGameAtPlayerFaction = snapshot.startsAtPlayerFaction
        gameState = refreshGeneralAssignments(in: bootstrappedState)
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        movementHighlights = []
        attackHighlights = []
        interactionLog = []
        deliveredPlaytestCues = []
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = Array(gameState.warDirectiveRecords.suffix(12))
        setSavedGameStatus(
            summary: snapshot.summary(scenarioName: scenario.displayName),
            recoveryMessage: nil,
            for: targetSlot
        )
        let message = "Continued saved campaign from \(saveSlotDisplayName(targetSlot)): \(scenario.displayName), turn \(gameState.turn)."
        lastCommandMessage = message
        appendInteractionEvent(message)
        runAIIfNeeded()
        return true
    }

    func clearSavedGame(slot: GameSaveSlot? = nil) {
        let targetSlot = slot ?? selectedSaveSlot
        UserDefaults.standard.removeObject(forKey: targetSlot.defaultsKey)
        if let legacyDefaultsKey = targetSlot.legacyDefaultsKey {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
        setSavedGameStatus(summary: nil, recoveryMessage: nil, for: targetSlot)
        let message = "\(saveSlotDisplayName(targetSlot)) campaign snapshot cleared."
        lastCommandMessage = message
        appendInteractionEvent(message)
    }

    func setSelectedSaveSlot(_ slot: GameSaveSlot) {
        selectedSaveSlot = slot
        savedGameSummary = savedGameSummaries[slot]
        savedGameRecoveryMessage = savedGameRecoveryMessages[slot]
    }

    func setSaveSlotLabel(_ label: String, for slot: GameSaveSlot) {
        selectedSaveSlot = slot
        savedGameSummary = savedGameSummaries[slot]
        savedGameRecoveryMessage = savedGameRecoveryMessages[slot]
        if let persistedLabel = GameSaveSlot.persistLabel(label, for: slot) {
            saveSlotLabels[slot] = persistedLabel
            let message = "Save slot name updated: \(slot.displayName) -> \(persistedLabel)."
            lastCommandMessage = message
            appendInteractionEvent(message)
        } else {
            saveSlotLabels.removeValue(forKey: slot)
            let message = "Save slot name reset: \(slot.displayName)."
            lastCommandMessage = message
            appendInteractionEvent(message)
        }
    }

    @discardableResult
    func startNewGame(
        scenario: ScenarioCatalogEntry,
        playerFaction requestedPlayerFaction: Faction,
        startsAtPlayerFaction: Bool = true
    ) -> Bool {
        isRunningAI = false
        let loadedState: GameState
        do {
            loadedState = try dataLoader.loadGameState(scenario)
        } catch {
            let message = "New game failed: \(error.localizedDescription)"
            lastCommandMessage = message
            appendInteractionEvent(message)
            return false
        }

        let availableFactions = availablePlayerFactions(for: scenario)
        let nextPlayerFaction = availableFactions.contains(requestedPlayerFaction)
            ? requestedPlayerFaction
            : (availableFactions.contains(scenario.defaultPlayerFaction)
                ? scenario.defaultPlayerFaction
                : (availableFactions.first ?? loadedState.activeFaction))
        let nextRegistry: GeneralRegistry
        do {
            nextRegistry = try dataLoader.loadGeneralRegistry(scenario)
        } catch {
            let message = "New game failed: commander catalog \(scenario.generalCatalogName).json could not be loaded. \(error.localizedDescription)"
            lastCommandMessage = message
            appendInteractionEvent(message)
            return false
        }
        var bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(loadedState)
        if startsAtPlayerFaction {
            bootstrappedState = stateStartingAtPlayerFaction(nextPlayerFaction, from: bootstrappedState)
        }
        currentScenario = scenario
        generalRegistry = nextRegistry
        playerFaction = nextPlayerFaction
        startsNewGameAtPlayerFaction = startsAtPlayerFaction
        gameState = refreshGeneralAssignments(in: bootstrappedState)
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        movementHighlights = []
        attackHighlights = []
        interactionLog = []
        deliveredPlaytestCues = []
        lastCommandMessage = nil
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = []
        let message = "New campaign loaded: \(scenario.displayName), player controls \(nextPlayerFaction.displayName)."
        lastCommandMessage = message
        appendInteractionEvent(message)
        if startsAtPlayerFaction {
            appendInteractionEvent("Opening orders assigned to \(nextPlayerFaction.displayName).")
        }
        runAIIfNeeded()
        return true
    }

    func availablePlayerFactions(for scenario: ScenarioCatalogEntry) -> [Faction] {
        if let definition = try? dataLoader.loadScenarioDefinition(named: scenario.scenarioName) {
            let parsedFactions = definition.factions
                .compactMap(Faction.init(rawValue:))
                .filter { !$0.isNeutral }
            if !parsedFactions.isEmpty {
                return parsedFactions.sorted {
                    if $0.turnOrderPriority == $1.turnOrderPriority {
                        return $0.rawValue < $1.rawValue
                    }
                    return $0.turnOrderPriority < $1.turnOrderPriority
                }
            }
        }

        if scenario.id == ScenarioCatalog.napoleonicTarget.id {
            return Faction.waterlooFactions.filter { !$0.isNeutral }
        }

        return Faction.legacyWorldWarIIFactions
    }

    private func stateStartingAtPlayerFaction(_ faction: Faction, from state: GameState) -> GameState {
        guard !faction.isNeutral else {
            return state
        }

        var next = state
        next.activeFaction = faction
        next.phase = .playerCommand
        next.playerCommandState.clearTurnLocks()
        for index in next.divisions.indices where next.divisions[index].faction == faction {
            next.divisions[index].hasActed = false
        }
        next.appendEvent("Opening command assigned to \(faction.displayName).")
        return StrategicStateBootstrapper().refreshRuntimeState(next)
    }

    private static func loadSavedGameSnapshot(slot: GameSaveSlot) -> GameSaveSnapshot.LoadResult {
        GameSaveSnapshot.load(slot: slot)
    }

    private static func loadSavedGameSlotSummaryStatuses() -> (
        summaries: [GameSaveSlot: GameSaveSnapshot.Summary],
        recoveryMessages: [GameSaveSlot: String]
    ) {
        var summaries: [GameSaveSlot: GameSaveSnapshot.Summary] = [:]
        var recoveryMessages: [GameSaveSlot: String] = [:]

        for slot in GameSaveSlot.allCases {
            let status = loadSavedGameSnapshot(slot: slot)
            if let snapshot = status.snapshot {
                guard let scenario = ScenarioCatalog.entry(for: snapshot.scenarioId) else {
                    recoveryMessages[slot] = unavailableScenarioMessage(snapshot.scenarioId)
                    continue
                }
                let scenarioName = scenario.displayName
                summaries[slot] = snapshot.summary(scenarioName: scenarioName)
            } else if let recoveryMessage = status.recoveryMessage {
                recoveryMessages[slot] = recoveryMessage
            }
        }

        return (summaries, recoveryMessages)
    }

    private static func unavailableScenarioMessage(_ scenarioId: String) -> String {
        "Saved campaign references scenario '\(scenarioId)' that is not available in this build."
    }

    private static func continueFailureMessage(for status: GameSaveSnapshot.LoadResult) -> String {
        switch status {
        case .missing:
            return "Continue failed: no saved campaign."
        case .loaded:
            return "Continue failed: saved campaign could not be opened."
        case let .unavailable(message):
            return "Continue failed: \(message)"
        }
    }

    private func setSavedGameStatus(
        summary: GameSaveSnapshot.Summary?,
        recoveryMessage: String?,
        for slot: GameSaveSlot
    ) {
        selectedSaveSlot = slot
        if let summary {
            savedGameSummaries[slot] = summary
        } else {
            savedGameSummaries.removeValue(forKey: slot)
        }
        if let recoveryMessage {
            savedGameRecoveryMessages[slot] = recoveryMessage
        } else {
            savedGameRecoveryMessages.removeValue(forKey: slot)
        }
        savedGameSummary = savedGameSummaries[slot]
        savedGameRecoveryMessage = savedGameRecoveryMessages[slot]
    }

    private func saveSlotDisplayName(_ slot: GameSaveSlot) -> String {
        slot.displayName(using: saveSlotLabels)
    }

    private func persistPlaytestSessionSettings() {
        PlaytestSessionSettings(
            observerModeEnabled: observerModeEnabled,
            mapDisplayLayer: mapDisplayLayer,
            replayDetailLevel: replayDetailLevel,
            aiCommandPace: aiCommandPace,
            aiControlMode: aiControlMode,
            playtestGuideCuesEnabled: playtestGuideCuesEnabled,
            playtestTextSize: playtestTextSize,
            reduceMotionEnabled: reduceMotionEnabled
        )
        .save()
    }

    var selectedDivision: Division? {
        guard let selectedUnitId else {
            return nil
        }
        return gameState.division(id: selectedUnitId)
    }

    var selectedRegionInspectorState: RegionInspectorState? {
        guard let selectedRegionId else {
            return nil
        }
        return mapDisplayAdapter.inspectorState(for: selectedRegionId, selectedHex: selectedHex, viewerFaction: playerFaction)
    }

    var selectedUnitInspectorStrategicState: UnitInspectorStrategicState? {
        guard let selectedDivision else {
            return nil
        }
        return mapDisplayAdapter.unitInspectorState(for: selectedDivision)
    }

    var selectedGeneralCommandZone: FrontZone? {
        inferredPlayerCommandZone()
    }

    var selectedGeneral: GeneralData? {
        generalRegistry.general(id: selectedGeneralAssignment?.generalId)
    }

    var selectedGeneralAssignment: GeneralAssignment? {
        selectedGeneralCommandZone?.generalAssignment
    }

    var selectedGeneralAssignedDivisions: [Division] {
        guard let assignment = selectedGeneralAssignment else {
            return []
        }
        let assignedIds = Set(assignment.assignedDivisionIds)
        return gameState.divisions
            .filter { assignedIds.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    var selectedGeneralHQUnderAttack: Bool {
        guard let zone = selectedGeneralCommandZone else {
            return false
        }
        return GeneralDispatcher(registry: generalRegistry).isHQUnderAttack(
            zone: zone,
            map: gameState.map,
            diplomacyState: gameState.diplomacyState
        )
    }

    var selectedGeneralTargetRegion: RegionNode? {
        selectedRegionId.flatMap { gameState.map.region(id: $0) }
    }

    var selectedGeneralTargetZone: FrontZone? {
        guard let selectedRegionId else {
            return nil
        }
        return gameState.warDeploymentState.zone(for: selectedRegionId)
    }

    var selectedGeneralPlannedOperations: [PlayerPlannedOperation] {
        let zoneId = selectedGeneralCommandZone?.id
        return Array(gameState.playerCommandState.plannedOperations
            .filter { operation in
                operation.turn == gameState.turn &&
                    (zoneId == nil || operation.zoneId == zoneId)
            }
            .suffix(5))
    }

    var canOrderSelectedGeneralHoldLine: Bool {
        canIssuePlayerDirective && selectedGeneralCommandZone != nil
    }

    var canOrderSelectedGeneralAttackRegion: Bool {
        canIssuePlayerDirective && selectedAttackTarget != nil && selectedGeneralCommandZone != nil
    }

    var canAdvanceOrders: Bool {
        guard gameState.phase.allowsCommands,
              !gameState.activeFaction.isNeutral,
              !isRunningAI else {
            return false
        }

        if observerModeEnabled {
            return shouldRunAI(for: gameState.activeFaction, phase: gameState.phase)
        }

        return true
    }

    var displayEventLog: [GameLogEntry] {
        Array((gameState.eventLog + interactionLog).suffix(replayDetailLevel.eventLimit))
    }

    var selectedUnitCanAct: Bool {
        selectedActionDivision != nil
    }

    var playerOrdersStatusMessage: String? {
        guard !observerModeEnabled,
              gameState.activeFaction == playerFaction,
              gameState.phase.allowsCommands else {
            return nil
        }

        let playerFormations = gameState.divisions.filter {
            $0.faction == playerFaction && !$0.isDestroyed
        }
        let readyFormations = playerFormations.filter { !$0.hasActed }
        let usesNapoleonicVocabulary = playerFaction.usesNapoleonicLogisticsVocabulary

        if playerFormations.isEmpty {
            return usesNapoleonicVocabulary
                ? "No player formations remain on the field."
                : "No player units remain on the field."
        }

        if readyFormations.isEmpty {
            return usesNapoleonicVocabulary
                ? "All friendly formations have spent their orders. End Orders when ready."
                : "All friendly units have acted. End Turn when ready."
        }

        return usesNapoleonicVocabulary
            ? "\(readyFormations.count) friendly formation(s) still awaiting orders."
            : "\(readyFormations.count) friendly unit(s) still ready."
    }

    private var selectedActionDivision: Division? {
        guard !observerModeEnabled else {
            return nil
        }
        guard let division = selectedDivision,
              division.faction == playerFaction,
              gameState.activeFaction == playerFaction,
              gameState.phase.allowsCommands,
              !division.hasActed else {
            return nil
        }

        return division
    }

    private var canIssuePlayerDirective: Bool {
        !observerModeEnabled &&
            gameState.activeFaction == playerFaction &&
            gameState.phase.allowsCommands
    }

    private var selectedAttackTarget: (region: RegionNode, zone: FrontZone)? {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId),
              let targetZone = gameState.warDeploymentState.zone(for: selectedRegionId),
              gameState.diplomacyState.isHostile(playerFaction, to: targetZone.faction) else {
            return nil
        }
        return (region, targetZone)
    }

    private var mapDisplayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }

    private func refreshedRuntimeState(_ state: GameState) -> GameState {
        refreshGeneralAssignments(
            in: StrategicStateBootstrapper().refreshRuntimeState(state)
        )
    }

    private func refreshGeneralAssignments(in state: GameState) -> GameState {
        normalizeCommandPhase(Self.refreshGeneralAssignments(in: state, registry: generalRegistry))
    }

    private static func refreshGeneralAssignments(
        in state: GameState,
        registry: GeneralRegistry
    ) -> GameState {
        guard !registry.allGenerals.isEmpty else {
            return state
        }
        var next = state
        next.warDeploymentState = GeneralDispatcher(registry: registry).assignGenerals(
            to: state.warDeploymentState,
            map: state.map
        )
        return next
    }

    private func normalizeCommandPhase(_ state: GameState) -> GameState {
        guard state.phase.allowsCommands else {
            return state
        }
        guard !state.activeFaction.isNeutral else {
            var next = state
            next.phase = .resolution
            return next
        }
        guard state.activeFaction.usesNapoleonicLogisticsVocabulary else {
            return state
        }

        var next = state
        next.phase = state.activeFaction == playerFaction ? .playerCommand : .aiCommand
        return next
    }

    private func applyPlayerCommandBookkeeping(
        _ command: Command,
        to state: GameState,
        previousState: GameState
    ) -> GameState {
        var next = state
        if command == .endTurn || next.activeFaction != previousState.activeFaction || next.turn != previousState.turn {
            next.playerCommandState.clearTurnLocks()
            return next
        }

        guard let divisionId = command.actingDivisionId,
              previousState.activeFaction == playerFaction,
              previousState.phase.allowsCommands,
              previousState.division(id: divisionId)?.faction == playerFaction else {
            return next
        }

        next.playerCommandState.lockDivision(divisionId)
        return registerPlayerIntervention(for: divisionId, in: next)
    }

    private func registerPlayerIntervention(for divisionId: String, in state: GameState) -> GameState {
        guard let zoneId = logicalZoneId(for: divisionId, in: state.warDeploymentState),
              var zone = state.warDeploymentState.frontZones[zoneId],
              let assignment = zone.generalAssignment else {
            return state
        }

        var next = state
        zone.generalAssignment = assignment.registeringPlayerIntervention(cost: 2)
        next.warDeploymentState.frontZones[zoneId] = zone
        return next
    }

    private func inferredPlayerCommandZone() -> FrontZone? {
        if let division = selectedDivision,
           division.faction == playerFaction,
           let zoneId = gameState.warDeploymentState.zoneId(for: division.coord, map: gameState.map),
           let zone = gameState.warDeploymentState.frontZones[zoneId],
           zone.faction == playerFaction {
            return zone
        }

        if let selectedRegionId,
           let zone = gameState.warDeploymentState.zone(for: selectedRegionId),
           zone.faction == playerFaction {
            return zone
        }

        guard let targetZone = selectedGeneralTargetZone,
              gameState.diplomacyState.isHostile(playerFaction, to: targetZone.faction) else {
            return nil
        }

        return playerZonesAdjacent(to: targetZone.id).first
    }

    private func playerZonesAdjacent(to targetZoneId: FrontZoneId) -> [FrontZone] {
        gameState.warDeploymentState.frontZones.values
            .filter { zone in
                zone.faction == playerFaction &&
                    zone.frontSegments.contains { $0.neighborEnemyZone == targetZoneId }
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func sourceRegionId(for zone: FrontZone, targetZoneId: FrontZoneId?) -> RegionId? {
        if let selectedDivision,
           selectedDivision.faction == zone.faction,
           let regionId = selectedDivision.location(in: gameState.map),
           zone.regionIds.contains(regionId) {
            return regionId
        }

        if let selectedRegionId,
           zone.regionIds.contains(selectedRegionId) {
            return selectedRegionId
        }

        if let targetZoneId,
           let segment = zone.frontSegments
            .filter({ $0.neighborEnemyZone == targetZoneId })
            .sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue })
            .first {
            return segment.regionId
        }

        return zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
    }

    private func logicalZoneId(for divisionId: String, in deploymentState: WarDeploymentState) -> FrontZoneId? {
        deploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first {
                $0.unitsFront.contains(divisionId)
                    || $0.unitsDepth.contains(divisionId)
                    || $0.unitsGarrison.contains(divisionId)
            }?
            .id
    }

    private func submitPlayerDirective(
        _ directive: ZoneDirective,
        sourceRegionId: RegionId?,
        targetRegionId: RegionId?
    ) {
        guard canIssuePlayerDirective else {
            appendInteractionEvent(generalOrderRejectedMessage("not in the player orders phase.", legacy: "not in the player command phase."))
            return
        }
        guard gameState.warDeploymentState.frontZones[directive.zoneId]?.faction == playerFaction else {
            appendInteractionEvent(generalOrderRejectedMessage("source corps sector is not controlled by the player.", legacy: "source zone is not controlled by the player."))
            return
        }

        let startState = refreshedRuntimeState(gameState)
        guard let refreshedZone = startState.warDeploymentState.frontZones[directive.zoneId],
              refreshedZone.faction == playerFaction else {
            appendInteractionEvent(generalOrderRejectedMessage("source corps sector changed during refresh.", legacy: "source zone changed during refresh."))
            return
        }
        let lockedIds = startState.playerCommandState.micromanagedDivisionIds
        let execution = WarCommandExecutor(commandHandler: commandHandler).execute(
            directive,
            in: startState,
            excluding: lockedIds
        )

        var nextState = refreshGeneralAssignments(in: execution.finalState)
        let commandSummaries = execution.commandResults.enumerated().map { index, result in
            CommandResultSummary.directiveCommand(
                directiveIndex: 0,
                commandIndex: index,
                directive: directive,
                command: execution.generatedCommands[index],
                result: result,
                faction: playerFaction
            )
        }
        var diagnostics: [String] = []
        if execution.generatedCommands.isEmpty {
            diagnostics.append(interactionUsesNapoleonicVocabulary ? "Corps directive produced no field orders." : "Player directive generated no executable commands.")
        }
        let rejected = commandSummaries.filter { !$0.executed }
        if !rejected.isEmpty {
            diagnostics.append(interactionUsesNapoleonicVocabulary ? "\(rejected.count) order(s) were rejected by rules." : "\(rejected.count) command(s) were rejected by rules.")
        }
        if !lockedIds.isEmpty {
            diagnostics.append(interactionUsesNapoleonicVocabulary ? "\(lockedIds.count) micromanaged formation(s) excluded." : "\(lockedIds.count) micromanaged division(s) excluded.")
        }

        let record = WarDirectiveRecord(
            id: "player_directive_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
            issuerId: "player",
            turn: startState.turn,
            faction: playerFaction,
            zoneId: directive.zoneId,
            directiveType: directive.type,
            targetRegionIds: targetRegionId.map { [$0] } ?? directive.targetRegionIds,
            commandResults: commandSummaries,
            diagnostics: diagnostics,
            category: directive.category,
            tactic: directive.tactic,
            commanderAgentId: refreshedZone.generalAssignment?.generalId,
            commandTarget: directive.commandTarget
        )

        nextState.warDirectiveRecords.append(record)
        nextState.playerCommandState.recordOperation(
            PlayerPlannedOperation(
                id: "player_operation_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
                turn: startState.turn,
                zoneId: directive.zoneId,
                faction: playerFaction,
                directiveType: directive.type,
                sourceRegionId: sourceRegionId,
                targetRegionId: targetRegionId,
                createdByGeneralId: refreshedZone.generalAssignment?.generalId
            )
        )

        gameState = refreshGeneralAssignments(in: nextState)
        lastWarDirectiveRecords = Array((lastWarDirectiveRecords + [record]).suffix(12))
        lastCommandMessage = playerDirectiveMessage(for: execution, diagnostics: diagnostics)
        appendInteractionEvent(generalOrderSubmittedMessage(for: directive))
        refreshSelectionAfterStateChange()
    }

    private func playerDirectiveMessage(
        for execution: WarCommandExecutionResult,
        diagnostics: [String]
    ) -> String {
        let acceptedCount = execution.commandResults.filter(\.succeeded).count
        let totalCount = execution.generatedCommands.count
        if totalCount == 0 {
            return diagnostics.first ?? (interactionUsesNapoleonicVocabulary ? "Corps order produced no orders." : "General order produced no commands.")
        }
        if acceptedCount == totalCount {
            return interactionUsesNapoleonicVocabulary ? "Corps order executed \(acceptedCount) order(s)." : "General order executed \(acceptedCount) command(s)."
        }
        return interactionUsesNapoleonicVocabulary ? "Corps order executed \(acceptedCount)/\(totalCount) order(s)." : "General order executed \(acceptedCount)/\(totalCount) command(s)."
    }

    private func shouldRunAI(for faction: Faction, phase: GamePhase) -> Bool {
        aiControlMode.shouldRunAI(
            for: faction,
            phase: phase,
            playerFaction: playerFaction,
            observerModeEnabled: observerModeEnabled
        )
    }

    private func runAISequence(
        from state: GameState,
        pipelineMode: WarPipelineMode,
        observerEnabled: Bool,
        playerFaction: Faction,
        aiControlMode: PlaytestAIControlMode,
        commandPace: AICommandPace,
        reduceMotionEnabled: Bool
    ) async -> AgentTurnOutcome {
        var currentState = refreshedRuntimeState(state)
        var lastOutcome: AgentTurnOutcome?
        var sequenceErrors: [String] = []
        let maxSteps = max(1, currentState.turnOrderFactions.count)

        for _ in 0..<maxSteps {
            currentState = refreshedRuntimeState(currentState)
            guard shouldRunAIInSnapshot(
                state: currentState,
                observerEnabled: observerEnabled,
                playerFaction: playerFaction,
                aiControlMode: aiControlMode
            ) else {
                break
            }

            if let turnDelay = commandPace.turnDelay(reduceMotionEnabled: reduceMotionEnabled) {
                try? await Task.sleep(for: turnDelay)
            }

            let actingFaction = currentState.activeFaction
            let manager = turnManager(for: currentState.activeFaction, state: currentState)
            let outcome = await manager.runAITurn(
                state: currentState,
                faction: currentState.activeFaction,
                pipelineMode: pipelineMode
            )
            currentState = refreshedRuntimeState(outcome.state)
            sequenceErrors.append(contentsOf: outcome.record.errors.map {
                "\(factionDisplayNameForInteraction(actingFaction)): \(diagnosticDisplayText($0))"
            })
            lastOutcome = AgentTurnOutcome(
                state: currentState,
                record: outcome.record,
                directiveRecords: (lastOutcome?.directiveRecords ?? []) + outcome.directiveRecords
            )
        }

        if shouldRunAIInSnapshot(
            state: currentState,
            observerEnabled: observerEnabled,
            playerFaction: playerFaction,
            aiControlMode: aiControlMode
        ) {
            sequenceErrors.append(
                "Command dispatch paused after \(maxSteps) staff step(s) while \(factionDisplayNameForInteraction(currentState.activeFaction)) was still eligible; automatic processing stopped to avoid a loop."
            )
        }

        if let lastOutcome {
            return AgentTurnOutcome(
                state: currentState,
                record: record(lastOutcome.record, replacingErrorsWith: sequenceErrors),
                directiveRecords: lastOutcome.directiveRecords
            )
        }

        return AgentTurnOutcome(
            state: currentState,
            record: AgentDecisionRecord(
                id: "agent_noop_turn_\(currentState.turn)",
                turn: currentState.turn,
                agentId: "system",
                provider: "System",
                contextSummary: "No staff-controlled faction was active.",
                rawJSON: nil,
                parsedIntent: nil,
                commandResults: [],
                errors: sequenceErrors
            )
        )
    }

    private func record(
        _ record: AgentDecisionRecord,
        replacingErrorsWith errors: [String]
    ) -> AgentDecisionRecord {
        guard !errors.isEmpty else {
            return record
        }

        return AgentDecisionRecord(
            id: record.id,
            turn: record.turn,
            agentId: record.agentId,
            provider: record.provider,
            contextSummary: record.contextSummary,
            rawJSON: record.rawJSON,
            parsedIntent: record.parsedIntent,
            commandResults: record.commandResults,
            errors: errors
        )
    }

    private func shouldRunAIInSnapshot(
        state: GameState,
        observerEnabled: Bool,
        playerFaction: Faction,
        aiControlMode: PlaytestAIControlMode
    ) -> Bool {
        aiControlMode.shouldRunAI(
            for: state.activeFaction,
            phase: state.phase,
            playerFaction: playerFaction,
            observerModeEnabled: observerEnabled
        )
    }

    private func turnManager(for faction: Faction, state: GameState) -> TurnManager {
        if currentScenario.id == ScenarioCatalog.ardennesLegacy.id,
           ScenarioCatalog.ardennesLegacy.matches(state.scenarioId),
           faction == .germany,
           let turnManager,
           generalRegistry.allGenerals.isEmpty {
            return turnManager
        }

        let agent: GameAgent
        switch faction {
        case .germany:
            agent = GameAgent.guderian(from: dataLoader, state: state)
        case .allies, .france, .angloAllied, .prussia, .austria, .russia, .spain, .neutral:
            let assignedIds = state.divisions
                .filter { $0.faction == faction && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "\(faction.rawValue)_mock_commander",
                name: faction.usesNapoleonicLogisticsVocabulary
                    ? "\(faction.displayName) Command Staff"
                    : "\(faction.displayName) Mock Commander",
                faction: faction,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        }

        return TurnManager(
            agent: agent,
            provider: MockAIClient(),
            providerName: "MockAI",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: state, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(faction: faction, state: state)
        )
    }

    private static func buildCommanderPool(
        state: GameState,
        registry: GeneralRegistry = .empty
    ) -> TheaterCommanderPool {
        if !registry.allGenerals.isEmpty {
            return GeneralDispatcher(registry: registry).commanderPool(for: state)
        }

        let agents: [any ZoneCommanderProviding] = state.warDeploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { zone in
                let style: ZoneCommanderAgentConfig.CommandStyle = (zone.faction == .germany || zone.faction == .france || zone.faction == .prussia)
                    ? .aggressive
                    : .balanced
                let factionName = zone.faction.displayName
                let config = ZoneCommanderAgentConfig(
                    id: "auto_\(zone.id.rawValue)",
                    name: "\(factionName) Commander (\(zone.id.rawValue))",
                    faction: zone.faction,
                    assignedZoneId: zone.id,
                    skills: [],
                    commandStyle: style
                )
                return ZoneCommanderAgent(config: config)
            }
        return TheaterCommanderPool(commanders: agents)
    }

    private static func buildMarshalAgent(faction: Faction, state: GameState) -> MarshalAgent {
        MarshalAgent(config: MarshalAgentConfig.automatic(for: faction, state: state))
    }

    private var interactionUsesNapoleonicVocabulary: Bool {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary ||
            playerFaction.usesNapoleonicLogisticsVocabulary
    }

    private func unitNoun(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "formation" : "unit"
    }

    private func commandInteractionMessage(status: String, command: Command, resultMessage: String) -> String {
        guard interactionUsesNapoleonicVocabulary else {
            return "Command \(status): \(command.displayName). \(resultMessage)"
        }

        return "Order \(status): \(command.displayName(for: gameState.activeFaction)). \(resultMessage)"
    }

    private func observerCommandRejectedMessage(for command: Command) -> String {
        if interactionUsesNapoleonicVocabulary {
            return "Order rejected: \(command.displayName(for: gameState.activeFaction)) unavailable in observer mode."
        }

        return "Command rejected: \(command.displayName) unavailable in observer mode."
    }

    private func rejectedUnitCommandMessage(action: String) -> String {
        if interactionUsesNapoleonicVocabulary {
            return "\(action) rejected: no active friendly formation selected."
        }

        return "\(action) rejected: no active allied unit selected."
    }

    private func generalOrderRejectedMessage(_ napoleonicReason: String, legacy legacyReason: String) -> String {
        if interactionUsesNapoleonicVocabulary {
            return "Corps order rejected: \(napoleonicReason)"
        }

        return "General order rejected: \(legacyReason)"
    }

    private func generalOrderSubmittedMessage(for directive: ZoneDirective) -> String {
        if interactionUsesNapoleonicVocabulary {
            return "Corps order submitted: \(directiveTypeDisplayName(directive.type)) \(frontZoneDisplayName(directive.zoneId))."
        }

        return "General order submitted: \(directive.type.rawValue) \(directive.zoneId.rawValue)."
    }

    private func frontZoneDisplayName(_ zoneId: FrontZoneId) -> String {
        guard interactionUsesNapoleonicVocabulary else {
            return zoneId.rawValue
        }

        if let zoneName = gameState.warDeploymentState.frontZones[zoneId]?.name,
           !zoneName.isEmpty {
            return zoneName
        }

        return identifierDisplayText(zoneId.rawValue, fallback: "corps sector", suffix: " sector")
    }

    private func directiveTypeDisplayName(_ type: DirectiveType) -> String {
        guard interactionUsesNapoleonicVocabulary else {
            return type.rawValue
        }

        switch type {
        case .attack:
            return "Attack Sector"
        case .defend:
            return "Hold Contact Line"
        }
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

    private func aiTurnMessage(errorCount: Int) -> String {
        if interactionUsesNapoleonicVocabulary {
            return errorCount == 0
                ? "Command dispatch completed."
                : "Command dispatch completed with \(errorCount) issue(s)."
        }

        return errorCount == 0
            ? "AI turn completed."
            : "AI turn completed with \(errorCount) issue(s)."
    }

    private func aiInteractionMessage(provider: String, resultCount: Int) -> String {
        if interactionUsesNapoleonicVocabulary {
            return "Command dispatch \(providerDisplayName(provider)) resolved \(resultCount) order result(s)."
        }

        return "AI \(provider) resolved \(resultCount) command result(s)."
    }

    private func aiDiagnosticFeedbackMessages(for record: AgentDecisionRecord) -> [String] {
        let maxVisibleIssues = 3
        let visibleErrors = Array(record.errors.prefix(maxVisibleIssues))
        guard !visibleErrors.isEmpty else {
            return []
        }

        let prefix = interactionUsesNapoleonicVocabulary ? "Command dispatch issue" : "AI issue"
        var messages = visibleErrors.map { "\(prefix): \(diagnosticDisplayText($0))" }
        if record.errors.count > maxVisibleIssues {
            messages.append("\(prefix): \(record.errors.count - maxVisibleIssues) more issue(s) hidden in Staff Summary.")
        }
        return messages
    }

    private func aiNoActionFeedbackMessage(
        for record: AgentDecisionRecord,
        includeFirstError: Bool = true
    ) -> String? {
        let nonEndTurnResults = record.commandResults.filter {
            $0.commandDisplayName != Command.endTurn.displayName
        }
        let executedOrders = nonEndTurnResults.filter(\.executed)
        guard executedOrders.isEmpty else {
            return nil
        }

        if interactionUsesNapoleonicVocabulary {
            if includeFirstError, let firstError = record.errors.first {
                return "Staff note: no field orders took effect. \(diagnosticDisplayText(firstError))"
            }
            return "Staff note: no field orders took effect before the dispatch ended."
        }

        if includeFirstError, let firstError = record.errors.first {
            return "AI note: no battlefield commands took effect. \(firstError)"
        }
        return "AI note: no battlefield commands took effect before the turn ended."
    }

    private func providerDisplayName(_ provider: String) -> String {
        if interactionUsesNapoleonicVocabulary && provider.contains("MockAI") {
            return "Simulated Staff"
        }

        return provider
    }

    private func factionDisplayNameForInteraction(_ faction: Faction) -> String {
        guard interactionUsesNapoleonicVocabulary else {
            return faction.displayName
        }

        return faction.isLegacyWorldWarIIFaction ? "Archived Force" : faction.displayName
    }

    private func diagnosticDisplayText(_ text: String) -> String {
        let displayFaction = gameState.activeFaction.usesNapoleonicLogisticsVocabulary
            ? gameState.activeFaction
            : playerFaction
        return NapoleonicMessageSanitizer.displayText(text, for: displayFaction)
    }

    private func handleDivisionTap(_ division: Division) {
        if observerModeEnabled {
            selectDivision(division)
            appendInteractionEvent("Inspecting \(unitNoun(for: division.faction)): \(division.name).")
            return
        }

        if gameState.diplomacyState.isFriendly(playerFaction, to: division.faction) {
            selectDivision(division)
            appendInteractionEvent("Selected \(unitNoun(for: division.faction)): \(division.name).")
            appendPlaytestSelectionCues(for: division)
            return
        }

        if let attacker = selectedActionDivision,
           gameState.diplomacyState.isHostile(attacker.faction, to: division.faction) {
            submit(.attack(attackerId: attacker.id, targetId: division.id))
        } else {
            selectDivision(division)
            appendInteractionEvent("Selected enemy \(unitNoun(for: division.faction)): \(division.name).")
        }
    }

    private func selectDivision(_ division: Division) {
        selectedUnitId = division.id
        selectedHex = mapDisplayAdapter.unitDisplayHex(for: division) ?? division.coord
        selectedRegionId = division.location(in: gameState.map)
        refreshHighlights()
    }

    private func refreshSelectionAfterStateChange() {
        if let selectedUnitId,
           gameState.division(id: selectedUnitId) == nil {
            self.selectedUnitId = nil
        }

        if let selectedDivision {
            selectedHex = mapDisplayAdapter.unitDisplayHex(for: selectedDivision) ?? selectedDivision.coord
            selectedRegionId = selectedDivision.location(in: gameState.map)
        }

        refreshHighlights()
    }

    private func refreshHighlights() {
        guard let division = selectedActionDivision else {
            clearHighlights()
            return
        }

        movementHighlights = MovementRules().movementRange(for: division, in: gameState)
        attackHighlights = Set(
            gameState.divisions
                .filter {
                    gameState.diplomacyState.isHostile(division.faction, to: $0.faction) &&
                        division.coord.distance(to: $0.coord) <= division.range
                }
                .map(\.coord)
        )
    }

    private func clearHighlights() {
        movementHighlights = []
        attackHighlights = []
    }

    private func submitMove(division: Division, tappedHex: HexCoord) {
        submit(.move(divisionId: division.id, destination: tappedHex))
    }

    private func selectionMessage(for coord: HexCoord) -> String {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId) else {
            return "Selected hex \(coord.q),\(coord.r)."
        }
        let noun = interactionUsesNapoleonicVocabulary ? "sector" : "region"
        return "Selected \(noun): \(region.name) (\(selectedRegionId.rawValue))."
    }

    private func appendInteractionEvent(_ message: String) {
        interactionLog.append(
            GameLogEntry(
                turn: gameState.turn,
                faction: gameState.activeFaction,
                phase: gameState.phase,
                message: message,
                createdAt: Date()
            )
        )

        if interactionLog.count > 80 {
            interactionLog.removeFirst(interactionLog.count - 80)
        }
    }

    private func appendPlaytestSelectionCues(for division: Division) {
        appendPlaytestCueIfNeeded(.formationSelected, division: division)
        if division.isArtillery || division.range > 1 {
            appendPlaytestCueIfNeeded(.artillerySelected, division: division)
        }
        if division.isCavalry {
            appendPlaytestCueIfNeeded(.cavalrySelected, division: division)
        }
    }

    private func appendPlaytestCueIfNeeded(_ cue: PlaytestGuideCue, division: Division? = nil) {
        guard !observerModeEnabled,
              playtestGuideCuesEnabled,
              !deliveredPlaytestCues.contains(cue) else {
            return
        }

        deliveredPlaytestCues.insert(cue)
        let cueFaction = gameState.activeFaction.usesNapoleonicLogisticsVocabulary
            ? gameState.activeFaction
            : playerFaction
        appendInteractionEvent(cue.message(for: division, activeFaction: cueFaction))
    }

}
