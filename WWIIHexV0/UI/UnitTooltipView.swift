import SwiftUI

struct UnitTooltipView: View {
    let division: Division?

    var body: some View {
        if let division {
            VStack(alignment: .leading, spacing: 6) {
                Text(division.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        label(label("Type", for: division))
                        value(division.tooltipTypeCode)
                    }
                    GridRow {
                        label(label("Strength", for: division))
                        value("\(division.strength)/\(division.maxStrength)")
                    }
                    GridRow {
                        label("Morale")
                        value(division.tooltipMoraleText, tone: division.tooltipMoraleTone)
                    }
                    GridRow {
                        label(label("Supply", for: division))
                        value(division.supplyState.tooltipDisplayName(for: division.faction))
                    }
                    GridRow {
                        label("Fatigue")
                        value(division.tooltipFatigueText, tone: division.tooltipFatigueTone)
                    }
                    GridRow {
                        label("Ammo")
                        value(division.tooltipAmmunitionText, tone: division.tooltipAmmunitionTone)
                    }
                    GridRow {
                        label(label("Retreat", for: division))
                        value(retreatModeDisplayName(for: division))
                    }
                    GridRow {
                        label(label("Acted", for: division))
                        value(actionStateText(for: division))
                    }
                }
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius)
                    .stroke(NapoleonicDesignTokens.campaignPanelStroke, lineWidth: 1)
            }
            .padding(10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary(for: division))
        }
    }

    private func label(_ legacy: String, for division: Division) -> String {
        guard division.faction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "Type":
            return "Formation"
        case "Strength":
            return "Formation Strength"
        case "Supply":
            return "Logistics"
        case "Retreat":
            return "Withdrawal"
        case "Acted":
            return "Orders"
        default:
            return legacy
        }
    }

    private func accessibilitySummary(for division: Division) -> String {
        if division.faction.usesNapoleonicLogisticsVocabulary {
            return "\(division.name), \(division.tooltipTypeCode), formation strength \(division.strength) of \(division.maxStrength)"
        }

        return "\(division.name), \(division.tooltipTypeCode), strength \(division.strength) of \(division.maxStrength)"
    }

    private func retreatModeDisplayName(for division: Division) -> String {
        guard division.faction.usesNapoleonicLogisticsVocabulary else {
            return division.retreatMode.tooltipDisplayName
        }

        switch division.retreatMode {
        case .retreatable:
            return "Withdrawal Ordered"
        case .hold:
            return "Hold Line"
        }
    }

    private func actionStateText(for division: Division) -> String {
        if division.faction.usesNapoleonicLogisticsVocabulary {
            return division.hasActed ? "Spent" : "Available"
        }

        return division.hasActed ? "Yes" : "No"
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func value(_ text: String, tone: Color = .primary) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private extension Division {
    var tooltipTypeCode: String {
        if faction.usesNapoleonicLogisticsVocabulary {
            return napoleonicTooltipTypeCode
        }

        if isArtillery {
            return "ART"
        }
        if isArmor {
            return "ARM"
        }
        if isCavalry {
            return "CAV"
        }
        if isMobileFormation {
            return "MOT"
        }
        return "INF"
    }

    private var napoleonicTooltipTypeCode: String {
        if components.contains(where: { $0.type == .supplyTrain && $0.weight >= 0.25 }) {
            return "SUP"
        }
        if components.contains(where: { $0.type == .guardInfantry && $0.weight >= 0.25 }) {
            return "GUARD"
        }
        if isArtillery {
            return "ART"
        }
        if isCavalry {
            return "CAV"
        }
        if components.contains(where: { $0.type == .lightInfantry && $0.weight >= 0.25 }) {
            return "LIGHT"
        }
        if components.contains(where: { $0.type == .engineer && $0.weight >= 0.25 }) {
            return "ENG"
        }
        return "LINE"
    }

    var tooltipMoraleText: String {
        if morale <= Division.brokenMoraleThreshold {
            return "Broken \(morale)"
        }
        if morale <= Division.shakenMoraleThreshold {
            return "Shaken \(morale)"
        }
        return "Steady \(morale)"
    }

    var tooltipFatigueText: String {
        if fatigue >= 70 {
            return "Exhausted \(fatigue)"
        }
        if fatigue >= 40 {
            return "Tired \(fatigue)"
        }
        return "Fresh \(fatigue)"
    }

    var tooltipAmmunitionText: String {
        if isAmmunitionSensitive && ammunition == 0 {
            return "Empty \(ammunition)/\(maxAmmunition)"
        }
        if isAmmunitionSensitive && isLowAmmunition {
            return "Low \(ammunition)/\(maxAmmunition)"
        }
        return "Ready \(ammunition)/\(maxAmmunition)"
    }

    var tooltipMoraleTone: Color {
        if morale <= Division.brokenMoraleThreshold {
            return NapoleonicDesignTokens.critical
        }
        if morale <= Division.shakenMoraleThreshold {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    var tooltipFatigueTone: Color {
        if fatigue >= 70 {
            return NapoleonicDesignTokens.critical
        }
        if fatigue >= 40 {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    var tooltipAmmunitionTone: Color {
        if isAmmunitionSensitive && ammunition == 0 {
            return NapoleonicDesignTokens.critical
        }
        if isAmmunitionSensitive && isLowAmmunition {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }
}

private extension RetreatMode {
    var tooltipDisplayName: String {
        switch self {
        case .retreatable:
            return "Retreatable"
        case .hold:
            return "Hold"
        }
    }
}

private extension SupplyState {
    func tooltipDisplayName(for faction: Faction) -> String {
        if faction.usesNapoleonicLogisticsVocabulary {
            switch self {
            case .supplied:
                return "Ready"
            case .lowSupply:
                return "Short"
            case .encircled:
                return "Isolated"
            }
        }

        switch self {
        case .supplied:
            return "Supplied"
        case .lowSupply:
            return "Low"
        case .encircled:
            return "Encircled"
        }
    }
}
