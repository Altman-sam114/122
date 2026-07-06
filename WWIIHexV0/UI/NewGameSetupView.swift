import SwiftUI

struct NewGameSetupView: View {
    let scenarios: [ScenarioCatalogEntry]
    let currentScenario: ScenarioCatalogEntry
    let currentPlayerFaction: Faction
    let currentStartsAtPlayerFaction: Bool
    let currentSaveSlot: GameSaveSlot
    let savedGameSummaries: [GameSaveSlot: GameSaveSnapshot.Summary]
    let savedGameRecoveryMessages: [GameSaveSlot: String]
    let saveSlotLabels: [GameSaveSlot: String]
    let sessionSettingsRecoveryMessage: String?
    let factionOptions: (ScenarioCatalogEntry) -> [Faction]
    let onStart: (ScenarioCatalogEntry, Faction, Bool) -> (succeeded: Bool, message: String)
    let onSaveCurrent: (GameSaveSlot) -> (succeeded: Bool, message: String)
    let onContinueSaved: (GameSaveSlot) -> (succeeded: Bool, message: String)
    let onClearSaved: (GameSaveSlot) -> (succeeded: Bool, message: String)
    let onRenameSaveSlot: (GameSaveSlot, String) -> (succeeded: Bool, message: String)
    let onSettingsChange: (Bool, MapDisplayLayer, ReplayDetailLevel, AICommandPace, PlaytestAIControlMode, Bool, PlaytestTextSize, Bool) -> Void
    let onCancel: () -> Void

    @State private var selectedScenarioId: String
    @State private var selectedPlayerFaction: Faction
    @State private var startsAtPlayerFaction: Bool
    @State private var selectedSaveSlot: GameSaveSlot
    @State private var selectedSaveSlotLabel: String
    @State private var observerModeEnabled: Bool
    @State private var selectedMapDisplayLayer: MapDisplayLayer
    @State private var replayDetailLevel: ReplayDetailLevel
    @State private var aiCommandPace: AICommandPace
    @State private var aiControlMode: PlaytestAIControlMode
    @State private var playtestGuideCuesEnabled: Bool
    @State private var playtestTextSize: PlaytestTextSize
    @State private var reduceMotionEnabled: Bool
    @State private var showCompatibilityCampaigns: Bool
    @State private var operationStatusMessage: String?
    @State private var operationSucceeded: Bool?

