# WWIIHexV0 — iOS / macOS AI 战略战棋工程（拿战迁移中）

> **当前状态：`main` 云端化快照。默认战争 AI 已加入“统治者战略姿态 -> 元帅模拟 LLM JSON -> decoder -> compiler -> ZoneDirective”决策链；下游仍收口到 `WarCommandExecutor -> RuleEngine`。v3.4 起 `RulerAgent` 只输出 `StrategicPostureEnvelope` 和审计记录，不能直接改状态，也不恢复 Cabinet / Minister。历史测试基线曾达到 v0.37 Probe 18/0、Stage Regression 69/0、Full 226/0；当前工作流默认本机只跑 `md/test/test.md` 允许的轻量检查，重验证交给 GitHub Actions。**

---

## 拿战迁移状态

项目已启动 v3.0-v3.8 拿破仑战争迁移规划；当前默认启动已从阿登 legacy 切到 `ScenarioCatalog.defaultPlayable = waterloo_1815`，默认玩家阵营为 France，并读取 Waterloo 专用将领目录。阿登仍保留为 `ScenarioCatalog.all` 中的 legacy scenario，但 HUD 的 `New Campaign` sheet 默认只展示 Waterloo，需打开 `Archived Campaigns` 后才展示 legacy 新局和旧 legacy 存档详情。v3.0 已完成迁移审计、兼容合同和风险拆分；v3.1 已开始落地多势力/联军基础，包括 France、Anglo-Allied、Prussia、Austria、Russia、Spain、Neutral 兼容 case、`DiplomacyState` 敌我 helper、通用 command phase helper、neutral region fallback，以及补给、前线、部署和战区压力的多势力敌我查询。不声称已经完成完整拿战规则。

v3.2 已起步建立 `ScenarioCatalog` 场景目录：`defaultPlayable` 和 `napoleonicTarget` 当前都指向 `waterloo_1815_scenario` / `waterloo_1815_regions` / `napoleonic_terrain_rules` / `napoleonic_unit_templates` / `napoleonic_generals`，`ardennesLegacy` 只作为兼容剧本保留。当前仓库已有最小 Waterloo 数据骨架、Napoleon / Wellington / Blucher 的专用拿战将领目录、Waterloo terrain rules 数据入口，以及 line infantry / grand battery / strongpoint guard / Prussian vanguard 等拿战单位模板；v3.7 已把这些拿战 JSON 加入 iOS 和 macOS target 的 bundle resource，供默认启动和新局选择路径加载。v3.3 已新增 lineInfantry / lightInfantry / cavalry / guardInfantry（raw value 为 `guard`）/ engineer / supplyTrain 等 `ComponentType` case，拿战模板已使用对应 raw value；`napoleonic_terrain_rules.json` 已通过 `DataLoader` 映射为运行时 `TerrainRuleSet` / `GameState.terrainRules`，Waterloo 主路径移动/战斗读取场景地形规则，`BaseTerrain` 仍作为 legacy fallback 和未数据化特化规则来源。当前 `CombatRules` 已有最小骑兵/炮兵地形修正，`Division` 也已有最小 morale 字段和战斗/休整损益规则，但 Waterloo 仍只是小规模 schema slice，完整队形、显式骑兵冲锋和炮兵准备规则尚未完成。

v3.4 已起步接入拿战 AI Agent 分层的数据合同：AI 回合先由 `RulerAgent` 生成 Codable `StrategicPostureEnvelope`（offensive / defensive / coalitionMaintenance / stabilizeFront），经 `StrategicPostureDecoder` 校验后写入 `RulerDecisionRecord`，再把姿态传给 `MarshalAgent` 生成 `TheaterDirectiveEnvelope`。元帅输出仍经 decoder / compiler 降级为 `ZoneDirective`，最终只由 `WarCommandExecutor -> RuleEngine` 执行；当前还没有完整 ChiefOfStaff / CorpsCommander / Diplomat 独立 Agent，也未接真实 LLM。

v3.5 已起步处理拿战后勤、预备队、增援、战术疲劳/弹药、士气和胜负节奏：现有 `EconomyResources.manpower / industry / supplies` 和 `ProductionKind` raw case 保持兼容，但 France / Anglo-Allied / Prussia 等拿战势力的经济 UI 与规则日志会显示 `Recruits`、`Ammunition/Horses`、`Reserves`、`Line Infantry Reserve`、`Guard Detachment`、`Cavalry Reserve`、`Artillery Battery` 和 `Supply Wagon`；完成排产时会生成拿战 component 组合，而不是 legacy 装甲/摩托化组件。Waterloo 数据切片已有 French Imperial Guard、French Cavalry Reserve 与 Prussian IV Corps 的 delayed reinforcement schedule，回合结算会通过安全己控入口 hex 部署，找不到安全入口则保留 pending 并记录日志。`Division` 已有最小 `morale` / `fatigue` / `ammunition` 字段，移动、攻击、反击、HOLD 和 resupply/rest 会产生或恢复战术消耗，低士气会降低攻防并可触发撤退，broken morale 会让 move / attack 在 `CommandValidator` 被拒绝，低弹药会降低弹药敏感单位火力，HUD、单位详情、tooltip、Agent 摘要与 Marshal 前线摘要会显示士气/疲劳/弹药警告。`DataLoader` 现在会把 scenario JSON 的 `victoryConditions` 映射进 `GameState.victoryConditions`，`VictoryRules` 的 Waterloo 分支按这些运行时条件读取目标 id、目标 faction 和决定回合；法军夺取 Mont-Saint-Jean 胜，到指定回合仍阻止 France 控制 Hougoumont、Mont-Saint-Jean 与 Prussian Arrival Road 则联军胜。完整 ammunition / horses 经济账本、高级命令摩擦、高级队形、通用 victory condition DSL 和完整滑铁卢规模仍未完成。

