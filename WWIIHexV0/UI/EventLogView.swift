import SwiftUI

struct EventLogView: View {
    let entries: [GameLogEntry]
    let activeFaction: Faction
    let replayDetailLevel: ReplayDetailLevel
    let playtestTextSize: PlaytestTextSize

    init(
        entries: [GameLogEntry],
        activeFaction: Faction = .france,
        replayDetailLevel: ReplayDetailLevel = .standard,
        playtestTextSize: PlaytestTextSize = .standard
    ) {
        self.entries = entries
        self.activeFaction = activeFaction
        self.replayDetailLevel = replayDetailLevel
        self.playtestTextSize = playtestTextSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: playtestTextSize.sectionSpacing) {
            Text(title)
                .font(playtestTextSize.headingFont)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: playtestTextSize.rowSpacing) {
                    if recentEntries.isEmpty {
                        Text("No events yet.")
                            .font(playtestTextSize.messageFont)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { item in
                            VStack(alignment: .leading, spacing: playtestTextSize.itemSpacing) {
                                HStack(spacing: 6) {
                                    Text(item.category.displayName(for: activeFaction))
                                        .font(playtestTextSize.badgeFont)
                                        .foregroundStyle(item.category.foregroundStyle)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(item.category.backgroundStyle)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(metadata(for: item.entry))
                                        .font(playtestTextSize.metadataFont)
                                        .foregroundStyle(.secondary)
                                }

                                Text(messageDisplayText(for: item.entry))
                                    .font(playtestTextSize.messageFont)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minHeight: 120)
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        activeFaction.usesNapoleonicLogisticsVocabulary ? "Dispatches" : "Event Log"
    }

    private var recentEntries: [LogDisplayEntry] {
        entries
            .suffix(replayDetailLevel.eventLimit)
            .reversed()
            .map { LogDisplayEntry(entry: $0, category: LogDisplayCategory(entry: $0)) }
    }

    private func metadata(for entry: GameLogEntry) -> String {
        let faction = factionDisplayName(entry.faction)
        if replayDetailLevel == .concise {
            return "Turn \(entry.turn) - \(faction)"
        }

        let phase = phaseDisplayName(entry.phase, faction: entry.faction ?? activeFaction)
        if let relatedRecordId = entry.relatedRecordId,
           replayDetailLevel.showsRecordIdentifiers {
            return "Turn \(entry.turn) - \(faction) - \(phase) - \(relatedRecordId)"
        }
        return "Turn \(entry.turn) - \(faction) - \(phase)"
    }

    private func factionDisplayName(_ faction: Faction?) -> String {
        guard let faction else {
            return activeFaction.usesNapoleonicLogisticsVocabulary ? "Staff" : "System"
        }

        if activeFaction.usesNapoleonicLogisticsVocabulary && faction.isLegacyWorldWarIIFaction {
            return "Archived Force"
        }

        return faction.displayName
    }

    private func messageDisplayText(for entry: GameLogEntry) -> String {
        let displayFaction = entry.faction ?? activeFaction
        guard displayFaction.usesNapoleonicLogisticsVocabulary else {
            return entry.message
        }

        return NapoleonicMessageSanitizer.displayText(entry.message, for: displayFaction)
    }

    private func phaseDisplayName(_ phase: GamePhase?, faction: Faction) -> String {
        guard let phase else {
            return "Setup"
        }
        guard faction.usesNapoleonicLogisticsVocabulary else {
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
}

private struct LogDisplayEntry: Identifiable {
    let entry: GameLogEntry
    let category: LogDisplayCategory

    var id: UUID {
        entry.id
    }
}

private enum LogDisplayCategory {
    case combat
    case retreat
    case reinforcement
    case encirclement
    case supply
    case frontChange
    case theaterChange
    case regionOwnerChange
    case diplomacy
    case event

    init(entry: GameLogEntry) {
        switch entry.category {
        case .combat:
            self = .combat
            return
        case .retreat:
            self = .retreat
            return
        case .reinforce:
            self = .reinforcement
            return
        case .encircle:
            self = .encirclement
            return
        case .supply:
            self = .supply
            return
        case .frontChange:
            self = .frontChange
            return
        case .theaterChange:
            self = .theaterChange
            return
        case .regionOwnerChange:
            self = .regionOwnerChange
            return
        case .diplomacy:
            self = .diplomacy
            return
        case .event:
            break
        }

        let message = entry.message
        let text = message.lowercased()

        if text.contains("retreat") || text.contains("routed") || text.contains("routing") {
            self = .retreat
        } else if text.contains("reinforce") || text.contains("replacement") || text.contains("replenish") {
            self = .reinforcement
        } else if text.contains("encircle") || text.contains("encircled") {
            self = .encirclement
        } else if text.contains("attack") || text.contains("damage") || text.contains("combat") || text.contains("hit") {
            self = .combat
        } else if text.contains("supply") || text.contains("supplied") {
            self = .supply
        } else {
            self = .event
        }
    }

    func displayName(for faction: Faction) -> String {
        if faction.usesNapoleonicLogisticsVocabulary {
            switch self {
            case .reinforcement:
                return "Reserve"
            case .frontChange:
                return "Contact"
            case .theaterChange:
                return "Wing"
            case .regionOwnerChange:
                return "Sector"
            case .diplomacy:
                return "Coalition"
            default:
                break
            }
        }

        switch self {
        case .combat:
            return "Combat"
        case .retreat:
            return "Retreat"
        case .reinforcement:
            return "Reinforce"
        case .encirclement:
            return "Encircle"
        case .supply:
            return "Supply"
        case .frontChange:
            return "Front"
        case .theaterChange:
            return "Theater"
        case .regionOwnerChange:
            return "Region"
        case .diplomacy:
            return "Diplomacy"
        case .event:
            return "Event"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .combat:
            return .red
        case .retreat:
            return .orange
        case .reinforcement:
            return .green
        case .encirclement:
            return .purple
        case .supply:
            return .teal
        case .frontChange:
            return .blue
        case .theaterChange:
            return .indigo
        case .regionOwnerChange:
            return .mint
        case .diplomacy:
            return .cyan
        case .event:
            return .secondary
        }
    }

    var backgroundStyle: Color {
        foregroundStyle.opacity(0.12)
    }
}

private extension PlaytestTextSize {
    var headingFont: Font {
        switch self {
        case .compact:
            return .subheadline.weight(.semibold)
        case .standard:
            return .headline
        case .large:
            return .title3.weight(.semibold)
        }
    }

    var badgeFont: Font {
        switch self {
        case .compact:
            return .caption2.weight(.semibold)
        case .standard:
            return .caption.weight(.semibold)
        case .large:
            return .callout.weight(.semibold)
        }
    }

    var metadataFont: Font {
        switch self {
        case .compact:
            return .caption2
        case .standard:
            return .caption
        case .large:
            return .callout
        }
    }

    var messageFont: Font {
        switch self {
        case .compact:
            return .callout
        case .standard:
            return .body
        case .large:
            return .title3
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .compact:
            return 6
        case .standard:
            return 8
        case .large:
            return 10
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        case .compact:
            return 6
        case .standard:
            return 8
        case .large:
            return 12
        }
    }

    var itemSpacing: CGFloat {
        switch self {
        case .compact:
            return 1
        case .standard:
            return 2
        case .large:
            return 4
        }
    }
}