    init(
        scenarios: [ScenarioCatalogEntry],
        currentScenario: ScenarioCatalogEntry,
        currentPlayerFaction: Faction,
        currentStartsAtPlayerFaction: Bool,
        currentSaveSlot: GameSaveSlot,
        savedGameSummaries: [GameSaveSlot: GameSaveSnapshot.Summary],
        savedGameRecoveryMessages: [GameSaveSlot: String],
        saveSlotLabels: [GameSaveSlot: String],
        sessionSettingsRecoveryMessage: String?,
        currentObserverMode: Bool,
        currentMapDisplayLayer: MapDisplayLayer,
        currentReplayDetailLevel: ReplayDetailLevel,
        currentAICommandPace: AICommandPace,
        currentAIControlMode: PlaytestAIControlMode,
        currentPlaytestGuideCuesEnabled: Bool,
        currentPlaytestTextSize: PlaytestTextSize,
        currentReduceMotionEnabled: Bool,
        factionOptions: @escaping (ScenarioCatalogEntry) -> [Faction],
        onStart: @escaping (ScenarioCatalogEntry, Faction, Bool) -> (succeeded: Bool, message: String),
        onSaveCurrent: @escaping (GameSaveSlot) -> (succeeded: Bool, message: String),
        onContinueSaved: @escaping (GameSaveSlot) -> (succeeded: Bool, message: String),
        onClearSaved: @escaping (GameSaveSlot) -> (succeeded: Bool, message: String),
        onRenameSaveSlot: @escaping (GameSaveSlot, String) -> (succeeded: Bool, message: String),
        onSettingsChange: @escaping (Bool, MapDisplayLayer, ReplayDetailLevel, AICommandPace, PlaytestAIControlMode, Bool, PlaytestTextSize, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.scenarios = scenarios
        self.currentScenario = currentScenario
        self.currentPlayerFaction = currentPlayerFaction
        self.currentStartsAtPlayerFaction = currentStartsAtPlayerFaction
        self.currentSaveSlot = currentSaveSlot
        self.savedGameSummaries = savedGameSummaries
        self.savedGameRecoveryMessages = savedGameRecoveryMessages
        self.saveSlotLabels = saveSlotLabels
        self.sessionSettingsRecoveryMessage = sessionSettingsRecoveryMessage
        self.factionOptions = factionOptions
        self.onStart = onStart
        self.onSaveCurrent = onSaveCurrent
        self.onContinueSaved = onContinueSaved
        self.onClearSaved = onClearSaved
        self.onRenameSaveSlot = onRenameSaveSlot
        self.onSettingsChange = onSettingsChange
        self.onCancel = onCancel
        _selectedScenarioId = State(initialValue: currentScenario.id)
        _selectedPlayerFaction = State(initialValue: currentPlayerFaction)
        _startsAtPlayerFaction = State(initialValue: currentStartsAtPlayerFaction)
        _selectedSaveSlot = State(initialValue: currentSaveSlot)
        _selectedSaveSlotLabel = State(initialValue: saveSlotLabels[currentSaveSlot] ?? "")
        _observerModeEnabled = State(initialValue: currentObserverMode)
        _selectedMapDisplayLayer = State(initialValue: currentMapDisplayLayer)
        _replayDetailLevel = State(initialValue: currentReplayDetailLevel)
        _aiCommandPace = State(initialValue: currentAICommandPace)
        _aiControlMode = State(initialValue: currentAIControlMode)
        _playtestGuideCuesEnabled = State(initialValue: currentPlaytestGuideCuesEnabled)
        _playtestTextSize = State(initialValue: currentPlaytestTextSize)
        _reduceMotionEnabled = State(initialValue: currentReduceMotionEnabled)
        _showCompatibilityCampaigns = State(
            initialValue: currentScenario.migrationStage == "legacy_wwii"
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let operationStatusMessage {
                    Section("Status") {
                        Label(operationStatusMessage, systemImage: operationStatusIcon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(operationStatusStyle)
                    }
                }

                Section("Continue") {
                    Picker("Save Slot", selection: $selectedSaveSlot) {
                        ForEach(GameSaveSlot.allCases) { slot in
                            Text(saveSlotDisplayName(slot)).tag(slot)
                        }
                    }

                    TextField("Slot Name", text: $selectedSaveSlotLabel)
                    Button("Rename Slot", systemImage: "tag", action: renameSaveSlot)
                        .disabled(!saveSlotLabelChanged)

                    if let savedGameSummary = selectedSavedGameSummary,
                       isHiddenCompatibilitySummary(savedGameSummary) {
                        Label("Archived saved campaign available", systemImage: "archivebox")
                            .font(.footnote.weight(.semibold))
                        LabeledContent("Saved At", value: savedGameSummary.savedAt.formatted(date: .abbreviated, time: .shortened))
                        Button("Show Archived", systemImage: "archivebox", action: showCompatibilitySavedGame)
                        Button("Clear Saved", systemImage: "trash", role: .destructive, action: clearSavedGame)
                    } else if let savedGameSummary = selectedSavedGameSummary {
                        LabeledContent("Saved", value: savedGameSummary.title)
                        LabeledContent("Forces", value: savedGameSummary.detail)
                        LabeledContent("Saved At", value: savedGameSummary.savedAt.formatted(date: .abbreviated, time: .shortened))
                        Button("Continue Saved", systemImage: "play.circle", action: continueSavedGame)
                        Button("Clear Saved", systemImage: "trash", role: .destructive, action: clearSavedGame)
                    } else if let savedGameRecoveryMessage = selectedSavedGameRecoveryMessage {
                        Label("Saved campaign unavailable", systemImage: "exclamationmark.triangle")
                            .font(.footnote.weight(.semibold))
                        Text(savedGameRecoveryMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Clear Saved", systemImage: "trash", role: .destructive, action: clearSavedGame)
                    } else {
                        Text("No saved campaign snapshot in \(saveSlotDisplayName(selectedSaveSlot)).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Save Current", systemImage: "square.and.arrow.down", action: saveCurrentGame)
                }

                Section("Campaign") {
                    Picker("Campaign", selection: $selectedScenarioId) {
                        ForEach(visibleScenarios) { scenario in
                            Text(scenario.displayName).tag(scenario.id)
                        }
                    }
                    Toggle("Archived Campaigns", isOn: $showCompatibilityCampaigns)
                }

                Section("Player Power") {
                    Picker("Power", selection: $selectedPlayerFaction) {
                        ForEach(availableFactions) { faction in
                            Text(faction.displayName).tag(faction)
                        }
                    }
                    Text(otherFactionsControlDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Opening Turn") {
                    Toggle("Begin with selected power", isOn: $startsAtPlayerFaction)
                    Text(openingTurnDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Settings") {
                    Toggle("Observer Mode", isOn: $observerModeEnabled)

                    Picker("Map Layer", selection: $selectedMapDisplayLayer) {
                        ForEach(MapDisplayLayer.allCases) { layer in
                            Text(layer.displayName(for: selectedPlayerFaction)).tag(layer)
                        }
                    }

                    Picker("Dispatch Detail", selection: $replayDetailLevel) {
                        ForEach(ReplayDetailLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Staff Pace", selection: $aiCommandPace) {
                        ForEach(AICommandPace.allCases) { pace in
                            Text(pace.displayName).tag(pace)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Staff Control", selection: $aiControlMode) {
                        ForEach(PlaytestAIControlMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Guide Notes", isOn: $playtestGuideCuesEnabled)

                    Toggle("Reduce Motion", isOn: $reduceMotionEnabled)

                    Picker("Text Size", selection: $playtestTextSize) {
                        ForEach(PlaytestTextSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let sessionSettingsRecoveryMessage {
                        Label(sessionSettingsRecoveryMessage, systemImage: "arrow.counterclockwise.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reset") {
                    Text("Starting a campaign reloads campaign data, clears selections and dispatch history, then keeps all orders inside the normal rules path.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", systemImage: "play.fill", action: submit)
                        .disabled(availableFactions.isEmpty)
                }
            }
            .onAppear(perform: reconcileSelectedFaction)
            .onChange(of: selectedScenarioId) { _, _ in
                reconcileSelectedFaction()
                clearOperationStatus()
            }
            .onChange(of: showCompatibilityCampaigns) { _, _ in
                reconcileSelectedScenario()
                reconcileSelectedFaction()
                clearOperationStatus()
            }
            .onChange(of: selectedPlayerFaction) { _, _ in
                clearOperationStatus()
            }
            .onChange(of: startsAtPlayerFaction) { _, _ in
                clearOperationStatus()
            }
            .onChange(of: selectedSaveSlot) { _, _ in
                selectedSaveSlotLabel = saveSlotLabels[selectedSaveSlot] ?? ""
                clearOperationStatus()
            }
            .onChange(of: observerModeEnabled) { _, _ in
                submitSettings()
            }
            .onChange(of: selectedMapDisplayLayer) { _, _ in
                submitSettings()
            }
            .onChange(of: replayDetailLevel) { _, _ in
                submitSettings()
            }
            .onChange(of: aiCommandPace) { _, _ in
                submitSettings()
            }
            .onChange(of: aiControlMode) { _, _ in
                submitSettings()
            }
            .onChange(of: playtestGuideCuesEnabled) { _, _ in
                submitSettings()
            }
            .onChange(of: reduceMotionEnabled) { _, _ in
                submitSettings()
            }
            .onChange(of: playtestTextSize) { _, _ in
                submitSettings()
            }
        }
    }

    private var selectedScenario: ScenarioCatalogEntry {
        scenarios.first { $0.id == selectedScenarioId } ?? currentScenario
    }

    private var visibleScenarios: [ScenarioCatalogEntry] {
        let visible = scenarios.filter {
            showCompatibilityCampaigns || !isCompatibilityScenario($0) || $0.id == currentScenario.id
        }
        return visible.isEmpty ? scenarios : visible
    }

    private var availableFactions: [Faction] {
        factionOptions(selectedScenario)
    }

    private var selectedSavedGameSummary: GameSaveSnapshot.Summary? {
        savedGameSummaries[selectedSaveSlot]
    }

    private var selectedSavedGameRecoveryMessage: String? {
        savedGameRecoveryMessages[selectedSaveSlot]
    }

    private var saveSlotLabelChanged: Bool {
        GameSaveSlot.normalizedLabel(selectedSaveSlotLabel) !=
            GameSaveSlot.normalizedLabel(saveSlotLabels[selectedSaveSlot] ?? "")
    }

    private func reconcileSelectedFaction() {
        guard !availableFactions.contains(selectedPlayerFaction) else {
            return
        }
        selectedPlayerFaction = availableFactions.contains(selectedScenario.defaultPlayerFaction)
            ? selectedScenario.defaultPlayerFaction
            : (availableFactions.first ?? currentPlayerFaction)
    }

    private func reconcileSelectedScenario() {
        guard !visibleScenarios.contains(where: { $0.id == selectedScenarioId }) else {
            return
        }
        selectedScenarioId = visibleScenarios.first?.id ?? currentScenario.id
    }

    private func submit() {
        let result = onStart(selectedScenario, selectedPlayerFaction, startsAtPlayerFaction)
        if !result.succeeded {
            setOperationStatus(result)
        }
    }

    private func saveCurrentGame() {
        persistSaveSlotLabelIfNeeded()
        setOperationStatus(onSaveCurrent(selectedSaveSlot))
    }

    private func continueSavedGame() {
        let result = onContinueSaved(selectedSaveSlot)
        if !result.succeeded {
            setOperationStatus(result)
        }
    }

    private func clearSavedGame() {
        setOperationStatus(onClearSaved(selectedSaveSlot))
    }

    private func renameSaveSlot() {
        persistSaveSlotLabelIfNeeded()
    }

    private func showCompatibilitySavedGame() {
        showCompatibilityCampaigns = true
        if let savedGameSummary = selectedSavedGameSummary,
           let scenario = scenarios.first(where: { $0.matches(savedGameSummary.scenarioId) }) {
            selectedScenarioId = scenario.id
            let scenarioFactions = factionOptions(scenario)
            if scenarioFactions.contains(savedGameSummary.playerFaction) {
                selectedPlayerFaction = savedGameSummary.playerFaction
            }
        }
        reconcileSelectedFaction()
        clearOperationStatus()
    }

    private func persistSaveSlotLabelIfNeeded() {
        guard saveSlotLabelChanged else {
            return
        }
        let result = onRenameSaveSlot(selectedSaveSlot, selectedSaveSlotLabel)
        selectedSaveSlotLabel = GameSaveSlot.normalizedLabel(selectedSaveSlotLabel) ?? ""
        setOperationStatus(result)
    }

    private func setOperationStatus(_ result: (succeeded: Bool, message: String)) {
        operationStatusMessage = result.message
        operationSucceeded = result.succeeded
    }

    private func clearOperationStatus() {
        operationStatusMessage = nil
        operationSucceeded = nil
    }

    private func submitSettings() {
        onSettingsChange(
            observerModeEnabled,
            selectedMapDisplayLayer,
            replayDetailLevel,
            aiCommandPace,
            aiControlMode,
            playtestGuideCuesEnabled,
            playtestTextSize,
            reduceMotionEnabled
        )
    }

    private var openingTurnDescription: String {
        if startsAtPlayerFaction {
            return "The first orders phase is assigned to the selected power."
        }
        switch aiControlMode {
        case .simulatedStaff:
            return "The scenario's scripted opening power acts first; other powers use the simulated staff."
        case .manualAdvance:
            return "The scenario's scripted opening power acts first; other powers wait for manual End Orders."
        }
    }

    private var otherFactionsControlDescription: String {
        switch aiControlMode {
        case .simulatedStaff:
            return "Other non-neutral powers are controlled by the simulated staff."
        case .manualAdvance:
            return "Other non-neutral powers wait for manual End Orders."
        }
    }

    private var operationStatusIcon: String {
        operationSucceeded == true ? "checkmark.circle" : "exclamationmark.triangle"
    }

    private var operationStatusStyle: Color {
        operationSucceeded == true ? .green : .orange
    }

    private func saveSlotDisplayName(_ slot: GameSaveSlot) -> String {
        slot.displayName(using: saveSlotLabels)
    }

    private func isHiddenCompatibilitySummary(_ summary: GameSaveSnapshot.Summary) -> Bool {
        guard !showCompatibilityCampaigns,
              let scenario = scenarios.first(where: { $0.matches(summary.scenarioId) }) else {
            return false
        }
        return isCompatibilityScenario(scenario)
    }

    private func isCompatibilityScenario(_ scenario: ScenarioCatalogEntry) -> Bool {
        scenario.migrationStage == "legacy_wwii"
    }
}
