import SwiftUI

struct DiplomacyPanelView: View {
    let diplomacyState: DiplomacyState
    let activeFaction: Faction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label("Diplomacy"))
                .font(.headline)
                .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            if let rulerRecord = diplomacyState.latestRulerRecord {
                rulerSection(rulerRecord)
                Divider()
            }

            countrySection
            Divider()
            blocSection
            Divider()
            relationSection
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Countries"))
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.countries) { country in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.name)
                            .font(.caption.weight(.semibold))
                        Text("\(country.faction.displayName) | \(country.blocId.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(country.warSupport)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(country.faction == activeFaction ? .primary : .secondary)
                }
            }
        }
    }

    private var blocSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Blocs"))
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.blocs) { bloc in
                LabeledContent(bloc.name) {
                    Text(memberCountText(bloc.memberCountryIds.count))
                        .foregroundStyle(bloc.faction == activeFaction ? .primary : .secondary)
                }
                .font(.caption)
            }
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label("Relations"))
                .font(.subheadline.weight(.semibold))

            if diplomacyState.relations.isEmpty {
                Text(label("No diplomatic relations."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(diplomacyState.relations) { relation in
                    HStack {
                        Text("\(relation.firstCountryId.rawValue) - \(relation.secondCountryId.rawValue)")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(relation.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(relation.status.isHostile ? .red : .secondary)
                    }
                }
            }
        }
    }

    private func rulerSection(_ record: RulerDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label("Ruler"))
                .font(.subheadline.weight(.semibold))
            LabeledContent(label("Agent")) {
                Text(staffIdentifierDisplayText(record.rulerAgentId))
            }
            LabeledContent(label("Posture")) {
                Text(record.posture.displayName)
            }
            if let zoneId = record.preferredFrontZoneId {
                LabeledContent(label("Focus")) {
                    Text(frontZoneDisplayText(zoneId.rawValue))
                }
            }
            Text(record.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func label(_ legacy: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return legacy
        }

        switch legacy {
        case "Diplomacy":
            return "Coalition"
        case "Countries":
            return "Powers"
        case "Blocs":
            return "Coalitions"
        case "Relations":
            return "Coalition Relations"
        case "No diplomatic relations.":
            return "No coalition relations."
        case "Ruler":
            return "Sovereign"
        case "Posture":
            return "Campaign Posture"
        case "Focus":
            return "Focus Sector"
        default:
            return legacy
        }
    }

    private func memberCountText(_ count: Int) -> String {
        activeFaction.usesNapoleonicLogisticsVocabulary
            ? "\(count) power(s)"
            : "\(count) member(s)"
    }

    private func staffIdentifierDisplayText(_ identifier: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return identifier
        }

        let normalized = identifier.lowercased()
        if normalized.contains("mockai") ||
            normalized.contains("mock_commander") ||
            normalized.contains("legacy") ||
            normalized.contains("_ai") ||
            normalized.contains("ai_") ||
            normalized == "ai" {
            return "\(activeFaction.displayName) Command Staff"
        }

        return identifierDisplayText(identifier, fallback: "\(activeFaction.displayName) Command Staff")
    }

    private func frontZoneDisplayText(_ rawValue: String) -> String {
        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        return identifierDisplayText(rawValue, fallback: "corps sector", suffix: " sector")
    }

    private func identifierDisplayText(
        _ rawValue: String,
        fallback: String,
        suffix: String? = nil
    ) -> String {
        let stopWords: Set<String> = [
            "region", "front", "frontzone", "zone", "theater", "sector",
            "legacy", "mock", "ai", "commander", "marshal", "directive",
            "power", "faction", "global", "ruler"
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
