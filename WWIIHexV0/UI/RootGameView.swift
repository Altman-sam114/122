import SwiftUI

struct RootGameView: View {
    @ObservedObject var container: AppContainer
    @State private var selectedCompactPanel: CompactInfoPanel = .unit
    @State private var isInfoExpanded = false
    @State private var isGeneralProfilePresented = false
    @State private var isNewGameSetupPresented = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack(alignment: .bottomTrailing) {
                boardView
                    .ignoresSafeArea()

                VStack {
                    HUDView(
                        gameState: container.gameState,
                        playerFaction: container.playerFaction,
                        aiControlMode: container.aiControlMode,
                        canAdvanceOrders: container.canAdvanceOrders,
                        observerModeEnabled: container.observerModeEnabled,
                        onEndTurn: container.advanceOrRunAI,
                        onNewGame: showNewGameSetup
                    )
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                    Picker("Map Layer", selection: Binding(
                        get: { container.mapDisplayLayer },
                        set: { container.setMapDisplayLayer($0) }
                    )) {
                        ForEach(MapDisplayLayer.allCases) { layer in
                            Text(layer.displayName(for: container.gameState.activeFaction)).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)

                    Toggle("Observer", isOn: Binding(
                        get: { container.observerModeEnabled },
                        set: { container.setObserverModeEnabled($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.caption.weight(.semibold))
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)

                    Spacer()
                }

                if isInfoExpanded {
                    infoOverlay(isLandscape: isLandscape, size: proxy.size)
                        .transition(.opacity)
                }

                Button {
                    isInfoExpanded.toggle()
                } label: {
                    Text("[ INFO ]")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(10)

                UnitTooltipView(division: container.selectedDivision)
                    .allowsHitTesting(false)
            }
        }
        .background(PlatformStyles.systemBackground)
        .sheet(isPresented: $isGeneralProfilePresented) {
            if let general = container.selectedGeneral {
                GeneralProfileView(
                    general: general,
                    assignment: container.selectedGeneralAssignment,
                    zone: container.selectedGeneralCommandZone,
                    assignedDivisions: container.selectedGeneralAssignedDivisions,
                    activeFaction: container.gameState.activeFaction,
                    hqUnderAttack: container.selectedGeneralHQUnderAttack,
                    onClose: { isGeneralProfilePresented = false }
                )
            } else {
                Text("No general selected.")
                    .font(.headline)
                    .padding()
            }
        }
        .sheet(isPresented: $isNewGameSetupPresented) {
            NewGameSetupView(
                scenarios: ScenarioCatalog.all,
                currentScenario: container.currentScenario,
                currentPlayerFaction: container.playerFaction,
                currentStartsAtPlayerFaction: container.startsNewGameAtPlayerFaction,
                currentSaveSlot: container.selectedSaveSlot,
                savedGameSummaries: container.savedGameSummaries,
                savedGameRecoveryMessages: container.savedGameRecoveryMessages,
                saveSlotLabels: container.saveSlotLabels,
                sessionSettingsRecoveryMessage: container.sessionSettingsRecoveryMessage,
                currentObserverMode: container.observerModeEnabled,
                currentMapDisplayLayer: container.mapDisplayLayer,
                currentReplayDetailLevel: container.replayDetailLevel,
                currentAICommandPace: container.aiCommandPace,
                currentAIControlMode: container.aiControlMode,
                currentPlaytestGuideCuesEnabled: container.playtestGuideCuesEnabled,
                currentPlaytestTextSize: container.playtestTextSize,
                currentReduceMotionEnabled: container.reduceMotionEnabled,
                factionOptions: container.availablePlayerFactions(for:),
                onStart: startNewGame,
                onSaveCurrent: saveCurrentGame,
                onContinueSaved: continueSavedGame,
                onClearSaved: clearSavedGame,
                onRenameSaveSlot: renameSaveSlot,
                onSettingsChange: applySessionSettings,
                onCancel: hideNewGameSetup
            )
        }
    }

    private func showNewGameSetup() {
        isNewGameSetupPresented = true
    }

    private func hideNewGameSetup() {
        isNewGameSetupPresented = false
    }

    private func startNewGame(
        scenario: ScenarioCatalogEntry,
        playerFaction: Faction,
        startsAtPlayerFaction: Bool
    ) -> (succeeded: Bool, message: String) {
        let succeeded = container.startNewGame(
            scenario: scenario,
            playerFaction: playerFaction,
            startsAtPlayerFaction: startsAtPlayerFaction
        )
        if succeeded {
            hideNewGameSetup()
        }
        return operationResult(succeeded: succeeded, fallbackMessage: "New campaign could not be loaded.")
    }

    private func saveCurrentGame(slot: GameSaveSlot) -> (succeeded: Bool, message: String) {
        let succeeded = container.saveCurrentGame(to: slot)
        return operationResult(succeeded: succeeded, fallbackMessage: "Save failed.")
    }

    private func continueSavedGame(slot: GameSaveSlot) -> (succeeded: Bool, message: String) {
        let succeeded = container.continueSavedGame(from: slot)
        if succeeded {
            hideNewGameSetup()
        }
        return operationResult(succeeded: succeeded, fallbackMessage: "Continue failed.")
    }

    private func clearSavedGame(slot: GameSaveSlot) -> (succeeded: Bool, message: String) {
        container.clearSavedGame(slot: slot)
        return operationResult(succeeded: true, fallbackMessage: "\(slot.displayName(using: container.saveSlotLabels)) saved campaign cleared.")
    }

    private func renameSaveSlot(
        slot: GameSaveSlot,
        label: String
    ) -> (succeeded: Bool, message: String) {
        container.setSaveSlotLabel(label, for: slot)
        return operationResult(succeeded: true, fallbackMessage: "Save slot name updated.")
    }

    private func operationResult(
        succeeded: Bool,
        fallbackMessage: String
    ) -> (succeeded: Bool, message: String) {
        (succeeded: succeeded, message: container.lastCommandMessage ?? fallbackMessage)
    }

    private func applySessionSettings(
        observerModeEnabled: Bool,
        mapDisplayLayer: MapDisplayLayer,
        replayDetailLevel: ReplayDetailLevel,
        aiCommandPace: AICommandPace,
        aiControlMode: PlaytestAIControlMode,
        playtestGuideCuesEnabled: Bool,
        playtestTextSize: PlaytestTextSize,
        reduceMotionEnabled: Bool
    ) {
        container.applySessionSettings(
            observerModeEnabled: observerModeEnabled,
            mapDisplayLayer: mapDisplayLayer,
            replayDetailLevel: replayDetailLevel,
            aiCommandPace: aiCommandPace,
            aiControlMode: aiControlMode,
            playtestGuideCuesEnabled: playtestGuideCuesEnabled,
            playtestTextSize: playtestTextSize,
            reduceMotionEnabled: reduceMotionEnabled
        )
    }

    private var boardView: some View {
        BoardSceneView(
            renderState: BoardSceneAdapter.renderState(from: container),
            onHexTapped: container.handleBoardTap
        )
        .accessibilityLabel("\(ScenarioCatalog.displayName(for: container.gameState.scenarioId)) hex board")
    }

    private func infoOverlay(isLandscape: Bool, size: CGSize) -> some View {
        let width = isLandscape ? min(max(size.width * 0.32, 260), 360) : size.width
        let height = isLandscape ? size.height : min(max(size.height * 0.44, 320), 460)

        return VStack(spacing: 0) {
            compactPanelWithTabs
        }
        .frame(width: width, height: height)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
        }
        .padding(isLandscape ? 10 : 0)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isLandscape ? .trailing : .bottom
        )
    }

