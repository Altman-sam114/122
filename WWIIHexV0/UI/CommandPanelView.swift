import SwiftUI

struct CommandPanelView: View {
    let selectedDivision: Division?
    let activeFaction: Faction
    let phase: GamePhase
    let playerFaction: Faction
    let aiControlMode: PlaytestAIControlMode
    let canAdvanceOrders: Bool
    let observerModeEnabled: Bool
    let lastCommandMessage: String?
    let playerOrdersStatusMessage: String?
    let onHold: () -> Void
    let onAllowRetreat: () -> Void
    let onResupply: () -> Void
    let onEndTurn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label("Commands"))
                .font(.headline)
                .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onHold) {
                    Label(label("Hold"), systemImage: "shield.fill")
                }
                .disabled(!canSetHold)

                Button(action: onAllowRetreat) {
                    Label(label("Retreat OK"), systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(!canSetRetreatable)

                Button(action: onResupply) {
                    Label(label("Reinforce"), systemImage: "cross.circle")
                }
                .disabled(!canCommandSelectedUnit)
            }
            .buttonStyle(.bordered)

            Button(action: onEndTurn) {
                Label(label("End Turn"), systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvanceOrders)

            if let lastCommandMessage {
                Text(messageDisplayText(lastCommandMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var canCommandSelectedUnit: Bool {
        guard !observerModeEnabled else {
            return false
        }

        guard let selectedDivision else {
            return false
        }

        return selectedDivision.faction == playerFaction &&
            activeFaction == playerFaction &&
            phase.allowsCommands &&
            !selectedDivision.hasActed
    }

    private var canSetHold: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .hold
    }

    private var canSetRetreatable: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .retreatable
    }

    private var statusText: String {
        if observerModeEnabled {
            if canAdvanceOrders {
                return activeFaction.usesNapoleonicLogisticsVocabulary
                    ? "Observer mode: use End Orders to advance staff dispatch."
                    : "Observer mode: use End Turn to advance AI."
            }

            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Observer mode: orders disabled."
                : "Observer mode: commands disabled."
        }

        guard let selectedDivision else {
            if activeFaction != playerFaction && phase.allowsCommands {
                if aiControlMode == .manualAdvance {
                    return activeFaction.usesNapoleonicLogisticsVocabulary
                        ? "Manual dispatch: use End Orders to advance \(activeFaction.displayName)."
                        : "Manual command: use End Turn to advance \(activeFaction.displayName)."
                }

                return activeFaction.usesNapoleonicLogisticsVocabulary
                    ? "Staff dispatch is resolving \(activeFaction.displayName)."
                    : "AI command is resolving \(activeFaction.displayName)."
            }

            if let playerOrdersStatusMessage {
                return playerOrdersStatusMessage
            }

            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "No active formation selected."
                : "No active unit selected."
        }

        guard selectedDivision.faction == playerFaction else {
            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Enemy formation selected. Orders disabled."
                : "Enemy unit selected. Commands disabled."
        }

        guard activeFaction == playerFaction, phase.allowsCommands else {
            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Orders unavailable during \(phaseDisplayName)."
                : "Commands unavailable during \(phase.displayName)."
        }

        guard !selectedDivision.hasActed else {
            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Selected formation has spent its orders."
                : "Selected unit has acted."
        }

        return activeFaction.usesNapoleonicLogisticsVocabulary
            ? "Move/Attack orders ready."
            : "Move/Attack ready."
    }

    private func messageDisplayText(_ text: String) -> String {
        NapoleonicMessageSanitizer.displayText(text, for: activeFaction)
    }

    private var phaseDisplayName: String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return phase.displayName
        }

        switch phase {
        case .germanAI, .aiCommand:
            return "Staff Dispatch"
        case .alliedPlayer, .playerCommand:
            return "Orders"
        case .resolution:
            return "Resolution"
        }
    }

    private func label(_ legacy: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "Commands":
            return "Orders"
        case "Retreat OK":
            return "Withdraw OK"
        case "Reinforce":
            return "Rest & Supply"
        case "End Turn":
            return "End Orders"
        default:
            return legacy
        }
    }
}