v3.6 已起步处理发布级拿战 UI：`NapoleonicDesignTokens` 集中保存拿战面板、描边和状态色；`HUDView`、`UnitInspectorView`、`UnitTooltipView` 和 `EconomyPanelView` 已开始用 `Steady/Shaken/Broken`、`Fresh/Tired/Exhausted`、`Ready/Strained`、`Low/Empty` 等文字加颜色表达士气、疲劳、弹药和预备队状态。HUD 标题、RootGameView accessibility label 和 SpriteKit empty board title 已改读 `ScenarioCatalog.displayName(for:)`，不再硬编码 `Ardennes V0`；拿战 faction 下 map layer picker、compact tabs、日志分类、interaction log、`CommandResult.message`、规则事件日志、tooltip/VoiceOver、SpriteKit 单位棋子、增援入口、目标点 marker、`WarDirectiveRecord` recent replay 线和 tactic marker、单位/地域/命令/将军/指挥官档案/外交/AI 复盘面板会显示 Sector / Active Wing / Contact / Corps、Formation / Orders / Corps Order / Order executed/rejected / Hold Line / Withdrawal / Commander Profile / Coalition / Staff / Command Dispatch 等术语，AI 面板空状态和拿战 provider 显示也不再暴露 Guderian / MockAI 占位。当前仍未完成完整地图美术、完整炮击/冲锋路径、指挥官头像、完整战报回放面板或截图验收。

