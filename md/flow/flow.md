# WWIIHexV0 核心流程文档（main 当前核心链路）

> 本文是项目当前核心逻辑的接手文档。目标不是复述历史设计，而是按当前代码真实链路说明：数据如何进入游戏，hex / region / theater / front / deploy 如何派生，主游戏和地图编辑器如何共同维护同一套地图语义，AI / 玩家命令如何落到规则系统。

资料依据：`AGENT.md`、`README.md`、`update_log.md`、`md/test/test.md`、v0.355/v0.36/v0.37 阶段文档、最近 git 记录，以及当前源码中的 `Core/`、`Rules/`、`Commands/`、`Agents/`、`Turn/`、`App/`、`SpriteKit/`、`UI/`、`MapEditor/` 与关键测试。

---

## 0. 一句话总览

当前主链路是：

```text
MapEditor / JSON 数据
  -> DataLoader
  -> GameState
  -> Hex controller / Division coord
  -> Region 聚合
  -> EconomyState 收入 / 生产 / 补员
  -> Initial Theater snapshot + runtime hexToTheater
  -> FrontLine 动态 hex 接触
  -> WarDeployment hexToFrontZone + FRONT/DEPTH/GARRISON
  -> RulerAgent / StrategicPosture JSON
  -> StrategicPostureDecoder
  -> MarshalAgent / TheaterDirective JSON
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> ZoneCommanderAgent fallback / 手写 ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> CommandExecutor
  -> StrategicStateSynchronizer
  -> UI overlay / 日志 / RulerDecisionRecord / WarDirectiveRecord
```

最关键的铁律：

- `HexTile.controller` 和 `Division.coord` 是战术层权威。
- `RegionNode.controller` 是从 region 内 hex controller 加权聚合出来的战略快照。
- `regionToTheater` 是初始/基础战区归属，不是运行时推进层。
- `hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威。
- `EconomyState` 是 faction 级经济总账；收入来自受控 region、城市、工厂、基础设施和补给值，但战术占领仍以 hex 为准。
- `Faction` 当前是兼容层：旧 `.germany/.allies` 仍可加载，新 v3.1 已加入 `.france/.angloAllied/.prussia/.austria/.russia/.spain/.neutral`，为滑铁卢和后续拿战势力迁移做基础。
- `DiplomacyState` 当前提供国家/集团记录和敌我关系查询 helper；补给、region pressure、AI 摘要、战术目标排序、攻击校验、ZOC/路径阻挡、占领、前线邻接、部署分类、战区压力和 HQ 威胁已可通过它判断 hostile / friendly，而不再全部依赖 `Faction.opponent` 或 `faction != otherFaction`。`Faction.opponent` 仍作为 legacy 二元兼容 helper 保留，但已标记 deprecated，新运行时关系应改用 `DiplomacyState`。
- `GamePhase` 仍保留 `.germanAI/.alliedPlayer` raw value 兼容旧数据，同时新增 `.aiCommand/.playerCommand`、`allowsCommands` 和 `commandPhase(for:)` helper。`legacyCompatibleCommandPhase(for:)` 只保留为旧命名包装；命令校验和 AI 触发已开始从具体 Germany/Allies phase 脱钩。
- 玩家、AI、后续聊天命令最终都必须经过 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`，不能直接改 `GameState`。
- v3.4 起默认战争 AI 上游是 `RulerAgent -> StrategicPostureEnvelope -> StrategicPostureDecoder -> MarshalAgent -> TheaterDirective JSON -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler`，下游执行收口到 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- `RulerAgent` 只生成国家/联军级姿态、元帅上下文和 `RulerDecisionRecord`，不得直接生成底层 `Command` 或修改 `GameState` 的战术权威状态。

---

## 0.1 云端协作与验证闭环

本节记录协作制度，不改变游戏业务逻辑。本项目默认从本地重测试迁移为：

```text
人工提出目标
  -> Agent A 读文档/源码并写版本化提示词
  -> Agent B 基于 main 实现
  -> Agent B 本机只跑 md/test/test.md 允许的轻量检查
  -> Agent B commit 到 main 并 push origin/main
  -> GitHub Actions 运行 .github/workflows/ci-results.yml
  -> Actions 上传未加密 ci-results artifact
  -> Agent C 使用 gh 下载 artifact 到 /private/tmp/wwiihexv0-c-review-<run_id>/
  -> Agent C 核对 manifest / junit / xcodebuild.log / failure summary
      -> 失败：退回 Agent B 在 main 追加修复 commit
      -> 通过：确认 origin/main 最新 run 与 artifact 一致，并补齐核心文档
```

当前默认协作规则：

- `main` 是唯一默认上传、提交、推送和云端验证分支。
- 历史分支如 `v0.4`、`v0.5-marshal-decision-chain`、`v0.7-tactical-upgrade`、`v1.1-macos-main-game` 仍可作为历史记录和差异来源，但本轮不写入默认工作流。
- 不默认创建 PR，不设计 `smalldata_test`、`develop`、`codeb/...` 或候选分支合并制度。
- 本机默认不跑 `xcodebuild build/test`、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、模拟器或 UI test。
- 云端 workflow 当前执行静态检查与 `WWIIHexV0` scheme 的 iOS generic build，并把 XCTest/Probe 在 manifest 中明确标记为 `skipped`。后续若人工授权，可把更多重测试迁入云端 workflow。
- Agent C 不能只看 Agent B 文字汇报；必须下载并核对未加密结果包。manifest 的 `branch`、`commitSha`、`runId`、`runAttempt` 必须与 `origin/main` 最新 run 对齐。

---

## 1. 核心状态对象

### 1.1 GameState

源码：`WWIIHexV0/Core/GameState.swift`

`GameState` 是运行时总状态，主要字段：

```text
scenarioId
turn / maxTurns
activeFaction
phase
map: MapState
theaterState: TheaterState
frontLineState: FrontLineState
warDeploymentState: WarDeploymentState
economyState: EconomyState
reinforcementState: ReinforcementState
diplomacyState: DiplomacyState
divisions: [Division]
victoryState
victoryConditions
eventLog
warDirectiveRecords
playerCommandState
```

状态含义：

- `map` 保存地图、hex、region、补给源和目标点。
- `divisions` 保存所有单位。单位当前位置在 `Division.coord`，不是 region 或 theater。
- v3.5 起 `Division` 还保存最小战术消耗状态：`morale`、`fatigue` 和 `ammunition`。移动、攻击、反击、HOLD、resupply/rest 会通过规则层改变这些字段；疲劳影响 attack/defense/movement，低士气影响 attack/defense 并可触发撤退，低弹药影响弹药敏感单位火力。
- `theaterState` 保存初始战区快照与运行时动态战区。
- `frontLineState` 从动态战区相邻 hex 派生。
- `warDeploymentState` 从动态战区/前线/单位位置派生，供 AI 调度单位。
- `economyState` 保存 manpower、industry、supplies、生产队列、上回合收入/维护费/补员消耗，不直接改变战术占领权。
- `reinforcementState` 保存 scenario delayed reinforcement 的 pending schedule 和已到场 id。它不直接改变战术状态；只有 `EconomyRules.resolveScheduledReinforcements` 在回合结算中找到安全己控入口 hex 后，才把 reinforcement division 加入 `divisions`。
- v3.5 起 `EconomyState` 的底层 schema 仍保持 manpower / industry / supplies 兼容，但 France / Anglo-Allied / Prussia 等拿战 faction 的 UI 和日志会把它展示为 Recruits / Ammunition/Horses / Supplies，并把生产队列展示为 Reserves / Reserve Orders。
- `diplomacyState` 保存国家、集团、国家间关系和统治者记录；当前核心用途是 `isHostile` / `isFriendly` 敌我查询。旧二元数据缺关系时仍兼容回退到不同 faction 敌对，但 `.neutral` 不会因为缺 relation 被当作 hostile；缺国家记录或缺关系时，拿战联军成员之间 fallback 为 friendly，France 与联军成员 fallback 为 hostile。
- `victoryConditions` 保存 scenario JSON 中的胜利条件运行时副本。旧存档缺该字段时 decode 为 `[]`，Waterloo 分支会使用内置 fallback；新 Waterloo 加载路径会从 JSON 注入 objective id、目标 faction 和决定回合。
- `eventLog` 给 UI 和调试看。
- `warDirectiveRecords` 记录战争指令执行回放，供 v0.36+ 后续接 LLM / 聊天命令审计。

### 1.2 MapState / Hex

源码：`WWIIHexV0/Core/MapState.swift`、`WWIIHexV0/Core/Terrain.swift`

`MapState` 的底层是 hex：

```text
width / height
tiles: [HexCoord: HexTile]
supplySources: [SupplySource]
objectives: [Objective]
regions: [RegionId: RegionNode]
hexToRegion: [HexCoord: RegionId]
regionEdges: Set<RegionEdge>
```

`HexTile` 关键字段：

```text
coord
baseTerrain
hasRoad
riverEdges
controller: Faction?
cityName / fortressName
isPassable
regionId: RegionId?
```

当前语义：

- `HexCoord` 是 axial q/r 坐标，移动、攻击、距离、邻接都基于 hex。
- `HexTile.controller` 是真实占领权威；中立 hex 的 controller 为 `nil`。
- `HexTile.regionId` 是聚合标记，不参与寻路/战斗权威判断。
- `MapState.region(for:)` 优先读 `hexToRegion`，fallback 读 `tile.regionId`。
- `MapState.supplySources(for:)` 会通过 `controllingFaction(for:)` 判断补给源当前归属，优先看 supply hex 的 controller，再 fallback region controller，再 fallback 原始 supply faction。

### 1.3 Region

源码：`WWIIHexV0/Core/Region.swift`

`RegionNode` 是省份/区块规则层：

```text
id / name
owner
controller
terrain
neighbors
displayHexes
representativeHex
city
infrastructure / supplyValue / factories / resources
coreOf
occupationState
isPassable
```

当前语义：

- Region 是战略聚合层，不替代 hex。
- `displayHexes` 声明该 region 覆盖哪些 hex。
- `representativeHex` 是 UI 和某些 region->hex 转换的默认点。
- `neighbors` / `regionEdges` 是省份邻接图，但 v0.358 后不能单独拿它判断动态前线。前线必须看真实 hex 邻接。
- `RegionNode.controller` 不是直接推进权威。它由 `RegionOccupationRules.aggregateControl` 从 hex controller 加权派生。

### 1.4 Theater

源码：`WWIIHexV0/Core/Theater.swift`、`WWIIHexV0/Rules/TheaterSystem.swift`

`TheaterState` 关键字段：

```text
initialSnapshot: TheaterInitialSnapshot?
theaters: [TheaterId: TheaterNode]
hexToTheater: [HexCoord: TheaterId]
regionToTheater: [RegionId: TheaterId]
lastUpdatedTurn
```

`TheaterNode` 关键字段：

```text
id / name / status
regionIds
neighborTheaterIds
controllingFaction
controlRatios
victoryPointArea
frontWeight
unitIds
supportEligibleUnitIds
spilloverPolicy
recentThreats
```

当前语义必须分清三件事：

1. `initialSnapshot.regionToTheater`
   - 开局时捕获。
   - 只读初始战区布局。
   - UI 的 `initialTheater` 图层读取这里。
   - 地图编辑器导出的 region->theater assignment 会进入这里。

2. `regionToTheater`
   - 当前基础/初始战区单位。
   - 作为动态战区生成、合并、formalization、退役的参照。
   - 不代表运行时推进结果。
   - 不允许“占领一个 hex 后把整个 region 的 `regionToTheater` 改掉”。

3. `hexToTheater`
   - 运行时动态战区权威。
   - 单位突破进入某个 hex 后，只把这个 hex 改到进攻方动态战区。
   - 前线、动态战区图层、部署层都应以它为准。

`TheaterSystem.updateTheaters` 的派生刷新包括：

```text
seedMissingHexAssignments
  -> 给未填的 hexToTheater 填基础 regionToTheater
rebuildDynamicRegionMembership
  -> TheaterNode.regionIds 变为“该动态战区当前覆盖到的 region 集合”
rebuildNeighborTheaters
  -> 按 hexToTheater 的真实 hex 邻接生成战区邻接
assignUnits
  -> 按单位所在 hex 的 dynamicTheaterId 分配 theater.unitIds
calculateMetrics
  -> 按动态 theater 内 hex controller 计算 controlRatios / controllingFaction / frontWeight
```

`formalizationThreshold` 当前默认 0.70。它用于 formalized / provisional 状态判断，不阻止前线按单个 hex 推进。

### 1.5 FrontLine

源码：`WWIIHexV0/Core/FrontLine.swift`、`WWIIHexV0/Core/FrontSegment.swift`、`WWIIHexV0/Core/FrontLineState.swift`、`WWIIHexV0/Rules/FrontLineManager.swift`

`FrontLineState` 关键字段：

```text
frontLines: [FrontLineId: FrontLine]
regionStates: [RegionId: RegionFrontState]
enemyNeighborCache: [RegionId: [RegionId]]
dirtyRegionIds
diagnostics
```

`FrontLine`：

```text
id
theaterId
opposingTheaterIds
factionA / factionB
segments: [FrontSegment]
type: normal / breakthrough / encirclement
state: stable / pressured / collapsing 等
```

`FrontSegment`：

```text
regionA
regionB
edgeType
pressureLevel
supplyImpact
isEncirclementCandidate
```

当前前线生成逻辑：

```text
对每个 active theater:
  对 theater.regionIds 中的每个 region:
    只看该 region 内 dynamicTheaterId == theater.id 的 hex
    扫描这些 hex 的六向邻接 hex
    如果邻接 hex 属于另一个 dynamic theater
       且 DiplomacyState 判定双方 sourceFaction hostile:
         形成 enemy region 接触
         生成 FrontSegment(regionA: friendly region, regionB: enemy region)
```

重要结论：

- 前线不是 region 边界。
- 前线不是 initial theater 边界。
- 前线不是 `regionToTheater` 的邻接。
- 前线是真实动态战区 hex 接触。
- 同一个 region 被两个动态战区切开时，允许出现 `regionA == regionB` 的突破前线。这是 v0.358 后确认的合法状态。
- `FrontLine.type == .breakthrough` 的一个来源是：segment 的 `regionA` 仍由敌方 region controller 控制，但已有我方动态 theater hex 突入。

### 1.6 WarDeployment / FrontZone

源码：`WWIIHexV0/Core/WarDeploymentState.swift`、`WWIIHexV0/Core/FrontZone.swift`、`WWIIHexV0/Core/FrontZoneSegment.swift`、`WWIIHexV0/Rules/WarDeploymentManager.swift`

`WarDeploymentState` 关键字段：

```text
frontZones: [FrontZoneId: FrontZone]
hexToFrontZone: [HexCoord: FrontZoneId]
regionToFrontZone: [RegionId: FrontZoneId]
dirtyRegionIds
diagnostics
```

`FrontZone`：

```text
id / name
faction
regionIds
neighbors
frontSegments
unitsFront
unitsDepth
unitsGarrison
pressure
state
isCoreZone
```

当前部署层权威：

- `hexToFrontZone` 是动态部署归属权威。
- `regionToFrontZone` 是 dominant / fallback，不是突破推进权威。
- `FrontZoneId` 当前通常复用 `TheaterId.rawValue`。
- `WarDeploymentManager.advanceHex` 只推进一个 hex 的 zone 归属。
- `DeploymentLayer` / `UnitDeploymentRole` 当前落地为：
  - `frontUnit`
  - `depthUnit`
  - `garrisonUnit`

单位分配逻辑要点：

```text
每个 division:
  先按 division.coord 查 hexToFrontZone，fallback regionToFrontZone
  如果该 zone.faction == division.faction:
    使用该 zone
  否则如果所在 region 周边有己方 zone:
    分到相邻己方 zone
  否则 fallback 到该 faction 的 primary combat zone

  如果 hex 接触 hostile zone
     或 assignedZoneId != 当前 hex zoneId
     或当前 hex zone 对 assignedZone.faction hostile
     或 hex controller 对 assignedZone.faction hostile:
       unitsFront
  否则如果 zone.isCoreZone 或 region 有 city/factory/core:
       unitsGarrison
  否则:
       unitsDepth
```

