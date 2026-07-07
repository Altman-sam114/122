import SpriteKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

final class BoardScene: SKScene {
    private var renderState: BoardRenderState?
    private var layout: HexLayout?
    private var onHexTapped: ((HexCoord) -> Void)?
    // v0.21: camera 平移
    private var boardCamera: SKCameraNode?
    private var lastDragViewPosition: CGPoint?
    private var lastDragScenePosition: CGPoint?
    private var totalDragDistance: CGFloat = 0
    private let tapThreshold: CGFloat = 8

    override init(size: CGSize) {
        super.init(size: size)
        // v0.21: resizeFill 让 scene 跟 SKView 同尺寸；hex 大小由 HexLayout.fixed 决定（不塞满），
        // 超出 view 的 hex 画在 scene 外，由平移（任务 0.2）暴露。
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1.0)
        setupCamera()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1.0)
        setupCamera()
    }

    private func setupCamera() {
        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)
        self.boardCamera = camera
    }

    func configure(with renderState: BoardRenderState, onHexTapped: @escaping (HexCoord) -> Void) {
        self.renderState = renderState
        self.onHexTapped = onHexTapped
        redraw()
    }

    override func didMove(to view: SKView) {
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        redraw()
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view else { return }
        lastDragViewPosition = touch.location(in: view)
        totalDragDistance = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let view,
              let prev = lastDragViewPosition,
              let camera = boardCamera else {
            return
        }
        let current = touch.location(in: view)
        let delta = CGPoint(x: current.x - prev.x, y: current.y - prev.y)
        totalDragDistance += hypot(delta.x, delta.y)
        // 拖动方向反转（手指右移 → 内容右移 → camera 左移）
        camera.position.x -= delta.x
        camera.position.y += delta.y
        clampCamera()
        lastDragViewPosition = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            lastDragViewPosition = nil
        }
        // 累计拖动超阈值视为平移，不当 tap
        guard totalDragDistance < tapThreshold,
              let touch = touches.first,
              let layout,
              let state = renderState?.gameState else {
            return
        }

        let point = touch.location(in: self)
        let coord = layout.pixelToHex(point)
        guard state.map.contains(coord) else {
            return
        }

        onHexTapped?(coord)
    }
    #endif

    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        lastDragScenePosition = event.location(in: self)
        totalDragDistance = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let prev = lastDragScenePosition,
              let camera = boardCamera else {
            return
        }
        let current = event.location(in: self)
        let delta = CGPoint(x: current.x - prev.x, y: current.y - prev.y)
        totalDragDistance += hypot(delta.x, delta.y)
        camera.position.x -= delta.x
        camera.position.y -= delta.y
        clampCamera()
        lastDragScenePosition = current
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            lastDragScenePosition = nil
        }
        guard totalDragDistance < tapThreshold,
              let layout,
              let state = renderState?.gameState else {
            return
        }

        let point = event.location(in: self)
        let coord = layout.pixelToHex(point)
        guard state.map.contains(coord) else {
            return
        }

        onHexTapped?(coord)
    }

    func handleScrollWheel(_ event: NSEvent, anchor: CGPoint) {
        guard let camera = boardCamera else { return }

        if event.modifierFlags.contains(.shift) || abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            camera.position.x += event.scrollingDeltaX * camera.xScale
            camera.position.y -= event.scrollingDeltaY * camera.yScale
            clampCamera()
            return
        }

        let multiplier: CGFloat = event.scrollingDeltaY > 0 ? 0.92 : 1.08
        zoomCamera(multiplier: multiplier, anchor: anchor)
    }

    func handleMagnify(_ event: NSEvent, anchor: CGPoint) {
        let multiplier = max(0.5, min(1.5, 1 - event.magnification))
        zoomCamera(multiplier: multiplier, anchor: anchor)
    }
    #endif

    /// 限制 camera 在地图边界内，避免拖空。
    private func clampCamera() {
        guard let layout, let state = renderState?.gameState else { return }
        let mapWidth = state.map.width
        let mapHeight = state.map.height
        // 地图四角像素（fixed layout 下）
        let corners: [CGPoint] = [
            layout.hexToPixel(HexCoord(q: 0, r: 0)),
            layout.hexToPixel(HexCoord(q: mapWidth - 1, r: 0)),
            layout.hexToPixel(HexCoord(q: 0, r: mapHeight - 1)),
            layout.hexToPixel(HexCoord(q: mapWidth - 1, r: mapHeight - 1))
        ]
        let minX = corners.map(\.x).min() ?? 0
        let maxX = corners.map(\.x).max() ?? 0
        let minY = corners.map(\.y).min() ?? 0
        let maxY = corners.map(\.y).max() ?? 0
        let margin = layout.hexSize
        if let camera = boardCamera {
            camera.position.x = min(max(camera.position.x, minX - margin), maxX + margin)
            camera.position.y = min(max(camera.position.y, minY - margin), maxY + margin)
        }
    }

    private func zoomCamera(multiplier: CGFloat, anchor: CGPoint) {
        guard let camera = boardCamera else { return }
        let oldScale = camera.xScale
        let nextScale = max(0.45, min(2.4, oldScale * multiplier))
        guard nextScale != oldScale else { return }

        let ratio = nextScale / oldScale
        camera.position = CGPoint(
            x: anchor.x + (camera.position.x - anchor.x) * ratio,
            y: anchor.y + (camera.position.y - anchor.y) * ratio
        )
        camera.setScale(nextScale)
        clampCamera()
    }

    private func redraw() {
        // v0.21: 保 camera，只清内容节点
        let cameraRef = boardCamera
        removeAllChildren()
        if let cameraRef {
            addChild(cameraRef)
            self.camera = cameraRef
            self.boardCamera = cameraRef
        }

        guard let renderState else {
            drawEmptyState()
            return
        }

        let state = renderState.gameState
        // v0.21: 固定大 hexSize（~36），不再 fitted 塞满 scene。超出靠平移（任务 0.2）。
        let layout = HexLayout.fixed(mapWidth: state.map.width, mapHeight: state.map.height)
        self.layout = layout

        drawTiles(renderState: renderState, layout: layout)
        drawLayerOverlay(renderState: renderState, layout: layout)
        drawRegionOverlays(renderState: renderState, layout: layout)
        drawRoads(map: state.map, layout: layout)
        drawRivers(map: state.map, layout: layout)
        drawObjectiveMarkers(renderState: renderState, layout: layout)
        drawRecentDirectiveReplay(renderState: renderState, layout: layout)
        drawPlannedOperations(renderState: renderState, layout: layout)
        drawReinforcementEntryMarkers(renderState: renderState, layout: layout)
        drawUnits(renderState: renderState, layout: layout)
    }

    private func drawTiles(renderState: BoardRenderState, layout: HexLayout) {
        let state = renderState.gameState
        let supplyByCoord = Dictionary(uniqueKeysWithValues: state.map.supplySources.compactMap { source in
            state.map.controllingFaction(for: source).map { (source.coord, $0) }
        })
        let adapter = renderState.displayAdapter

        for tile in state.map.tiles.values.sorted(by: tileSort) {
            guard let displayState = adapter.hexDisplayState(for: tile.coord, viewerFaction: renderState.viewerFaction) else {
                continue
            }

            let node = HexNode(
                displayState: displayState,
                layout: layout,
                supplySourceFaction: supplyByCoord[tile.coord],
                isSelected: renderState.selectedHex == tile.coord,
                isMoveHighlighted: renderState.movementHighlights.contains(tile.coord),
                isAttackHighlighted: renderState.attackHighlights.contains(tile.coord)
            )
            addChild(node)
        }
    }

    private func drawRoads(map: MapState, layout: HexLayout) {
        let directions: [HexDirection] = [.east, .southEast, .southWest]

        for tile in map.tiles.values where tile.hasRoad {
            for direction in directions {
                let nextCoord = tile.coord.neighbor(in: direction)
                guard let nextTile = map.tile(at: nextCoord),
                      nextTile.hasRoad else {
                    continue
                }

                let start = layout.hexToPixel(tile.coord)
                let end = layout.hexToPixel(nextCoord)
                let path = CGMutablePath()
                path.move(to: start)
                path.addLine(to: end)

                let road = SKShapeNode(path: path)
                road.strokeColor = TerrainStyle.roadStroke
                road.lineWidth = max(2, layout.hexSize * 0.08)
                road.lineCap = .round
                road.zPosition = 15
                addChild(road)
            }
        }
    }

    private func drawRegionOverlays(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer == .hex else {
            return
        }

        for region in renderState.gameState.map.regions.values {
            let node = RegionOverlayNode(
                region: region,
                layout: layout,
                isSelected: renderState.selectedRegionId == region.id
            )
            addChild(node)
        }
    }

    private func drawLayerOverlay(renderState: BoardRenderState, layout: HexLayout) {
        let node = MapLayerOverlayNode(
            state: renderState.gameState,
            layer: renderState.mapDisplayLayer,
            layout: layout
        )
        addChild(node)
    }

    private func drawRivers(map: MapState, layout: HexLayout) {
        for tile in map.tiles.values {
            let center = layout.hexToPixel(tile.coord)
            for direction in HexDirection.ordered where tile.riverEdges.contains(direction) {
                let edge = layout.edgePoints(center: center, direction: direction)
                let path = CGMutablePath()
                path.move(to: edge.0)
                path.addLine(to: edge.1)

                let river = SKShapeNode(path: path)
                river.strokeColor = TerrainStyle.riverStroke
                river.lineWidth = max(3, layout.hexSize * 0.10)
                river.lineCap = .round
                river.zPosition = 18
                addChild(river)
            }
        }
    }

    private func drawRecentDirectiveReplay(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }

        let records = renderState.gameState.warDirectiveRecords
            .filter { shouldShowDirectiveReplay($0, renderState: renderState) }
            .suffix(6)
        guard !records.isEmpty else {
            return
        }

        for record in records {
            guard let zoneId = record.zoneId,
                  let directiveType = record.directiveType,
                  let sourcePoint = operationPoint(
                    regionId: nil,
                    zoneId: zoneId,
                    state: renderState.gameState,
                    layout: layout
                  ) else {
                continue
            }

            if let targetRegionId = directiveReplayTargetRegion(record),
               let targetPoint = operationPoint(
                regionId: targetRegionId,
                zoneId: zoneId,
                state: renderState.gameState,
                layout: layout
               ),
               sourcePoint != targetPoint {
                drawDirectiveReplayArrow(
                    from: sourcePoint,
                    to: targetPoint,
                    record: record,
                    type: directiveType
                )
            } else {
                drawDirectiveReplayHoldMarker(at: sourcePoint, record: record)
            }
        }
    }

    private func shouldShowDirectiveReplay(
        _ record: WarDirectiveRecord,
        renderState: BoardRenderState
    ) -> Bool {
        guard record.issuerId != "player",
              !record.faction.isNeutral,
              record.zoneId != nil,
              record.directiveType != nil else {
            return false
        }

        if renderState.observerModeEnabled {
            return true
        }

        return record.faction == renderState.viewerFaction ||
            renderState.gameState.diplomacyState.isFriendly(renderState.viewerFaction, to: record.faction)
    }

    private func directiveReplayTargetRegion(_ record: WarDirectiveRecord) -> RegionId? {
        if case .region(let regionId) = record.commandTarget {
            return regionId
        }

        return record.targetRegionIds.sorted { $0.rawValue < $1.rawValue }.first
    }

    private func drawDirectiveReplayArrow(
        from start: CGPoint,
        to end: CGPoint,
        record: WarDirectiveRecord,
        type: DirectiveType
    ) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let color = directiveReplayColor(for: record, type: type)
        let line = SKShapeNode(path: path)
        line.strokeColor = color.withAlphaComponent(0.58)
        line.lineWidth = 2.5
        line.lineCap = .round
        line.glowWidth = 1.2
        line.zPosition = 23
        addChild(line)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 10
        let spread: CGFloat = .pi / 7
        let headPath = CGMutablePath()
        headPath.move(to: end)
        headPath.addLine(
            to: CGPoint(
                x: end.x - cos(angle - spread) * arrowLength,
                y: end.y - sin(angle - spread) * arrowLength
            )
        )
        headPath.move(to: end)
        headPath.addLine(
            to: CGPoint(
                x: end.x - cos(angle + spread) * arrowLength,
                y: end.y - sin(angle + spread) * arrowLength
            )
        )

        let head = SKShapeNode(path: headPath)
        head.strokeColor = color.withAlphaComponent(0.66)
        head.lineWidth = 2.5
        head.lineCap = .round
        head.zPosition = 23.5
        addChild(head)

        drawDirectiveReplayTacticMarker(
            at: end,
            record: record,
            color: color,
            angle: angle
        )

        drawDirectiveReplayLabel(
            directiveReplayLabel(for: record, type: type),
            at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2),
            color: color
        )
    }

    private func drawDirectiveReplayHoldMarker(at point: CGPoint, record: WarDirectiveRecord) {
        let type = record.directiveType ?? .defend
        let color = directiveReplayColor(for: record, type: type)
        let marker = SKShapeNode(circleOfRadius: 13)
        marker.position = point
        marker.strokeColor = color.withAlphaComponent(0.62)
        marker.fillColor = color.withAlphaComponent(0.10)
        marker.lineWidth = 2.5
        marker.glowWidth = 0.8
        marker.zPosition = 23
        addChild(marker)

        drawDirectiveReplayLabel(
            directiveReplayLabel(for: record, type: type),
            at: CGPoint(x: point.x, y: point.y + 18),
            color: color
        )
    }

    private func drawDirectiveReplayLabel(_ text: String, at point: CGPoint, color: SKColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 7.5
        label.fontColor = color.withAlphaComponent(0.88)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = 24
        addChild(label)
    }

    private func drawDirectiveReplayTacticMarker(
        at point: CGPoint,
        record: WarDirectiveRecord,
        color: SKColor,
        angle: CGFloat
    ) {
        guard let tactic = record.tactic else {
            return
        }

        let node = SKNode()
        node.position = point
        node.zPosition = 24.2

        switch tactic {
        case .fireCoverage,
             .artilleryPreparation:
            addDirectiveReticle(to: node, color: color)
        case .breakthrough, .spearhead, .blitzkrieg, .cavalryCharge:
            node.zRotation = angle
            addDirectiveSpearhead(to: node, color: color)
        case .pincerMovement:
            node.zRotation = angle
            addDirectivePincer(to: node, color: color)
        case .feint, .guerrillaWarfare:
            node.zRotation = angle
            addDirectiveFeint(to: node, color: color)
        case .standardAttack,
             .holdPosition,
             .elasticDefense,
             .defenseInDepth,
             .lastStand:
            return
        }

        addChild(node)
    }

    private func addDirectiveReticle(to node: SKNode, color: SKColor) {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.strokeColor = color.withAlphaComponent(0.72)
        ring.fillColor = color.withAlphaComponent(0.06)
        ring.lineWidth = 1.8
        node.addChild(ring)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -13, y: 0))
        path.addLine(to: CGPoint(x: -5, y: 0))
        path.move(to: CGPoint(x: 5, y: 0))
        path.addLine(to: CGPoint(x: 13, y: 0))
        path.move(to: CGPoint(x: 0, y: -13))
        path.addLine(to: CGPoint(x: 0, y: -5))
        path.move(to: CGPoint(x: 0, y: 5))
        path.addLine(to: CGPoint(x: 0, y: 13))

        let crosshair = SKShapeNode(path: path)
        crosshair.strokeColor = color.withAlphaComponent(0.72)
        crosshair.lineWidth = 1.6
        crosshair.lineCap = .round
        node.addChild(crosshair)
    }

    private func addDirectiveSpearhead(to node: SKNode, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -11, y: -7))
        path.addLine(to: CGPoint(x: 12, y: 0))
        path.addLine(to: CGPoint(x: -11, y: 7))
        path.closeSubpath()

        let marker = SKShapeNode(path: path)
        marker.strokeColor = color.withAlphaComponent(0.82)
        marker.fillColor = color.withAlphaComponent(0.22)
        marker.lineWidth = 1.8
        marker.lineJoin = .round
        node.addChild(marker)
    }

    private func addDirectivePincer(to node: SKNode, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -15, y: 9))
        path.addLine(to: CGPoint(x: -4, y: 0))
        path.addLine(to: CGPoint(x: -15, y: -9))
        path.move(to: CGPoint(x: 15, y: 9))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: 15, y: -9))

        let marker = SKShapeNode(path: path)
        marker.strokeColor = color.withAlphaComponent(0.78)
        marker.lineWidth = 2.0
        marker.lineCap = .round
        marker.lineJoin = .round
        node.addChild(marker)
    }

    private func addDirectiveFeint(to node: SKNode, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -12, y: -6))
        path.addCurve(
            to: CGPoint(x: 11, y: 4),
            control1: CGPoint(x: -6, y: 8),
            control2: CGPoint(x: 5, y: -8)
        )
        path.move(to: CGPoint(x: 3, y: 9))
        path.addLine(to: CGPoint(x: 11, y: 4))
        path.addLine(to: CGPoint(x: 4, y: -2))

        let marker = SKShapeNode(path: path)
        marker.strokeColor = color.withAlphaComponent(0.72)
        marker.lineWidth = 1.8
        marker.lineCap = .round
        marker.lineJoin = .round
        node.addChild(marker)
    }

    private func directiveReplayLabel(for record: WarDirectiveRecord, type: DirectiveType) -> String {
        guard record.faction.usesNapoleonicLogisticsVocabulary else {
            return type == .attack ? "CMD" : "HOLD"
        }

        switch record.tactic {
        case .fireCoverage,
             .artilleryPreparation:
            return "ART"
        case .cavalryCharge:
            return "CAV"
        case .pincerMovement:
            return "PIN"
        case .breakthrough, .spearhead, .blitzkrieg:
            return "ADV"
        case .feint, .guerrillaWarfare:
            return "FEI"
        case .elasticDefense, .defenseInDepth, .lastStand, .holdPosition:
            return "HOLD"
        case .standardAttack:
            return type == .attack ? "ORD" : "HOLD"
        case nil:
            return type == .attack ? "ORD" : "HOLD"
        }
    }

    private func directiveReplayColor(for record: WarDirectiveRecord, type: DirectiveType) -> SKColor {
        if record.commandResults.isEmpty ||
            !record.commandResults.contains(where: \.executed) {
            return SKColor(white: 0.58, alpha: 1)
        }

        switch type {
        case .attack:
            return TerrainStyle.unitFillColor(for: record.faction)
        case .defend:
            return SKColor(red: 0.18, green: 0.64, blue: 0.38, alpha: 1)
        }
    }

    private func drawPlannedOperations(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }

        let operations = renderState.gameState.playerCommandState.plannedOperations.filter {
            $0.turn == renderState.gameState.turn && $0.faction == renderState.viewerFaction
        }
        guard !operations.isEmpty else {
            return
        }

        for operation in operations {
            guard let sourcePoint = operationPoint(
                regionId: operation.sourceRegionId,
                zoneId: operation.zoneId,
                state: renderState.gameState,
                layout: layout
            ) else {
                continue
            }

            if let targetRegionId = operation.targetRegionId,
               let targetPoint = operationPoint(
                regionId: targetRegionId,
                zoneId: operation.zoneId,
                state: renderState.gameState,
                layout: layout
               ) {
                drawOperationArrow(
                    from: sourcePoint,
                    to: targetPoint,
                    type: operation.directiveType,
                    tactic: operation.tactic
                )
            } else {
                drawOperationHoldMarker(at: sourcePoint)
            }
        }
    }

    private func operationPoint(
        regionId: RegionId?,
        zoneId: FrontZoneId,
        state: GameState,
        layout: HexLayout
    ) -> CGPoint? {
        if let regionId,
           let hex = state.map.representativeHex(for: regionId) {
            return layout.hexToPixel(hex)
        }

        guard let zone = state.warDeploymentState.frontZones[zoneId] else {
            return nil
        }
        let hqRegionId = zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
        guard let hqRegionId,
              let hex = state.map.representativeHex(for: hqRegionId) else {
            return nil
        }
        return layout.hexToPixel(hex)
    }

    private func drawOperationArrow(
        from start: CGPoint,
        to end: CGPoint,
        type: DirectiveType,
        tactic: TacticName?
    ) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let color = operationColor(for: type)
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 4
        line.lineCap = .round
        line.zPosition = 26
        addChild(line)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 14
        let spread: CGFloat = .pi / 7
        let left = CGPoint(
            x: end.x - cos(angle - spread) * arrowLength,
            y: end.y - sin(angle - spread) * arrowLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + spread) * arrowLength,
            y: end.y - sin(angle + spread) * arrowLength
        )
        let headPath = CGMutablePath()
        headPath.move(to: end)
        headPath.addLine(to: left)
        headPath.move(to: end)
        headPath.addLine(to: right)

        let head = SKShapeNode(path: headPath)
        head.strokeColor = color
        head.lineWidth = 4
        head.lineCap = .round
        head.zPosition = 27
        addChild(head)

        drawOperationTacticMarker(at: end, tactic: tactic, color: color, angle: angle)
    }

    private func drawOperationHoldMarker(at point: CGPoint) {
        let marker = SKShapeNode(circleOfRadius: 18)
        marker.position = point
        marker.strokeColor = operationColor(for: .defend)
        marker.fillColor = operationColor(for: .defend).withAlphaComponent(0.16)
        marker.lineWidth = 4
        marker.zPosition = 26
        addChild(marker)
    }

    private func drawOperationTacticMarker(
        at point: CGPoint,
        tactic: TacticName?,
        color: SKColor,
        angle: CGFloat
    ) {
        guard let tactic else {
            return
        }

        let node = SKNode()
        node.position = point
        node.zPosition = 28

        switch tactic {
        case .artilleryPreparation, .fireCoverage:
            addDirectiveReticle(to: node, color: color)
        case .cavalryCharge, .breakthrough, .spearhead, .blitzkrieg:
            node.zRotation = angle
            addDirectiveSpearhead(to: node, color: color)
        case .pincerMovement:
            node.zRotation = angle
            addDirectivePincer(to: node, color: color)
        case .feint, .guerrillaWarfare:
            node.zRotation = angle
            addDirectiveFeint(to: node, color: color)
        case .standardAttack,
             .holdPosition,
             .elasticDefense,
             .defenseInDepth,
             .lastStand:
            return
        }

        addChild(node)

        let label = operationTacticLabel(tactic)
        guard !label.isEmpty else {
            return
        }
        drawDirectiveReplayLabel(
            label,
            at: CGPoint(x: point.x, y: point.y + 17),
            color: color
        )
    }

    private func operationTacticLabel(_ tactic: TacticName) -> String {
        switch tactic {
        case .artilleryPreparation, .fireCoverage:
            return "ART"
        case .cavalryCharge:
            return "CAV"
        case .pincerMovement:
            return "PIN"
        case .breakthrough, .spearhead, .blitzkrieg:
            return "ADV"
        case .feint, .guerrillaWarfare:
            return "FEI"
        case .standardAttack,
             .holdPosition,
             .elasticDefense,
             .defenseInDepth,
             .lastStand:
            return ""
        }
    }

    private func operationColor(for type: DirectiveType) -> SKColor {
        switch type {
        case .attack:
            return SKColor(red: 0.95, green: 0.32, blue: 0.20, alpha: 0.85)
        case .defend:
            return SKColor(red: 0.18, green: 0.64, blue: 0.38, alpha: 0.85)
        }
    }

    private func drawObjectiveMarkers(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }

        let objectivesByCoord = Dictionary(grouping: renderState.gameState.map.objectives, by: \.coord)
        guard !objectivesByCoord.isEmpty else {
            return
        }

        for (coord, objectives) in objectivesByCoord.sorted(by: objectiveMarkerSort) {
            guard let displayState = renderState.displayAdapter.hexDisplayState(
                for: coord,
                viewerFaction: renderState.viewerFaction
            ),
                  displayState.visibility != .unseen else {
                continue
            }

            drawObjectiveMarker(
                at: layout.hexToPixel(coord),
                objectives: objectives,
                displayState: displayState,
                state: renderState.gameState,
                layout: layout
            )
        }
    }

    private func objectiveMarkerSort(
        _ lhs: (key: HexCoord, value: [Objective]),
        _ rhs: (key: HexCoord, value: [Objective])
    ) -> Bool {
        if lhs.key.r == rhs.key.r {
            return lhs.key.q < rhs.key.q
        }
        return lhs.key.r < rhs.key.r
    }

    private func drawObjectiveMarker(
        at center: CGPoint,
        objectives: [Objective],
        displayState: HexDisplayState,
        state: GameState,
        layout: HexLayout
    ) {
        guard let objective = objectives.sorted(by: { $0.id < $1.id }).first else {
            return
        }

        let usesNapoleonicVocabulary = state.activeFaction.usesNapoleonicLogisticsVocabulary ||
            state.divisions.contains { $0.faction.usesNapoleonicLogisticsVocabulary }
        let controller = state.map.tile(at: objective.coord)?.controller ?? displayState.controller
        let markerCenter = CGPoint(
            x: center.x + layout.hexSize * 0.40,
            y: center.y + layout.hexSize * 0.36
        )
        let width = max(32, layout.hexSize * 0.88)
        let height = max(15, layout.hexSize * 0.38)
        let alpha: CGFloat = displayState.visibility == .explored ? 0.58 : 0.92

        let backplate = SKShapeNode(
            rectOf: CGSize(width: width, height: height),
            cornerRadius: max(3, height * 0.20)
        )
        backplate.position = markerCenter
        backplate.fillColor = objectiveFillColor(for: objective.type).withAlphaComponent(alpha)
        backplate.strokeColor = objectiveStrokeColor(for: objective.type, controller: controller)
        backplate.lineWidth = max(1.2, layout.hexSize * 0.035)
        backplate.zPosition = 24
        addChild(backplate)

        let glyph = SKShapeNode(path: objectiveGlyphPath(for: objective.type, size: height * 0.56))
        glyph.position = CGPoint(x: markerCenter.x - width * 0.30, y: markerCenter.y)
        glyph.strokeColor = objectiveGlyphColor(for: objective.type)
        glyph.fillColor = objectiveGlyphColor(for: objective.type).withAlphaComponent(0.22)
        glyph.lineWidth = max(1.0, layout.hexSize * 0.026)
        glyph.lineCap = .round
        glyph.lineJoin = .round
        glyph.zPosition = 25
        addChild(glyph)

        let countSuffix = objectives.count > 1 ? "+\(objectives.count - 1)" : ""
        let label = SKLabelNode(text: objectiveMarkerLabel(
            for: objective.type,
            usesNapoleonicVocabulary: usesNapoleonicVocabulary
        ) + countSuffix)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = max(5.5, layout.hexSize * 0.13)
        label.fontColor = objectiveTextColor(for: objective.type)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: markerCenter.x + width * 0.12, y: markerCenter.y - height * 0.02)
        label.zPosition = 25
        addChild(label)
    }

    private func objectiveMarkerLabel(
        for type: ObjectiveType,
        usesNapoleonicVocabulary: Bool
    ) -> String {
        switch (type, usesNapoleonicVocabulary) {
        case (.city, true):
            return "VLG"
        case (.city, false):
            return "OBJ"
        case (.fortress, true):
            return "FARM"
        case (.fortress, false):
            return "FORT"
        case (.supply, true):
            return "ROAD"
        case (.supply, false):
            return "SUP"
        }
    }

    private func objectiveFillColor(for type: ObjectiveType) -> SKColor {
        switch type {
        case .city:
            return SKColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 1)
        case .fortress:
            return SKColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 1)
        case .supply:
            return SKColor(red: 0.32, green: 0.58, blue: 0.46, alpha: 1)
        }
    }

    private func objectiveStrokeColor(for type: ObjectiveType, controller: Faction?) -> SKColor {
        if let controller, !controller.isNeutral {
            return TerrainStyle.controllerColor(for: controller).withAlphaComponent(0.96)
        }

        switch type {
        case .city:
            return SKColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 0.96)
        case .fortress:
            return SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 0.96)
        case .supply:
            return SKColor(red: 0.14, green: 0.30, blue: 0.24, alpha: 0.96)
        }
    }

    private func objectiveTextColor(for type: ObjectiveType) -> SKColor {
        switch type {
        case .city:
            return SKColor(white: 0.12, alpha: 1)
        case .fortress, .supply:
            return SKColor(white: 0.98, alpha: 1)
        }
    }

    private func objectiveGlyphColor(for type: ObjectiveType) -> SKColor {
        switch type {
        case .city:
            return SKColor(white: 0.16, alpha: 1)
        case .fortress, .supply:
            return SKColor(white: 0.96, alpha: 1)
        }
    }

    private func objectiveGlyphPath(for type: ObjectiveType, size: CGFloat) -> CGPath {
        let half = size / 2
        let path = CGMutablePath()

        switch type {
        case .city:
            path.move(to: CGPoint(x: -half, y: -half * 0.35))
            path.addLine(to: CGPoint(x: 0, y: half))
            path.addLine(to: CGPoint(x: half, y: -half * 0.35))
            path.addLine(to: CGPoint(x: half * 0.62, y: -half * 0.35))
            path.addLine(to: CGPoint(x: half * 0.62, y: -half))
            path.addLine(to: CGPoint(x: -half * 0.62, y: -half))
            path.addLine(to: CGPoint(x: -half * 0.62, y: -half * 0.35))
            path.closeSubpath()
        case .fortress:
            path.move(to: CGPoint(x: -half, y: -half))
            path.addLine(to: CGPoint(x: -half, y: half * 0.55))
            path.addLine(to: CGPoint(x: -half * 0.45, y: half * 0.55))
            path.addLine(to: CGPoint(x: -half * 0.45, y: half))
            path.addLine(to: CGPoint(x: half * 0.45, y: half))
            path.addLine(to: CGPoint(x: half * 0.45, y: half * 0.55))
            path.addLine(to: CGPoint(x: half, y: half * 0.55))
            path.addLine(to: CGPoint(x: half, y: -half))
            path.closeSubpath()
            path.move(to: CGPoint(x: -half * 0.55, y: -half * 0.10))
            path.addLine(to: CGPoint(x: half * 0.55, y: -half * 0.10))
        case .supply:
            path.move(to: CGPoint(x: -half, y: -half * 0.10))
            path.addCurve(
                to: CGPoint(x: half, y: half * 0.12),
                control1: CGPoint(x: -half * 0.35, y: half * 0.62),
                control2: CGPoint(x: half * 0.35, y: -half * 0.60)
            )
            path.move(to: CGPoint(x: -half * 0.22, y: -half))
            path.addLine(to: CGPoint(x: 0, y: -half * 0.34))
            path.addLine(to: CGPoint(x: half * 0.22, y: -half))
        }

        return path
    }

    private func drawReinforcementEntryMarkers(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }

        let pending = renderState.gameState.reinforcementState.pending.filter {
            shouldShowReinforcementEntry($0, renderState: renderState)
        }
        guard !pending.isEmpty else {
            return
        }

        let grouped = Dictionary(grouping: pending, by: \.entryCoord)
        for (coord, reinforcements) in grouped.sorted(by: reinforcementEntrySort) {
            guard renderState.gameState.map.contains(coord) else {
                continue
            }
            drawReinforcementEntryMarker(
                at: layout.hexToPixel(coord),
                reinforcements: reinforcements,
                layout: layout
            )
        }
    }

    private func shouldShowReinforcementEntry(
        _ reinforcement: ScheduledReinforcement,
        renderState: BoardRenderState
    ) -> Bool {
        let faction = reinforcement.division.faction
        guard !faction.isNeutral else {
            return false
        }

        if renderState.observerModeEnabled {
            return true
        }

        return faction == renderState.viewerFaction ||
            renderState.gameState.diplomacyState.isFriendly(renderState.viewerFaction, to: faction)
    }

    private func reinforcementEntrySort(
        _ lhs: (key: HexCoord, value: [ScheduledReinforcement]),
        _ rhs: (key: HexCoord, value: [ScheduledReinforcement])
    ) -> Bool {
        if lhs.key.r == rhs.key.r {
            return lhs.key.q < rhs.key.q
        }
        return lhs.key.r < rhs.key.r
    }

    private func drawReinforcementEntryMarker(
        at center: CGPoint,
        reinforcements: [ScheduledReinforcement],
        layout: HexLayout
    ) {
        guard let first = reinforcements.min(by: { $0.arrivalTurn < $1.arrivalTurn }) else {
            return
        }

        let markerCenter = CGPoint(x: center.x, y: center.y + layout.hexSize * 0.48)
        let radius = max(8, layout.hexSize * 0.22)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: markerCenter.x, y: markerCenter.y + radius))
        path.addLine(to: CGPoint(x: markerCenter.x + radius, y: markerCenter.y))
        path.addLine(to: CGPoint(x: markerCenter.x, y: markerCenter.y - radius))
        path.addLine(to: CGPoint(x: markerCenter.x - radius, y: markerCenter.y))
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        body.fillColor = TerrainStyle.unitFillColor(for: first.division.faction).withAlphaComponent(0.78)
        body.strokeColor = reinforcementStrokeColor(for: first.division.faction)
        body.lineWidth = max(1.5, layout.hexSize * 0.045)
        body.zPosition = 34
        addChild(body)

        let title = SKLabelNode(text: first.division.faction.usesNapoleonicLogisticsVocabulary ? "RES" : "REF")
        title.fontName = "AvenirNext-DemiBold"
        title.fontSize = max(6, layout.hexSize * 0.14)
        title.fontColor = reinforcementTextColor(for: first.division.faction)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: markerCenter.x, y: markerCenter.y + radius * 0.16)
        title.zPosition = 35
        addChild(title)

        let countPrefix = reinforcements.count > 1 ? "x\(reinforcements.count) " : ""
        let turn = SKLabelNode(text: "\(countPrefix)T\(first.arrivalTurn)")
        turn.fontName = "AvenirNext-Regular"
        turn.fontSize = max(5, layout.hexSize * 0.11)
        turn.fontColor = title.fontColor
        turn.horizontalAlignmentMode = .center
        turn.verticalAlignmentMode = .center
        turn.position = CGPoint(x: markerCenter.x, y: markerCenter.y - radius * 0.42)
        turn.zPosition = 35
        addChild(turn)
    }

    private func reinforcementStrokeColor(for faction: Faction) -> SKColor {
        switch faction {
        case .austria, .neutral:
            return SKColor(red: 0.42, green: 0.34, blue: 0.14, alpha: 0.95)
        default:
            return SKColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 0.95)
        }
    }

    private func reinforcementTextColor(for faction: Faction) -> SKColor {
        switch faction {
        case .austria, .neutral:
            return SKColor(white: 0.10, alpha: 1)
        default:
            return SKColor(white: 0.98, alpha: 1)
        }
    }

    private func drawUnits(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }
        let adapter = renderState.displayAdapter
        let placements = adapter.unitPlacements(viewerFaction: renderState.viewerFaction)
        let deploymentManager = WarDeploymentManager()

        let orderedDivisions = renderState.gameState.divisions
            .map { division in
                (division: division, displayHex: adapter.unitDisplayHex(for: division) ?? division.coord)
            }
            .sorted { lhs, rhs in
                let lhsHex = lhs.displayHex
                let rhsHex = rhs.displayHex
                if lhsHex.r == rhsHex.r {
                    return lhsHex.q < rhsHex.q
                }
                return lhsHex.r < rhsHex.r
            }

        for item in orderedDivisions {
            let division = item.division
            guard let placement = placements[division.id] else {
                continue
            }

            let node = UnitNode(
                division: division,
                layout: layout,
                placement: placement,
                isSelected: renderState.selectedUnitId == division.id,
                isPlayerManaged: renderState.gameState.playerCommandState.micromanagedDivisionIds.contains(division.id),
                fillColorOverride: deploymentColorOverride(
                    for: division,
                    renderState: renderState,
                    deploymentManager: deploymentManager
                )
            )
            addChild(node)
        }
    }

    private func deploymentColorOverride(
        for division: Division,
        renderState: BoardRenderState,
        deploymentManager: WarDeploymentManager
    ) -> SKColor? {
        guard renderState.mapDisplayLayer == .deployment else {
            return nil
        }
        let role = deploymentManager.deploymentRole(
            for: division,
            in: renderState.gameState.map,
            state: renderState.gameState.warDeploymentState,
            diplomacyState: renderState.gameState.diplomacyState
        )
        return TerrainStyle.deploymentUnitColor(for: division.faction, role: role)
    }

    private func drawEmptyState() {
        let field = SKShapeNode(
            rectOf: CGSize(width: max(size.width - 48, 120), height: max(size.height - 48, 120)),
            cornerRadius: 8
        )
        field.fillColor = SKColor(red: 0.24, green: 0.30, blue: 0.22, alpha: 1.0)
        field.strokeColor = SKColor(red: 0.55, green: 0.60, blue: 0.48, alpha: 1.0)
        field.lineWidth = 2
        field.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(field)

        let title = SKLabelNode(text: emptyStateTitle)
        title.fontName = "AvenirNext-DemiBold"
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        addChild(title)
    }

    private var emptyStateTitle: String {
        let scenarioId = renderState?.gameState.scenarioId ?? ScenarioCatalog.defaultPlayable.id
        return "\(ScenarioCatalog.displayName(for: scenarioId)) Board"
    }

    private func tileSort(_ lhs: HexTile, _ rhs: HexTile) -> Bool {
        if lhs.coord.r == rhs.coord.r {
            return lhs.coord.q < rhs.coord.q
        }
        return lhs.coord.r < rhs.coord.r
    }
}
