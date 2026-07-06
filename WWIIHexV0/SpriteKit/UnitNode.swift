import SpriteKit

final class UnitNode: SKNode {
    let divisionId: String

    init(
        division: Division,
        layout: HexLayout,
        placement: UnitDisplayPlacement,
        isSelected: Bool,
        isPlayerManaged: Bool = false,
        fillColorOverride: SKColor? = nil
    ) {
        self.divisionId = division.id
        super.init()

        let anchor = layout.hexToPixel(placement.hex)
        position = CGPoint(x: anchor.x + placement.offset.x, y: anchor.y + placement.offset.y)
        zPosition = 40
        alpha = division.hasActed ? 0.58 : 1

        let width = layout.hexSize * 1.08
        let height = layout.hexSize * 0.72

        if isPlayerManaged {
            let halo = SKShapeNode(rectOf: CGSize(width: width + 8, height: height + 8), cornerRadius: min(7, layout.hexSize * 0.14))
            halo.fillColor = SKColor(red: 0.95, green: 0.72, blue: 0.22, alpha: 0.22)
            halo.strokeColor = SKColor(red: 1.00, green: 0.78, blue: 0.24, alpha: 0.95)
            halo.lineWidth = max(2, layout.hexSize * 0.06)
            halo.zPosition = -1
            addChild(halo)
        }

        let body = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(5, layout.hexSize * 0.10))
        body.fillColor = fillColorOverride ?? TerrainStyle.unitFillColor(for: division.faction)
        body.strokeColor = isSelected ? TerrainStyle.selectedStroke : TerrainStyle.unitStrokeColor(for: division.faction)
        body.lineWidth = isSelected ? max(3, layout.hexSize * 0.08) : 1.5
        body.zPosition = 0
        addChild(body)

        addFormationSymbol(for: division, width: width, height: height)

        addLabel(
            text: division.markerReadinessText,
            y: -height * 0.28,
            fontSize: max(7, layout.hexSize * 0.16),
            weight: "AvenirNext-Regular"
        )