    private var compactPanelWithTabs: some View {
        VStack(spacing: 0) {
            Picker("Panel", selection: $selectedCompactPanel) {
                ForEach(CompactInfoPanel.allCases) { panel in
                    Text(panel.displayName(for: container.gameState.activeFaction)).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            compactPanel
        }
    }

    @ViewBuilder
    private var compactPanel: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch selectedCompactPanel {
                case .unit:
                    UnitInspectorView(
                        division: container.selectedDivision,
                        activeFaction: container.gameState.activeFaction,
                        playerFaction: container.playerFaction,
                        strategicState: container.selectedUnitInspectorStrategicState
                    )
                    RegionInspectorView(
                        inspectorState: container.selectedRegionInspectorState,
                        activeFaction: container.gameState.activeFaction
                    )
                    CommandPanelView(
                        selectedDivision: container.selectedDivision,
                        activeFaction: container.gameState.activeFaction,
                        phase: container.gameState.phase,
                        playerFaction: container.playerFaction,
                        aiControlMode: container.aiControlMode,
                        canAdvanceOrders: container.canAdvanceOrders,
                        observerModeEnabled: container.observerModeEnabled,
                        lastCommandMessage: container.lastCommandMessage,
                        playerOrdersStatusMessage: container.playerOrdersStatusMessage,
                        onHold: container.holdSelected,
                        onAllowRetreat: container.allowRetreatSelected,
                        onResupply: container.resupplySelected,
                        onEndTurn: container.advanceOrRunAI
                    )
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        activeFaction: container.gameState.activeFaction,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisions: container.selectedGeneralAssignedDivisions,
                        targetRegion: container.selectedGeneralTargetRegion,
                        targetZone: container.selectedGeneralTargetZone,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperations: container.selectedGeneralPlannedOperations,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .region:
                    RegionInspectorView(
                        inspectorState: container.selectedRegionInspectorState,
                        activeFaction: container.gameState.activeFaction
                    )
                case .general:
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        activeFaction: container.gameState.activeFaction,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisions: container.selectedGeneralAssignedDivisions,
                        targetRegion: container.selectedGeneralTargetRegion,
                        targetZone: container.selectedGeneralTargetZone,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperations: container.selectedGeneralPlannedOperations,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .log:
                    EventLogView(
                        entries: container.displayEventLog,
                        activeFaction: container.gameState.activeFaction,
                        replayDetailLevel: container.replayDetailLevel,
                        playtestTextSize: container.playtestTextSize
                    )
                case .economy:
                    EconomyPanelView(
                        gameState: container.gameState,
                        playerFaction: container.playerFaction,
                        observerModeEnabled: container.observerModeEnabled,
                        onQueueProduction: container.queueProduction
                    )
                case .diplomacy:
                    DiplomacyPanelView(
                        diplomacyState: container.gameState.diplomacyState,
                        activeFaction: container.gameState.activeFaction
                    )
                case .agent:
                    AgentPanelView(
                        record: container.lastAgentDecisionRecord,
                        rulerRecord: container.gameState.diplomacyState.latestRulerRecord,
                        activeFaction: container.gameState.activeFaction,
                        directiveRecords: container.lastWarDirectiveRecords,
                        replayDetailLevel: container.replayDetailLevel,
                        playtestTextSize: container.playtestTextSize
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }
}

private enum CompactInfoPanel: String, CaseIterable, Identifiable {
    case unit = "Unit"
    case region = "Region"
    case general = "General"
    case log = "Log"
    case economy = "Economy"
    case diplomacy = "Diplomacy"
    case agent = "AI"

    var id: String {
        rawValue
    }

    func displayName(for faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        switch self {
        case .unit:
            return "Formation"
        case .region:
            return "Sector"
        case .general:
            return "General"
        case .log:
            return "Dispatches"
        case .economy:
            return "Logistics"
        case .diplomacy:
            return "Coalition"
        case .agent:
            return "Staff"
        }
    }
}