v3.7 已起步处理试玩闭环的新局、最小保存/继续、基础设置、短引导和 AI 回放摘要：`AppContainer` 现在维护 `currentScenario`、可切换 `playerFaction`、对应 `GeneralRegistry` 和开局顺序配置；`NewGameSetupView` 从 HUD 打开，默认列出非 legacy scenario，打开 `Archived Campaigns` 后才显示 `ScenarioCatalog.all` 中的 legacy entry，按所选 scenario JSON 派生可选非中立阵营，并通过 `AppContainer.startNewGame(scenario:playerFaction:startsAtPlayerFaction:)` 重新加载数据、清空选择/回放状态、刷新将领分配。新局 sheet 的 `Opening Turn` 可以选择是否让玩家所选 faction 先行动，并暴露 Observer Mode、Map Layer、Dispatch Detail、Staff Pace、Staff Control、Guide Notes、Reduce Motion 和 Text Size；底层仍由 `AICommandPace` / `PlaytestAIControlMode` 持久化。`PlaytestSessionSettings` 会把这些试玩偏好保存到 `UserDefaults` key `WWIIHexV0.playtestSessionSettings.v1`，下次启动继续使用，若偏好数据无法解码则重置为标准设置并给出提示。`ReplayDetailLevel` 控制事件日志条数、AI directive 条数、context summary、AI 回放摘要密度和 raw JSON 显示；`PlaytestAIControlMode` 默认 Staff 保持现有 simulated staff / MockAI fallback 自动处理其它非 neutral faction，`runAISequence` 会以当前 turn order faction 数量为上限连续处理非玩家 AI faction，Manual 只关闭自动 dispatch；非 observer Manual 下人工仍通过 End Orders / `Command.endTurn` 推进当前 active faction，包括非玩家 faction，observer + Manual 保持只读，`AppContainer.submit(_:)` 会拒绝 observer 直接命令，不改变 AI 输出、命令校验或规则执行；`AICommandPace` 控制 simulated staff 行动前的短延迟，开启 Reduce Motion 时跳过这段本地等待；`PlaytestTextSize` 提供 Compact / Standard / Large 三档，使用 Dynamic Type 字体样式调整 `EventLogView` 与 `AgentPanelView` 的标题、metadata、正文、raw JSON 和行距。`AgentPanelView` 会从 `AgentDecisionRecord` 与最近 `WarDirectiveRecord` 只读聚合执行、拒绝、问题、重点目标和最新 tactic，并新增 Recent Dispatch Timeline，把最近 directive 按 turn、scope、target、tactic、执行/拒绝/问题数摘要成可读时间线；Concise 下仍隐藏逐条命令/directive 明细。`runAISequence` 现在会聚合连续 AI faction 的 record-level 错误并写入可见的 `Command dispatch issue` / `AI issue` interaction log；如果有限步数 guard 结束后 active faction 仍符合 AI 自动触发条件，也会追加 dispatch paused 诊断，避免静默卡住。默认 directive 管线的 AI end-turn 失败也会同步进诊断型 `WarDirectiveRecord`，供 Recent Dispatch Timeline / Staff Summary 看到。`PlaytestGuideCue` 会在首次选择 formation、炮兵/远程单位、骑兵和首次结束命令时写入非阻塞 `Staff note`，并受 Guide Notes 本地设置控制；命令面板也会显示本方还有多少 formation / unit 可行动，Manual 非玩家 active faction 会提示用 End Orders 手动推进，observer + Staff 会提示用 End Orders 触发 staff dispatch，observer + Manual 保持 orders disabled，macOS Orders 菜单也跟随 `canAdvanceOrders` 禁用，AI 回合若没有非 End Turn 的有效战场命令，会在 interaction log 追加 Staff note / AI note。HUD phase 也会基于 active faction、玩家阵营、Staff Control 和 observer 状态显示 `Your Orders` / `Staff Dispatch` / `Manual Dispatch` / `Manual Observation`，避免拿战玩家回合继续显示 `AI Command` 或手动阶段被误读成自动 staff。`GameSaveSnapshot` 以 schemaVersion 1 保存到 `GameSaveSlot` 的 Slot 1 / Slot 2 / Slot 3 本地试玩槽，Slot 1 兼容读取旧 `UserDefaults` key `WWIIHexV0.savedGameSnapshot.v1`；`GameSaveSlot` 另用独立 `UserDefaults` key 保存最小 slot label，`NewGameSetupView` 的 Slot Name / Rename Slot 可自定义 32 字以内槽名，保存、继续、清理消息会优先显示该 label，但 label 不写入 snapshot、不升级 schemaVersion。继续成功时会重载对应将领目录、重新 bootstrap / assign generals，并调用现有 `runAIIfNeeded()` eligibility gate；Staff 模式（包括 observer + Staff）若恢复到 AI-eligible active faction，会继续 simulated staff，非 observer Manual 需由人工 End Orders 推进，observer + Manual 保持只读。坏快照、schema 不兼容或引用当前构建不存在 scenario 的快照会在 Continue 区块按 slot 显示不可用原因，并提供 `Clear Saved` 清理入口；legacy snapshot 默认只显示中性占位和 `Clear Saved`，打开 `Archived Campaigns` 后才显示 forces 详情和继续入口。`NewGameSetupView` 现在也会在 sheet 内显示最近一次 Start / Save Current / Continue Saved / Clear Saved / Rename Slot 的状态消息；开始或继续失败时 sheet 保持打开并展示 `AppContainer.lastCommandMessage`，保存、重命名或清理成功也会在本地 Status 区块确认。所有玩家、AI 或手动推进的行动仍收口到 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine`。当前仅有最小 slot label，仍未完成发布级命名存档、完整迁移器、文件导出、云同步、完整教学流程、完整动画回放和完整运行时错误恢复。

v3.8 已起步发布候选收口：默认 playable 场景切到 Waterloo 1815，`ScenarioCatalogEntry` 记录 `defaultPlayerFaction`，`AppContainer.bootstrap()` 会按默认场景读取玩家阵营和专用将领目录，默认加载失败时不再自动打开阿登 legacy，而是保留 Waterloo 元数据、构造 1x1 inert 恢复地图并提示打开 `New Campaign` 切换到可用 scenario；阿登只作为 legacy 兼容剧本保留，并默认隐藏在 `Archived Campaigns` 之后，旧 legacy 存档摘要默认也不展示 Germany / Allies forces 详情。将领目录加载失败不再在新局/继续路径静默变成空 registry：新局或继续会保留当前状态并显示失败原因，启动时若默认场景已成功加载但二次读取将领目录失败，也会切到同一 1x1 inert 恢复态；`DataLoader.loadGameState` 也会复用已加载并校验过的 `GeneralRegistry` 做部署层将领分配，不再二次 `try?` 读取。`ScenarioCatalog.entry(for:)` 会把阿登 catalog id `ardennes_v0` 与 MapEditor legacy JSON runtime id `mapeditor_scenario` 解析到同一 legacy 场景，`loadGameState(ScenarioCatalogEntry)`、保存和继续会把 `GameState.scenarioId` 归一到 catalog id，避免旧存档摘要、标题和继续路径错配；`DataLoader.loadGameState` 现在会在构造状态前做通用资源校验，拦截未知/未声明 faction、坏 supply source、坏 riverEdges、raw hexToRegion key / tile region 反向映射错误、初始单位重叠、缺失 tile/objective/template/general、将领目录重复 id / 越界 loyalty、preferred region/theater、keyLocations、template maxHP/components/weight、unit/reinforcement hp/facing/supply/retreat mode、terrain rule、victory target faction 引用和 region/scenario 不匹配，并把 JSON victory conditions 与 terrain rules 注入运行时 `GameState`；Waterloo 主路径移动、战斗防御、AI breakthrough / defensive sorting 已读取 `GameState.terrainRules`；`RegionVictoryRules` 和 `VictoryRules` 的 Bastogne / St. Vith legacy 判定都只在 legacy 阿登 / MapEditor legacy runtime id 下评估；`DataLoader.loadInitialGameState()` 仍保留为 legacy / probe fallback，不作为主 app 默认启动入口；新局 faction 列表读取 scenario JSON 失败时只有阿登 legacy 会回退 Germany / Allies，非 legacy scenario 只回到 catalog 默认玩家阵营；MapEditor legacy 资源桥仍写阿登文件，但导出的 `factions/initialPhase/playerFaction/aiFaction` 和新单位 id 前缀会按实际 faction 派生，不再把所有非 Germany 导出为 Allies 语义，读取 legacy 资源时也不再用 nil / `.west` / `.retreatable` / `.supplied` 覆盖坏枚举或坏 region key；拿战 faction 下 AI 复盘会把 raw mock commander / MockAI / MockAI+MarshalDirective、部署角色、front zone / region / theater raw id、diagnostic 和普通 directive tactic 展示包装为 Command Staff / Simulated Staff、Contact Line / Reserve / Strongpoint、sector / wing、staff note 和可读命令名，Standard context summary 用 staff display name 而不是 raw mock commander id，EventLog phase metadata 也会显示 Orders / Staff Dispatch 而不是 Player Command / AI Command；`NapoleonicMessageSanitizer` 统一供 EventLog、AgentPanel、CommandPanel 和 AppContainer interaction log 净化 raw AI、MockAI、legacy pipeline、Germany / Allies 与 validation rawValue，`TurnManager` 和 `WarCommandExecutor` 的默认诊断/规则拒绝事件也会优先写 Staff / Corps / End Orders 与 `CommandValidationError.displayName(for:)` 文案，Full raw JSON 仍保留 schema 审计信息；供给源 marker 会按 France / Coalition / Prussia 显示短码，app 显示名已切到 Waterloo Command。此状态仍不是发布已验证：Waterloo 仍是小规模数据切片，运行时视觉/交互、Xcode build、模拟器/真机启动和长回合观察者模式都未获授权执行。

当前拿战迁移入口文档：

- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`
- `md/prompt/v3.0-拿战迁移/v3.0_audit_and_contract.md`
- `md/prompt/v3.0-拿战迁移/v3.1_powers_coalitions_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.2_waterloo_data_entry.md`
- `md/prompt/v3.0-拿战迁移/v3.3_component_types_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.4_agent_hierarchy_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.5_logistics_reinforcement_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.6_napoleonic_ui_polish_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.7_napoleonic_playtest_loop_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.8_napoleonic_release_candidate_foundation.md`
- `md/plan/plan.md`

后续迁移必须保留 hex 战术权威、Region 聚合层、动态 `hexToTheater` / `hexToFrontZone` 语义，以及 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一执行管线。