这层是 AI 调度能否“看见部队”的关键。历史上的“AI 看起来不动”根因之一就是突破后的单位被误判成 garrison，从 `unitsFront` 调度池消失。现在前线/敌区/敌控 hex 会强制把这种单位归到 front。

### 1.7 DiplomacyState / 敌我关系 helper

源码：`WWIIHexV0/Core/DiplomacyState.swift`

`DiplomacyState` 当前保存：

```text
countries
blocs
relations
rulerRecords
lastUpdatedTurn
```

当前主链路已使用的能力：

- `isHostile(lhs, rhs)`：判断两个 faction 是否敌对。
- `isFriendly(lhs, rhs)`：判断两个 faction 是否友好或共同作战。
- `hostileFactions(to:)`：返回给定 faction 的敌对 faction 列表。

兼容规则：

- 同一 faction 永远不是 hostile。
- `.neutral` 不会因为缺少 relation 被视为 hostile。
- France 与第七次反法同盟默认 atWar；Anglo-Allied、Prussia、Austria、Russia、Spain 之间默认 coBelligerent。
- 旧数据缺少国家或关系时，不直接失败，回退为不同 faction 敌对。
- 有明确 relation 时，以 `DiplomaticStatus.isHostile` 为准。

当前读取 `DiplomacyState.isHostile` 的路径：

```text
SupplyRules / RegionSupplyRules
  -> 撤退安全格、补给通路是否穿过敌控 hex/region
RegionCombatRules
  -> region pressure 敌军统计
AgentContextBuilder
  -> enemyDivisions / enemy supply summary
MarshalBattlefieldSummarizer
  -> 目标丢失、敌控 region、敌军存在、敌军强度摘要
WarCommandExecutor
  -> 目标 hex / 接近 hex 排序时敌控优先
CommandValidator / RegionCommandValidator
  -> attack 目标必须 hostile
MovementRules
  -> ZOC 与路径阻挡只看 hostile 单位
OccupationRules / CommandExecutor
  -> friendly / coBelligerent 地块不可被占领或推进；neutral / hostile 可推进
FrontLineManager
  -> 动态战区邻接只在双方 hostile 时生成 front segment
WarDeploymentManager
  -> hostile zone、hostile presence、front/depth/garrison 分类和 encirclement contact
TheaterSystem
  -> frontWeight 与 theater retirement friendly neighbor 判断
ZoneCommanderAgent / GeneralRegistry
  -> 可见敌军、敌控 region、争夺前沿 presence 和 HQ under attack
```

仍未完成：

- `FrontLine.factionB` 仍是单一兼容字段；当前由对侧 segment controller 推导，后续完整多敌方前线应升级为 `opposingFactions` 或由 `opposingTheaterIds` 动态推导。
- `FrontZone.faction` 仍是单一势力字段；联军共同防区、混编指挥区和多势力 HQ 还没有设计。
- `ZoneCommanderAgent` / `GeneralRegistry` 仍按 exact faction 筛选可指挥单位和将军，这是指挥权边界，不是敌我关系；后续若要同盟指挥权共享，需要单独 schema。
- 默认启动已切到 Waterloo 1815 数据切片；阿登 legacy 仍保留为兼容 scenario，但默认隐藏在 `New Campaign` sheet 的 `Archived Campaigns` 开关后。当前滑铁卢仍是小规模 schema slice，不是完整战役。

### 1.8 v3.4 统治者战略姿态层

源码：`WWIIHexV0/Agents/RulerAgent.swift`、`WWIIHexV0/Turn/TurnManager.swift`

v3.4 起步后，默认 `.marshalDirective` AI 回合会先调用 `RulerAgent.automatic(for:in:)`，生成并校验 Codable `StrategicPostureEnvelope`。该 envelope 表示国家/联军级战略姿态，不代表可执行命令：

```text
RulerAgent
  -> StrategicPostureEnvelope
     - schemaVersion
     - issuerId
     - turn
     - faction / countryId
     - posture
     - preferredFrontZoneId
     - targetRegionIds
     - attackThresholdAdjustment
     - reserveBias
     - strategicIntent
     - coalitionGuidance
     - rationale
  -> StrategicPostureDecoder 校验 schema / issuer / turn / faction / zone / region
  -> RulerDecisionRecord 写入 diplomacyState.rulerRecords
  -> MarshalAgent 读取 strategicPosture 生成 TheaterDirectiveEnvelope
```

当前边界：

- 统治者只能位于元帅上游，输出国家级姿态、优先方向或约束条件。
- 统治者不得直接生成底层 `Command`，不得绕过 `MarshalAgent` / `ZoneDirective`。
- 统治者不得直接修改 `HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater` 或 `hexToFrontZone`。
- 解码失败时只能走 deterministic fallback，不执行半成品外部输出。
- 本切片尚未实现独立 ChiefOfStaff / CorpsCommander / Diplomat Agent，也未接真实 LLM。

### 1.9 EconomyState / EconomyRules

源码：`WWIIHexV0/Core/EconomyState.swift`、`WWIIHexV0/Rules/EconomyRules.swift`

v0.8 新增初级回合经济层。它是 faction 级总账，不是第三套地图权威。

`EconomyState`：

```text
ledgers: [Faction: FactionEconomyLedger]
lastResolvedTurn
```

`FactionEconomyLedger`：

```text
faction
stockpile: EconomyResources
lastIncome
lastUpkeep
lastReinforcementSpend
productionQueue: [ProductionOrder]
lastUpdatedTurn
```

`EconomyResources` 只包含三项：

```text
manpower
industry
supplies
```

v3.5 起步后，这三项仍是底层兼容 schema，不新增完整 ammunition / horses 经济账本字段；战术层另由 `Division.ammunition` 保存单位当前弹药：

- legacy Germany / Allies 路径仍显示 `Manpower / Industry / Supplies`、`Production`、`Infantry Division / Panzer Division / Motorized Division`。
- France / Anglo-Allied / Prussia / Austria / Russia / Spain 路径通过 `Faction.usesNapoleonicLogisticsVocabulary` 切换展示层，显示 `Recruits / Ammunition/Horses / Supplies`、`Reserves`、`Line Infantry Reserve / Guard Detachment / Cavalry Reserve / Artillery Battery / Supply Wagon`。
- `ProductionKind` raw case 仍保留 `panzerDivision`、`motorizedDivision` 等兼容名；拿战玩家可见名由 `ProductionKind.displayName(for:)` 提供。
- `EconomyResources.summary(for:)` 负责规则日志和 UI 成本摘要的 faction-aware 文案。

收入算法：

```text
对 faction 控制且 passable 的每个 region:
  如果该 region 没有任何真实己方控制 hex，跳过
  cityLevel = EconomyRules.cityLevel(region, map)
  coreBonus = region.coreOf 为空或包含 faction ? 1 : 0
  manpower = max(1, cityLevel.manpowerGrowth + coreBonus * 4 + infrastructure)
  industry = max(0, factories + cityLevel.industryValue + infrastructure / 3)
  supplies = max(1, supplyValue * 3 + factories + infrastructure / 2)
```

城市等级不是单独 JSON schema，当前从既有字段推导：

- capital、victoryPoints >= 5 或 factories >= 5 -> `metropolis`。
- victoryPoints >= 2、factories >= 2 或 supplyValue >= 3 -> `town`。
- 有 city / fortress / factory 但不满足上面条件 -> `village`。
- 没有城市、堡垒或工厂信号 -> `none`。

生产队列由 `Command.queueProduction(kind:)` 进入规则系统：

```text
EconomyPanelView
  -> AppContainer.queueProduction
  -> Command.queueProduction
  -> RuleEngine
  -> CommandValidator.validateProduction
  -> CommandExecutor.executeQueueProduction
  -> EconomyRules.queueProduction
```

排产时预付资源，完成时才部署单位或发放 supply stockpile。完成单位只能放到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex。找不到安全部署点时订单保留到下回合继续尝试。

v3.5 起，拿战 faction 的完成排产会由 `EconomyRules.makeNapoleonicProducedFormation` 生成拿战 component 组合：

- `infantryDivision` raw case -> line infantry reserve：`lineInfantry / lightInfantry / artillery`。
- `panzerDivision` raw case -> guard detachment：`guard / cavalry / artillery`。
- `motorizedDivision` raw case -> cavalry reserve：`cavalry / lightInfantry / artillery`。
- `artilleryDivision` raw case -> artillery battery：`artillery / lineInfantry`。
- legacy faction 仍走既有 `.infantry / .panzer / .motorized / .artillery` factory。

v3.5 起还新增最小 delayed reinforcement schedule：

```text
ScenarioDefinition.reinforcements?
  -> DataLoader.makeReinforcements
  -> GameState.reinforcementState.pending
  -> Command.endTurn
  -> EconomyRules.resolveFactionTurn
  -> EconomyRules.resolveScheduledReinforcements
  -> 找 entryCoord 2 格内安全己控空 hex
  -> 成功：append Division + mark arrived + reinforce 日志
  -> 失败：保留 pending + reinforce 日志
```

运行时边界：

- `reinforcements` 是 scenario JSON 的可选字段，旧阿登 JSON 缺字段时自动为空。
- `DataLoader` 校验 reinforcement faction、unit template、entry hex 和可选 trigger controller。
- 增援不会由 UI 或 Agent 直接塞进 `GameState.divisions`；只在 active faction 回合结算时由规则层处理。
- 安全入口要求：hex 存在、passable、controller 是 reinforcement faction、空置、非敌邻。
- 当前 Waterloo 数据切片已有 `fr_cavalry_reserve` 第 3 回合、`fr_imperial_guard_reserve` 第 5 回合法军入口，以及 `pr_bulow_iv_corps` 第 4 回合普军入口；普军 IV Corps 显式通过 `objective_prussian_arrival` + `triggerController=prussia` 绑定 Prussian Arrival Road 控制权。这只是入口路 hex 控制权触发，不代表完整 Prussian arrival 剧情规则。
- 当前 `pr_bulow_iv_corps` 已归属 `commander_bulow`，`entryCoord` 指向 q5,r1 Wavre Road 抽象后方入口；q4,r1 Prussian Arrival Road 仍是触发 objective 和 Waterloo hold 条件成员。Wavre Road 是 road / supply / reinforcement entry hex，不代表完整 Wavre 后方地图。
- `pr_blucher_approach_screen` 是 q4,r0 Prussian Approach 的开局初始屏护单位，和 `ReinforcementState.pending` / `pr_bulow_iv_corps` delayed reinforcement 分开；它不改变 q4,r1 触发 objective、q5,r1 Wavre Road 入口或任何增援时序。Prussian Approach region 保留后方轴线名称，q4,r0 另有非 objective 的 `key_prussian_approach_screen` road marker，q4,r1 的 key location / region objective 显示名与 scenario objective 统一为 Prussian Arrival Road。

自动补员在 active faction 结束回合时发生，只处理：

```text
本阵营
未毁灭
未撤退
supplied
strength < maxStrength
不与敌军相邻
```

每个单位每回合最多恢复 2 strength，并按装甲、摩托化、火炮权重扣 manpower / industry / supplies。v0.8 不恢复 organization。

战术 morale / fatigue / ammunition 当前不进入 faction 经济账本；它们由行动和休整直接落在 `Division` 上：

```text
move:
  根据 MovementPath.cost 增加 fatigue
  lowSupply / encircled 额外增加疲劳
attack:
  增加 fatigue
  弹药敏感单位消耗 1 ammunition
  目标按 strength 损失降低 morale
counterattack:
  增加少量 fatigue
  弹药敏感单位消耗 1 ammunition
  目标按 strength 损失降低 morale
hold:
  恢复 2 fatigue
  恢复少量 morale
resupply/rest:
  supplied 恢复 strength、fatigue、ammunition 和 morale
  lowSupply 只恢复少量 fatigue 和 morale
  encircled 不恢复
```

疲劳阈值会降低 attack / defense / movement；士气 <= 40 / <= 25 会降低 attack / defense，broken morale 还会触发 retreatable 单位自动撤退。`CommandValidator` 还会用 `.moraleBroken` 拒绝 morale <= `Division.brokenMoraleThreshold` 的 move / attack；hold、allowRetreat 和 resupply/rest 仍作为姿态或恢复路径允许走各自校验。弹药为 0 或 low ammunition 会降低弹药敏感单位的 effective attack。HUD、单位详情、tooltip、Agent D 摘要和 Marshal 前线摘要都会暴露这些警告。

---

## 2. 数据启动流程

### 2.1 默认启动路径

源码：`WWIIHexV0/Data/DataLoader.swift`、`WWIIHexV0/App/AppContainer.swift`

主入口：

```text
AppContainer.bootstrap()
  -> DataLoader().loadGameState(ScenarioCatalog.defaultPlayable)
     - 默认 Waterloo 加载失败时保留 Waterloo 元数据，构造 1x1 inert 恢复地图并提示从 New Campaign 手动选择
     - 恢复态使用 1 回合、1x1 inert 地图和 VictoryState.ongoing，避免加载失败时误进入胜负态
  -> RuleEngine()
  -> startup.scenario.defaultPlayerFaction
  -> StrategicStateBootstrapper().bootstrapIfNeeded(...)
  -> loadGeneralRegistry(startup.scenario)
     - 启动恢复态可降为空 registry 并写诊断；新局/继续路径 registry 失败会保留当前状态并返回失败
  -> AppContainer(... scenario: startup.scenario, playerFaction: startup.scenario.defaultPlayerFaction ...)
```

`DataLoader.loadInitialGameState()` 仍保留为 legacy/probe API；主 app 当前不再用它作为默认启动入口。v3.2 起步后场景入口已经从裸字符串硬编码抽出，v3.8 起主 app 默认启动直接走 `ScenarioCatalog.defaultPlayable`：

```text
ScenarioCatalog.defaultPlayable
  -> waterloo_1815_scenario
  -> waterloo_1815_regions
  -> napoleonic_terrain_rules
  -> napoleonic_unit_templates
  -> napoleonic_generals
  -> defaultPlayerFaction: france
```

`ScenarioCatalog.entry(for:)` 负责从存档或 runtime `GameState.scenarioId` 反查 catalog entry。阿登 legacy 的 catalog id 保持 `ardennes_v0`，MapEditor legacy JSON 的 runtime id / region `scenarioId` 仍是 `mapeditor_scenario`；两者通过 `runtimeScenarioIds` alias 解析到同一个 `ScenarioCatalog.ardennesLegacy`，避免继续存档、slot 摘要、HUD/棋盘标题和 legacy 数据校验出现身份分裂。

通过 `DataLoader.loadGameState(ScenarioCatalogEntry)` 进入的主路径会把 `GameState.scenarioId` 归一为 catalog id。保存 snapshot 前和继续恢复后也会再次归一，因此旧 `mapeditor_scenario` 快照仍可被 alias 接住，但新的 runtime / save payload 使用 `ardennes_v0` 或 `waterloo_1815` 这类 catalog id。`DataLoader.loadInitialGameState()` 仍优先加载 `ScenarioCatalog.ardennesLegacy`，保留给旧探针/测试路径。