        addSupplyMarker(for: division, layout: layout, bodyWidth: width, bodyHeight: height)
        addStackMarker(placement: placement, layout: layout, bodyWidth: width, bodyHeight: height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addFormationSymbol(for division: Division, width: CGFloat, height: CGFloat) {
        if division.faction.usesNapoleonicLogisticsVocabulary {
            addNapoleonicSymbol(for: division, width: width, height: height)
        } else {
            addLegacyNATOSymbol(for: division, width: width, height: height)
        }
    }

    private func addLegacyNATOSymbol(for division: Division, width: CGFloat, height: CGFloat) {
        let lineColor = symbolStrokeColor(for: division.faction)
        let lineWidth = max(1.5, min(width, height) * 0.08)
        let inset = min(width, height) * 0.18

        if division.isArtillery {
            let radius = min(width, height) * 0.22
            let circle = SKShapeNode(circleOfRadius: radius)
            circle.strokeColor = lineColor
            circle.lineWidth = lineWidth
            circle.fillColor = .clear
            circle.zPosition = 1
            addChild(circle)
        } else if division.isArmor {
            let ellipse = SKShapeNode(ellipseOf: CGSize(width: width - inset * 1.4, height: height - inset * 1.4))
            ellipse.strokeColor = lineColor
            ellipse.lineWidth = lineWidth
            ellipse.fillColor = .clear
            ellipse.zPosition = 1
            addChild(ellipse)
        } else {
            let isMotorized = division.isMobileFormation
            let halfW = width / 2 - inset
            let halfH = height / 2 - inset

            addSymbolLine(
                from: CGPoint(x: -halfW, y: halfH),
                to: CGPoint(x: halfW, y: -halfH),
                color: lineColor,
                lineWidth: lineWidth
            )

            if !isMotorized {
                addSymbolLine(
                    from: CGPoint(x: -halfW, y: -halfH),
                    to: CGPoint(x: halfW, y: halfH),
                    color: lineColor,
                    lineWidth: lineWidth
                )
            }
        }
    }

    private func addNapoleonicSymbol(for division: Division, width: CGFloat, height: CGFloat) {
        let color = symbolStrokeColor(for: division.faction)
        let lineWidth = max(1.3, min(width, height) * 0.065)

        if division.isSupplyTrainFormation {
            addSupplyWagonSymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else if division.isArtillery {
            addCannonSymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else if division.isCavalry {
            addCavalrySymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else if division.isGuardFormation {
            addGuardStarSymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else if division.isEngineerFormation {
            addEngineerBridgeSymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else if division.isLightInfantryFormation {
            addSkirmisherSymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        } else {
            addLineInfantrySymbol(width: width, height: height, color: color, lineWidth: lineWidth)
        }
    }

    private func addLineInfantrySymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let halfW = width * 0.30
        let yOffset = height * 0.09
        addSymbolLine(from: CGPoint(x: -halfW, y: yOffset), to: CGPoint(x: halfW, y: yOffset), color: color, lineWidth: lineWidth)
        addSymbolLine(from: CGPoint(x: -halfW, y: -yOffset), to: CGPoint(x: halfW, y: -yOffset), color: color, lineWidth: lineWidth)
    }

    private func addSkirmisherSymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let radius = max(1.8, min(width, height) * 0.055)
        let offsets = [
            CGPoint(x: -width * 0.20, y: height * 0.08),
            CGPoint(x: 0, y: -height * 0.02),
            CGPoint(x: width * 0.20, y: height * 0.08)
        ]
        for offset in offsets {
            let dot = SKShapeNode(circleOfRadius: radius)
            dot.fillColor = color
            dot.strokeColor = color
            dot.lineWidth = lineWidth * 0.5
            dot.position = offset
            dot.zPosition = 1
            addChild(dot)
        }
    }

    private func addCavalrySymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.26, y: height * 0.14))
        path.addLine(to: CGPoint(x: 0, y: -height * 0.16))
        path.addLine(to: CGPoint(x: width * 0.26, y: height * 0.14))
        addSymbolPath(path, color: color, lineWidth: lineWidth)
    }

    private func addCannonSymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let wheel = SKShapeNode(circleOfRadius: min(width, height) * 0.11)
        wheel.strokeColor = color
        wheel.fillColor = .clear
        wheel.lineWidth = lineWidth
        wheel.position = CGPoint(x: -width * 0.10, y: -height * 0.06)
        wheel.zPosition = 1
        addChild(wheel)

        addSymbolLine(
            from: CGPoint(x: -width * 0.03, y: height * 0.01),
            to: CGPoint(x: width * 0.28, y: height * 0.13),
            color: color,
            lineWidth: lineWidth
        )
    }

