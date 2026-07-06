import SwiftUI

struct HUDView: View {
    let gameState: GameState
    let playerFaction: Faction?
    let aiControlMode: PlaytestAIControlMode
    let canAdvanceOrders: Bool
    let observerModeEnabled: Bool
    let onEndTurn: () -> Void
    let onNewGame: (() -> Void)?

    init(
        gameState: GameState,
        playerFaction: Faction? = nil,
        aiControlMode: PlaytestAIControlMode = .simulatedStaff,
        canAdvanceOrders: Bool = true,
        observerModeEnabled: Bool = false,
        onEndTurn: @escaping () -> Void,
        onNewGame: (() -> Void)? = nil
    ) {
        self.gameState = gameState
        self.playerFaction = playerFaction
        self.aiControlMode = aiControlMode
        self.canAdvanceOrders = canAdvanceOrders
        self.observerModeEnabled = observerModeEnabled
        self.onEndTurn = onEndTurn
        self.onNewGame = onNewGame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NapoleonicDesignTokens.sectionSpacing) {
            HStack {
                Text(scenarioTitle)
                    .font(.headline)
                    .foregroundStyle(headerTint)

                Spacer()

                if let onNewGame {
                    NewGameButton(title: label("New Game"), action: onNewGame)
                }

                Button(action: onEndTurn) {
                    Label(label("End Turn"), systemImage: "forward.end")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvanceOrders)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    metric("Turn", "\(gameState.turn) / \(gameState.maxTurns)")
                    metric("Faction", gameState.activeFaction.displayName)
                }

                GridRow {
                    metric("Phase", phaseText)
                    metric("Victory", victoryText)
                }

                GridRow {
                    metric(manpowerLabel, "\(activeLedger.stockpile.manpower)")
                    metric(industryLabel, "\(activeLedger.stockpile.industry)")
                }

                GridRow {
                    metric("Supplies", "\(activeLedger.stockpile.supplies)")
                    metric(queueLabel, "\(activeLedger.productionQueue.count)")
                }

                GridRow {
                    metric(label("Reinforcements"), "\(pendingReinforcementCount)")
                    metric("Fatigue", fatigueSummary, tone: fatigueTone)
                }

                GridRow {
                    metric("Morale", moraleSummary, tone: moraleTone)
                    metric("Readiness", readinessSummary, tone: readinessTone)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NapoleonicDesignTokens.panelPadding)
        .background(NapoleonicDesignTokens.campaignPanelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius)
                .stroke(NapoleonicDesignTokens.campaignPanelStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius))
    }

    private func metric(_ label: String, _ value: String, tone: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: NapoleonicDesignTokens.metricSpacing) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerTint: Color {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary
    }

    private var scenarioTitle: String {
        ScenarioCatalog.displayName(for: gameState.scenarioId)
    }

    private var usesNapoleonicVocabulary: Bool {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary
    }

    private func label(_ legacy: String) -> String {
        guard usesNapoleonicVocabulary else {
            return legacy
        }

        switch legacy {
        case "New Game":
            return "New Campaign"
        case "End Turn":
            return "End Orders"
        case "Reinforcements":
            return "Reserve Arrivals"
        default:
            return legacy
        }
    }

    private var victoryText: String {
        guard let winner = gameState.victoryState.winner else {
            return "Ongoing"
        }
        return "\(winner.displayName) Victory"
    }

    private var activeLedger: FactionEconomyLedger {
        gameState.economyState.ledger(for: gameState.activeFaction)
    }

    private var manpowerLabel: String {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary ? "Recruits" : "Manpower"
    }

    private var industryLabel: String {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary ? "Ammo/Horses" : "Industry"
    }

    private var queueLabel: String {
        gameState.activeFaction.usesNapoleonicLogisticsVocabulary ? "Reserve Orders" : "Queue"
    }

    private var phaseText: String {
        guard let playerFaction,
              gameState.phase.allowsCommands,
              !gameState.activeFaction.isNeutral else {
            return gameState.phase.displayName
        }

        if observerModeEnabled {
            if aiControlMode == .manualAdvance {
                return usesNapoleonicVocabulary ? "Manual Observation" : "Observer Manual"
            }

            return usesNapoleonicVocabulary ? "Staff Dispatch" : "AI Command"
        }

        if gameState.activeFaction == playerFaction {
            return usesNapoleonicVocabulary ? "Your Orders" : "Player Command"
        }

        if aiControlMode == .manualAdvance {
            return usesNapoleonicVocabulary ? "Manual Dispatch" : "Manual Command"
        }

        return usesNapoleonicVocabulary ? "Staff Dispatch" : "AI Command"
    }

    private var pendingReinforcementCount: Int {
        gameState.reinforcementState.pending.filter { $0.division.faction == gameState.activeFaction }.count
    }

    private var activeDivisions: [Division] {
        gameState.divisions.filter {
            $0.faction == gameState.activeFaction && !$0.isDestroyed
        }
    }

    private var averageFatigue: Int {
        guard !activeDivisions.isEmpty else {
            return 0
        }
        return activeDivisions.reduce(0) { $0 + $1.fatigue } / activeDivisions.count
    }

    private var averageMorale: Int {
        guard !activeDivisions.isEmpty else {
            return 0
        }
        return activeDivisions.reduce(0) { $0 + $1.morale } / activeDivisions.count
    }

    private var fatigueSummary: String {
        guard !activeDivisions.isEmpty else {
            return usesNapoleonicVocabulary ? "No Formations" : "No Units"
        }
        if averageFatigue >= 70 {
            return "Exhausted \(averageFatigue)"
        }
        if averageFatigue >= 40 {
            return "Tired \(averageFatigue)"
        }
        return "Fresh \(averageFatigue)"
    }

    private var moraleSummary: String {
        guard !activeDivisions.isEmpty else {
            return usesNapoleonicVocabulary ? "No Formations" : "No Units"
        }
        if averageMorale <= Division.brokenMoraleThreshold {
            return "Broken \(averageMorale)"
        }
        if averageMorale <= Division.shakenMoraleThreshold {
            return "Shaken \(averageMorale)"
        }
        return "Steady \(averageMorale)"
    }

    private var fatigueTone: Color {
        guard !activeDivisions.isEmpty else {
            return .secondary
        }
        if averageFatigue >= 70 {
            return NapoleonicDesignTokens.critical
        }
        if averageFatigue >= 40 {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    private var moraleTone: Color {
        guard !activeDivisions.isEmpty else {
            return .secondary
        }
        if averageMorale <= Division.brokenMoraleThreshold {
            return NapoleonicDesignTokens.critical
        }
        if averageMorale <= Division.shakenMoraleThreshold {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    private var readinessSummary: String {
        guard !activeDivisions.isEmpty else {
            return usesNapoleonicVocabulary ? "No Formations" : "No Units"
        }
        let warnings = activeDivisions.filter {
            $0.isLowMorale || $0.fatigue >= 70 || ($0.isAmmunitionSensitive && $0.isLowAmmunition)
        }.count
        let ready = max(0, activeDivisions.count - warnings)
        return warnings == 0 ? "Ready \(ready) / \(activeDivisions.count)" : "Strained \(ready) / \(activeDivisions.count)"
    }

    private var readinessTone: Color {
        guard !activeDivisions.isEmpty else {
            return .secondary
        }
        let warnings = activeDivisions.filter {
            $0.isLowMorale || $0.fatigue >= 70 || ($0.isAmmunitionSensitive && $0.isLowAmmunition)
        }.count
        return warnings == 0 ? NapoleonicDesignTokens.steady : NapoleonicDesignTokens.warning
    }
}