v3.8 默认入口在 `loadGameState(scenarioName:regionName:unitTemplateName:generalCatalogName:terrainRulesName:)` 构造 `GameState` 前会运行通用资源校验：scenario / region scenarioId alias 必须匹配；terrain rule id / movementCost / defenseBonus / roadMovementCost / riverCrossingExtraCost 必须合法；tile controller、supplyFaction 和 riverEdges 必须是已知且已声明/可解析；region raw `hexToRegion` key 必须能解析为 `q,r` 且不能重复，映射目标必须存在，tile `regionId` 必须存在并与 `hexToRegion` 反向映射一致；初始单位不能重叠或引用缺失 tile/template/general；objective、tile objective、victory condition objective、victory target faction、Waterloo 已知 victory condition 形状、reinforcement trigger、region displayHex / representativeHex 和 assignedGeneralId 必须引用存在资源；unit template maxHP、component type、component weight、空 components、unit/reinforcement hp/facing/supplyState/retreatMode、keyLocations 的 id/coord/faction/objective/kind 也会检查。Waterloo 数据维护时，scenario objectives、tile objectiveId、keyLocations.objectiveId、victoryConditions.objectiveIds、reinforcements.triggerObjectiveId 与 region objectives 应保持同名战场目标口径一致；DataLoader 只校验 scenario 侧 objective 引用，region objectives 仍需数据审查同步。将领目录会先校验重复 general id、空 id/name、loyalty/satisfaction 范围，再构造 `GeneralRegistry`，场景资源校验还会检查将领 faction、preferredRegionIds 和 preferredTheaterIds 是否属于当前 scenario/region 数据。通过校验后，`DataLoader` 会把 scenario JSON 的 `victoryConditions` 映射为 `GameState.victoryConditions`，把场景 terrain JSON 映射为 `GameState.terrainRules`，供 `VictoryRules`、`MovementRules` 和 `CombatRules` 在运行时读取。若 raw `loadGameState` 调用未显式传 `terrainRulesName`，但 `scenarioName` / `regionName` 匹配 `ScenarioCatalog` 条目，DataLoader 会自动使用该条目的 terrain rules；自定义 MapEditor probe 仍走 `.legacy` fallback。Ardennes 的 Germany / Allies supply 与 Guderian 覆盖校验仍保留在 legacy `ScenarioDataSet` 路径，不套到 Waterloo。

`ScenarioCatalog.napoleonicTarget` 指向 v3.2 最小 Waterloo 1815 数据骨架：

```text
ScenarioCatalog.napoleonicTarget
  -> waterloo_1815_scenario
  -> waterloo_1815_regions
  -> napoleonic_terrain_rules
  -> napoleonic_unit_templates
  -> napoleonic_generals
```

当前 `waterloo_1815_*` JSON、`napoleonic_terrain_rules.json`、`napoleonic_unit_templates.json` 和 `napoleonic_generals.json` 已有小规模 schema slice，并已在 v3.7 加入 iOS / macOS target 的 bundle resources；v3.8 起它们也是默认启动路径，阿登只保留为 legacy 可选场景。`waterloo_1815_scenario.json` 的 release-facing displayName 为 `Waterloo 1815`，小规模数据切片边界写在 dataNotes / 文档中，不暴露在默认场景标题里。`waterloo_1815_scenario.json` 当前声明 6 个 scenario objectives；`waterloo_1815_regions.json` 当前声明对应的 6 个 region objectives，用于 region 级摘要、地图/面板展示和后续目标排序口径；Plancenoit 已作为法军持有的地图目标加入，但不在当前 `VictoryRules` 的 Waterloo runtime condition 中；q5,r1 Wavre Road 已作为普军后方 road / supply / reinforcement entry hex 加入，但不新增 objective，不代表完整 Wavre 后方地图；q2,r1 Anglo-Allied Rear Road 已作为 Mont-Saint-Jean 后方 road / supply hex 的非 objective key location marker 加入，scenario dataNotes 也记录其非 objective 后方补给路口径，不新增 objective、region、胜负条件或增援触发；`aa_papelotte_left_reserve` 已作为 Anglo-Allied 左翼预备加入 Papelotte 空 hex，复用现有 line infantry 模板和 Wellington 归属，不新增 objective、region 或胜负条件；La Haye Sainte 的 region 将领种子已对齐 `commander_wellington`，初始守军复用既有 `strongpoint_guard` 模板以匹配该据点 / fortress 口径；`fr_napoleon_center` 显示为 French I Corps Detachment，`pr_bulow_iv_corps` 显示为 Prussian IV Corps Vanguard，表达当前只是抽象 playable formation 而非完整 corps 级 OOB；`pr_blucher_approach_screen` 已作为 Prussian Approach q4,r0 前卫 screen 加入非 objective / 非 supply hex，复用 `prussian_vanguard` 模板和 Blucher 归属，不改变 q4,r1 Prussian Arrival Road 触发或 q5,r1 Wavre Road 增援入口；Prussian Approach region 保持后方轴线名称，q4,r1 key location / region objective 显示名与 scenario objective 统一为 Prussian Arrival Road。`napoleonic_generals.json` 当前已有 Napoleon / Wellington / Blucher / Bulow，Bulow 用于 Prussian IV Corps 的增援归属与偏好 region 数据，不代表完整 CorpsCommander Agent。该默认入口仍不是完整战役。v3.3 已新增拿战 `ComponentType` case，`napoleonic_unit_templates.json` 当前使用 `lineInfantry`、`lightInfantry`、`cavalry`、`guard`、`engineer` 和 `artillery` raw value，其中 `guard` 对应 Swift case `guardInfantry`；Waterloo 增援表已开始使用 `cavalry_reserve`，让法国骑兵预备队在默认数据切片中可见，`reserve_infantry_column` 的 guard 权重也达到既有 guard morale 阈值。Waterloo 移动/战斗主路径已读取 `GameState.terrainRules`：`MovementRules` 使用 scenario road / terrain / river movement cost，骑兵进入 hill / forest / city / fortress 会额外消耗 1 点移动、进入 mountain 额外消耗 2 点；`CombatRules` 使用 scenario terrain defense 与 river extra cost；`WarCommandExecutor` 与 `ZoneCommanderAgent` 的 breakthrough / defensive sorting 也同步读取同一 rule set。`BaseTerrain` 仍是旧存档和 legacy fallback，并继续承载 JSON 未覆盖的特化语义，例如 infantry support、cavalry/artillery adjustment、armor slowdown、supply path 和 region path 成本。`CombatRules` 已有最小拿战战术修正：骑兵进攻 plain 有轻量加成，攻击 hill / forest / mountain / city / fortress 受限，HOLD 的重步兵可压制平地骑兵冲击；远程炮兵对 plain / hill 目标略有优势，对复杂/据点地形略受限。`WarCommandExecutor` 的 breakthrough / spearhead 会先按 artillery-first 排序，fire coverage 在存在炮兵或远程单位时只提交这些单位；`MockAIClient` 会把 `cityName` / `fortressName` tile 也视为 objective-like 炮兵目标，避免 hill + cityName 的 Mont-Saint-Jean 被低估；fallback 目标选择会在未控制目标中按 Waterloo 已知 objective id 和当前 faction 做 deterministic objective-aware sorting，再用 kind / name / id 稳定排序，France 优先 Mont-Saint-Jean / La Haye Sainte，Prussia 优先 Prussian Arrival Road / Plancenoit，legacy 和未知 objective 仍回退旧 type 排序；该排序只决定 fallback move 候选顺序，不改 objective 数据、hex/region controller、VictoryRules 或命令执行链；部署 contact reason 在拿战 faction 下优先使用 region name / 格式化 sector 名，不再直接拼 raw region id。`Division` 已有最小 morale 字段，战斗损失、HOLD、resupply/rest、撤退失败和包围损耗会改变 morale，低士气会降低攻防并触发 retreatable 单位撤退。完整 terrain DSL、队形、完整骑兵冲锋和炮兵准备尚未完成。
旧 `DataLoader.loadInitialGameState()` 仍可作为 legacy / probe API 读取老阿登路径，但主 app 默认启动不再用它兜底。

v3.7 起 `AppContainer` 还维护当前新局配置：

```text
RootGameView / HUD NewGameButton
  -> NewGameSetupView
  -> AppContainer.startNewGame(scenario:playerFaction:startsAtPlayerFaction:)
  -> DataLoader.loadGameState(ScenarioCatalogEntry)
  -> dataLoader.loadGeneralRegistry(scenario)
  -> 可选把 activeFaction / phase 切到玩家所选 power
  -> StrategicStateBootstrapper.bootstrapIfNeeded
  -> GeneralDispatcher.assignGenerals
  -> 清空 selection / highlights / dispatch history
```

`NewGameSetupView` 只收集 scenario、玩家 power 与 Opening Turn 配置；它不直接修改 `GameState`。这里的 power 是玩家可见文案，底层仍使用 `Faction` / `playerFaction` schema 和 API。可选阵营来自所选 scenario JSON 的 `factions`，过滤 neutral 后按 `Faction.turnOrderPriority` 排序。Opening Turn 开启时，`AppContainer` 在新局装配阶段把 `activeFaction` 设为玩家所选 faction，`phase` 设为 `.playerCommand`，展示为玩家所选 power 的 orders phase，清空本回合玩家锁定并重置该 faction 已部署 formation 的 `hasActed`；这不改变 hex controller、division coord、动态战区、部署层或经济账本。若 campaign data 读取失败，`AppContainer` 保留当前局面并把失败原因写入 `lastCommandMessage` 与 interaction log；`RootGameView` 会把 `startNewGame` 的返回结果传回 sheet，失败时保留 `NewGameSetupView` 并在本地 Status 区块显示该消息。

同一 sheet 也承载 v3.7 基础 session 设置：

```text
NewGameSetupView Settings
  -> Observer Mode
  -> Map Layer
  -> Dispatch Detail
  -> AI Pace
  -> AI Control
  -> Guide Notes
  -> Reduce Motion
  -> Text Size
  -> AppContainer.applySessionSettings(observerModeEnabled:mapDisplayLayer:replayDetailLevel:aiCommandPace:aiControlMode:playtestGuideCuesEnabled:playtestTextSize:reduceMotionEnabled:)
  -> PlaytestSessionSettings
  -> UserDefaults["WWIIHexV0.playtestSessionSettings.v1"]
```

`PlaytestSessionSettings` 当前持久化 observer mode、map layer、`ReplayDetailLevel`、`AICommandPace`、`PlaytestAIControlMode`、Guide Notes、Reduce Motion 和 `PlaytestTextSize`，仍只影响本地 UI / replay / simulated staff 触发与节奏，不写入 `GameState` 或存档。`PlaytestSessionSettings.loadResult` 会区分 missing / loaded / resetToStandard；偏好数据无法解码时移除损坏的 `UserDefaults` 值、恢复标准设置，并通过 `AppContainer.sessionSettingsRecoveryMessage` 写入 interaction log 和 `NewGameSetupView` Settings 区块。`ReplayDetailLevel` 有 Concise / Standard / Full 三档，控制 `AppContainer.displayEventLog` 的日志条数、`EventLogView` 的 metadata 粒度、`AgentPanelView` 的 directive 条数、可读 Staff Summary、Issue Preview、Recent Dispatch Timeline、context summary、逐条命令/directive 明细和 Dispatch Audit / raw JSON 审计显示。`PlaytestAIControlMode` 有 Staff / Manual 两档，默认 Staff 保持旧行为：非 observer 下玩家所选 faction 手动，其它非 neutral faction 自动触发 simulated staff；observer mode 下 Staff 可让玩家所选 faction 也自动触发，并可用 End Orders / End Turn 触发 staff dispatch。Manual 只关闭自动 dispatch 触发；非 observer 下人工仍通过 HUD / CommandPanel 的 End Orders 发送 `Command.endTurn` 推进当前 active faction，包括非玩家 faction；observer + Manual 保持只读，End Orders disabled，`AppContainer.submit(_:)` 拒绝 observer 直接命令，不允许绕过 `WarCommandExecutor`、`RuleEngine` 或直接操控其它 faction 单位。`PlaytestTextSize` 有 Compact / Standard / Large 三档，使用 Dynamic Type 字体样式调整 `EventLogView` 与 `AgentPanelView` 的标题、metadata、正文、审计文本和行距，不改变日志内容、AI 输出或规则执行。`TurnManager` 生成的默认 staff 失败、end orders 失败、空 directive、directive 拒绝和缺少 corps sector 诊断已改为 Staff / Corps / End Orders 文案，并通过 `CommandValidationError.displayName(for:)` 显示拿战校验原因；`AppContainer` 在把连续 staff errors 写入 interaction log 前会净化 faction 名、MockAI、legacy pipeline 和 validation rawValue，避免 CommandPanel / EventLog 的玩家可见消息绕过 UI sanitizer。`EventLogView` 在拿战 faction 下会把 Standard / Concise 事件正文和 metadata 中的 raw AI、MockAI、legacy pipeline、Germany / Allies 等审计词转成 Staff / Simulated Staff / Archived Campaigns / Coalition 口径；事件正文优先用 `GameLogEntry.faction` 选择 sanitizer，避免当前 active faction 推进后误用其它 faction 口径；底层 `GameLogEntry.message` 不被改写。`AgentPanelView` 的摘要只读聚合当前 `AgentDecisionRecord` 与最近 `WarDirectiveRecord`，显示执行数、拒绝数、问题数、focus sector / target 和最新 tactic；拿战 faction 下 raw `*_mock_commander` agent id、marshal id、`MockAI` provider、front zone / region / theater raw id、普通 tactic/category、deployment role、record error 和 directive diagnostic 会包装为 Command Staff / Marshal / Simulated Staff / 可读命令名 / sector / wing / staff note 展示，其中 ruler focus 使用 `RulerDecisionRecord.faction`、directive badge / target / diagnostics / focus summary 使用 `WarDirectiveRecord.faction`，不依赖当前 active faction；Full 下拿战路径的 raw JSON 区块标题显示为 Dispatch Audit，空态显示 `No dispatch audit recorded.`，可见审计正文也走 `NapoleonicMessageSanitizer`；底层 `AgentDecisionRecord.rawJSON` 和 legacy raw JSON 展示不被改写。Issue Preview 只读 `AgentDecisionRecord.errors`、`CommandResultSummary.errors` 和 `WarDirectiveRecord.diagnostics`，Concise 只显示一条全局原因，Standard 显示前几条，Full 不限制并可看明细；Recent Dispatch Timeline 只读最近 directive 的 turn、scope、target、tactic、执行/拒绝/问题数和最多两条 directive-level 拒绝/诊断原因，帮助玩家理解 AI 回合节奏；Concise 下保留摘要、时间线与问题反馈，隐藏逐条 command / directive 明细。`AICommandPace` 只在 `runAISequence` 调用 simulated staff 前插入短延迟，不改变 AI 输出、命令校验或规则执行；Reduce Motion 开启时跳过这段本地等待；Guide Notes 关闭时 `PlaytestGuideCue` 不再写入首次选择/结束命令的短提示。

v3.8 默认拿战 replay 展示继续收口：`MockAI+MarshalDirective` 等 provider 也按 `Simulated Staff` 展示，Standard context summary 与 intent 会走拿战 sanitizer，缺省 AgentPanel / EventLog 预览以 France 口径显示，EventLog phase metadata 在拿战 faction 下显示 `Orders` / `Staff Dispatch`，DataLoader 初始日志只写 `Campaign loaded.` / `Archived campaign loaded.`，EventLog / AgentPanel / AppContainer interaction log 的 Standard / Concise 层会净化 raw diagnostic、legacy pipeline、front zone / region / theater id、WWII faction 名、germanAI / alliedPlayer 与 Panzer / tank / motorized 等 legacy token；AgentPanel Full 拿战标题显示 `Dispatch Audit` 并净化可见审计文本，底层 raw JSON 仍保留审计内容。

EventLog 分类名在拿战 faction 下显示为 Engagement / Withdrawal / Reserve / Logistics / Isolation / Contact / Wing / Sector / Coalition / Dispatch；encirclement attrition / encircled 等正文在 Standard / Concise 层显示为 isolation losses / isolated。这是展示层映射，不改写 `GameLogEntry` 底层 category 或 message，Full/raw 审计口径仍保留。

v3.8 后续收口还覆盖 ruler/focus raw id：`AgentPanelView` 和 `DiplomacyPanelView` 在 Standard / Concise 层把 `ruler_*`、front zone id、country / bloc id 和 ruler rationale 中的 legacy / raw 诊断词显示成可读 commander / sector / country / coalition 文案；`GeneralCommandPanelView` 的 corps zone 名称与 planned operation target 在拿战 faction 下优先显示 region/front-zone 名称或格式化 sector；`Command.displayName(for:in:)` 会在有 `GameState` 的玩家命令、RuleEngine 结果、WarCommandExecutor 诊断和 AgentPanel command results 中用 formation name 替代 raw unit id；`AppContainer` 的玩家 corps order interaction log 和选中 sector interaction log 也会优先显示 front zone / region 名称或可读 sector 名，而不是 raw `zoneId` / `regionId`。`StrategicPostureDecoderError`、`TheaterDirectiveDecoderError`、legacy `CommandIntentAdapterError` 与 legacy AI order refusal 摘要也会把 region / theater / front-zone id 和 validation raw value 包装成可读 sector / wing / order reason；Full raw JSON 与底层 schema 仍保留审计值。`CommandExecutor` 的拿战动态推进事件会优先显示 theater name 或格式化 wing 名，legacy 路径仍保留 raw dynamic theater id 便于兼容调试。