    private func addGuardStarSymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let outer = min(width, height) * 0.20
        let inner = outer * 0.44
        let path = CGMutablePath()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * CGFloat.pi / 5 - CGFloat.pi / 2
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.strokeColor = color
        star.fillColor = color.withAlphaComponent(0.18)
        star.lineWidth = lineWidth
        star.zPosition = 1
        addChild(star)
    }

    private func addEngineerBridgeSymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let halfW = width * 0.27
        addSymbolLine(from: CGPoint(x: -halfW, y: -height * 0.08), to: CGPoint(x: halfW, y: -height * 0.08), color: color, lineWidth: lineWidth)
        addSymbolLine(from: CGPoint(x: -halfW, y: height * 0.08), to: CGPoint(x: halfW, y: height * 0.08), color: color, lineWidth: lineWidth)
        addSymbolLine(from: CGPoint(x: -width * 0.12, y: -height * 0.12), to: CGPoint(x: -width * 0.12, y: height * 0.12), color: color, lineWidth: lineWidth)
        addSymbolLine(from: CGPoint(x: width * 0.12, y: -height * 0.12), to: CGPoint(x: width * 0.12, y: height * 0.12), color: color, lineWidth: lineWidth)
    }

    private func addSupplyWagonSymbol(width: CGFloat, height: CGFloat, color: SKColor, lineWidth: CGFloat) {
        let wagon = SKShapeNode(rectOf: CGSize(width: width * 0.36, height: height * 0.20), cornerRadius: 2)
        wagon.strokeColor = color
        wagon.fillColor = .clear
        wagon.lineWidth = lineWidth
        wagon.position = CGPoint(x: 0, y: height * 0.03)
        wagon.zPosition = 1
        addChild(wagon)

        for x in [-width * 0.13, width * 0.13] {
            let wheel = SKShapeNode(circleOfRadius: min(width, height) * 0.055)
            wheel.strokeColor = color
            wheel.fillColor = .clear
            wheel.lineWidth = lineWidth * 0.8
            wheel.position = CGPoint(x: x, y: -height * 0.12)
            wheel.zPosition = 1
            addChild(wheel)
        }
    }

    private func addSymbolLine(from start: CGPoint, to end: CGPoint, color: SKColor, lineWidth: CGFloat) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        addSymbolPath(path, color: color, lineWidth: lineWidth)
    }

    private func addSymbolPath(_ path: CGPath, color: SKColor, lineWidth: CGFloat) {
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = lineWidth
        node.fillColor = .clear
        node.zPosition = 1
        addChild(node)
    }

    private func symbolStrokeColor(for faction: Faction) -> SKColor {
        switch faction {
        case .austria, .neutral:
            return SKColor(white: 0.12, alpha: 0.95)
        default:
            return SKColor(white: 0.97, alpha: 0.95)
        }
    }

    private func addLabel(text: String, y: CGFloat, fontSize: CGFloat, weight: String) {
        let label = SKLabelNode(text: text)
        label.fontName = weight
        label.fontSize = fontSize
        label.fontColor = SKColor(white: 0.97, alpha: 1)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        label.zPosition = 2
        addChild(label)
    }

    private func addSupplyMarker(for division: Division, layout: HexLayout, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let radius = max(3, layout.hexSize * 0.10)
        let marker = SKShapeNode(circleOfRadius: radius)
        marker.fillColor = TerrainStyle.supplyColor(for: division.supplyState)
        marker.strokeColor = SKColor(white: 1, alpha: 0.85)
        marker.lineWidth = 1
        marker.position = CGPoint(x: bodyWidth / 2 - radius * 0.8, y: bodyHeight / 2 - radius * 0.8)
        marker.zPosition = 3
        addChild(marker)

        guard division.supplyState != .supplied else {
            return
        }

        let alert = SKLabelNode(text: "!")
        alert.fontName = "AvenirNext-Bold"
        alert.fontSize = max(7, layout.hexSize * 0.16)
        alert.fontColor = SKColor(white: 1, alpha: 1)
        alert.horizontalAlignmentMode = .center
        alert.verticalAlignmentMode = .center
        alert.position = marker.position
        alert.zPosition = 4
        addChild(alert)
    }

    private func addStackMarker(placement: UnitDisplayPlacement, layout: HexLayout, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        guard placement.stackCount > 1 else {
            return
        }

        let marker = SKShapeNode(circleOfRadius: max(4, layout.hexSize * 0.12))
        marker.fillColor = SKColor(white: 0.05, alpha: 0.94)
        marker.strokeColor = SKColor(white: 1, alpha: 0.75)
        marker.lineWidth = 1
        marker.position = CGPoint(x: -bodyWidth / 2 + layout.hexSize * 0.13, y: bodyHeight / 2 - layout.hexSize * 0.13)
        marker.zPosition = 4
        addChild(marker)

        let count = SKLabelNode(text: "\(placement.stackCount)")
        count.fontName = "AvenirNext-DemiBold"
        count.fontSize = max(7, layout.hexSize * 0.17)
        count.fontColor = SKColor(white: 1, alpha: 1)
        count.horizontalAlignmentMode = .center
        count.verticalAlignmentMode = .center
        count.position = marker.position
        count.zPosition = 5
        addChild(count)
    }
}

private extension Division {
    var isGuardFormation: Bool {
        components.contains { $0.type == .guardInfantry && $0.weight >= 0.25 }
    }

    var isLightInfantryFormation: Bool {
        components.contains { $0.type == .lightInfantry && $0.weight >= 0.25 }
    }

    var isEngineerFormation: Bool {
        components.contains { $0.type == .engineer && $0.weight >= 0.25 }
    }

    var isSupplyTrainFormation: Bool {
        components.contains { $0.type == .supplyTrain && $0.weight >= 0.25 }
    }

    var markerCode: String {
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

    var markerReadinessText: String {
        "\(strength)/\(maxStrength) \(retreatMode.markerCode(for: faction))"
    }
}

private extension RetreatMode {
    func markerCode(for faction: Faction) -> String {
        switch self {
        case .retreatable:
            return faction.usesNapoleonicLogisticsVocabulary ? "W" : "R"
        case .hold:
            return "H"
        }
    }
}