---

## 协作与云端验证

项目默认使用 `main` 直推触发 GitHub Actions 云端验证。本机只跑 `md/test/test.md` 允许的轻量检查；云端 workflow 会生成未加密 `ci-results` artifact，供 Agent C 下载并核对 manifest、JUnit 摘要、构建日志和失败摘要。完整 Agent A/B/C 规则见 `AGENTS.md`，云端检查细节见 `md/test/test.md`。

---

## 项目定位

一款 iOS / macOS 回合制历史 hex 战棋工程；当前默认发布候选入口为 Waterloo 1815，`WWIIHexV0` 作为历史工程名保留。目标结合战棋（六角格操作感）、大战略（省份占领、补给、前线）与角色扮演（LLM 驱动的将领 AI）。

**核心参考：**
- 《统一指挥2》：六角格战棋、补给、攻击（战术层参照）
- 《钢铁雄心4》：大战略、省份占领、前线、补给、生产、国家管理（战略层参照）
- EasyTech《钢铁命令》：战役推进、将领、战术操作
- 《世界征服者4》：移动端轻量化策略体验

**核心创新：本地部署 LLM 驱动游戏 AI**
- 国家统治者和元帅已进入当前 AI 上游；统治者只输出战略姿态，部长/Cabinet 不恢复
- agent 根据视野、战况摘要、性格和历史背景输出结构化 JSON 命令
- 游戏规则系统负责校验并执行，LLM 不直接绕过规则修改状态

---

## 地图 / 战区架构（核心决策）

**分层叠加，不是替换。** 六角格保留作战术/战斗层，省份与战区负责战略聚合。

```
Hex（战术层 / 真实占领与移动）
  ↓ hexToRegion
Region（省份规则层 / 资源、人力、补给、胜利点聚合）
  ↓ regionToTheater（初始战区基本单位，只读基准）
Initial Theater Layout（地图编辑器初始划分 / 只读 snapshot）
  ↓ hexToTheater
Dynamic Theater State（运行时动态战区 / 随 hex 推进变化）
  ↓ 动态 hex 邻接
FrontLine / FrontSegment（前线与分段，按动态战区接触生成）
  ↓
WarDeploymentState（FRONT / DEPTH / GARRISON 部署池）
  ↓
ZoneDirective / WarCommandExecutor / RuleEngine
```

**为什么分层：**
- 全球地图纯 hex ≈ 16 万节点，iOS 跑不动（尤其带 LLM agent）
- HOI4 证明：省是规则原子，全球 ~1-2 万省可实时跑
- 战术级 hex（UC2 风格）提供精细操作，战略级省提供全球性能
- **同一局内可切换**：大战略模式看省，zoom 进某省切 hex 板战术微操
- **v0.358 之后的关键语义**：
  - `regionToTheater` = 初始战区基本单位，服务地图编辑器、动态战区生成/合并/消亡的参照，不是运行时推进层。
  - `hexToTheater` = 运行时动态战区权威映射。单位占领一个 hex，只推进这个 hex 的动态战区归属，不能把整个 region 拉走。
  - 前线 = 我方动态战区与敌方动态战区的 hex 邻接接触，按 region 形成 `FrontSegment`。

**v0.2 以来的长期原则**：省份作为战略层叠加，**不替换** hex 坐标系。现有 hex 规则全保留，省作为聚合视图 + 省级规则并行运行。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 平台 | iOS；v1.1 新增 macOS 主游戏 target `WWIIHexV0Mac` |
| 语言 | Swift |
| UI 框架 | SwiftUI（面板、按钮、日志、单位详情） |
| 地图渲染 | SpriteKit（六角格地图、单位显示、移动/攻击反馈） |
| AI 接口 | `DecisionProvider` 协议（MockAI 已实现，预留本地 LLM） |

---

## 项目架构

```
WWIIHexV0/
├── Core/          — 核心数据模型（Division、GameState、HexTile、HexCoord、MapState 等）
├── Commands/      — 命令系统（Command、CommandResult、CommandValidation、GameCommandHandling）
├── Rules/         — 规则引擎（RuleEngine、CombatRules、SupplyRules、MovementRules、VictoryRules、CommandExecutor、CommandValidator）
├── Agents/        — AI Agent 管线（旧 Agent D + ZoneCommanderAgent / MarshalAgent）
├── Turn/          — 回合管理器（TurnManager，按 active faction 编排 AI / staff 回合；runGermanAITurn 仅为 legacy 便利入口）
├── SpriteKit/     — 地图渲染（BoardScene、UnitNode、HexNode、HexLayout、TerrainStyle、BoardSceneAdapter）
├── UI/            — 界面组件（UnitInspectorView、EventLogView、HUDView、CommandPanelView、AgentPanelView、RootGameView）
├── App/           — 入口（AppContainer、WWIIHexV0App、WWIIHexV0MacApp）
├── Data/          — 场景数据（DataLoader、ScenarioDefinition JSON、general_agents.json、generals.json、unit/terrain/general catalog JSON，含 v3.2 napoleonic_*）
├── Probes/        — 历史高速探针测试 target（默认不执行）
└── Tests/         — 历史单元测试 / 集成测试 / 真实战局模拟（默认不执行）
```

### 核心架构原则

- **规则与 UI 解耦**：游戏状态只能由 `RuleEngine` 修改，UI 只读取状态
- **命令管线**：玩家 / AI → `Command` → `CommandValidator` 校验 → `CommandExecutor` 执行 → 日志
- **AI 接口可替换**：`DecisionProvider` 协议，MockAI 已实现，未来可插入本地 LLM
- **地图分层**：hex（战术层，`HexCoord`）+ region（省份层，`RegionId`）+ dynamic theater（运行时战区，`hexToTheater`），不替换
- **AI 命令与玩家命令共用同一管线**：都经 `RuleEngine` 校验执行

---

## AI / 指令管线接口（已落地）

当前同时保留两条管线：

