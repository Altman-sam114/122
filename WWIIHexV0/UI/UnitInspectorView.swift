import SwiftUI

struct UnitInspectorView: View {
    let division: Division?
    let activeFaction: Faction
    let playerFaction: Faction
    let strategicState: UnitInspectorStrategicState?

    var body: some View {
        VStack(alignment: .leading, spacing: NapoleonicDesignTokens.sectionSpacing) {
            Text(label("Unit Details"))
                .font(.headline)
                .foregroundStyle(usesNapoleonicVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            if let division {
                unitDetails(division)
            } else {
                Text(label("No unit selected."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(NapoleonicDesignTokens.panelPadding)
        .background(NapoleonicDesignTokens.campaignPanelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius)
                .stroke(NapoleonicDesignTokens.campaignPanelStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: NapoleonicDesignTokens.cornerRadius))
    }

    private func unitDetails(_ division: Division) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(division.name)
                .font(.subheadline.weight(.semibold))

            LabeledContent(label("Faction")) {
                Text(division.faction.displayName)
            }

            LabeledContent(label("Mode")) {
                Text(division.faction == playerFaction ? "Player" : "Read-only")
            }

            if let strategicState {
                LabeledContent("Hex") {
                    Text("\(strategicState.coord.q),\(strategicState.coord.r)")
                }

                LabeledContent(label("Region")) {
                    Text(strategicState.regionId?.rawValue ?? "None")
                }

                LabeledContent(label("Dynamic Theater")) {
                    Text(strategicState.dynamicTheaterId?.rawValue ?? "None")
                }

                LabeledContent(label("FrontZone")) {
                    Text(strategicState.frontZoneId?.rawValue ?? "None")
                }

                LabeledContent(label("Deploy")) {
                    Text(strategicState.deploymentRole.displayName(for: inspectionFaction))
                }

                LabeledContent(label("FrontLine")) {
                    Text(frontLineSummary(strategicState.frontLineIds))
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent(label("Strength")) {
                Text(division.inspectorStrengthText)
            }

            LabeledContent(label("Morale")) {
                statusValue(
                    moraleDisplayText(for: division),
                    systemImage: "heart.text.square",
                    tone: moraleTone(for: division)
                )
            }

            LabeledContent(label("Retreat Mode")) {
                Text(retreatModeDisplayName(for: division))
            }

            LabeledContent(label("Supply")) {
                Text(division.supplyState.displayName(for: inspectionFaction))
            }

            LabeledContent(label("Fatigue")) {
                statusValue(
                    fatigueDisplayText(for: division),
                    systemImage: "speedometer",
                    tone: fatigueTone(for: division)
                )
            }

            LabeledContent(label("Ammunition")) {
                statusValue(
                    ammunitionDisplayText(for: division),
                    systemImage: "scope",
                    tone: ammunitionTone(for: division)
                )
            }

            LabeledContent(label("Has Acted")) {
                Text(division.hasActed ? "Yes" : "No")
            }

            LabeledContent(label("Status")) {
                statusValue(
                    division.inspectorStatusText,
                    systemImage: division.isCombatStrained ? "exclamationmark.triangle" : "checkmark.seal",
                    tone: division.isCombatStrained ? NapoleonicDesignTokens.warning : NapoleonicDesignTokens.steady
                )
            }

            LabeledContent(label("Components")) {
                Text(componentSummary(for: division))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var inspectionFaction: Faction {
        division?.faction ?? activeFaction
    }

    private var usesNapoleonicVocabulary: Bool {
        inspectionFaction.usesNapoleonicLogisticsVocabulary
    }

    private func label(_ legacy: String) -> String {
        guard usesNapoleonicVocabulary else {
            return legacy
        }

        switch legacy {
        case "Unit Details":
            return "Formation Details"
        case "No unit selected.":
            return "No formation selected."
        case "Faction":
            return "Allegiance"
        case "Mode":
            return "Control"
        case "Region":
            return "Sector"
        case "Dynamic Theater":
            return "Active Wing"
        case "FrontZone":
            return "Corps Sector"
        case "Deploy":
            return "Deployment"
        case "FrontLine":
            return "Contact Line"
        case "Retreat Mode":
            return "Withdrawal Orders"
        case "Supply":
            return "Logistics"
        case "Has Acted":
            return "Orders Spent"
        case "Status":
            return "Readiness"
        case "Components":
            return "Composition"
        default:
            return legacy
        }
    }

    private func componentSummary(for division: Division) -> String {
        division.components
            .map { "\($0.type.displayCode) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: " / ")
    }

    private func frontLineSummary(_ ids: [FrontLineId]) -> String {
        ids.isEmpty ? "None" : ids.map(\.rawValue).joined(separator: ", ")
    }

    private func statusValue(_ text: String, systemImage: String, tone: Color) -> some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func moraleDisplayText(for division: Division) -> String {
        if division.morale <= Division.brokenMoraleThreshold {
            return "Broken \(division.morale) / \(Division.maximumMorale)"
        }
        if division.morale <= Division.shakenMoraleThreshold {
            return "Shaken \(division.morale) / \(Division.maximumMorale)"
        }
        return "Steady \(division.morale) / \(Division.maximumMorale)"
    }

    private func fatigueDisplayText(for division: Division) -> String {
        if division.fatigue >= 70 {
            return "Exhausted \(division.fatigue) / \(Division.maximumFatigue)"
        }
        if division.fatigue >= 40 {
            return "Tired \(division.fatigue) / \(Division.maximumFatigue)"
        }
        return "Fresh \(division.fatigue) / \(Division.maximumFatigue)"
    }

    private func ammunitionDisplayText(for division: Division) -> String {
        if division.isAmmunitionSensitive && division.ammunition == 0 {
            return "Empty \(division.ammunition) / \(division.maxAmmunition)"
        }
        if division.isAmmunitionSensitive && division.isLowAmmunition {
            return "Low \(division.ammunition) / \(division.maxAmmunition)"
        }
        return "Ready \(division.ammunition) / \(division.maxAmmunition)"
    }

    private func retreatModeDisplayName(for division: Division) -> String {
        guard usesNapoleonicVocabulary else {
            return division.retreatMode.displayName
        }

        switch division.retreatMode {
        case .retreatable:
            return "Withdrawal allowed"
        case .hold:
            return "Hold line"
        }
    }

    private func moraleTone(for division: Division) -> Color {
        if division.morale <= Division.brokenMoraleThreshold {
            return NapoleonicDesignTokens.critical
        }
        if division.morale <= Division.shakenMoraleThreshold {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    private func fatigueTone(for division: Division) -> Color {
        if division.fatigue >= 70 {
            return NapoleonicDesignTokens.critical
        }
        if division.fatigue >= 40 {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }

    private func ammunitionTone(for division: Division) -> Color {
        if division.isAmmunitionSensitive && division.ammunition == 0 {
            return NapoleonicDesignTokens.critical
        }
        if division.isAmmunitionSensitive && division.isLowAmmunition {
            return NapoleonicDesignTokens.warning
        }
        return NapoleonicDesignTokens.steady
    }
}

private extension Division {
    var inspectorStrengthText: String {
        "\(strength) / \(maxStrength)"
    }

    var inspectorStatusText: String {
        var statuses: [String] = []

        if isRetreating {
            statuses.append("Retreating")
        }

        if isDestroyed {
            statuses.append("Destroyed")
        }

        if fatigue >= 70 {
            statuses.append("Exhausted")
        } else if fatigue >= 40 {
            statuses.append("Tired")
        }

        if morale <= Division.brokenMoraleThreshold {
            statuses.append("Broken Morale")
        } else if morale <= Division.shakenMoraleThreshold {
            statuses.append("Shaken")
        }

        if isAmmunitionSensitive && ammunition == 0 {
            statuses.append("No Ammunition")
        } else if isAmmunitionSensitive && isLowAmmunition {
            statuses.append("Low Ammunition")
        }

        return statuses.isEmpty ? "Ready" : statuses.joined(separator: ", ")
    }

    var isCombatStrained: Bool {
        isRetreating ||
            isDestroyed ||
            fatigue >= 70 ||
            isLowMorale ||
            (isAmmunitionSensitive && isLowAmmunition)
    }
}

private extension RetreatMode {
    var displayName: String {
        switch self {
        case .retreatable:
            return "Retreatable"
        case .hold:
            return "Hold"
        }
    }
}

private extension ComponentType {
    var displayCode: String {
        switch self {
        case .tank:
            return "ARM"
        case .motorizedInfantry:
            return "MOT"
        case .infantry:
            return "INF"
        case .artillery:
            return "ART"
        case .lineInfantry:
            return "LINE"
        case .lightInfantry:
            return "LIGHT"
        case .cavalry:
            return "CAV"
        case .guardInfantry:
            return "GUARD"
        case .engineer:
            return "ENG"
        case .supplyTrain:
            return "SUP"
        }
    }
}

private extension SupplyState {
    func displayName(for faction: Faction) -> String {
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
            return "Low Supply"
        case .encircled:
            return "Encircled"
        }
    }
}

private extension UnitDeploymentRole {
    func displayName(for faction: Faction) -> String {
        if faction.usesNapoleonicLogisticsVocabulary {
            switch self {
            case .frontUnit:
                return "Contact Line"
            case .depthUnit:
                return "Reserve"
            case .garrisonUnit:
                return "Strongpoint"
            }
        }

        switch self {
        case .frontUnit:
            return "FRONT"
        case .depthUnit:
            return "DEPTH"
        case .garrisonUnit:
            return "GARRISON"
        }
    }
}

private extension Set where Element == HexDirection {
    var displaySummary: String {
        HexDirection.ordered
            .filter { contains($0) }
            .map(\.displayCode)
            .joined(separator: ", ")
    }
}

private extension HexDirection {
    var displayCode: String {
        switch self {
        case .east:
            return "E"
        case .northEast:
            return "NE"
        case .northWest:
            return "NW"
        case .west:
            return "W"
        case .southWest:
            return "SW"
        case .southEast:
            return "SE"
        }
    }
}