v3.7 短引导同样只走本地 interaction log：

```text
玩家首次选择本方 formation / artillery / cavalry
  -> AppContainer.appendPlaytestSelectionCues
  -> PlaytestGuideCue
  -> interactionLog 追加 Staff note

玩家首次结束本方命令阶段
  -> AppContainer.endTurn
  -> PlaytestGuideCue.endingOrders
  -> interactionLog 追加 Staff note
  -> Command.endTurn
  -> RuleEngine
```

`PlaytestGuideCue` 当前不弹 modal、不阻塞地图、不写入 `GameState`，也不绕过 `Command` / `RuleEngine`。`deliveredPlaytestCues` 只是 `AppContainer` 本地集合，新局和继续时清空，用于避免同一局面反复刷提示。
`playtestGuideCuesEnabled` 同样只存在于 `AppContainer` / `PlaytestSessionSettings`，关闭后只屏蔽本地 `Staff note`，不改变可选命令、AI 输出或规则状态。

v3.7 还补了两类最小无行动反馈和一类 AI dispatch 诊断：

```text
玩家命令阶段
  -> AppContainer.playerOrdersStatusMessage
  -> 统计 playerFaction 未毁灭且未 acted 的 formation / unit
  -> CommandPanelView 未选中单位时显示仍有几支可行动，或提示全部已用完

AI 回合结束
  -> AppContainer.aiNoActionFeedbackMessage
  -> 检查 AgentDecisionRecord.commandResults
  -> 如果没有非 End Turn 的已执行战场命令
  -> interactionLog 追加 Staff note / AI note

AI 诊断
  -> AppContainer.aiDiagnosticFeedbackMessages
  -> 聚合连续 AI faction 的 AgentDecisionRecord.errors
  -> interactionLog 追加 Staff dispatch issue / AI issue，最多显示前三条
  -> runAISequence 到达有限步数但仍 AI-eligible 时追加 dispatch paused 诊断
  -> TurnManager.executeDirectiveEnvelope 把默认 directive 管线的 AI end-turn 失败同步进诊断型 WarDirectiveRecord

AI 回放拒绝原因预览
  -> AgentPanelView.dispatchIssuePreviewLines
  -> 合并 AgentDecisionRecord.errors / CommandResultSummary.errors / WarDirectiveRecord.diagnostics
  -> Issue Preview 显示全局短原因，Recent Dispatch Timeline 显示每条 directive 的首要原因
  -> 只读展示；不重试命令、不恢复状态、不替代 CommandValidator / RuleEngine
```

这些反馈只读 `GameState` / `AgentDecisionRecord` / `CommandResultSummary` / `WarDirectiveRecord` 并写本地展示日志、诊断记录或面板预览；它们不生成命令、不改变 `HexTile.controller`、`Division.coord`、`hexToTheater`、`hexToFrontZone` 或经济账本，也不替代 `CommandValidator` / `RuleEngine`。Legacy Agent D 路径的 end-turn 失败仍主要通过 `AgentDecisionRecord.errors` 可见，默认战争 AI 主路径是 directive / marshal 管线。

v3.7 同时有最小三槽保存/继续路径：

```text
NewGameSetupView
  -> 选择 GameSaveSlot(slot1 / slot2 / slot3)
  -> 可选编辑 Slot Name / Rename Slot
  -> AppContainer.setSaveSlotLabel(label, for: slot)
  -> UserDefaults[slot.labelDefaultsKey]，不写入 GameSaveSnapshot schema
  -> AppContainer.saveCurrentGame(to: slot)
  -> normalizeCommandPhase(gameState)
  -> 将 snapshot.gameState.scenarioId 归一为 currentScenario.id
  -> GameSaveSnapshot(schemaVersion: 1, scenarioId, playerFaction, startsAtPlayerFaction, savedAt, GameState)
  -> UserDefaults[slot.defaultsKey]

NewGameSetupView
  -> 选择 GameSaveSlot
  -> AppContainer.continueSavedGame(from: slot)
  -> GameSaveSnapshot.load(slot:) 区分 missing / loaded / unavailable
  -> slot1 若没有新 key，会兼容读取旧 UserDefaults["WWIIHexV0.savedGameSnapshot.v1"]
  -> 只接受 schemaVersion 1；坏快照或 schema 不兼容会写入 savedGameRecoveryMessages[slot]
  -> ScenarioCatalog 必须匹配 snapshot.scenarioId；找不到 scenario 时标记该 slot 不可继续
  -> ScenarioCatalog.entry(for:) 接受 catalog id 和 runtime alias
  -> bootstrap 后将恢复的 GameState.scenarioId 归一为 scenario.id
  -> dataLoader.loadGeneralRegistry(scenario)
  -> StrategicStateBootstrapper.bootstrapIfNeeded(snapshot.gameState)
  -> GeneralDispatcher.assignGenerals
  -> 清空 selection / highlights / dispatch history
  -> AppContainer.runAIIfNeeded()
  -> Staff 模式（包括 observer + Staff）若恢复到 AI-eligible activeFaction，则继续 simulated staff；非 observer 下 Manual 需由人工 End Orders 推进，observer + Manual 只读

NewGameSetupView
  -> 选择 GameSaveSlot
  -> AppContainer.clearSavedGame(slot: slot)
  -> 删除 UserDefaults[slot.defaultsKey]，slot1 同时删除 legacy key
  -> 清空 savedGameSummaries[slot] / savedGameRecoveryMessages[slot] 并写入 interaction log
```

保存/继续只装配和恢复本地试玩 snapshot，不是完整发布级存档系统；不可解码、schema 不兼容或引用当前构建不存在 scenario 的快照只显示不可用原因，不自动删除，仍由玩家在 Continue 区块选择对应 slot 后点 `Clear Saved` 清理。当前多 slot 固定为 3 个 `UserDefaults` 本地试玩槽，只提供独立 `UserDefaults` slot label，不提供发布级命名存档、文件导出、云同步、自动 schema 迁移器或运行时恢复验收。继续后只调用既有 `runAIIfNeeded()` eligibility gate；如果 Staff 模式（包括 observer + Staff）恢复到 AI-eligible active faction，后续 AI 行动仍必须经 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine`，Manual 不自动 dispatch，observer + Manual 保持只读。

`NewGameSetupView` 会把 Start、Save Current、Continue Saved 和 Clear Saved 的回调结果保存成本地 `operationStatusMessage`。开始/继续成功后 sheet 仍按原行为关闭；开始/继续失败、保存成功/失败和清理成功会留在 sheet 内显示可读状态。该状态只来自 `AppContainer.lastCommandMessage` / 回调 fallback，不写入 `GameState`、存档或规则事件。

### 2.2 loadGameState 的完整链条

源码：`WWIIHexV0/Data/DataLoader.swift`

```text
loadGameState(ScenarioCatalogEntry)
  -> loadScenarioDefinition(named: scenarioName)
  -> validate initialPhase / playerFaction / aiFaction against declared factions
  -> loadRegionDataSet(named: regionName)
  -> loadTerrainRules(named: terrainRulesName)
     - 阿登 legacy 读 terrain_rules
     - Waterloo 目标读 napoleonic_terrain_rules
     - v3.8 起会映射为 GameState.terrainRules；Waterloo 主路径移动、战斗和 AI tactical sorting 读取该运行时规则集
  -> loadUnitTemplates(named: unitTemplateName)
  -> makeMapState(from: scenario)
     - ScenarioTileDefinition -> HexTile
     - tile.controller 字符串转 Faction；"neutral" 在 v3.1 后转为 `.neutral`，旧缺省仍可保持 nil
     - tile.regionId 写入 HexTile.regionId
     - supply source / objective 写入 MapState
     - regionData.objectives 仍属于 region 数据层目标摘要，不替代 MapState.objectives；Waterloo 数据应保持两者覆盖同一批关键战场点
  -> apply(regionData, to: map)
     - regionData.toRegions()
     - regionData.toHexToRegion()
     - regionData.toRegionEdges()
     - 反填 HexTile.regionId
     - validateRegionGraph()
  -> RegionOccupationRules().mapByAggregatingControllers(in: map)
     - 从 hex controller 派生 region controller
  -> makeDivisions(from: scenario.initialUnits, unitTemplateName:)
     - 阿登 legacy 读 unit_templates
     - Waterloo 目标读 napoleonic_unit_templates
     - legacy 模板目录保留旧 fallback；非 legacy 模板目录要求 templateId 命中，并使用模板 maxHP
  -> makeTheaterState(map, regionData, divisions, diplomacyState, turn)
     - 优先使用 regionData.regions[].theaterId
     - 没有 assignment 时使用 TheaterSystem.makeInitialFixedTheaters
     - TheaterSystem.updateTheaters seed hexToTheater 并刷新派生字段
     - capture initialSnapshot
  -> FrontLineManager.makeInitialState(...)
  -> WarDeploymentManager.makeInitialState(...)
  -> assignGenerals(..., generalCatalogName:)
     - 阿登 legacy 读 generals
     - Waterloo 目标读 napoleonic_generals
  -> GameState(...)
