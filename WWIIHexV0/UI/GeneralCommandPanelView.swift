import SwiftUI

struct GeneralCommandPanelView: View {
    let zone: FrontZone?
    let activeFaction: Faction
    let general: GeneralData?
    let assignment: GeneralAssignment?
    let assignedDivisions: [Division]
    let targetRegion: RegionNode?
    let targetZone: FrontZone?
    let hqUnderAttack: Bool
    let plannedOperations: [PlayerPlannedOperation]
    let canHoldLine: Bool
    let canAttackRegion: Bool
    let onShowProfile: () -> Void
    let onHoldLine: () -> Void
    let onAttackRegion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label("General Command"))
                .font(.headline)
                .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            if let zone {
                LabeledContent(label("Front Zone")) {
                    Text(frontZoneDisplayText(zone))
                        .multilineTextAlignment(.trailing)
                }
            } else {
                Text(label("No friendly front zone selected."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let general {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Button(action: onShowProfile) {
                            portraitBadge(for: general)
                        }
                            .accessibilityLabel(profileAccessibilityLabel(for: general))
                            .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(general.localizedName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(general.rank) / \(styleLabel(general.commandStyle))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(general.biography)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !general.skills.isEmpty {
                        Text(general.skills.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let assignment {
                        metricBar(title: label("Loyalty"), value: assignment.loyalty)
                        metricBar(title: label("Satisfaction"), value: assignment.satisfaction)
                        LabeledContent(label("Interventions")) {
                            Text("\(assignment.interventionCount)")
                        }
                    }

                    Button(label("View Profile"), systemImage: "person.text.rectangle", action: onShowProfile)
                        .buttonStyle(.bordered)
                }
            } else if zone != nil {
                Text(label("No general assigned to this zone."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hqUnderAttack {
                Label(label("HQ region contested"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if !assignedDivisions.isEmpty {
                Text(label("Assigned Units"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(assignedDivisions.prefix(5)), id: \.id) { division in
                        Label(displayDivisionName(division), systemImage: unitIcon(for: division))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            if let targetRegion, canAttackRegion {
                LabeledContent(label("Target")) {
                    Text(targetRegion.name)
                }
            }

            HStack(spacing: 8) {
                Button(label("Hold Line"), systemImage: "shield.fill", action: onHoldLine)
                    .disabled(!canHoldLine)
                Button(label("Attack Region"), systemImage: "arrow.up.right.circle", action: onAttackRegion)
                    .disabled(!canAttackRegion)
            }
            .buttonStyle(.bordered)

            if !plannedOperations.isEmpty {
                Text(label("Planned Operations"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plannedOperations) { operation in
                        Label(operationSummary(operation), systemImage: operationIcon(operation))
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func label(_ legacy: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "General Command":
            return "Corps Command"
        case "Front Zone":
            return "Corps Sector"
        case "No friendly front zone selected.":
            return "No friendly corps sector selected."
        case "No general assigned to this zone.":
            return "No commander assigned to this sector."
        case "HQ region contested":
            return "Headquarters sector contested"
        case "Assigned Units":
            return "Assigned Formations"
        case "Target":
            return "Target Sector"
        case "Hold Line":
            return "Hold Contact Line"
        case "Attack Region":
            return "Attack Sector"
        case "Planned Operations":
            return "Planned Orders"
        case "View Profile":
            return "Commander Profile"
        case "Satisfaction":
            return "Confidence"
        case "Interventions":
            return "Command Interventions"
        default:
            return legacy
        }
    }

    private func portraitBadge(for general: GeneralData) -> some View {
        Text(initials(for: general))
            .font(.caption.weight(.bold))
            .frame(width: 40, height: 40)
            .background(PlatformStyles.selectionTint)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(portraitAccessibilityLabel(for: general))
    }

    private func profileAccessibilityLabel(for general: GeneralData) -> String {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return "Open commander profile for \(general.localizedName)"
        }

        return "Open profile for \(general.localizedName)"
    }

    private func portraitAccessibilityLabel(for general: GeneralData) -> String {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return "\(general.localizedName) commander portrait placeholder"
        }

        return "\(general.localizedName) portrait placeholder"
    }

    private func metricBar(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
            }
            .font(.caption)
            ProgressView(value: Double(value), total: 100)
                .tint(value >= 65 ? .green : value >= 40 ? .orange : .red)
        }
    }

    private func initials(for general: GeneralData) -> String {
        let words = general.localizedName.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(general.name.prefix(2)).uppercased() : String(letters).uppercased()
    }

    private func styleLabel(_ style: ZoneCommanderAgentConfig.CommandStyle) -> String {
        switch style {
        case .aggressive:
            return "Aggressive"
        case .balanced:
            return "Balanced"
        case .cautious:
            return "Cautious"
        }
    }

    private func displayDivisionName(_ division: Division) -> String {
        NapoleonicMessageSanitizer.displayText(division.name, for: activeFaction)
    }

    private func unitIcon(for division: Division) -> String {
        if division.isArmor {
            return "shield.lefthalf.filled"
        }
        if division.isArtillery {
            return "scope"
        }
        return "person.3.fill"
    }

    private func operationIcon(_ operation: PlayerPlannedOperation) -> String {
        operation.directiveType == .attack ? "arrow.up.right.circle" : "shield.fill"
    }

    private func frontZoneDisplayText(_ zone: FrontZone) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return zone.name
        }

        let name = zone.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty,
           name != zone.id.rawValue,
           !name.contains("_") {
            return NapoleonicMessageSanitizer.displayText(name, for: activeFaction)
        }
        return identifierDisplayText(zone.id.rawValue, fallback: "Corps Sector", suffix: " sector")
    }

    private func operationSummary(_ operation: PlayerPlannedOperation) -> String {
        let target = operationTargetDisplayName(operation)
        return "\(directiveLabel(operation.directiveType)) / \(target)"
    }

    private func operationTargetDisplayName(_ operation: PlayerPlannedOperation) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return operation.targetRegionId?.rawValue ?? operation.sourceRegionId?.rawValue ?? operation.zoneId.rawValue
        }

        if let targetRegionId = operation.targetRegionId {
            if targetRegion?.id == targetRegionId,
               let name = targetRegion?.name,
               !name.isEmpty {
                return name
            }
            return identifierDisplayText(targetRegionId.rawValue, fallback: "Target Sector", suffix: " sector")
        }

        if let sourceRegionId = operation.sourceRegionId {
            return identifierDisplayText(sourceRegionId.rawValue, fallback: "Source Sector", suffix: " sector")
        }

        if zone?.id == operation.zoneId,
           let name = zone?.name,
           !name.isEmpty {
            return name
        }
        return identifierDisplayText(operation.zoneId.rawValue, fallback: "Corps Sector", suffix: " sector")
    }

    private func directiveLabel(_ type: DirectiveType) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
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
            "power", "faction", "global", "ruler", "germany", "german",
            "allies", "allied", "panzer", "tank", "motorized", "division",
            "wwii", "ardennes", "bastogne"
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
}