- **Legacy Agent D 管线**：`AgentContextBuilder → DecisionProvider → AgentDecisionParser → AgentCommandMapper → RuleEngine`。已保留作回归参考，默认不再作为战争 AI 主路径。
- **ZoneDirective 管线（执行权威）**：`ZoneDirective → WarCommandExecutor → RuleEngine → WarDirectiveRecord`。`WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 也可执行。
- **v0.5/v3.4 默认 AI 上游**：`RulerAgent → StrategicPostureEnvelope → StrategicPostureDecoder → MarshalAgent → MarshalBattlefieldSummarizer → SimulatedMarshalLLMClient → TheaterDirectiveDecoder → TheaterDirectiveCompiler → DirectiveEnvelope / ZoneDirective`。它只做战略姿态、战略意图、JSON I/O、解码校验和 fallback，不直接修改战术状态。
- **v3.1 多势力与敌我关系基础**：`Faction` 已加入 France / Anglo-Allied / Prussia / Austria / Russia / Spain / Neutral 兼容 case；`DiplomacyState.isHostile` / `isFriendly` 已作为补给、region pressure、AI 摘要、目标排序、攻击校验、ZOC、占领、前线邻接、部署分类、战区压力和 HQ 威胁的统一敌我查询入口；旧二元数据缺外交关系时仍回退到不同 faction 敌对，Neutral 不会因缺 relation 被视为敌对。
- **v3.4 统治者层起步**：`RulerAgent` 当前只位于元帅上游，输出国家级姿态或约束条件并写入 `RulerDecisionRecord`；不得绕过 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

| 文件 | 职责 | 关键类型/协议 |
|------|------|--------------|
| `Agents/DecisionProvider.swift` | 统一 AI 接口 | `protocol DecisionProvider { func decide(context:) async throws -> AgentDecisionEnvelope }` |
| `Agents/GameAgent.swift` | 运行时 agent 模型 | `GameAgent`（精简版，无 Cabinet/DirectiveDomain，v0.5 污染已剔除） |
| `Agents/AgentConfiguration.swift` | agent 加载 | `GameAgent.guderian(from:state:)`，优先 `general_agents.json`，失败 fallback |
| `Agents/AgentContexts.swift` | agent 能看到的摘要 | `AgentContext` + `AgentContextBuilder`（无 organization，适配 v0.1） |
| `Agents/AgentDecision.swift` | 结构化决策 DTO | `AgentDecisionEnvelope` / `AgentOrder` / `AgentOrderType`（move/attack/hold/resupply） |
| `Agents/AgentDecisionParser.swift` | JSON → envelope | 校验 schemaVersion / agentId / turn，malformed 抛 typed error |
| `Agents/AgentCommandMapper.swift` | order → Command | `AgentCommandMapper.map(_:agentId:) -> IssuedCommand`，缺字段抛 error |
| `Agents/AgentDecisionRecord.swift` | 决策记录 | `AgentDecisionRecord` / `CommandResultSummary`（UI 读） |
| `Agents/MockAIClient.swift` | 启发式 staff / fallback provider | 启发式：resupply → attack → move(向未控制目标) → hold |
| `Agents/LLMClient.swift` | Legacy LLM 接口预留 | `protocol LLMClient` + `LLMRequest`（旧 Agent D 用，默认不启用） |
| `Agents/LocalLLMDecisionProvider.swift` | 本地 LLM provider | 注入 `LLMClient` + `AgentPromptBuilder` + parser，失败由上层 fallback MockAI |
| `Agents/AgentPromptBuilder.swift` | prompt 构造 | system + user prompt，强制 JSON 输出 |
| `Core/DiplomacyState.swift` | 国家/集团/关系与敌我 helper | `isHostile` / `isFriendly` / `hostileFactions`，供补给、AI 摘要、ZOC、占领、前线、部署、战区压力和 HQ 威胁读取 |
| `Turn/TurnManager.swift` | AI 回合编排 | `runAITurn(state:faction:) async -> AgentTurnOutcome`；`runGermanAITurn` 仅保留 legacy 便利入口 |
| `App/AppContainer.swift` | AI 接线 | `runAIIfNeeded()` 通过 `PlaytestAIControlMode.shouldRunAI` 判断自动触发：Staff 模式按 active faction / player faction / observer mode / `phase.allowsCommands` 运行 AI，Manual 模式不自动 dispatch；非 observer Manual 推进仍走 `Command.endTurn`，observer Manual 只读且 `submit(_:)` 拒绝直接命令；继续存档成功后也调用同一 gate |
| `UI/AgentPanelView.swift` | 决策展示 | 读 `record`（agent/provider/intent/context/command results/errors/raw JSON） |
| `UI/RootGameView.swift` | 回合触发 | HUD / CommandPanel 调用 `advanceOrRunAI()`；玩家命令提交后 `AppContainer.submit` 也会调用 `runAIIfNeeded()` |

**MockAI 行为（legacy 兼容 / simulated staff fallback）：**
跳过已行动单位 → 低补给/包围优先 resupply → 射程内低 hp 敌军优先 attack（炮兵优先打城市/要塞）→ 向当前未控制目标 move → 否则 hold；Waterloo / 拿战 faction 输出 formations、contact sector、corps deployment 口径，legacy 阿登仍按旧数据目标推进。

**v0.7 ZoneDirective 战术行为：**
`ZoneCommanderAgent` 读取所属 `FrontZone` 的前线/部署摘要，`BinaryTacticClassifier` 会结合兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告，在 `standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`、`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand` 之间分类；`WarCommandExecutor` 将这些战术降级为 `move / attack / hold / allowRetreat`，仍统一交给 `RuleEngine` 校验执行。`WarDirectiveRecord` 记录 `category` / `tactic` / `commanderAgentId` / `commandTarget`，便于后续接真 LLM 回放与审计。

**v0.5/v3.4 MarshalDirective 行为：**
`RulerAgent` 先生成 `StrategicPostureEnvelope` 和 `RulerDecisionRecord`，只给元帅层提供姿态、偏好和 reserveBias，不直接执行命令。`MarshalBattlefieldSummarizer` 把 `GameState` 降维为元帅摘要，只包含 front zone、strength ratio、补给/士气/疲劳/弹药警告、目标和事件，不把全量 hex 网格喂给模型。敌我判断读取 `DiplomacyState.isHostile`，而不是在摘要层直接依赖二元 `Faction.opponent`。`SimulatedMarshalLLMClient` 读取 strategic posture 后生成 fenced JSON 形式的 `TheaterDirectiveEnvelope`；`TheaterDirectiveDecoder` 提取并校验 JSON；`TheaterDirectiveCompiler` 把元帅意图编译成现有 `ZoneDirective`。v0.7 后 `TheaterDirective` 可携带 `convergenceRegionId` / `coordinatedZoneIds` 支持钳形会师意图；解码或编译失败时 fallback 到 `TheaterCommanderPool`，不执行半成品 LLM 输出。

**v3.4 Ruler / Diplomacy 边界：**
统治者层当前已经进入默认 AI 上游，但只生成 `StrategicPostureEnvelope`、`RulerDecisionRecord` 和元帅上下文；它不能直接生成底层 `Command`，不能改写 hex / theater / deployment 权威状态。后续如要加入独立皇帝、君主、参谋长、军团长、国家集团或外交官 agent，仍必须先设计独立 schema，并保持底层战争规则由 `ZoneDirective`、`WarCommandExecutor` 和 `RuleEngine` 收口。

---

## 当前完成进度

### ✅ v0：六角格测试板（已完成）

**历史 v0 场景**：阿登测试战场（legacy Ardennes），德军 vs 盟军，11×9 六角格地图；当前默认 playable 为 Waterloo 1815 数据切片。

| 功能模块 | 状态 |
|----------|------|
| 六角格 axial 坐标系统 | ✅ |
| 地形系统（平原/森林/山地/城市/道路/河流/要塞） | ✅ |
| 移动系统（地形消耗、道路加成、跨河惩罚、敌方阻挡） | ✅ |
| 战斗系统（近战/炮兵远程、地形防御修正、反击） | ✅ |
| 侧翼/背后加成 | ✅ |
| 占领系统（城市控制权变更） | ✅ |
| 补给系统（supplied / lowSupply / encircled） | ✅ |
| 包围判定与惩罚 | ✅ |
| 历史 v0 回合系统（legacy 德军 AI → 盟军玩家 → 结算；v3.8 当前按 active faction / player faction / staff control 推进） | ✅ |
| MockAI 将领 agent（guderian，装甲突破风格） | ✅ |
| 结构化 JSON 命令解析与校验 | ✅ |
| AI 决策日志面板（AgentPanelView 读 AgentDecisionRecord） | ✅ |
| 胜利条件（巴斯托涅占领 / 消灭 3 单位 / 切断补给） | ✅ |

---

### ✅ v0.1：strength、撤退与补员（已完成）

| 功能模块 | 状态 |
|----------|------|
| `Division` 升级为 strength/maxStrength，保留 hp/maxHP 兼容 | ✅ |
| 战斗改为 strength 伤害（organization 已移除） | ✅ |
| 撤退状态：自动寻找安全相邻格撤退 | ✅ |
| 撤退失败施加额外惩罚 | ✅ |
| `resupply/rest` 恢复 strength | ✅ |
| 包围每回合扣 strength | ✅ |
| UI 显示 Strength、Retreating 状态 | ✅ |
| 日志按 combat/retreat/reinforce/encircle/supply 分类 | ✅ |
| 死守 / 允许撤退（RetreatMode）按钮与 HOLD 防御加成 | ✅ |

**v0.1 最终模型：** 只看兵力，无 organization。`RetreatMode`（retreatable/hold）控制撤退：HOLD 防御 +20%，RETREATABLE 单次损失比例 ≥ 35% 自动撤退。

---

### ✅ Agent D：AI/Agent 决策管线（已完成）

| 功能模块 | 状态 |
|----------|------|
| `DecisionProvider` 协议（MockAI + LocalLLM 共用） | ✅ |
| `AgentContext` / `AgentContextBuilder`（Codable 摘要，无 UI/SpriteKit 对象） | ✅ |
| `AgentDecisionEnvelope` / `AgentOrder` JSON schema | ✅ |
| `AgentDecisionParser`（校验 schema/agent/turn） | ✅ |
| `AgentCommandMapper`（order → Command，缺字段抛 error） | ✅ |
| `MockAIClient`（动态目标启发式；legacy 阿登目标仍按旧数据兼容） | ✅ |
| `LLMClient` / `LocalLLMDecisionProvider` / `AgentPromptBuilder`（预留，v0 默认关） | ✅ |
| `TurnManager`（德军 AI 回合编排，含 endTurn） | ✅ |
| `AppContainer.runAIIfNeeded()`（启动自动跑 AI 回合） | ✅ |
| `AgentDecisionRecord` + `AgentPanelView`（UI 读决策记录） | ✅ |
| `AgentPipelineTests`（8 测试：context/MockAI/parser/mapper/provider 失败/非法命令） | ✅ |

---

### ✅ v0.2 Agent 1：省份图架构（已完成）

省份图规则层模型。**叠加，不替换 hex。** hex 仍战术层权威坐标，province 是战略层聚合。

| 文件 | 职责 |
|------|------|
| `Core/Region.swift` | `RegionId`（RawRepresentable<String>）、`RegionNode`、`RegionEdge`、`RegionGraph`、`CityInfo`、`ResourceAmount`、`ResourceType`、`OccupationState`、`RegionEdgeKey`（对称键）、`RegionValidationError`（9 case） |
| `Core/MapState.swift`（改） | 加 `regions`/`hexToRegion`/`regionEdges` 字段（默认空）；加 province 查询：`region(for:)`/`region(id:)`/`neighbors(of:)`/`areAdjacent`/`edgeBetween`/`representativeHex`/`regionDistance`/`regionGraph`；加 `validateRegionGraph()` |
| `Core/Terrain.swift`（改） | `HexTile` 加 `regionId: RegionId?`（默认 nil） |
| `RegionGraph.validate()` | idMismatch/emptyDisplayHexes/representativeHexNotInDisplayHexes/neighborNotFound/neighborNotBidirectional/edgeEndpointNotFound/edgeNotInNeighbors |
| `MapState.validateRegionGraph()` | 复用上图校验 + hexToRegionPointsToMissingRegion + displayHexesOverlap |
| `Tests/RegionGraphTests.swift` | 19 测试：编解码/neighbors/areAdjacent/hexToRegion/representativeHex/validate 全错误类型+valid+empty |

**设计约束（Agent 1 已守）：**
- hex 规则全保留，province 默认空不破现有行为
- `MapState.ardennesV0()` 不改（保持纯 hex，测试用）
- 省份挂载在 Data 层（DataLoader），Core 不依赖 Data

---

### ✅ v0.2 Agent 2：省份数据层（已完成）

阿登 v0.2 省份图数据 + 加载。17 省覆盖全部 99 hex，零重叠，邻接双向一致。

| 文件 | 职责 |
|------|------|
| `Data/ardennes_v02_regions.json` | 17 省/41 边/99 hex 映射/2 补给源/4 目标。schemaVersion 2 |
| `Data/RegionDataSet.swift` | `RegionDataSet` + Codable 定义（`RegionNodeDefinition`/`CityInfoDefinition`/`ResourceAmountDefinition`/`OccupationStateDefinition`/`RegionEdgeDefinition`/`RegionSupplySourceDefinition`/`RegionObjectiveDefinition`）+ 映射 `toRegions()`/`toRegionEdges()`/`toHexToRegion()` |
| `Data/DataLoader.swift`（改） | 历史 v0.2：`loadInitialGameState()` 曾叠加阿登省份数据（try? 失败 fallback 纯 hex）+ 反向填 HexTile.regionId；v3.8 主 app 启动走 `AppContainer.bootstrap -> DataLoader.loadGameState(ScenarioCatalog.defaultPlayable)`，`loadInitialGameState()` 仅作 legacy / probe fallback |

**省份设计：**
- 德方控制：german_east_depot（补给源）、eifel_approach、schnee_eifel
- 盟方控制：allied_west_depot（补给源）、bastogne（主目标 VP5）、bastogne_fortress、st_vith、western_approach
- 中立（owner/controller null 在 v3.1 后映射为 `.neutral`，不再回退 `.allies`）：meuse_approach、houffalize、luxembourg_road、ardennes_forest_north/central/south、northern_ridge、southern_ridge、northern_frontier
- 路径：german_east_depot→bastogne=2，allied_west_depot→bastogne=3

| `Tests/ArdennesV02DataTests.swift` | 17 测试：解码/region 数/hexToRegion 覆盖/validate/邻接双向/repHex/路径连通/补给源/目标/关键省/控制权 |

---

### ✅ v0.3：战区、前线、部署、战争指令（当前主线，已推进至 v0.37）

| 版本 | 主题 | 关键内容 |
|------|------|----------|
| **v0.31** | Theater 战区层 | 四战区初始化、控制比例、70% 阈值、扩张/退役接口 |
| **v0.32** | FrontLine 前线层 | 动态前线、segment、dirty 更新、简化包围识别 |
| **v0.33** | WarDeployment 部署层 | FRONT / DEPTH / GARRISON 分层，FrontZone 单元池 |
| **v0.34** | 地图编辑器 | 默认地图与项目 schema 打通 |
| **v0.351** | 初级战争指令 | `ZoneDirective` / `WarCommandExecutor` / `MockAICommander` |
| **v0.352** | 新管线唯一化 | `WarPipelineMode.zoneDirective` 默认，观察者模式，分层战略 UI |
| **v0.353** | 默认地图验收 | hex controller 成为归属权威，补给归属跟随占领者 |
| **v0.354** | 联动修复 | 占领→region→theater→frontline 同回合联动，ZOC 友军穿越修正，拒绝率治理 |
| **v0.355** | 动态/初始战区分离 | `initialSnapshot` 与运行时动态战区分离，前线 overlay 与观察者 UI |
| **v0.356-v0.357** | 地图/前线 UI 修正 | 编辑器与游戏视角统一、开局单位越界检查、前线按战区/segment 着色 |
| **v0.358** | hex 动态战区语义收口 | 动态战区改跟 `hexToTheater`，region 基础战区只作初始/生成参照；AI/部署/前线测试同步更新 |
| **v0.36** | 命令层扩展与多将领 MockAI | `CommandCategory` / `TacticName` / `DirectiveTarget` / `ZoneCommanderAgent` / `TheaterCommanderPool` |
| **v0.37** | 命令层统一整合 | 移除 `TurnManager` 的 `MockAICommander` fallback，默认路径收口到 `TheaterCommanderPool`；补 issuer-agnostic executor 探针 |
| **v0.5** | 元帅层与模拟 LLM JSON | `MarshalAgent` / `TheaterDirectiveEnvelope` / decoder / compiler / marshal fallback |
| **v0.7** | 高级战术与命令扩展 | 闪电战、定点矛头、突破、钳形攻势、火力覆盖、佯攻、游击战、弹性防御、纵深防御、死守 |

### ⏳ 后续方向

| 版本 | 主题 | 关键内容 |
|------|------|----------|
| **v0.4** | 聊天命令与角色服从 | 玩家通过聊天框命令将领；将领根据性格/忠诚回应；命令可被质疑/拖延/抗命 |
| **v0.5/v3.4** | 统治者姿态与元帅模拟 LLM JSON | `RulerAgent`、`StrategicPostureEnvelope`、`MarshalAgent`、`TheaterDirectiveEnvelope`、JSON decoder、compiler、fallback；不恢复 Cabinet/Minister |
| **v1.0** | 大战略原型 | 经济/科技/生产；空军实体化；简化海军；天气；多国家多战区；全球地图；美术资源 |
| **v1.x** | 多回合战术行动 | 撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 深度分流等复杂多回合行动骨架 |

**v0.37 决策记录：** 撤退、突破、闪电战、装甲差异化和 `AttackIntensity` 深度分流推迟至 1.x。v1.0 只先把 `infiltration` 解释为默认低投入上限，不引入额外伤害、绕规则推进或多回合追踪行动。

---

## 核心设计约束

**LLM 使用原则（必须始终遵守）：**
1. 不让每个单位每回合都调用 LLM
2. LLM 只读取摘要，不读取完整地图
3. LLM 输出必须经过 `CommandValidator` 校验才能执行
4. 非法命令先尝试自动修复，修复失败则丢弃并记录日志
5. 没有 LLM 时，MockAI 接管所有决策

**架构扩展约束（后续 agent 必须遵守）：**
- 不要跳过命令管线直接修改 `GameState`
- **不要替换 HexCoord 坐标系**：hex 是战术层，province 是叠加的战略层，两者共存
- **不要把 `regionToTheater` 当动态战区推进层**：运行时战区归属看 `hexToTheater`，突破只推进 hex。
- **不要给 Division 加回 organization**：v0.1 已移除，只看兵力
- **不要引入 v0.5 Cabinet/StrategicDirective/Minister 污染**：v0.5 误删事件已发生，GameAgent 保持精简版
- 新增系统通过 `DecisionProvider` / `RuleEngine` / `Command` 接入，不直接改核心规则
- 保持核心语义不退步；默认只做轻量检查，Xcode / XCTest / 模拟器等重测试必须由人工明确授权。

---

## 文档索引

```
md/
├── 项目总规划.md                    — 整体设计目标、地图方案、LLM 架构、长期路线图
├── v0测试/
│   ├── phase0_v0_minimum_scope.md   — v0 最小可玩范围定义、数据结构清单
│   ├── phase1_hex_core_rules.md     — 六角格坐标、地形、战斗、补给、包围详细规则
│   ├── phase3_v0_engineering_architecture.md — v0 工程架构设计
│   ├── 阶段性4:第一版可玩测试板任务拆解.md  — v0 任务拆解和实现步骤
│   └── 误删agentD/                  — Agent D 打捞代码 + jsonl 会话记录（历史归档）
└── v0.1～1.0提示词/
    ├── 总体长期规划.md              — v0 至 v1.0 路线图全览
    ├── v0.1.md                      — v0.1 子 agent 提示词（已完成）
    ├── v0.2.md                      — v0.2 提示词（⚠️ 旧版纯省份替换方案，已废弃；新版见下方）
    ├── v0.3.md                      — v0.3 前线系统提示词
    ├── v0.4.md                      — v0.4 聊天命令与角色服从提示词
    ├── v0.5.md                      — v0.5 国家与部长 agent 提示词
    └── v1.0.md                      — v1.0 大战略原型提示词
