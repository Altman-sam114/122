import SwiftUI

struct EconomyPanelView: View {
    let gameState: GameState
    let playerFaction: Faction
    let observerModeEnabled: Bool
    let onQueueProduction: (ProductionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NapoleonicDesignTokens.sectionSpacing) {
            Text(panelTitle(for: gameState.activeFaction))
                .font(.headline)
                .foregroundStyle(gameState.activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            ledgerSection(for: gameState.activeFaction)

            Divider()

            productionControls

            Divider()

            queueSection(for: gameState.activeFaction)
        }
        .padding(NapoleonicDesignTokens.panelPadding)
        .background(NapoleonicDesignTokens.campaignPanelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius)
                .stroke(NapoleonicDesignTokens.campaignPanelStroke, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: NapoleonicDesignTokens.cornerRadius))
    }

    private func ledgerSection(for faction: Faction) -> some View {
        let ledger = gameState.economyState.ledger(for: faction)

        return VStack(alignment: .leading, spacing: 8) {
            Text(ledgerTitle(for: faction))
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    metric(manpowerLabel(for: faction), ledger.stockpile.manpower)
                    metric(industryLabel(for: faction), ledger.stockpile.industry)
                    metric(suppliesLabel(for: faction), ledger.stockpile.supplies)
                }

                GridRow {
                    metric(incomeManpowerLabel(for: faction), ledger.lastIncome.manpower)
                    metric(incomeIndustryLabel(for: faction), ledger.lastIncome.industry)
                    metric(upkeepLabel(for: faction), ledger.lastUpkeep.supplies)
                }
            }
        }
    }

    private var productionControls: some View {
        let faction = gameState.activeFaction

        return VStack(alignment: .leading, spacing: 8) {
            Text(productionTitle(for: faction))
                .font(.subheadline.weight(.semibold))

            ForEach(ProductionKind.allCases) { kind in
                Button {
                    onQueueProduction(kind)
                } label: {
                    Label(kind.displayName(for: faction), systemImage: iconName(for: kind, faction: faction))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!canQueue(kind))
                .tint(faction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : nil)

                Text("Cost \(resourceSummary(kind.cost, for: faction)) | \(kind.buildTurns) turn(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queueSection(for faction: Faction) -> some View {
        let queue = gameState.economyState.ledger(for: faction).productionQueue

        return VStack(alignment: .leading, spacing: 6) {
            Text(queueTitle(for: faction))
                .font(.subheadline.weight(.semibold))

            if queue.isEmpty {
                Text(emptyQueueText(for: faction))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(queue) { order in
                    HStack {
                        Text(order.kind.displayName(for: faction))
                            .lineLimit(1)
                        Spacer()
                        Text(order.isReady ? "Ready" : "\(order.remainingTurns)")
                            .foregroundStyle(order.isReady ? NapoleonicDesignTokens.steady : .secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NapoleonicDesignTokens.brass)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func canQueue(_ kind: ProductionKind) -> Bool {
        !observerModeEnabled &&
            gameState.activeFaction == playerFaction &&
            gameState.phase.allowsCommands &&
            gameState.economyState.ledger(for: gameState.activeFaction).stockpile.canAfford(kind.cost)
    }

    private func panelTitle(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Logistics" : "Economy"
    }

    private func ledgerTitle(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary
            ? "\(faction.displayName) Logistics Ledger"
            : "\(faction.displayName) Ledger"
    }

    private func manpowerLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Recruits" : "Manpower"
    }

    private func industryLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Ammunition/Horses" : "Industry"
    }

    private func suppliesLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Supplies" : "Supplies"
    }

    private func incomeManpowerLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Income Recruits" : "Income MP"
    }

    private func incomeIndustryLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Income Ammo/Horses" : "Income IC"
    }

    private func upkeepLabel(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Supply Upkeep" : "Upkeep"
    }

    private func productionTitle(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Reserves" : "Production"
    }

    private func queueTitle(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "Reserve Orders" : "Queue"
    }

    private func emptyQueueText(for faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "No reserve orders." : "No active orders."
    }

    private func resourceSummary(_ resources: EconomyResources, for faction: Faction) -> String {
        resources.summary(for: faction)
    }

    private func iconName(for kind: ProductionKind, faction: Faction) -> String {
        if faction.usesNapoleonicLogisticsVocabulary {
            switch kind {
            case .infantryDivision:
                return "figure.walk"
            case .panzerDivision:
                return "flag.fill"
            case .motorizedDivision:
                return "arrow.up.right"
            case .artilleryDivision:
                return "scope"
            case .supplyStockpile:
                return "shippingbox"
            }
        }

        switch kind {
        case .infantryDivision:
            return "figure.walk"
        case .panzerDivision:
            return "shield.lefthalf.filled"
        case .motorizedDivision:
            return "truck.box"
        case .artilleryDivision:
            return "scope"
        case .supplyStockpile:
            return "shippingbox"
        }
    }
}
