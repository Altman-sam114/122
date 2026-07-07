import SwiftUI

struct AgentPanelView: View {
    let record: AgentDecisionRecord?
    let rulerRecord: RulerDecisionRecord?
    let activeFaction: Faction
    let directiveRecords: [WarDirectiveRecord]
    let replayDetailLevel: ReplayDetailLevel
    let playtestTextSize: PlaytestTextSize

    init(
        record: AgentDecisionRecord?,
        rulerRecord: RulerDecisionRecord? = nil,
        activeFaction: Faction = .france,
        directiveRecords: [WarDirectiveRecord] = [],
        replayDetailLevel: ReplayDetailLevel = .standard,
        playtestTextSize: PlaytestTextSize = .standard
    ) {
        self.record = record
        self.rulerRecord = rulerRecord
        self.activeFaction = activeFaction
        self.directiveRecords = directiveRecords
        self.replayDetailLevel = replayDetailLevel
        self.playtestTextSize = playtestTextSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: playtestTextSize.panelSpacing) {
            Text(label("AI Decision"))
                .font(playtestTextSize.panelTitleFont)
                .foregroundStyle(activeFaction.usesNapoleonicLogisticsVocabulary ? NapoleonicDesignTokens.imperialBlue : .primary)

            LabeledContent(label("Agent")) {
                Text(agentDisplayName(record?.agentId))
                    .font(playtestTextSize.valueFont)
            }
            .font(playtestTextSize.valueFont)

            LabeledContent(label("Provider")) {
                Text(providerDisplayName(record?.provider))
                    .font(playtestTextSize.valueFont)
            }
            .font(playtestTextSize.valueFont)

            LabeledContent(label("Intent")) {
                Text(intentDisplayText(record?.parsedIntent))
                    .font(playtestTextSize.valueFont)
                    .multilineTextAlignment(.trailing)
            }
            .font(playtestTextSize.valueFont)

            if replayDetailLevel.showsContextSummary,
               let contextSummary = record?.contextSummary {
                LabeledContent(label("Context")) {
                    Text(contextDisplayText(contextSummary))
                        .font(playtestTextSize.valueFont)
                        .multilineTextAlignment(.trailing)
                }
                .font(playtestTextSize.valueFont)
            }

            if hasDispatchSummary {
                Text(label("Dispatch Summary"))
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: playtestTextSize.summarySpacing) {
                    ForEach(0..<dispatchSummaryRows.count, id: \.self) { index in
                        let row = dispatchSummaryRows[index]
                        LabeledContent(row.title) {
                            Text(row.value)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(playtestTextSize.captionFont)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(PlatformStyles.tertiarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if !dispatchTimelineRows.isEmpty {
                Text(label("Dispatch Timeline"))
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: playtestTextSize.summarySpacing) {
                    ForEach(dispatchTimelineRows) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(row.turnText)
                                    .font(playtestTextSize.captionFont)
                                    .bold()
                                    .foregroundStyle(row.statusStyle)

                                Text(row.title)
                                    .font(playtestTextSize.captionFont)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            Text(row.detail)
                                .font(playtestTextSize.captionFont)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(row.statusText)
                                .font(playtestTextSize.captionFont)
                                .foregroundStyle(row.statusStyle)

                            if let issuePreview = row.issuePreview {
                                Text(issuePreview)
                                    .font(playtestTextSize.captionFont)
                                    .foregroundStyle(.orange)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(PlatformStyles.tertiarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if !dispatchIssuePreviewLines.isEmpty {
                Text(label("Issue Preview"))
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: playtestTextSize.summarySpacing) {
                    ForEach(dispatchIssuePreviewLines, id: \.self) { issue in
                        Text(issue)
                            .font(playtestTextSize.captionFont)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if hiddenDispatchIssueCount > 0 {
                        Text("+\(hiddenDispatchIssueCount) more in detailed replay")
                            .font(playtestTextSize.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(PlatformStyles.tertiarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let rulerRecord {
                Divider()
                LabeledContent(label("Ruler")) {
                    Text(staffIdentifierDisplayText(rulerRecord.rulerAgentId, faction: activeFaction))
                }
                .font(playtestTextSize.valueFont)
                LabeledContent(label("Posture")) {
                    Text(rulerRecord.posture.displayName)
                }
                .font(playtestTextSize.valueFont)
                if let zoneId = rulerRecord.preferredFrontZoneId {
                    LabeledContent(label("Focus")) {
                        Text(frontZoneDisplayText(zoneId.rawValue, faction: rulerRecord.faction))
                    }
                    .font(playtestTextSize.valueFont)
                }
            }

            if showsDetailedReplay, let record, !record.commandResults.isEmpty {
                Text(label("Command Results"))
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: playtestTextSize.summarySpacing) {
                    ForEach(record.commandResults) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commandResultTitle(result))
                                .font(playtestTextSize.captionFont)
                                .bold()
                            Text(resultLine(result))
                                .font(playtestTextSize.captionFont)
                                .foregroundStyle(result.executed ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if showsDetailedReplay, !displayedDirectiveRecords.isEmpty {
                Text(label("Zone Directives"))
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: playtestTextSize.summarySpacing) {
                    ForEach(displayedDirectiveRecords) { directive in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(directiveBadgeText(directive))
                                    .font(playtestTextSize.captionFont)
                                    .bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PlatformStyles.selectionTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(directiveSummary(directive))
                                    .font(playtestTextSize.captionFont)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            if !directive.diagnostics.isEmpty {
                                Text(directive.diagnostics.map {
                                    diagnosticDisplayText($0, faction: directive.faction)
                                }.joined(separator: " / "))
                                    .font(playtestTextSize.captionFont)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(PlatformStyles.tertiarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if replayDetailLevel.showsRawJSON {
                Text(activeFaction.usesNapoleonicLogisticsVocabulary ? "Dispatch Audit" : "Raw JSON")
                    .font(playtestTextSize.captionFont)
                    .foregroundStyle(.secondary)

                Text(dispatchAuditText)
                    .font(playtestTextSize.rawJSONFont)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(PlatformStyles.tertiarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
        case "AI Decision":
            return "Command Dispatch"
        case "Agent":
            return "Staff"
        case "Provider":
            return "Source"
        case "Intent":
            return "Intent"
        case "Context":
            return "Situation"
        case "Ruler":
            return "Sovereign"
        case "Posture":
            return "Campaign Posture"
        case "Focus":
            return "Focus Sector"
        case "Command Results":
            return "Order Results"
        case "Zone Directives":
            return "Corps Directives"
        case "Dispatch Summary":
            return "Staff Summary"
        case "Dispatch Timeline":
            return "Dispatch Timeline"
        case "Issue Preview":
            return "Dispatch Issues"
        case "Executed":
            return "Carried Out"
        case "Rejected":
            return "Refused"
        case "Issues":
            return "Issues"
        case "Focus Sectors":
            return "Focus Sectors"
        case "Latest Tactic":
            return "Latest Order"
        case "Directives":
            return "Corps Directives"
        case "Errors":
            return "Dispatch Issues"
        default:
            return legacy
        }
    }

    private func agentDisplayName(_ agentId: String?) -> String {
        guard let agentId else {
            return activeFaction.usesNapoleonicLogisticsVocabulary ? "No staff assigned" : "No agent selected"
        }

        guard activeFaction.usesNapoleonicLogisticsVocabulary else {
            return agentId
        }

        if isRawStaffIdentifier(agentId) || agentId == "system" {
            return "\(activeFaction.displayName) Command Staff"
        }

        return identifierDisplayText(agentId, fallback: "\(activeFaction.displayName) Command Staff")
    }

    private func intentDisplayText(_ intent: String?) -> String {
        if let intent {
            return diagnosticDisplayText(intent)
        }

        return activeFaction.usesNapoleonicLogisticsVocabulary ? "No dispatch submitted" : "No decision submitted"
    }

    private func contextDisplayText(_ summary: String) -> String {
        diagnosticDisplayText(summary)
    }

    private func providerDisplayName(_ provider: String?) -> String {
        guard let provider else {
            return activeFaction.usesNapoleonicLogisticsVocabulary ? "No staff source" : "No provider"
        }

        if activeFaction.usesNapoleonicLogisticsVocabulary && isRawStaffIdentifier(provider) {
            return "Simulated Staff"
        }

        return provider
    }

    private func directiveBadgeText(_ directive: WarDirectiveRecord) -> String {
        guard let zoneId = directive.zoneId else {
            return directive.faction.usesNapoleonicLogisticsVocabulary ? "army-wide" : "global"
        }

        return frontZoneDisplayText(zoneId.rawValue, faction: directive.faction)
    }

    private func directiveSummary(_ directive: WarDirectiveRecord) -> String {
        let type = directiveTypeText(directive.directiveType, faction: directive.faction)
        let tactic = directiveOrderText(directive, fallback: "none")
        let executed = directive.commandResults.filter(\.executed).count
        let rejected = directive.commandResults.count - executed
        let targets = directive.targetRegionIds.map {
            regionDisplayText($0.rawValue, faction: directive.faction)
        }.joined(separator: ", ")
        let targetText = targets.isEmpty ? noTargetText(faction: directive.faction) : targets
        let executedLabel = directive.faction.usesNapoleonicLogisticsVocabulary ? "carried out" : "ok"
        let rejectedLabel = directive.faction.usesNapoleonicLogisticsVocabulary ? "refused" : "rejected"
        return "\(type) / \(tactic) / \(executed) \(executedLabel), \(rejected) \(rejectedLabel) / \(targetText)"
    }

    private var displayedDirectiveRecords: [WarDirectiveRecord] {
        Array(directiveRecords.suffix(replayDetailLevel.directiveLimit))
    }

    private var showsDetailedReplay: Bool {
        replayDetailLevel != .concise
    }

    private var hasDispatchSummary: Bool {
        record != nil || !displayedDirectiveRecords.isEmpty
    }

    private var summaryCommandResults: [CommandResultSummary] {
        let directiveResults = displayedDirectiveRecords.flatMap(\.commandResults)
        let sourceResults = directiveResults.isEmpty ? (record?.commandResults ?? []) : directiveResults
        return sourceResults.filter { isFieldOrderResult($0) }
    }

    private var dispatchSummaryRows: [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = [
            (label("Executed"), "\(summaryCommandResults.filter(\.executed).count)"),
            (label("Rejected"), "\(summaryCommandResults.filter { !$0.executed }.count)"),
            (label("Issues"), "\(dispatchIssueCount)")
        ]

        if !displayedDirectiveRecords.isEmpty {
            rows.append((label("Directives"), "\(displayedDirectiveRecords.count)"))
        }

        if let focusText = focusSectorText {
            rows.append((label("Focus Sectors"), focusText))
        }

        if let tacticText = latestTacticText {
            rows.append((label("Latest Tactic"), tacticText))
        }

        return rows
    }

    private var dispatchTimelineRows: [DispatchTimelineRow] {
        displayedDirectiveRecords
            .reversed()
            .enumerated()
            .map { index, directive in
                dispatchTimelineRow(directive, displayIndex: index)
            }
    }

    private func dispatchTimelineRow(_ directive: WarDirectiveRecord, displayIndex: Int) -> DispatchTimelineRow {
        let commandResults = directive.commandResults.filter { isFieldOrderResult($0) }
        let executed = commandResults.filter(\.executed).count
        let rejected = commandResults.count - executed
        let issueLines = directiveIssueLines(for: directive, commandResults: commandResults)
        let issues = orderedUnique(issueLines).count
        let typeText = directiveTypeText(directive.directiveType, faction: directive.faction)
        let tacticText = directiveOrderText(directive, fallback: "diagnostic")
        let scopeText = directiveScopeText(directive)
        let targetText = directiveTargetText(directive)
        let title = "\(typeText) / \(tacticText)"
        let detail = activeFaction.usesNapoleonicLogisticsVocabulary
            ? "\(scopeText) to \(targetText)"
            : "\(scopeText) -> \(targetText)"
        let statusText = timelineStatusText(executed: executed, rejected: rejected, issues: issues)
        let statusStyle = timelineStatusStyle(executed: executed, rejected: rejected, issues: issues)
        let issuePreview = issuePreviewText(
            lines: issueLines,
            limit: 2
        )

        return DispatchTimelineRow(
            id: "\(directive.id)_timeline_\(displayIndex)",
            turnText: "T\(directive.turn)",
            title: title,
            detail: detail,
            statusText: statusText,
            statusStyle: statusStyle,
            issuePreview: issuePreview
        )
    }

    private func isFieldOrderResult(_ result: CommandResultSummary) -> Bool {
        guard result.id != "end_turn" else {
            return false
        }

        let commandDisplayName = result.commandDisplayName?.lowercased()
        return commandDisplayName != "end turn" && commandDisplayName != "end orders"
    }

    private func directiveScopeText(_ directive: WarDirectiveRecord) -> String {
        if let commanderAgentId = directive.commanderAgentId {
            if directive.faction.usesNapoleonicLogisticsVocabulary {
                if commanderAgentId.contains("marshal") {
                    return "\(directive.faction.displayName) Marshal"
                }
                if isRawStaffIdentifier(commanderAgentId) || commanderAgentId == "system" {
                    return "\(directive.faction.displayName) Command Staff"
                }
                return identifierDisplayText(commanderAgentId, fallback: "\(directive.faction.displayName) Command Staff")
            }
            return commanderAgentId
        }

        if let zoneId = directive.zoneId {
            return frontZoneDisplayText(zoneId.rawValue, faction: directive.faction)
        }

        return staffIdentifierDisplayText(directive.issuerId, faction: directive.faction)
    }

    private func directiveTargetText(_ directive: WarDirectiveRecord) -> String {
        if !directive.targetRegionIds.isEmpty {
            return directive.targetRegionIds.map {
                regionDisplayText($0.rawValue, faction: directive.faction)
            }.joined(separator: ", ")
        }

        if let commandTarget = directive.commandTarget {
            switch commandTarget {
            case let .region(regionId):
                return regionDisplayText(regionId.rawValue, faction: directive.faction)
            case let .theater(theaterId):
                return theaterDisplayText(theaterId.rawValue, faction: directive.faction)
            }
        }

        if let zoneId = directive.zoneId {
            return frontZoneDisplayText(zoneId.rawValue, faction: directive.faction)
        }

        return noTargetText(faction: directive.faction)
    }

    private func timelineStatusText(executed: Int, rejected: Int, issues: Int) -> String {
        let carriedOut = activeFaction.usesNapoleonicLogisticsVocabulary ? "carried out" : "executed"
        let refused = activeFaction.usesNapoleonicLogisticsVocabulary ? "refused" : "rejected"
        return "\(executed) \(carriedOut), \(rejected) \(refused), \(issues) issues"
    }

    private func timelineStatusStyle(executed: Int, rejected: Int, issues: Int) -> Color {
        if issues > 0 || rejected > 0 {
            return .orange
        }
        if executed > 0 {
            return .green
        }
        return .secondary
    }

    private var dispatchIssueCount: Int {
        allDispatchIssueLines.count
    }

    private var dispatchIssuePreviewLines: [String] {
        Array(allDispatchIssueLines.prefix(dispatchIssuePreviewLimit))
    }

    private var hiddenDispatchIssueCount: Int {
        max(0, allDispatchIssueLines.count - dispatchIssuePreviewLines.count)
    }

    private var dispatchIssuePreviewLimit: Int {
        switch replayDetailLevel {
        case .concise:
            return 1
        case .standard:
            return 5
        case .full:
            return Int.max
        }
    }

    private var allDispatchIssueLines: [String] {
        var issues: [String] = []
        if let record {
            issues.append(contentsOf: recordErrorsForPreview(record.errors))
            if displayedDirectiveRecords.isEmpty {
                issues.append(contentsOf: record.commandResults.flatMap(issueLines(for:)))
            }
        }

        for directive in displayedDirectiveRecords.reversed() {
            issues.append(contentsOf: directiveIssueLines(for: directive))
        }

        return orderedUnique(issues.compactMap { issue in
            let trimmed = issue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
    }

    private var focusSectorText: String? {
        let targetIds = displayedDirectiveRecords
            .flatMap { directive in
                directive.targetRegionIds.map {
                    regionDisplayText($0.rawValue, faction: directive.faction)
                }
            }
        let zoneIds = displayedDirectiveRecords
            .compactMap { directive -> String? in
                guard let zoneId = directive.zoneId else {
                    return nil
                }
                return frontZoneDisplayText(zoneId.rawValue, faction: directive.faction)
            }
        let focusIds = orderedUnique(targetIds.isEmpty ? zoneIds : targetIds)

        guard !focusIds.isEmpty else {
            return nil
        }

        let visibleFocusIds = focusIds.prefix(3)
        let suffix = focusIds.count > visibleFocusIds.count ? " +" : ""
        return visibleFocusIds.joined(separator: ", ") + suffix
    }

    private var latestTacticText: String? {
        guard let directive = displayedDirectiveRecords.reversed().first(where: {
            $0.tactic != nil || $0.category != nil || $0.directiveType != nil
        }) else {
            return nil
        }

        if let tactic = directive.tactic {
            return tacticDisplayName(tactic, faction: directive.faction)
        }

        if let category = directive.category {
            return categoryDisplayName(category, faction: directive.faction)
        }

        return directiveTypeText(directive.directiveType, faction: directive.faction)
    }

    private func directiveTypeText(_ type: DirectiveType?) -> String {
        directiveTypeText(type, faction: activeFaction)
    }

    private func directiveTypeText(_ type: DirectiveType?, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return type?.rawValue ?? "diagnostic"
        }

        switch type {
        case .attack:
            return "attack sector"
        case .defend:
            return "hold line"
        case nil:
            return "staff note"
        }
    }

    private func directiveOrderText(_ directive: WarDirectiveRecord, fallback: String) -> String {
        if let tactic = directive.tactic {
            return tacticDisplayName(tactic, faction: directive.faction)
        }
        if let category = directive.category {
            return categoryDisplayName(category, faction: directive.faction)
        }
        if directive.faction.usesNapoleonicLogisticsVocabulary {
            switch fallback {
            case "diagnostic":
                return "staff note"
            case "none":
                return "no order"
            default:
                return fallback
            }
        }
        return fallback
    }

    private func categoryDisplayName(_ category: CommandCategory, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return category.rawValue
        }

        switch category {
        case .offense:
            return "Attack Orders"
        case .defense:
            return "Holding Orders"
        }
    }

    private func tacticDisplayName(_ tactic: TacticName, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return tactic.rawValue
        }

        switch tactic {
        case .standardAttack:
            return "Attack Sector"
        case .blitzkrieg:
            return "Rapid Advance"
        case .spearhead:
            return "Column Assault"
        case .breakthrough:
            return "Break Contact Line"
        case .pincerMovement:
            return "Converging Attack"
        case .fireCoverage:
            return "Artillery Preparation"
        case .feint:
            return "Demonstration"
        case .guerrillaWarfare:
            return "Harassing Action"
        case .holdPosition:
            return "Hold Line"
        case .elasticDefense:
            return "Flexible Defense"
        case .defenseInDepth:
            return "Reserve Line"
        case .lastStand:
            return "Final Defense"
        }
    }

    private func resultLine(_ result: CommandResultSummary) -> String {
        if !result.mappingSucceeded {
            let errors = displayErrors(result.errors)
            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Order could not be formed: \(errors)"
                : "Mapping failed: \(errors)"
        }

        if result.executed {
            return diagnosticDisplayText(result.message)
        }

        if !result.errors.isEmpty {
            let errors = displayErrors(result.errors)
            return activeFaction.usesNapoleonicLogisticsVocabulary
                ? "Refused: \(errors)"
                : "Rejected: \(errors)"
        }

        return diagnosticDisplayText(result.message)
    }

    private func issueLines(for result: CommandResultSummary) -> [String] {
        guard !result.executed else {
            return []
        }

        let commandName = commandResultTitle(result)
        if !result.mappingSucceeded {
            let prefix = activeFaction.usesNapoleonicLogisticsVocabulary ? "could not form order" : "mapping failed"
            return ["\(commandName): \(prefix) \(displayErrors(result.errors))"]
        }
        if !result.errors.isEmpty {
            return ["\(commandName): \(displayErrors(result.errors))"]
        }
        return ["\(commandName): \(diagnosticDisplayText(result.message))"]
    }

    private func commandResultTitle(_ result: CommandResultSummary) -> String {
        if let commandDisplayName = result.commandDisplayName {
            return commandDisplayName
        }
        guard activeFaction.usesNapoleonicLogisticsVocabulary,
              let orderType = result.orderType else {
            return result.orderType?.rawValue ?? "Order"
        }

        switch orderType {
        case .move:
            return "Movement Order"
        case .attack:
            return "Attack Order"
        case .hold:
            return "Hold Line"
        case .resupply:
            return "Rest and Supply"
        }
    }

    private func directiveIssueLines(
        for directive: WarDirectiveRecord,
        commandResults: [CommandResultSummary]? = nil
    ) -> [String] {
        let resultIssueLines = (commandResults ?? directive.commandResults).flatMap(issueLines(for:))
        guard !resultIssueLines.isEmpty else {
            return directive.diagnostics.map(diagnosticDisplayText)
        }

        let diagnostics = directive.diagnostics.filter {
            !isDirectiveCommandRejectionDiagnostic($0)
        }
        return diagnostics.map(diagnosticDisplayText) + resultIssueLines
    }

    private func recordErrorsForPreview(_ errors: [String]) -> [String] {
        guard !displayedDirectiveRecords.isEmpty else {
            return errors.map(diagnosticDisplayText)
        }

        let directiveDiagnostics = Set(displayedDirectiveRecords.flatMap(\.diagnostics))
        return errors.filter { error in
            !directiveDiagnostics.contains(error) &&
                !isDirectiveCommandRejectionDiagnostic(error)
        }.map(diagnosticDisplayText)
    }

    private func displayErrors(_ errors: [String]) -> String {
        errors.map(diagnosticDisplayText).joined(separator: ", ")
    }

    private func diagnosticDisplayText(_ text: String) -> String {
        diagnosticDisplayText(text, faction: activeFaction)
    }

    private func diagnosticDisplayText(_ text: String, faction: Faction) -> String {
        NapoleonicMessageSanitizer.displayText(text, for: faction)
    }

    private func noTargetText(faction: Faction) -> String {
        faction.usesNapoleonicLogisticsVocabulary ? "no sector assigned" : "no target"
    }

    private func frontZoneDisplayText(_ rawValue: String) -> String {
        frontZoneDisplayText(rawValue, faction: activeFaction)
    }

    private func frontZoneDisplayText(_ rawValue: String, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        return identifierDisplayText(rawValue, fallback: "corps sector", suffix: " sector")
    }

    private func regionDisplayText(_ rawValue: String) -> String {
        regionDisplayText(rawValue, faction: activeFaction)
    }

    private func regionDisplayText(_ rawValue: String, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        return identifierDisplayText(rawValue, fallback: "sector", suffix: " sector")
    }

    private func theaterDisplayText(_ rawValue: String) -> String {
        theaterDisplayText(rawValue, faction: activeFaction)
    }

    private func theaterDisplayText(_ rawValue: String, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return rawValue
        }

        return identifierDisplayText(rawValue, fallback: "campaign wing", suffix: " wing")
    }

    private func staffIdentifierDisplayText(_ identifier: String, faction: Faction) -> String {
        guard faction.usesNapoleonicLogisticsVocabulary else {
            return identifier
        }

        if isRawStaffIdentifier(identifier) {
            return "\(faction.displayName) Command Staff"
        }
        return identifierDisplayText(identifier, fallback: "\(faction.displayName) Command Staff")
    }

    private func isRawStaffIdentifier(_ identifier: String) -> Bool {
        let normalized = identifier.lowercased()
        return normalized.contains("mockai") ||
            normalized.contains("mock_commander") ||
            normalized.contains("legacy") ||
            normalized.contains("_ai") ||
            normalized.contains("ai_") ||
            normalized == "ai"
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

    private func isDirectiveCommandRejectionDiagnostic(_ diagnostic: String) -> Bool {
        let trimmed = diagnostic.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if let directiveRange = trimmed.range(of: "Directive ") {
            candidate = String(trimmed[directiveRange.lowerBound...])
        } else {
            candidate = trimmed
        }

        return candidate.hasPrefix("Directive ") &&
            candidate.contains(" command ") &&
            candidate.contains(" rejected:")
    }

    private func issuePreviewText(lines: [String], limit: Int) -> String? {
        let visibleLines = orderedUnique(lines).prefix(limit)
        guard !visibleLines.isEmpty else {
            return nil
        }
        return visibleLines.joined(separator: " / ")
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var uniqueValues: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            uniqueValues.append(value)
        }

        return uniqueValues
    }

    private var rawJSONPlaceholder: String {
        if activeFaction.usesNapoleonicLogisticsVocabulary {
            return "No dispatch audit recorded."
        }

        return """
        {
          "agentId": null,
          "status": "no_decision",
          "orders": []
        }
        """
    }

    private var dispatchAuditText: String {
        guard let rawJSON = record?.rawJSON else {
            return rawJSONPlaceholder
        }
        return activeFaction.usesNapoleonicLogisticsVocabulary ? diagnosticDisplayText(rawJSON) : rawJSON
    }
}

private struct DispatchTimelineRow: Identifiable {
    let id: String
    let turnText: String
    let title: String
    let detail: String
    let statusText: String
    let statusStyle: Color
    let issuePreview: String?
}

private extension PlaytestTextSize {
    var panelTitleFont: Font {
        switch self {
        case .compact:
            return .subheadline.weight(.semibold)
        case .standard:
            return .headline
        case .large:
            return .title3.weight(.semibold)
        }
    }

    var valueFont: Font {
        switch self {
        case .compact:
            return .callout
        case .standard:
            return .body
        case .large:
            return .title3
        }
    }

    var captionFont: Font {
        switch self {
        case .compact:
            return .caption2
        case .standard:
            return .caption
        case .large:
            return .callout
        }
    }

    var rawJSONFont: Font {
        switch self {
        case .compact:
            return .system(.caption2, design: .monospaced)
        case .standard:
            return .system(.caption, design: .monospaced)
        case .large:
            return .system(.callout, design: .monospaced)
        }
    }

    var panelSpacing: CGFloat {
        switch self {
        case .compact:
            return 8
        case .standard:
            return 10
        case .large:
            return 12
        }
    }

    var summarySpacing: CGFloat {
        switch self {
        case .compact:
            return 4
        case .standard:
            return 6
        case .large:
            return 8
        }
    }
}