```

> ⚠️ `v0.2.md` 是旧的"纯省份替换 hex"方案，已废弃。v0.2 新方向见本文档"地图架构"与"v0.2"行：**省份叠加，不替换 hex**。

---

## 给后续 Claude Code 的提示

**你接手时的代码库状态：**
- v0.5 分支已引入元帅层与模拟 LLM JSON/decoder/ compiler；历史测试基线曾达到 v0.37 Probe 18/0、Stage Regression 69/0、Full 226/0。当前默认不跑重测试，只做 `md/test/test.md` 允许的轻量检查。
- 战斗模型：兵力伤害为主，`RetreatMode`（retreatable/hold）控制撤退，无 organization。
- 默认战争 AI 管线：`MarshalAgent` 读取摘要并模拟输出 `TheaterDirectiveEnvelope` JSON，经 `TheaterDirectiveDecoder` 与 `TheaterDirectiveCompiler` 降级成 `ZoneDirective`，再走 `WarCommandExecutor`。`TheaterCommanderPool` / `ZoneCommanderAgent` 仍作为 fallback 和显式 `.zoneDirective` 路径。
- Legacy Agent D 管线保留但默认不调用。
- 地图坐标系：hex 仍是战术权威；Region 是省份规则层；动态战区看 `hexToTheater`。

**继续开发前请先阅读：**
1. 本 README（地图架构三层决策 + Agent D 接口表）
2. `WWIIHexV0/Core/Division.swift`（当前 Division 模型）
3. `WWIIHexV0/Core/MapState.swift` / `Region.swift` / `Theater.swift`
4. `WWIIHexV0/Rules/TheaterSystem.swift` / `FrontLineManager.swift` / `WarDeploymentManager.swift`
5. `WWIIHexV0/Commands/WarDirective.swift` / `WarCommandExecutor.swift`
6. `WWIIHexV0/Agents/ZoneCommanderAgent.swift` / `MockAICommander.swift`
7. `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`

**当前必须遵守：**
- 不删 `HexCoord`，不把运行时战区推进退回 region 粒度。
- `Initial Theater Layout` / `regionToTheater` 是地图编辑器与动态演化基准，不是实时前线。
- `Dynamic Theater State` / `hexToTheater` 是游戏战区层权威。
- 前线 UI 和 AI target 选择必须基于动态 hex 邻接；历史测试 fixture / 语义文档也必须构造真实相邻 hex，不能只声明 region 邻接。
- `ZoneDirective` 新字段必须保持 Codable 向后兼容。
- 元帅层和统治者层不得绕过 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- 当前 v0.5 只模拟 LLM JSON 接口，不接真实模型；真实 LLM 接入必须保留 decoder 校验与 fallback。

**轻量检查**（每轮先读 [`md/test/test.md`](md/test/test.md)，默认禁止 Xcode / XCTest / 模拟器 / 性能类测试）：
```bash
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md
```
旧测试口径残留、JSON / project / scheme 检查按 `md/test/test.md` 追加执行。未获人工授权时，不跑历史 Probe / Stage / Full。
