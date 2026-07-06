import SwiftUI

struct GeneralProfileView: View {
    let general: GeneralData
    let assignment: GeneralAssignment?
    let zone: FrontZone?
    let assignedDivisions: [Division]
    let activeFaction: Faction
    let hqUnderAttack: Bool
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    identityBlock
                    VStack(alignment: .leading, spacing: 12) {
                        biographyBlock
                        statusBlock
                    }
                }

                skillsBlock
                assignedUnitsBlock
            }
            .padding(18)
        }
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .top) {
            HStack {
                Text(label("General Profile"))
                    .font(.headline)
                    .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)
                Spacer()
                Button(label("Close"), systemImage: "xmark", action: onClose)
                    .buttonStyle(.bordered)
            }
            .padding(12)
            .background(PlatformStyles.systemBackground)
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(initials)
                .font(.title.weight(.bold))
                .frame(width: 112, height: 144)
                .background(PlatformStyles.selectionTint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(portraitAccessibilityLabel)

            Text(general.localizedName)
                .font(.title3.weight(.semibold))
            Text(general.rank)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(general.faction.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PlatformStyles.tertiarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(minWidth: 132, alignment: .leading)
    }

    private var biographyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Biography"))
                .font(.headline)
            Text(general.biography)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent(label("Command Style")) {
                Text(styleLabel(general.commandStyle))
            }
            if let zone {
                LabeledContent(label("Assigned Zone")) {
                    Text(zone.name)
                        .multilineTextAlignment(.trailing)
                }
            }
            if hqUnderAttack {
                Label(label("HQ region contested"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Relationship"))
                .font(.headline)
            metricBar(title: label("Loyalty"), value: assignment?.loyalty ?? general.baseLoyalty)
            metricBar(title: label("Satisfaction"), value: assignment?.satisfaction ?? general.baseSatisfaction)
            LabeledContent(label("Player Interventions")) {
                Text("\(assignment?.interventionCount ?? 0)")
            }
        }
    }

    private var skillsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Skills"))
                .font(.headline)
            if general.skills.isEmpty {
                Text(label("No explicit skills configured."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(general.skills, id: \.self) { skill in
                        Label(skill.replacingOccurrences(of: "_", with: " "), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PlatformStyles.tertiarySystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var assignedUnitsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Assigned Units"))
                .font(.headline)
            if assignedDivisions.isEmpty {
                Text(label("No active divisions assigned."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignedDivisions, id: \.id) { division in
                    LabeledContent(division.name) {
                        Text("\(division.strength)/\(division.maxStrength)")
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func metricBar(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
            }
            .font(.caption)
            ProgressView(value: Double(value), total: 100)
                .tint(metricTint(for: value))
        }
    }

    private func label(_ legacy: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "General Profile":
            return "Commander Profile"
        case "Biography":
            return "Service Record"
        case "Command Style":
            return "Command Temperament"
        case "Assigned Zone":
            return "Assigned Corps Sector"
        case "HQ region contested":
            return "Headquarters sector contested"
        case "Relationship":
            return "Command Relationship"
        case "Satisfaction":
            return "Confidence"
        case "Player Interventions":
            return "Command Interventions"
        case "Skills":
            return "Staff Qualities"
        case "No explicit skills configured.":
            return "No staff qualities configured."
        case "Assigned Units":
            return "Assigned Formations"
        case "No active divisions assigned.":
            return "No active formations assigned."
        default:
            return legacy
        }
    }

    private func metricTint(for value: Int) -> Color {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return value >= 65 ? NapoleonicDesignTokens.steady : value >= 40 ? NapoleonicDesignTokens.warning : NapoleonicDesignTokens.critical
        }

        return value >= 65 ? .green : value >= 40 ? .orange : .red
    }

    private var initials: String {
        let words = general.localizedName.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(general.name.prefix(2)).uppercased() : String(letters).uppercased()
    }

    private var portraitAccessibilityLabel: String {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return "\(general.localizedName) commander portrait placeholder"
        }

        return "\(general.localizedName) portrait placeholder"
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
}