```

DEBUG 下资源读取优先源码目录 `WWIIHexV0/Data/*.json`，不是旧 bundle。旧 simulator 进程不会自动重载，改默认地图后需要重新运行 app。

v3.8 起 `AppContainer.bootstrap()` 不再通过 `DataLoader.loadInitialGameState()` 静默回退默认入口；它先尝试 `ScenarioCatalog.defaultPlayable`，成功时同步使用 Waterloo 场景、France 默认玩家阵营和 Waterloo 将领目录。若默认场景加载失败，会保留 Waterloo 场景元数据、构造 1x1 inert 恢复地图，并在 interaction log 写入提示，要求玩家打开 `New Campaign` 切换到可用 scenario，避免默认发布候选入口静默暴露阿登 legacy 内容；该恢复态的 `victoryState` 固定为 `.ongoing`，不触发胜负态。启动恢复态若将领目录也加载失败，只降为空 registry 并写入诊断；若默认场景已成功加载但启动阶段二次读取将领目录失败，则同样改用 1x1 inert 恢复态，不让正常 Waterloo 局面带 `.empty` commander registry 继续运行。`startNewGame` 和 `continueSavedGame` 的将领目录失败会保留当前状态并返回失败，继续 slot 仍保留摘要并显示 recovery message。继续存档和 slot summary 使用 `ScenarioCatalog.entry(for:)`，因此 legacy 快照中无论记录 `ardennes_v0` 还是 `mapeditor_scenario` 都会回到同一阿登 legacy entry。`DataLoader.loadGameState` 会复用已加载并校验过的 `GeneralRegistry` 分配部署层将领，不再在 `assignGenerals` 内二次 `try?` 读取。默认 stored Guderian `TurnManager` 会同时校验当前 scenario 与 runtime `GameState.scenarioId` 都匹配 Ardennes legacy，避免外部注入状态误触发 legacy manager。`DataLoader.loadInitialGameState()` 仍作为 legacy 兼容 API 保留给旧探针/测试路径。

### 2.3 StrategicStateBootstrapper

源码：`WWIIHexV0/Core/StrategicStateBootstrapper.swift`

它有两个用途：

1. `bootstrapIfNeeded`
   - 只补缺失层。
   - 先用 `EconomyRules.bootstrapIfNeeded` 为旧状态补 faction 经济总账。
   - 如果 state 有 region 但缺 theater/front/deployment，会从当前 map/divisions 生成。
   - App 初始化、命令提交后会用它兜底。

2. `refreshRuntimeState`
   - 强制刷新运行时派生层。
   - 先聚合 region controller。
   - 强制 `TheaterSystem.updateTheaters(force: true)`。
   - 重新 `FrontLineManager.makeInitialState`。
   - 重新 `WarDeploymentState.bootstrapFrontZones`。
   - AI 行动前会调用，确保指令读取的是当前动态层。

---

## 3. 地图编辑器流程

### 3.1 MapEditorDocument

源码：`MapEditor/MapEditorDocument.swift`

编辑器自己的文档模型：

```text
id / displayName
width / height
hexes: [HexCoord: MapEditorHex]
regions: [RegionId: MapEditorRegionDraft]
theaters: [TheaterId: MapEditorTheaterDraft]
regionTheaterAssignments: [RegionId: TheaterId]
initialUnits: [MapEditorUnitDraft]
backgroundImage
```

四种编辑模式：

```text
hexPainter         地块
regionBuilder      省份
theaterAssignment  战区
unitPlanner        部队
```

编辑动作：

```text
idle
adding
deleting
```

地块工具：

```text
paint   覆盖已有 hex
extend  在已有 hex 邻位扩展稀疏地图
```

关键行为：

- `MapEditorDocument.contains(_:)` 判断实际存在的 hex，支持稀疏地图。
- `addHex(at:)` 只能在已有 hex 邻位扩展，避免凭空造孤岛。
- `deleteHex(at:)` 会删除该 hex 上初始部队；如果某 region 已无 hex，会删除 region 和 theater assignment。
- `resize` 会裁剪外部 hex、清理无效 region assignment 和越界单位。
- 底图 `backgroundImage` 只存在编辑器文档，不写入游戏 JSON。

### 3.2 编辑会话

源码：`MapEditor/MapEditorViewModel.swift`

典型流程：

```text
选择 mode
  -> beginAdding / beginDeleting
  -> 点击或拖拽 canvas
  -> applyPrimaryAction(at:)
  -> stage 或直接编辑
  -> finishEditing
  -> commitPendingRegion / commitPendingTheater / commitPendingUnits
```

不同模式行为：

- `hexPainter`
  - adding + paint：写 terrain、road、controller、supply。
  - adding + extend：尝试在相邻空位生成 plain hex。
  - deleting：删除 hex。

- `regionBuilder`
  - adding：把点击 hex 先放进 `pendingRegionHexes`，完成时统一 assign 到选中或新建 region。
  - deleting / erase：把 hex 的 regionId 清空。

- `theaterAssignment`
  - 点击 hex 后先取该 hex 的 regionId。
  - adding：把 region 放进 `pendingTheaterRegions`，完成时统一 assign 到选中或新建 theater。
  - deleting：清除 region 的 theater assignment。

- `unitPlanner`
  - adding：点击 hex 放入 `pendingUnitHexes`，完成时按模板、阵营、朝向、HP 生成初始单位。
  - 同一 hex 新 stamp 会先删除原单位。
  - deleting / erase：删除该 hex 上初始单位。

快捷键：

- `N`：添加。
- `M`：完成。

### 3.3 导出链路

源码：`MapEditor/MapEditorExporter.swift`

导出产物：

```text
ScenarioDefinition JSON
RegionDataSet JSON
```

导出前校验：

- 所有 hex 必须有 regionId，否则 `unassignedHex`。
- 所有被引用 region 必须在 `document.regions` 里定义。
- 每个导出的 region 必须至少有一个 hex，否则 `emptyRegion`。

`ScenarioDefinition` 写入：

- map width/height/isSparse。
- 每个 `MapEditorHex` 写为 `ScenarioTileDefinition`。
- terrain / road / controller / city / fortress / supply / objective / regionId。
- factions 从 hex controller、supply faction、initial units、region owner/controller/coreOf 聚合；若没有非 neutral faction，fallback 到 legacy Germany / Allies；显式 neutral-only 文档会额外保留 `.neutral`。
- initialTurn 固定 1；initialPhase、playerFaction、aiFaction 按导出 faction 派生，legacy Allies 优先作为 player，拿战 France 优先作为 player，AI faction 取另一个非 neutral faction。
- `initialUnits` 从 `MapEditorUnitDraft` 写入。
- 底图不写入。

`RegionDataSet` 写入：

```text
hexToRegion:
  每个 hex 的 coord key -> regionId

regions:
  每个 MapEditorRegionDraft -> RegionNodeDefinition
  theaterId = document.regionTheaterAssignments[draft.id]
  displayHexes = 属于该 region 的 hex
  representativeHex = displayHexes 几何中心最近 hex
  terrain = region 内 dominant terrain
  city = 第一处 city / fortress / city terrain
  neighbors = 从 hex 邻接自动推导

edges:
  从跨 region hex 邻接自动推导
  两侧 hex 都有 road 时 hasRoad = true

supplySources / objectives:
  从对应 hex 自动归到 region
```

重要：region 邻接和 edge 不是人工手填权威，而是在导出时从真实 hex 邻接推导。这和运行时前线必须看 hex 邻接是一致的。

### 3.4 MapEditor legacy 阿登资源桥

源码：`MapEditor/MapEditorGameResourceBridge.swift`

legacy 阿登读写路径：

```text
WWIIHexV0/Data/ardennes_v0_scenario.json
WWIIHexV0/Data/ardennes_v02_regions.json
```

流程：

```text
loadLegacyArdennesDocument()
  -> 读取 legacy Ardennes ScenarioDefinition + RegionDataSet
  -> makeDocument(...)
     - scenario tile -> MapEditorHex
     - regionData.toHexToRegion 优先填 regionId
     - region definitions -> MapEditorRegionDraft
     - region theaterId -> regionTheaterAssignments
     - scenario initialUnits -> MapEditorUnitDraft

overwriteLegacyArdennesGameResources(document:)
  -> MapEditorExporter.export(... 固定 legacy Ardennes 文件名)
  -> 写回 WWIIHexV0/Data
```

旧 `loadDefaultDocument()` / `overwriteDefaultGameResources(document:)` 仍保留为兼容 wrapper，但 MapEditor UI 和 ViewModel 已改用 legacy Ardennes 命名。该桥不等于当前 playable 默认入口；主游戏默认入口由 `ScenarioCatalog.defaultPlayable` 控制，当前指向 Waterloo 1815。MapEditor 新建单位 id 前缀按 faction 和已有 id suffix 生成，避免 France / Prussia 等非 Germany 单位继续写成 `all_*`，也避免替换单位时复用已存在 id。legacy 资源桥读取 scenario initialUnits 时不再把未知 faction 静默兜底为 `.allies`，而是抛出 unknown faction 错误；tile controller、supplyFaction、unit facing、retreatMode、supplyState 和 region `hexToRegion` raw key 也会 fail-fast，不再用 nil、`.west`、`.retreatable` 或 `.supplied` 覆盖坏数据；MapEditor canvas 的单位缩写优先识别 cavalry / guard / battery / supply / light infantry / line infantry，拿战模板会显示 CAV / GD / BAT / SUP / LGT / LINE，panzer / tank / motorized 缩写只作为 legacy fallback；MapEditor 导出端对纯 neutral / blank 文档不再注入 Germany / Allies，而是导出 `.neutral` faction 与 `.resolution` phase。

相关测试确认：

- 编辑器 document、导出 JSON、游戏加载后的 `hexToRegion` / `regionToTheater` / `tile.regionId` / `region.name` 必须一致。
- 游戏和编辑器 hex layout 的垂直方向必须一致。
- 默认开局单位不能出现在敌对初始 theater 中。
- App bootstrap 不应自动跑 AI 或移动开局单位。

---

## 4. 主游戏 UI 与输入流程

### 4.1 AppContainer

源码：`WWIIHexV0/App/AppContainer.swift`

`AppContainer` 是 SwiftUI 和规则层之间的中介。它持有：

```text
@Published gameState
selectedUnitId / selectedHex / selectedRegionId
movementHighlights / attackHighlights
interactionLog
lastCommandMessage
lastAgentDecisionRecord
lastWarDirectiveRecords
observerModeEnabled
mapDisplayLayer
```

玩家提交命令：

```text
submit(command)
  -> commandHandler.execute(command, in: gameState)
  -> StrategicStateBootstrapper.bootstrapIfNeeded(result.state)
  -> lastCommandMessage = result.message
  -> appendInteractionEvent(...)
  -> refreshSelectionAfterStateChange()
  -> runAIIfNeeded()
```

点击地图：

```text
handleBoardTap(coord)
  -> selectedHex = coord
  -> selectedRegionId = MapDisplayAdapter.regionId(for: coord)
  -> 如果已有己方可行动单位选中，且点击处有 DiplomacyState.isHostile 判定的敌军:
       submit(.attack)
     else 如果点击处有单位:
       handleDivisionTap
     else 如果已有己方可行动单位选中:
       submit(.move)
     else:
       清空选择
```

v3.8 起，`handleBoardTap`、`handleDivisionTap`、`selectedAttackTarget`、`selectedGeneralSourceZone` 和 `attackHighlights` 的敌军 / 目标判定都应读取 `gameState.diplomacyState.isHostile`；co-belligerent / allied formation 被点击时只能作为友军选择或查看，不应作为攻击目标或攻击高亮。`GeneralCommandPanelView` 只在 `canAttackRegion` 为 true 时显示目标 region。

玩家可行动单位必须满足：

- 非 observer mode。
- 单位属于 `playerFaction`。
- 当前 activeFaction 是 `playerFaction`。
- 当前 `phase.allowsCommands == true`。
- 未行动。
- move / attack 还要求 morale 高于 `Division.brokenMoraleThreshold`；低于或等于该阈值时由 `CommandValidator` 返回 `.moraleBroken`，但 hold / allowRetreat / resupply 仍可作为恢复或撤退相关命令。

### 4.2 RootGameView

源码：`WWIIHexV0/UI/RootGameView.swift`

主界面元素：

- `BoardSceneView`：SpriteKit 地图。
- `HUDView`：回合、下一步、新游戏。
- `MapDisplayLayer` segmented picker：
  - `Hex`
  - `Province`
  - `Initial`
  - `Dynamic`
  - `Front`
  - `Deploy`
- `Observer` toggle。
- `[ INFO ]` 面板，内含：
  - Unit + Region + Command
  - Region
  - Log
  - AI
- `UnitTooltipView`。

v3.6 起步后，发布级拿战 UI 先从共享 token 和状态可读性切入：

- `PlatformStyles.swift` 中新增 `NapoleonicDesignTokens`，统一面板 padding、圆角、描边和拿战状态色。
- `HUDView`、`UnitInspectorView`、`UnitTooltipView` 和 `EconomyPanelView` 复用 token；morale / fatigue / ammunition / readiness 不只用颜色，还用 `Steady`、`Shaken`、`Broken`、`Fresh`、`Tired`、`Exhausted`、`Low`、`Empty` 等文字说明；拿战 HUD 空态显示 `No Formations`，结束按钮显示 `End Orders`，增援计数显示 `Reserve Arrivals`。
- `HUDView` 标题、`RootGameView` accessibility label 和 `BoardScene` empty board title 读取 `ScenarioCatalog.displayName(for: gameState.scenarioId)`，不再硬编码 `Ardennes V0`。
- `MapDisplayLayer.displayName(for:)` 保留 legacy Province / Initial / Dynamic / Front / Deploy，同时在拿战 faction 下把主界面图层 picker 显示为 Sector、Initial Wing、Active Wing、Contact、Corps。
- `RootGameView` compact info tabs 在拿战 faction 下显示 Formation / Sector / Dispatches / Logistics / Coalition / Staff；`EventLogView` 同步拿战日志标题、分类名、phase metadata 和 Standard / Concise 正文净化，避免 raw AI / MockAI / legacy pipeline / Germany / Allies 进入默认拿战日志；`AgentPanelView` 空状态和 Standard replay 不再使用 Guderian / MockAI / raw mock commander id 占位；`CommandResultSummary.commandDisplayName` 按执行 faction 生成，拿战 replay 中显示 Reserve Order / End Orders 等术语。
- `UnitInspectorView`、`RegionInspectorView`、`CommandPanelView`、`GeneralCommandPanelView` 和 `DiplomacyPanelView` 继续保留 legacy 阿登文案，但当 `activeFaction` 或选中 formation 使用拿战词汇时，玩家可见标签切到 Formation Details、Sector、Orders、Corps Command、Coalition、Active Wing、Corps Sector、Contact Line、Withdrawal Orders 等术语；部署角色值在拿战下显示 Contact Line / Reserve / Strongpoint，地图据点 marker 显示 `SP`，region inspector 把 fortress terrain 包装成 Strongpoint。Region inspector 和 unit strategic summary 的拿战空值文案仅是展示层映射：hex 无控制显示 Uncontrolled，无 settlement / city level 显示 Not present，无 active wing / corps sector 显示 No active wing assigned / No corps sector assigned，无目标/单位显示 No listed objectives / No formations / No visible enemy formations；不改变 RegionNode、HexTile.controller、目标、单位或规则层状态。
- `UnitInspectorView`、`UnitTooltipView`、`GeneralProfileView`、`GeneralCommandPanelView`、`RegionInspectorView` 和 `MapDisplayAdapter` 的拿战显示上下文会净化玩家可见 formation 名、allegiance 名、目标 controller status、component type code、contact line 与 composition 空态，避免主 UI 暴露 Germany / Allies / tank / motorized 等 legacy 文案；这是 display-only adapter 口径，不改变 `Division`、`Faction`、`ComponentType`、`GameState`、objective、region 或规则执行。
- `GeneralProfileView` 和 `AgentPanelView` 继续作为已有将军档案与 AI 复盘入口，但拿战 faction 下显示 Commander Profile、Service Record、Assigned Formations、Command Dispatch、Sovereign、Campaign Posture、Staff Summary、Corps Directives；Staff Summary 会只读聚合执行、拒绝、问题、focus sector / target 与最新 tactic，并把 raw front zone / region / theater id、record error 和 directive diagnostic 映射为 sector / wing / staff note 展示；`EventLogView` 的 front change 分类显示为 Contact。
- `AppContainer` 的 `interactionLog` 写入仍只记录展示消息，不直接改变规则状态；拿战 faction 下玩家命令、军团命令、选择反馈和 AI 回合摘要显示为 Order、Formation、Sector、Corps Order、Reserve Order、Command Dispatch、Simulated Staff 等术语，legacy faction 保留 Command / unit / region / General order / Production / AI / MockAI 显示。
- `RuleEngine`、`CommandExecutor` 和 `WarCommandExecutor` 的结果/事件消息也开始按 faction 切换展示：拿战 faction 下 `CommandResult.message` 显示 Order executed / Order rejected，校验错误显示 formation / sector / reserves 语义，HOLD / allow retreat / dynamic theater / front change 事件显示 Hold Line、Withdrawal、active wing 和 Contact sector；规则执行权威仍只在原命令管线内。
- `UnitTooltipView` 在拿战 faction 下把 Type / Strength / Supply / Retreat / Acted 显示为 Formation / Formation Strength / Logistics / Withdrawal / Orders，把 supply state 显示为 Ready / Short / Isolated，并把 tooltip type code 切到 LINE / LIGHT / CAV / ART / GUARD / ENG / SUP；VoiceOver 摘要使用 formation strength。
- `UnitNode` 保留 legacy NATO/二战符号路径，但拿战 faction 下改绘拿战 formation symbol：线列步兵双线、轻步兵散点、骑兵 V、炮兵轮炮、近卫星标、工兵桥线、补给车；棋子底部状态码把 retreatable 从 legacy `R` 切为拿战 `W`。
- `BoardScene` 从 `ReinforcementState.pending` 只读绘制增援入口 marker：非 observer 只显示当前 viewer faction 或友军 pending 增援入口，observer 显示全部非 neutral pending 入口；拿战 faction marker 显示 `RES` 和最早到达回合，不改变 `EconomyRules.resolveScheduledReinforcements` 的安全入口部署规则。
- `BoardScene` 从 `MapState.objectives` 只读绘制目标点 marker：按现有 `ObjectiveType.city / fortress / supply` 显示村庄、据点/农庄和道路/补给目标图标；marker 读取 visibility，frontLine 图层隐藏，不改变胜利、占领或补给规则。region objectives 供 region 层摘要、面板和后续 AI 排序使用，不直接改变 marker、胜负、占领或补给规则。
- `BoardScene` 从 `WarDirectiveRecord` 只读绘制 recent directive replay：跳过玩家计划线已有的 `issuerId == "player"` 记录，非 observer 只显示 viewer faction 或友军记录，observer 显示全部非 neutral 记录；攻击记录画轻量箭头，防御/无目标记录画圆环，`fireCoverage` / breakthrough / pincer / feint 等 tactic 在终点显示瞄准圈、楔形、钳形或扰动 marker，不改变 directive 生成或执行。
- `HexNode` 的供给源 label 按 faction 输出短码，legacy Germany / Allies 仍为 `SUP G` / `SUP A`，Waterloo 下 France / Anglo-Allied / Prussia 显示 `SUP F` / `SUP C` / `SUP P`，避免拿战地图把非 Allies 补给源误标成 German。
- v3.7 起 `RootGameView` 的 HUD 新局按钮打开 `NewGameSetupView` sheet，可选择默认 Waterloo 数据切片，并选择玩家控制的非 neutral power；v3.8 起阿登 legacy 仍留在 `ScenarioCatalog.all`，但默认隐藏在 `Archived Campaigns` 开关后，当前局面本身是 legacy 时会保留可见，sheet 不再显示 raw `migrationStage`。`Player Power` / `Power` / `Opening Turn` 是展示层文案，底层仍保持 `Faction` / `playerFaction`；Opening Turn toggle 可决定是否由玩家所选 power 先进入 orders phase。v3.8 起默认启动也走 Waterloo，默认玩家阵营为 France。新局成功后 `AppContainer` 清空本地选择、highlight、interaction replay 和 agent/directive replay，再按新 registry 刷新将领分配；新局读取场景或将领目录失败都会保留当前局面，sheet 保持打开并显示 `lastCommandMessage`。`HUDView` 接收 `playerFaction`、AI Control 和 observer 状态，phase 文案基于 active faction / 玩家阵营 / AI Control 显示 Your Orders、Staff Dispatch、Manual Dispatch 或 Manual Observation，拿战路径的 active faction 指标显示为 Active Power，不改变底层命令校验。
- `NewGameSetupView` 也暴露最小 Continue 区块：玩家可在 Slot 1 / Slot 2 / Slot 3 之间选择，并用 Slot Name / Rename Slot 写入独立 `UserDefaults` label；`Save Current` 会先持久化当前 label 草稿，再把 `GameSaveSnapshot` 写入对应 `UserDefaults` slot key，`Continue Saved` 会按 snapshot 恢复 scenario、玩家 faction、开局顺序和 `GameState`，再重载对应将领目录、刷新本地 UI 状态并调用既有 AI eligibility gate；若 snapshot 的 scenario 在当前 `ScenarioCatalog` 中不存在或对应将领目录无法加载，该 slot 会标为不可继续并显示 recovery message，但不会删除 snapshot；Slot 1 会兼容读取旧单槽 key `WWIIHexV0.savedGameSnapshot.v1`，坏快照或 schema 不兼容会显示对应 slot 的 recovery message，`Clear Saved` 会删除当前 slot 快照并刷新 summary / recovery message，用于坏快照或旧试玩快照恢复，但不会删除 slot label。`GameSaveSnapshot.Summary` 带有非持久化 `scenarioId`，拿战路径详情显示 Current / Your Power，legacy fallback 仍显示 Active / Player；`NewGameSetupView` 在 `Archived Campaigns` 关闭时会把 legacy summary 收起为中性占位，只保留展示归档入口和 `Clear Saved`，避免默认 Waterloo 入口直接显示 Germany / Allies forces 或继续按钮；打开归档开关后才显示详情并允许继续，`Show Archived` 会把 picker 的 scenario 和玩家 faction 同步到 snapshot。sheet 内 Status 区块会在 Start / Continue 成功后按原行为关闭 sheet，失败时显示提示；Save Current 成功/失败、Rename Slot 和 Clear Saved 结果会留在 sheet 内显示，状态只读 `AppContainer` 回调结果。
- `NewGameSetupView` 的 Settings 区块暴露 Observer Mode、Map Layer、Dispatch Detail、Staff Pace、Staff Control、Guide Notes、Reduce Motion 和 Text Size；底层仍由 `AICommandPace` / `PlaytestAIControlMode` 写入 `PlaytestSessionSettings`。坏设置会自动重置为标准设置并显示 `sessionSettingsRecoveryMessage`，Dispatch Detail 通过 `ReplayDetailLevel` 控制日志和 AI replay 密度，Concise 只保留 `AgentPanelView` 摘要、Recent Dispatch Timeline、问题反馈并隐藏逐条 command / directive 明细，Full 在拿战路径显示 Dispatch Audit、legacy 路径显示 raw JSON；Staff Control 默认 Staff，保持其它非 neutral faction 自动走 simulated staff / MockAI fallback，Manual 只停止自动 dispatch；非 observer Manual 下回合推进仍通过 End Orders / `Command.endTurn` 推进当前 active faction，observer + Manual 则保持 End Orders disabled 的只读状态；Text Size 通过 `PlaytestTextSize` 调整 `EventLogView` / `AgentPanelView` 的动态字体层级和行距；Staff Pace 只调整 simulated staff 行动前延迟，Reduce Motion 开启时跳过这段本地等待，Guide Notes 只控制非阻塞短提示是否写入 interaction log。
- `PlaytestGuideCue` 通过 interaction log 提供非阻塞短引导：首次选择 formation、炮兵/远程单位、骑兵和首次结束命令时写入 `Staff note`，不遮挡地图核心交互。
- `CommandPanelView` 会通过 `AppContainer.playerOrdersStatusMessage` 在未选中单位时显示本方剩余可行动 formation / unit 数量；Manual 非玩家 active faction 会提示用 End Orders 推进该 faction，observer + Staff 会提示用 End Orders 触发 staff dispatch，observer + Manual 会保持 orders disabled，macOS Orders 菜单也跟随 `canAdvanceOrders` 禁用；AI 回合若没有非 End Turn 的已执行战场命令，`AppContainer.aiNoActionFeedbackMessage` 会向 interaction log 追加 `Staff note` / `AI note`；record-level 错误、directive end-turn 失败和自动 dispatch guard 暂停会通过 `Staff dispatch issue` / `AI issue` 或诊断型 `WarDirectiveRecord` 进入事件日志 / Staff Summary；连续 AI faction 的 record-level 诊断正文会按实际 acting faction 做拿战 sanitizer。
- 当前未完成 `RootGameView` 发布级布局结构、SpriteKit 地图美术、asset catalog、发布级命名存档/多存档/迁移器/文件导出/云同步、完整设置治理、完整引导、完整动画回放或截图/模拟器视觉验收；Waterloo 已是默认入口但仍是小规模数据切片。Reduce Motion 目前只起步影响本地 AI pacing delay，尚未形成全 app 动画策略。

当前开局不会在 `RootGameView` 自动 `.task { runAIIfNeeded() }`。AI 行动由 `advanceOrRunAI()`、命令提交后或继续存档成功后的 `runAIIfNeeded()` 触发。

### 4.3 v1.1 主游戏 macOS target

源码：

- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`

v1.1 新增独立 macOS 主游戏 target：

```text
WWIIHexV0Mac
  -> WWIIHexV0MacApp
  -> AppContainer.bootstrap()
  -> RootGameView(container:)
  -> BoardSceneView
  -> BoardScene
```

这个 target 和既有 target 的边界：

- `WWIIHexV0`：iOS 主游戏 target。
- `WWIIHexV0Mac`：macOS 主游戏 target。
- `MapEditorMac`：macOS 地图编辑器 target，不是主游戏入口。

`WWIIHexV0Mac` 复用主游戏数据和规则，不新增一套 mac 专用规则。resource phase 包含：

```text
ardennes_v0_scenario.json
ardennes_v02_regions.json
general_agents.json
generals.json
terrain_rules.json
unit_templates.json
```

DEBUG 下 `DataLoader` 仍优先读源码目录 `WWIIHexV0/Data/*.json`；bundle resources 是 release / fallback 路径。

`BoardSceneView` 现在有平台分支：

```text
iOS:
  UIViewRepresentable
  -> SKView
  -> BoardScene touch input

macOS:
  NSViewRepresentable
  -> BoardEventSKView
  -> BoardScene mouse / scroll / magnify input
```

macOS 输入桥接逻辑：

```text
鼠标点击
  -> BoardScene.mouseDown / mouseUp
  -> layout.pixelToHex
  -> onHexTapped(coord)
  -> AppContainer.handleBoardTap

鼠标拖拽
  -> BoardScene.mouseDragged
  -> camera.position 更新
  -> clampCamera

滚轮 / 触控板缩放
  -> BoardEventSKView.scrollWheel / magnify
  -> scene.convertPoint(fromView:)
  -> BoardScene.handleScrollWheel / handleMagnify
  -> zoomCamera(anchor:)
  -> clampCamera
```

注意：macOS 点击仍只进入 `AppContainer.handleBoardTap`。移动、攻击、结束回合和 AI 行动仍由 `RuleEngine` / `WarCommandExecutor` 处理；v1.1 不允许通过 AppKit 或 SpriteKit 直接修改 `GameState`。

---

## 5. 命令执行流程

### 5.1 Command / RuleEngine

源码：`WWIIHexV0/Commands/Command.swift`、`WWIIHexV0/Rules/RuleEngine.swift`、`WWIIHexV0/Rules/CommandValidator.swift`、`WWIIHexV0/Rules/CommandExecutor.swift`

底层 `Command` 当前包括：

```text
move(divisionId, destination)
attack(attackerId, targetId)
hold(divisionId)
allowRetreat(divisionId)
resupply(divisionId)
queueProduction(kind)
endTurn
```

执行总入口：

```text
RuleEngine.execute(command, in: state)
  -> EconomyRules.bootstrapIfNeeded(state)
  -> CommandValidator.validate(command, in: preparedState)
  -> invalid: 返回 CommandResult，state 不变
  -> valid: CommandExecutor.execute(command, in: preparedState)
```

展示层注意：

- `Command.displayName(for:)` 和 `CommandValidationError.displayName(for:)` 只改变玩家可见文案，不改变 command case、validation case 或执行语义。
- 拿战 faction 下 `RuleEngine` 返回的 `CommandResult.message` 使用 `Order executed` / `Order rejected`，并把 hold、allowRetreat、resupply、queueProduction 显示为 Hold Line、Withdrawal、Rest & Supply、Reserve Order。
- `CommandExecutor` / `WarCommandExecutor` 的 event log 在拿战 faction 下把动态战区推进、前线变化和自动撤退显示为 active wing、Contact sector、automatic withdrawal；实际状态更新仍写入 `hexToTheater` / `hexToFrontZone`，不改 `regionToTheater`。

### 5.2 校验规则

`CommandValidator` 的关键校验：

移动：

```text
phaseAllowsCommands
division exists
division.faction == activeFaction
division 未行动、未撤退、canAct
destination 在地图内
destination passable
destination 没有其他单位
忽略 movement 的最短路径 cost <= division.movement
真实 shortestPath 存在
```

攻击：

```text
attacker 可行动
target exists
target.faction != attacker.faction
distance <= attacker.range
```

恢复/姿态：

```text
phase 合法
division exists
faction 匹配 activeFaction
未行动、未毁灭、未撤退
```

结束回合：

```text
phaseAllowsCommands
```

生产排队：

```text
phaseAllowsCommands
active faction economy ledger 有足够 manpower / industry / supplies
```

### 5.3 移动与占领

`CommandExecutor.executeMove` 真实链路：

```text
记录 origin
sourceZoneId = warDeploymentState.zoneId(for: origin)
更新 facing
division.coord = destination
division.hasActed = true

if OccupationRules.canOccupy(division, destination, state):
  tile.controller = division.faction
  map.setTile(tile)

  if destinationRegionId && sourceZoneId:
    applyStrategicAdvance(
      regionId: destinationRegionId,
      hex: destination,
      sourceZoneId: sourceZoneId,
      faction: division.faction
    )

  StrategicStateSynchronizer.synchronizeAfterOccupationChange(
    affectedRegionIds: [destinationRegionId]
  )

appendEvent("moved")
```

`OccupationRules.canOccupy` 很小，但非常关键：

```text
tile exists
tile.isCapturable
tile.controller != division.faction
destination 没有其他单位
```

注意：

- 只有移动会触发占领。
- 攻击造成伤害/撤退/消灭，不会自动把攻击者推进到目标 hex。
- 移动进敌控空 hex 时，先改 hex controller，再同步战略层。
- 移动进有敌单位的 hex 会在 validator 被 `destinationOccupied` 拒绝。

### 5.4 动态战区推进

`CommandExecutor.applyStrategicAdvance` 的语义：

```text
advancingTheaterId = TheaterId(sourceZoneId.rawValue)
如果 theater 不存在，return
如果 destination hex 已经属于 advancingTheater，return
如果 shouldAdvanceDynamicTheater == false，return

TheaterSystem.expandDynamicTheater(
  breakthroughHex: destination,
  advancingTheaterId,
  faction
)

oldZoneId = warDeploymentState.zoneId(for: destination)
如果 oldZoneId != sourceZoneId:
  WarDeploymentManager.advanceHex(destination, from: oldZoneId, to: sourceZoneId)

appendEvent("Hex q,r reassigned to dynamic theater ...")
```

`shouldAdvanceDynamicTheater` 当前判断：

- 如果目标 hex 当前 zone 属于其他 faction，则可以推进。
- 否则如果目标 hex controller 不是本方，也可以推进。
- 否则不推进。

这确保动态推进是 hex 级，不会把整个 region 拉走。

### 5.5 Region / Theater / Front / Deploy 同步

源码：`WWIIHexV0/Rules/StrategicStateSynchronizer.swift`

占领变化后：

```text
RegionOccupationRules.aggregateControl(in: &state)
  -> changedRegionIds

affected = affectedRegionIds + changedRegionIds

TheaterSystem.updateTheaters(force: true)

FrontLineManager.update(
  events:
    changed -> regionControllerChanged
    unchanged -> occupationChanged
)

WarDeploymentManager.update(
  events: affected.map(regionControllerChanged)
)

可选写 region owner change event
```

Region controller 聚合权重：

- 每个已控制 hex 基础权重 1。
- `representativeHex` 加 region city VP。
- city / fortress / city terrain / fortress terrain 再加权。
- 中立 hex 不计入。
- 并列第一时不改 region controller。

### 5.6 攻击、撤退、补给、结束回合

攻击流程：

```text
CommandValidator.validateAttack
  -> attacker morale 必须高于 broken threshold，否则 moraleBroken
WarCommandExecutor 的 staff offensive dispatch
  -> broken morale formation 先降级为 Command.hold 休整，不生成 attack / move
计算 attackDamage
  -> effectiveAttack 叠加 supply / morale / fatigue / ammunition 与轻量骑兵/炮兵地形修正
  -> effectiveDefense 叠加 terrain / river / infantry strongpoint / HOLD
attacker.hasActed = true
attacker.facing = 面向 defender
attacker 增加 fatigue；弹药敏感单位消耗 ammunition
对 defender 扣 strength
resolveCombatResult
  -> retreatable 且 lossRatio >= 0.35 时 shouldRetreat
  -> hold 模式追加损失
  -> encircled 且撤退触发追加损失
  -> destroyed 则 removeDivision + victory record
如果 defender 没撤退且可反击:
  defender counterattack
  defender 增加少量 fatigue；弹药敏感单位消耗 ammunition
  attacker 也可能撤退/毁灭
```

结束回合：

```text
SupplyRules.updateSupplyStates
EconomyRules.resolveFactionTurn(for: activeFaction)
  -> 收入入账
  -> 支付战略补给维护费
  -> supplies 短缺时 supplied 单位降为 lowSupply
  -> 安全后方自动补员
  -> 推进生产队列并部署完成单位
  -> 处理到期 delayed reinforcement，安全入口可用才加入单位
SupplyRules.advanceRetreats
SupplyRules.applyEncirclementAttrition
VictoryRules.updateVictoryState

turnOrderFactions:
  由 GameState.participatingFactions 推导，排除 neutral
  legacy Germany / Allies 仍按旧顺序轮转
  France / Anglo-Allied / Prussia 等新势力可进入多方轮转
  回到 turnOrder 第一个 faction 时 turn += 1

phase:
  GamePhase.commandPhase(for:)
  旧 Germany -> germanAI，旧 Allies -> alliedPlayer
  新拿战势力 -> aiCommand；玩家控制权由 AppContainer.playerFaction 决定
  AppContainer.normalizeCommandPhase 在试玩 runtime / save 边界将拿战玩家 active faction 归一为 playerCommand，非玩家拿战 active faction 归一为 aiCommand

resetActionsForActiveFaction
StrategicStateBootstrapper.refreshRuntimeState
appendEvent("Turn advanced ...")
```

`SupplyRules` 的补给路径穿越和敌方 ZOC 例外读取 `DiplomacyState.isHostile` / `isFriendly`：敌对 formation 阻断补给，co-belligerent / allied formation 不阻断补给，并且可作为敌方 ZOC 中的友军占位例外。

`VictoryRules` 当前按 scenario catalog / victory condition 分流：

- `ardennes_v0` 等 legacy 路径继续使用 Bastogne / St. Vith / unit elimination / German armor supply 条件。
- `ScenarioCatalog.napoleonicTarget.matches(state.scenarioId)` 或存在 Waterloo victory condition id 时，使用最小 Waterloo 节奏：
  - `GameState.victoryConditions` 中的 `french_break_center` 提供 objective id 和 winner faction；France 控制 `objective_mont_saint_jean` 时立即以 `waterlooFrenchBreakthrough` 获胜。
  - `coalition_hold_until_prussia` 提供 objective id 列表、target faction 和决定回合；到该回合时，如果 Hougoumont、Mont-Saint-Jean 和 Prussian Arrival Road 都未被 France 控制，则 Anglo-Allied 以 `waterlooCoalitionLineHeld` 获胜。Prussian Arrival Road 同时作为该 holdObjectives 成员和 `pr_bulow_iv_corps` 的 `triggerObjectiveId`，因此该 objective 的 id / coord / controller 口径必须与 scenario、tile 和 region 数据同步。
  - Plancenoit 当前是地图 objective / region objective / AI 目标排序数据，不属于这两个 runtime victory condition；Wavre Road 当前是 q5,r1 普军后方 road / supply / reinforcement entry hex，不新增 objective，也不属于 Waterloo runtime victory condition；q4,r0 `pr_blucher_approach_screen` 只是初始单位，不是 hold objective 成员。MockAI 读取这些 objective id 做 fallback sorting 不等于把它们接入 Waterloo runtime victory condition。后续若把它们接入胜负节奏，必须同步更新 `waterloo_1815_scenario.json` 的 `victoryConditions` 和本文档。
  - 旧存档或半迁移状态缺少 runtime condition 时，Waterloo 分支会补内置 fallback 条件；这只是兼容保护，不代表通用 victory condition DSL 已完成。
- 非 Waterloo 且非 `ScenarioCatalog.ardennesLegacy` 的 scenario 当前不会进入 Bastogne / St. Vith legacy 判定；若尚未接通 victory DSL，会保持 ongoing，避免后续拿战变体意外继承阿登胜负条件。

`RegionVictoryRules` 只保留给 `ScenarioCatalog.ardennesLegacy` / `mapeditor_scenario` 这类 legacy 阿登 region analysis 使用；非阿登 scenario 直接返回空评估，避免未来误把 `RegionRuleSystem.analyze` 接到 Waterloo UI 时泄漏 Bastogne / St. Vith 口径。当前默认回合胜负仍由 `VictoryRules` 负责。

---

## 6. AI / 战争指令流程

### 6.1 v0.5/v3.4 默认统治者-元帅决策链

源码：`WWIIHexV0/Turn/TurnManager.swift`、`WWIIHexV0/Agents/ZoneCommanderAgent.swift`、`WWIIHexV0/Commands/WarDirective.swift`、`WWIIHexV0/Commands/WarCommandExecutor.swift`

v3.4 当前默认路径：

```text
AppContainer.runAIIfNeeded
  -> runAISequence
  -> TurnManager.runAITurn(... pipelineMode: .marshalDirective)
  -> RulerAgent.resolvePosture
  -> StrategicPostureDecoder.parse
  -> diplomacyState.appendRulerRecord
  -> MarshalAgent.resolve
  -> MarshalBattlefieldSummarizer.summary
  -> SimulatedMarshalLLMClient.completeTheaterDirectiveJSON(... strategicPosture)
  -> TheaterDirectiveDecoder.parse
  -> TheaterDirectiveCompiler.compile
  -> DirectiveEnvelope / ZoneDirective
  -> WarCommandExecutor.execute(directive, in: state)
  -> RuleEngine.execute(Command)
  -> WarDirectiveRecord
  -> RuleEngine.execute(.endTurn)
```

`MarshalAgent` 是元帅层，不是单位，也不是新规则执行器。它只读取降维摘要并输出 `TheaterDirectiveEnvelope` JSON：

`MarshalBattlefieldSummarizer` 的 `MarshalBattlefieldSummary` 当前 schemaVersion 为 6；每个 `MarshalFrontSummary` 除兵力、压力、目标和 supply warning 外，还带 `fatigueWarningCount` 与 `ammunitionWarningCount`，供元帅层在选择攻守和防御优先级时看到战术消耗风险。

```text
TheaterDirectiveEnvelope
  schemaVersion = 5
  issuerId / turn / faction
  strategicIntent
  directives: [TheaterDirective]

TheaterDirective
  zoneId
  category offense/defense
  tactic
  priority
  targetTheaterId
  weightedRegions / focusRegionId / supportRegionIds
  reserveBias
  intensity / maxCommittedUnits / exploitDepth
  rationale
```

`TheaterDirectiveDecoder` 负责从模拟 LLM 文本中提取 fenced JSON，使用 `JSONDecoder` 解码，并校验 schemaVersion、issuerId、turn、faction、zone 存在性、zone 阵营、region id、target theater/front zone 与 tactic/category 一致性。解码或校验失败时，不执行半成品 JSON，`MarshalAgent` fallback 到 `TheaterCommanderPool`。

`TheaterDirectiveCompiler` 把元帅意图降级到现有 `ZoneDirective`：

- offense -> `ZoneDirective.attack`，保留 target theater、weighted/focus/support regions、intensity、maxCommittedUnits、exploitDepth。
- defense -> `ZoneDirective.defend`，把 reserveBias 转成 targetReserves，把 focus/weighted regions 转成 strongpointRegionIds，把 supportRegionIds 转成 fallbackRegionIds。
- 某个 zone 没有元帅 directive 或编译失败时，使用 `TheaterCommanderPool` 给该 zone 的旧 directive。

最终执行由 `TurnManager.executeDirectiveEnvelope` 统一完成。`.marshalDirective` 和显式 `.zoneDirective` 共享同一段 WarCommandExecutor 执行、WarDirectiveRecord 记录、endTurn 推进逻辑。

v3.4 起默认 `.marshalDirective` 主路径会先插入 `RulerAgent` 的 `StrategicPostureEnvelope`：姿态记录写入 `diplomacyState.rulerRecords`，并作为元帅模拟 JSON 的输入。它只影响元帅的战略意图、攻守阈值和 reserveBias，不直接触碰 `ZoneDirective` 执行后的战术状态。

Legacy Agent D 仍存在，但只在显式 `.legacyAgentOrder` 分支运行：

```text
AgentContextBuilder
  -> DecisionProvider
  -> AgentDecisionParser
  -> AgentCommandMapper
  -> RuleEngine
```

默认不得把 Legacy 管线接回战争 AI 主路径。

v0.37 直接将军池路径仍可显式使用：

```text
TurnManager.runAITurn(... pipelineMode: .zoneDirective)
  -> TheaterCommanderPool.envelope
  -> ZoneCommanderAgent.makeDirective
  -> DirectiveEnvelope
  -> WarCommandExecutor
```

### 6.2 AI 触发条件

`AppContainer.shouldRunAI`：

```text
phase.allowsCommands == true
activeFaction 不是 neutral
Staff Control == Staff
且满足：
  observerModeEnabled == true
  或 activeFaction != playerFaction
```

Staff Control == Manual 时不触发自动 dispatch；非 observer 下 `advanceOrRunAI()` 会落回 `endTurn()`，由 `Command.endTurn` 经 `RuleEngine` 推进当前 active faction。observer + Manual 保持只读，End Orders disabled，`submit(_:)` 直接命令也会被拒绝；observer + Staff 可以用 End Orders 触发 `runAIIfNeeded()`。`continueSavedGame(from:)` 恢复成功后也会调用同一个 `runAIIfNeeded()` gate，因此 Staff 模式（包括 observer + Staff）可在恢复到 AI-eligible active faction 时继续 dispatch，非 observer 下 Manual 需由人工 End Orders 推进，observer + Manual 保持只读。

`runAISequence`：

- `maxSteps` 使用当前 `turnOrderFactions.count` 作为有限上限，避免 AI 决策异常时无限循环。
- Staff + 非 observer：会连续处理符合 Staff Control 的非玩家 active faction，直到回到玩家所选 faction 或 AI 资格失效，因此 Waterloo 的 Anglo-Allied / Prussia 等连续非玩家 faction 不需要额外人工点击。
- Staff + observer mode：玩家所选 faction 也符合自动 AI 条件，一次推进最多跑过一轮当前 turn order；Manual 下不自动进入 `runAISequence`。
- `applySessionSettings` / `setObserverModeEnabled` / `setAIControlMode` 在 observer 或 Staff Control 改变后会重新调用 `runAIIfNeeded()`，用于 Manual 切回 Staff 或开启 observer 后恢复自动 dispatch。

### 6.3 ZoneCommanderAgent 如何做决策

`TheaterCommanderPool` 会对当前 faction 的每个有 `frontSegments` 的 `FrontZone` 生成 directive。

每个 zone：

```text
visibleEnemyStrengthByRegion
friendlyFrontStrength
mobileFriendlyStrength
artillerySupportStrength
friendlyDepthStrength
pressure / supplyWarningCount
hasContestedForwardPresence
hasRecentStaticDefense
  -> BinaryTacticClassifier.classify
```

`BinaryTacticClassifier`：

```text
ratio = friendlyStrength / visibleEnemyStrength
如果 visibleEnemyStrength == 0，则 ratio = friendlyStrength
styleBoost:
  aggressive +0.15
  balanced 0
  cautious -0.15

shouldAttack =
  adjustedRatio >= attackThreshold(默认 1.2)
  或 hasContestedForwardPresence
  或 hasStaticDefense
```

分类结果：

- offense：
  - `blitzkrieg`：机动兵力占比高且 adjustedRatio >= 1.65。
  - `spearhead`：机动兵力可用，adjustedRatio >= 1.35，且有可见敌 region；用于定点矛头。
  - `breakthrough`：adjustedRatio >= 1.35，向弱点突破。
  - `fireCoverage`：炮兵/远程支援可用但优势不足，先火力覆盖。
  - `feint`：优势不足但需要牵制时少量佯攻。
  - `guerrillaWarfare`：机动兵力可用、敌 region 多、优势有限时袭扰纵深。
  - `standardAttack`：普通进攻 fallback。
- defense：
  - `lastStand`：极端劣势、无纵深预备队且压力高时死守。
  - `defenseInDepth`：有纵深预备队且压力/劣势明显时纵深防御。
  - `elasticDefense`：压力、补给警告或劣势时弹性防御。
  - `holdPosition`：普通防御 fallback。

`TacticConditionChecker` 不再恒放行：闪电战/游击战要求机动单位，火力覆盖要求炮兵或远程单位，佯攻要求前线单位，纵深防御要求 depth 预备队；不满足条件会降级为 `holdPosition`。

进攻 directive：

```text
ZoneDirective(
  zoneId,
  attack: AttackParameters(
    targetTheaterId,
    weightedRegions,
    intensity,
    focusRegionId,
    supportRegionIds,
    convergenceRegionId,
    coordinatedZoneIds,
    maxCommittedUnits,
    exploitDepth
  ),
  category: .offense,
  tactic: blitzkrieg / spearhead / breakthrough / pincerMovement / fireCoverage / feint / guerrillaWarfare / standardAttack,
  commandTarget: .region(focusRegionId) 或 .theater(target)
)
```

定点突破目标选择：

```text
priorityRegions =
  focusRegionId
  + commandTarget.region
  + convergenceRegionId
  + weightedRegions
  + supportRegionIds

若 tactic weakPointFocus:
  对候选 region 评分：
    enemyStrength 越低越优先
    terrain.movementCost 越低越优先
    region 内有 road 越优先
    city victoryPoints + supplyValue + factories + infrastructure 越高越优先
  最优 region 放到候选首位
```

钳形攻势数据层：

```text
pincerMovement 使用 convergenceRegionId + coordinatedZoneIds
每个 zone 仍各自编译成一条 ZoneDirective
执行器只推进本 zone 成功移动的具体 hex
会师/包围效果仍交给补给、前线、动态战区同步派生
```

防御 directive：

```text
ZoneDirective(
  zoneId,
  defense: DefenseParameters(
    targetReserves,
    stance,
    fallbackRegionIds,
    counterattackRegionIds,
    strongpointRegionIds,
    maxFrontCommitment
  ),
  category: .defense,
  tactic: holdPosition / elasticDefense / defenseInDepth / lastStand,
  commandTarget: .theater(self)
)
```

`AttackIntensity` 仍是参数字段；v0.7/v1.0 的真实分流主要由 `tactic` 决定。v1.0 已把 `.infiltration` 解释为默认低投入上限，但执行器不绕过 `RuleEngine` 给强度加直接伤害。

### 6.4 WarCommandExecutor 如何翻译指令

入口：

```swift
func execute(_ directive: ZoneDirective, in state: GameState) -> WarCommandExecutionResult
```

它不需要 `ZoneCommanderAgent` 实例，不需要 issuer。手写合法 `ZoneDirective` 可以直接执行，这是 v0.4 玩家命令 UI / 聊天命令要复用的后端能力。

执行路由：

```text
如果 directive.tactic 存在:
  standardAttack / blitzkrieg / spearhead / breakthrough / pincerMovement / fireCoverage / feint / guerrillaWarfare
    -> executeAttack(tactic)
  holdPosition / elasticDefense / defenseInDepth / lastStand
    -> executeDefense(tactic)
否则按 parameters:
  attack -> executeAttack
  defend -> executeDefense
```

防御翻译：

```text
zone 必须存在且有 frontSegments
lastStand:
  不保留 depth，全力 holdLine
elasticDefense:
  stance 强制 flexible，前线单位优先 allowRetreat
defenseInDepth:
  前线单位 allowRetreat
  保留 targetReserves 个 depth 预备队
  其余 depth 机动单位优先反击可见敌军，否则向 fallback/strongpoint region 移动
普通防御:
  unitIds = unitsFront + 部分 unitsDepth（保留 targetReserves）
对每个可行动单位:
  找 lightestFrontRegion
  如果单位已在该 region:
    holdLine -> .hold
    flexible -> .allowRetreat
  否则如果能找到 tacticalDestination:
    .move
  否则:
    hold / allowRetreat
  run(command, fallback: hold)
```

进攻翻译：

```text
zone 必须存在
targetZoneId = AttackParameters.targetTheaterId.rawValue
segments = 指向 targetZone 的 frontSegments，若为空则用全部 frontSegments

按 tactic 得到 AttackTacticProfile:
  blitzkrieg / spearhead:
    includeDepthUnits = true
    mobileOnlyWhenAvailable = true
    weakPointFocus = true
    holdNonCommittedFront = true
  breakthrough:
    includeDepthUnits = true
    weakPointFocus = true
  pincerMovement:
    includeDepthUnits = true
    mobileOnlyWhenAvailable = true
    convergenceRegionId 可作为深目标
  fireCoverage:
    artilleryFirst = true
    attackOnly = true；没有射程目标则 hold，不主动推进
  feint:
    只投入 maxCommittedUnits 或默认约 1/3 前线单位
  guerrillaWarfare:
    mobileOnlyWhenAvailable = true
    allowDeepTarget = true
    默认只投入约半数前线+纵深单位

attackingUnitIds =
  unitsFront
  + profile.includeDepthUnits ? unitsDepth : unitsFront 为空时 fallback unitsDepth
  -> 过滤可行动单位
  -> 需要时优先机动单位
  -> 按 artillery / mobile / attack / movement / strength 排序
  -> 应用 maxCommittedUnits

对每个可行动单位:
  targetEnemyRegion =
    focus / commandTarget.region / convergence / weighted / support 中仍相邻或允许深目标的 region
    或 front segment 相邻敌 region
    weakPointFocus 时用敌军强度、地形、道路、战略价值重排
  如果射程内有 visible enemy division:
    .attack
  否则如果 fireCoverage:
    .hold
  否则如果能找到 tacticalDestination:
    .move
  否则:
    .hold
  run(command, fallback: hold)
```

`run` 包装层会：

- 先记录 acting division 的 logical source zone。
- 调 `RuleEngine.execute(command, in: state)`。
- 如果被拒绝，写日志；如果原命令非法但 fallback hold 合法，则执行 fallback。
- 成功后做防御性同步：
  - 计算 affected region。
  - 尝试 `applyDirectiveOccupation`（通常普通 `CommandExecutor` 已处理过）。
  - 尝试 `applyStrategicAdvance`（确保 directive move 也推进 dynamic theater）。
  - `StrategicStateSynchronizer.synchronizeAfterOccupationChange`。
  - 记录 region owner change / front change event。

TurnManager 外层会为每条 directive 生成 `WarDirectiveRecord`：

```text
issuerId
turn
faction
zoneId
directiveType
targetRegionIds
commandResults
diagnostics
category
tactic
commanderAgentId
commandTarget
```

`WarDirectiveRecord.commandResults` 与 `WarDirectiveRecord.diagnostics` 也是 `AgentPanelView` Issue Preview 和 Recent Dispatch Timeline 拒绝原因预览的数据源。直接调用 `WarCommandExecutor.execute` 不会自动写 `WarDirectiveRecord`；记录职责在 `TurnManager.runDirectiveTurn` 外层。

---

## 7. UI / 地图显示流程

### 7.1 BoardScene

源码：`WWIIHexV0/SpriteKit/BoardScene.swift`

绘制顺序：

```text
drawTiles
drawLayerOverlay
drawRegionOverlays（仅 hex layer）
drawRoads
drawRivers
drawUnits（frontLine layer 隐藏单位）
```

点击：

```text
touchesEnded
  -> layout.pixelToHex(point)
  -> state.map.contains(coord)
  -> onHexTapped(coord)
```

平移：

- 触摸移动 camera。
- `clampCamera` 限制在地图边界附近。

### 7.2 MapDisplayAdapter

源码：`WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`

职责：

- hex -> region 查询。
- 视野判断。
- 单位显示位置/堆叠。
- Region inspector state。
- Unit inspector strategic state。

Inspector 中关键字段：

```text
selectedHexController
selectedHexDynamicTheaterId
selectedHexFrontZoneId
theaterId = dominantDynamicTheaterId(region)
frontZoneId = dominantDynamicFrontZoneId(region)
frontPressure
friendlyDivisions
visibleEnemyDivisions
```

单位 strategic state：

```text
coord
regionId
dynamicTheaterId
frontLineIds
frontZoneId
deploymentRole
```

### 7.3 MapDisplayLayer

源码：`WWIIHexV0/Core/MapDisplayLayer.swift`、`WWIIHexV0/SpriteKit/MapLayerOverlayCalculator.swift`、`WWIIHexV0/SpriteKit/MapLayerOverlayNode.swift`

当前 layer：

```text
hex
province
initialTheater
dynamicTheater
frontLine
deployment
```

bucket 来源：

| Layer | 数据来源 |
|---|---|
| `hex` | 每个 hex 自己 |
| `province` | `map.region(for: hex)` |
| `initialTheater` | `theaterState.initialSnapshot?.regionToTheater[regionId]` |
| `dynamicTheater` | `theaterState.dynamicTheaterId(for: hex, map:)` |
| `frontLine` | `frontLineState.regionStates[regionId].frontLines` |
| `deployment` | 该 hex 上单位的 `WarDeploymentManager.deploymentRole` |

前线 overlay 的线段来源：

```text
frontLineSegments()
  -> 遍历 FrontLine.segments
  -> friendlyBoundaryHexes(
       friendlyRegionId: segment.regionA,
       enemyRegionId: segment.regionB,
       friendlyTheaterId: frontLine.theaterId
     )
  -> 只取 friendly region 内、且 dynamicTheaterId == friendly theater 的 hex
  -> 这些 hex 必须邻接 enemy region 中另一个 dynamic theater 的 hex
  -> 用这些 friendly hex center 画线
```

这意味着前线视觉画在我方动态战区侧，不画敌我中间共用边，也不画初始 theater 边界。

`frontLineChains()` 会把相邻 hex 点串成拓扑链。不同 segment 起点有分隔符，多敌 theater 接触会加 dashed overlay。

---

## 8. 关键链路示例

### 8.1 玩家移动占领一个敌控空 hex

```text
玩家点击己方单位
  -> AppContainer.selectDivision
  -> MovementRules 生成 movementHighlights

玩家点击敌控空 hex
  -> AppContainer.submit(.move)
  -> RuleEngine.validate(move)
  -> CommandExecutor.executeMove
     - division.coord = destination
     - tile.controller = division.faction
     - TheaterSystem.expandDynamicTheater 只推进 destination hex
     - WarDeploymentManager.advanceHex 只推进 destination hex 的 FrontZone
     - StrategicStateSynchronizer
       - RegionOccupationRules 聚合 region controller
       - TheaterSystem.updateTheaters
       - FrontLineManager.update dirty region
       - WarDeploymentManager.update dirty region
  -> AppContainer.bootstrapIfNeeded
  -> UI 刷新 dynamic theater / front / deployment overlay
  -> 如果现在轮到 AI，则 runAIIfNeeded
```

不得发生：

- 不得把 destination 所在整个 region 的 `regionToTheater` 改成进攻方。
- 不得绕过 `OccupationRules.canOccupy`。
- 不得只改 region controller 而不改 hex controller。

### 8.2 AI 进攻一个前线 zone

```text
用户点下一回合 / AI faction active
  -> AppContainer.runAIIfNeeded
  -> StrategicStateBootstrapper.refreshRuntimeState
  -> TurnManager.runAITurn(.zoneDirective)
  -> TheaterCommanderPool 选出该 faction 有 frontSegments 的 FrontZone
  -> ZoneCommanderAgent 计算兵力比/可见敌军/前沿存在
  -> 生成 standardAttack ZoneDirective
  -> WarCommandExecutor.execute
     - 找 zone.unitsFront
     - 选 targetEnemyRegion
     - 能打则 attack，不能打则 move，不能 move 则 hold
     - 每个 command 都走 RuleEngine
     - 同步占领/动态战区/前线/部署
  -> TurnManager 写 WarDirectiveRecord
  -> RuleEngine.execute(.endTurn)
  -> AppContainer 写 lastAgentDecisionRecord / lastWarDirectiveRecords
```

AI 看到的前线单位池来自 `WarDeploymentState`。如果某单位没有进入 `unitsFront` / `unitsDepth`，该 zone 的 AI 就不会调度它。

### 8.3 地图编辑器改默认地图后进入游戏

```text
MapEditorGameResourceBridge.loadLegacyArdennesDocument
  -> 读现有 scenario + region JSON
  -> 用户编辑 hex / region / theater / unit
  -> overwriteLegacyArdennesGameResources
     - MapEditorExporter.export
       - 校验所有 hex 有 region
       - 从 hex 邻接推导 region neighbors / edges
       - 写 scenario JSON
       - 写 region JSON
     - 覆盖 WWIIHexV0/Data legacy 阿登资源

重新运行游戏 app
  -> DataLoader DEBUG 优先读源码 JSON
  -> loadGameState
  -> map / regions / theater initialSnapshot / front / deploy 全部重建
```

注意：已经启动的旧 simulator app 不会自动重新加载默认 JSON。

---

## 9. 调试断点与排查顺序

遇到“AI 不动、前线不对、地图不一致、占领不同步、拒绝率异常”时，按这条链查，不要直接改大块逻辑：

```text
1. 数据加载
   - DataLoader 是否读的是源码 JSON 还是旧 bundle？
   - ScenarioDefinition tiles / initialUnits 是否正确？
   - RegionDataSet.hexToRegion / regions[].theaterId 是否正确？
   - map.validateRegionGraph() 是否为空？

2. Hex 层
   - Division.coord 是否真的变化？
   - HexTile.controller 是否真的变化？
   - 目标 hex 是否被其他单位占据？
   - OccupationRules.canOccupy 是否允许？

3. Region 层
   - state.map.region(for: hex) 是否正确？
   - RegionOccupationRules.aggregateControl 后 region.controller 是否改变？
   - 是否出现权重并列导致 controller 不变？

4. Theater 层
   - initialSnapshot.regionToTheater 是否保持不变？
   - regionToTheater 是否被错误当成动态推进层？
   - hexToTheater[destination] 是否只改了目标 hex？
   - dynamicTheaterId(for:) 是否 fallback 到 regionToTheater 造成误读？

5. Front 层
   - FrontLineManager 是否扫描到真实相邻 hex？
   - fixture 是否只写了 Region.neighbors 但没有真实 hex 邻接？
   - split region 是否需要允许 regionA == regionB？
   - frontLineState.diagnostics.updatedRegionIds 是否包含目标 region？

6. Deploy 层
   - hexToFrontZone[destination] 是否更新？
   - regionToFrontZone 是否只是 dominant/fallback？
   - 单位为什么是 front/depth/garrison？
   - zone.unitsFront 是否包含应该行动的单位？

7. Directive 层
   - TheaterCommanderPool 是否为该 faction 生成 directive？
   - ZoneCommanderAgent 是否因为 zone.frontSegments 为空而返回 nil？
   - visibleEnemyStrength / friendlyFrontStrength 是否合理？
   - tactic/category 是否被记录？

8. Executor / RuleEngine 层
   - WarCommandExecutor.generatedCommands 是否为空？
   - CommandValidator 拒绝原因是什么？
   - fallback hold 是否执行？
   - WarDirectiveRecord.diagnostics 是否记录了拒绝？

9. UI 层
   - 当前 MapDisplayLayer 读的是 initial 还是 dynamic？
   - frontLine overlay 是否画在 friendlyBoundaryHexes？
   - observerMode 是否导致玩家不能选中行动单位？
```

---

## 10. 当前已知边界

- 真 LLM 尚未接入；当前只用 `SimulatedMarshalLLMClient` 模拟 fenced JSON 输出和解码流程。
- 默认 AI 上游已是 `RulerAgent -> StrategicPostureEnvelope -> StrategicPostureDecoder -> MarshalAgent -> TheaterDirectiveEnvelope -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler`，下游执行必须是 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- 元帅层不能直接输出底层 `Command`，不能直接修改地图、单位、hex controller 或动态战区权威。
- 统治者层当前只输出战略姿态和审计记录，不能直接输出底层 `Command`，不能直接修改地图、单位、hex controller 或动态战区权威。
- 当前工作树存在外交/经济/UI 等非 v0.5 方向残留，合并前需要单独审查文件归属和 public API 冲突。
- `AttackIntensity.infiltration` 已在 `WarCommandExecutor` 中解释为默认低投入上限；`.limitedCounter` 和 `.allOut` 仍主要依赖 tactic profile 与显式 `maxCommittedUnits`。
- `TacticConditionChecker` 当前总是允许现有战术。
- 战区互助接口 `requestSupport` / `getAvailableForces` / `notifyThreat` 有模型但没有主流程调用方。
- 攻击不会自动占领目标 hex，只有移动会占领。
- Legacy Agent D 管线仍保留，不应删除，也不应默认接回主战争 AI。
- `RegionCommand` / AgentOrder v2 仍可桥接到 hex command，但当前默认战争 AI 是 ZoneDirective。
- 地图编辑器的 theater assignment 是初始战区划分，不是运行时动态战区脚本。
- 历史回退的 Cabinet/Minister/StrategicDirective 管线仍不得恢复；v0.5 当前实现没有把内阁或部长塞进 `GameState`。

---

## 11. 轻量检查入口与历史回归参考

检查规范以 `md/test/test.md` 为准。当前默认不跑 Xcode / XCTest / 模拟器 / 性能类验证，只做轻量语法、格式和配置检查。

历史上这些回归曾用于守住核心语义，但现在只作只读参考，不作为每轮默认执行项：

- Probe：`WWIIHexV0Probes`
  - 数据启动、region graph、theater、frontline、deployment。
  - v0.358 动态 hex 战区推进。
  - v0.36 tactic/directive。
  - v0.37 手写 directive issuer-agnostic 执行。
- Dynamic Theater Regression：`WWIIHexV0Tests/Stage0355DynamicTheaterTests`
  - 守住 `regionToTheater` 不动态推进、`hexToTheater` 单 hex 推进、split region front、deployment split。
- MapEditor：`WWIIHexV0Tests/MapEditorOutputTests`
  - 守住编辑器输出与游戏加载一致、默认资源一致、视角一致、开局不自动 AI。
- Stage Regression：
  - Theater / FrontLine / WarDeployment / CommandSystem / Agent / Observer / LayeredMap。

默认允许的检查方向：

- 文档改动：尾随空白、旧测试口径残留、人工阅读一致性。
- JSON 改动：对改动文件运行 `jq empty`。
- Xcode project / scheme 改动：运行 `plutil -lint` 或 `xmllint --noout`。
- 少量 Swift 改动：仅在不会触发全项目构建时，对直接改动文件做单文件语法检查。

多分支或多子 Agent 并发后，即使不跑测试，也必须检查文件重叠、public API 分叉、数据 schema 分叉、Xcode project 冲突和文档口径冲突。未完成冲突检查前，不得声称候选分支可合并。

---

## 12. v1.0 UI / AI / Playtest 分支收口

v1.0 分支名：`v1.0-ui-ai-playtest`。

该分支不改变战术权威和命令权威，只让当前主游戏更适合人工初版试玩和后续调参：

```text
GameState / WarDirectiveRecord / EventLog
  -> RootGameView
  -> HUD + Info tabs
  -> AgentPanelView 展示 raw JSON / command results / zone directives
  -> EventLogView 展示最近 60 条分类日志

BoardScene
  -> 缓存 unit display hex
  -> 排序绘制单位
  -> deployment 图层复用 WarDeploymentManager 计算 role

Marshal / ZoneDirective
  -> AttackParameters.intensity
  -> WarCommandExecutor.attackTacticProfile
  -> infiltration 低投入上限
  -> RuleEngine 仍是唯一执行权威
```

算法变化：

- AI 面板从只展示 `AgentDecisionRecord` 扩展为同时展示 `WarDirectiveRecord`，每条 directive 可看到 zone、attack/defend、tactic、命令成功/拒绝数量和目标 region。
- 日志面板用 `LogDisplayEntry` 保存 entry + category，避免 body 内对同一条日志重复分类。
- 单位绘制先缓存 `unitDisplayHex` 再排序，避免 comparator 重复计算。
- `AttackIntensity.infiltration` 在无显式 `maxCommittedUnits` 时默认只投入约半数前线/纵深候选单位，避免渗透/袭扰全线压上。

试玩观察重点：

- UI：HUD、Info tabs、Economy、Diplomacy、AI panel 是否可读。
- 地图：hex/province/initial/dynamic/front/deploy 图层是否清晰。
- AI：raw JSON、zone directive、diagnostics 是否能解释 AI 回合。
- 规则：玩家和 AI 行动是否仍能追溯到 `CommandResultSummary` / `WarDirectiveRecord`。
- 性能体感：地图拖动、图层切换、日志面板滚动是否有明显卡顿。

当前限制：

- 未跑 Xcode / XCTest / 模拟器 / 性能测试。
- 当前工作树含多版本未提交改动，v1.0 合并前必须重新审查 `project.pbxproj`、Swift 新文件引用、AI schema 和文档版本口径。

---

## 13. v0.4 将军养成、将军 UI 与玩家双轨命令

v0.4 分支名：`v0.4-generals-command-ui-final`。

该分支把 0.41-0.48 的将军与玩家命令链路收口到当前代码，仍保持命令权威不变：

```text
Data/generals.json
  -> DataLoader.loadGeneralRegistry
  -> GeneralRegistry / GeneralDispatcher
  -> FrontZone.generalAssignment
  -> AppContainer.selectedGeneral*
  -> GeneralCommandPanelView / GeneralProfileView

玩家微操单位
  -> AppContainer.submit(Command)
  -> RuleEngine
  -> PlayerCommandState.micromanagedDivisionIds
  -> WarCommandExecutor.execute(... excluding: lockedIds)

玩家宏观将军命令
  -> GeneralCommandPanelView 按钮
  -> AppContainer 组装 ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> WarDirectiveRecord + PlayerPlannedOperation
  -> BoardScene 计划线 / 金色微操单位圈
```

核心算法：

- 将军数据：`GeneralData` 从 `generals.json` 读取，包含阵营、军衔、倾向、技能、头像占位、履历、偏好 theater/region、忠诚和满意度基线。
- 初始分配：`RegionNodeDefinition.assignedGeneralId` 可由地图 JSON / MapEditor 写入。`DataLoader` 在生成 `WarDeploymentState` 后收集 region 种子，调用 `GeneralDispatcher.assignGenerals`。
- 指派规则：
  1. 如果 FrontZone 已有合法同阵营 `generalAssignment`，保留该将军，只刷新 `assignedDivisionIds`。
  2. 否则优先使用该 zone 下 region 的 `assignedGeneralId`。
  3. 再按将军 `preferredTheaterIds` / `preferredRegionIds` 匹配。
  4. 最后从同阵营未占用将军池取第一名；没有可用将军时安全空岗。
- HQ 逻辑：不生成占格子的 HQ 单位。`GeneralAssignment.hqRegionId` 指向战区内友方城市或最大 region，`GeneralDispatcher.isHQUnderAttack` 通过 region controller 判断 HQ 是否被夺。
- 将军养成初步：`GeneralAssignment` 保存 `loyalty`、`satisfaction`、`interventionCount`。玩家直接微操某个将军辖下单位时，记录干预次数并轻微降低满意度。
- 微操锁：玩家在己方 phase 对具体师执行 move/attack/hold/resupply/allowRetreat 后，该师 id 写入 `PlayerCommandState.micromanagedDivisionIds`。本回合玩家再下达战区宏观命令时，`WarCommandExecutor.execute(... excluding:)` 会跳过这些师，避免同一回合被将军指令覆盖。`endTurn` 或 active faction / turn 改变时清空锁。
- 半自动指令：`GeneralCommandPanelView` 的 `Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，直接复用 `WarCommandExecutor -> RuleEngine`，不通过 `TurnManager.runDirectiveTurn`，因此不会自动结束玩家回合。
- 记录与反馈：玩家宏观命令写入 `WarDirectiveRecord` 和 `PlayerPlannedOperation`。`BoardScene` 只读 `PlayerCommandState.plannedOperations`，画源 region 到目标 region 的箭头；防御命令画源点圆环。v3.6 起 `BoardScene` 还只读最近的非玩家 `WarDirectiveRecord`，用轻量 replay 线显示 AI/将领 directive。玩家微操锁定单位在 `UnitNode` 上显示金色底圈。
- UI：`RootGameView` 新增 `General` tab，Unit tab 也嵌入 `GeneralCommandPanelView`。`GeneralProfileView` 用 sheet 展示将军身份、履历、技能、忠诚/满意度、干预次数、HQ 状态和辖下部队。

边界：

- v0.4 不让将军或 UI 直接修改 `GameState` 战术权威；所有行动仍要走 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- v0.4 没有实现真正抗命、政变、完整 RPG 成长树或真实 LLM 聊天解析；当前是忠诚/满意度和干预次数的可视化与数据底座。
- v0.4 没有做自由手绘前线。采用 region 锚点法：选择战区/目标 region 后自动画箭头，符合 0.44 文档中的移动端妥协方案。
- 当前工作树混有 v0.5、v0.7、v0.9、v1.x 外部改动；合并前必须重新做文件/API/schema/project 冲突审查。
