import SwiftUI

struct RegionInspectorView: View {
    let inspectorState: RegionInspectorState?
    let activeFaction: Faction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label("Region"))
                .font(.headline)
                .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            if let inspectorState {
                regionDetails(inspectorState)
            } else {
                Text(label("No region selected."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func regionDetails(_ state: RegionInspectorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.region.name)
                .font(.subheadline.weight(.semibold))

            if let selectedHex = state.selectedHex {
                LabeledContent("Hex") {
                    Text("\(selectedHex.q),\(selectedHex.r)")
                }

                LabeledContent(label("Hex Controller")) {
                    Text(state.selectedHexController?.displayName ?? "None")
                }

                LabeledContent(label("Hex Dynamic Theater")) {
                    Text(state.selectedHexDynamicTheaterDisplayName)
                }

                LabeledContent(label("Hex FrontZone")) {
                    Text(state.selectedHexFrontZoneDisplayName)
                }
            }

            LabeledContent(label("Controller")) {
                Text(state.region.controller.displayName)
            }

            LabeledContent(label("Terrain")) {
                Text(terrainDisplayName(state.region.terrain))
            }

            LabeledContent(label("City")) {
                Text(state.region.city?.name ?? "None")
            }

            LabeledContent(label("City Level")) {
                Text(state.cityLevel.displayName)
            }

            LabeledContent(label("Fortress")) {
                Text(state.region.terrain == .fortress ? label("Yes") : label("No"))
            }

            LabeledContent(label("Supply")) {
                Text("\(state.region.supplyValue)")
            }

            LabeledContent(label("Factories")) {
                Text("\(state.region.factories)")
            }

            LabeledContent(label("Output")) {
                Text(state.economicOutput.summary(for: activeFaction))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent(label("Theater")) {
                Text(state.theaterDisplayName)
            }

            LabeledContent(label("FrontZone")) {
                Text(state.frontZoneDisplayName)
            }

            LabeledContent(label("Front Pressure")) {
                Text(state.frontPressure, format: .number.precision(.fractionLength(2)))
            }

            LabeledContent(label("Infrastructure")) {
                Text("\(state.region.infrastructure)")
            }

            LabeledContent(label("Objectives")) {
                Text(state.objectiveNames.isEmpty ? "None" : state.objectiveNames.joined(separator: ", "))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent(label("Objective Status")) {
                Text(state.objectiveStatus)
            }

            LabeledContent(label("Friendly Units")) {
                Text(unitNames(state.friendlyDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent(label("Visible Enemies")) {
                Text(unitNames(state.visibleEnemyDivisions))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func label(_ legacy: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "Region":
            return "Sector"
        case "No region selected.":
            return "No sector selected."
        case "Hex Controller":
            return "Hex Control"
        case "Hex Dynamic Theater":
            return "Hex Active Wing"
        case "Hex FrontZone":
            return "Hex Corps Sector"
        case "Controller":
            return "Control"
        case "Terrain":
            return "Ground"
        case "City":
            return "Settlement"
        case "City Level":
            return "Settlement Level"
        case "Fortress":
            return "Strongpoint"
        case "Yes":
            return "Present"
        case "No":
            return "None"
        case "Supply":
            return "Logistics"
        case "Factories":
            return "Depots"
        case "Output":
            return "Logistics Output"
        case "Theater":
            return "Wing"
        case "FrontZone":
            return "Corps Sector"
        case "Front Pressure":
            return "Contact Pressure"
        case "Infrastructure":
            return "Roads & Works"
        case "Objectives":
            return "Battle Objectives"
        case "Objective Status":
            return "Objective Control"
        case "Friendly Units":
            return "Friendly Formations"
        case "Visible Enemies":
            return "Visible Enemy Formations"
        default:
            return legacy
        }
    }

    private func terrainDisplayName(_ terrain: BaseTerrain) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return terrain.displayName
        }

        switch terrain {
        case .fortress:
            return "Strongpoint"
        default:
            return terrain.displayName
        }
    }

    private func unitNames(_ divisions: [Division]) -> String {
        guard !divisions.isEmpty else {
            return "None"
        }
        return divisions.map(\.name).joined(separator: ", ")
    }
}
