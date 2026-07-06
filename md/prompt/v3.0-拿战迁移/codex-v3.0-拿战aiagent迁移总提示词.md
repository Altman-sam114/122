# Codex v3.0-v3.8 任务提示词：从 WWIIHexV0 迁移为 AI Agent 驱动的拿破仑战争战棋

> 本文是交给后续实现 Agent 的总提示词。它不是本轮代码实现记录，而是后续多版本迁移的路线、边界、并发分工和验收标准。执行前必须先读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和本文件。

---

## 0. 当前项目判断

你接手的是 `WWIIHexV0`，当前代码不是早期原型，而是一个已经有多条方向沉淀的 Swift + SwiftUI + SpriteKit 战棋工程。现有主链路包括：

```text
MapEditor / JSON
  -> DataLoader
  -> GameState
  -> HexTile.controller + Division.coord
  -> Region 聚合
  -> EconomyState 收入 / 生产 / 补员
  -> Theater / FrontLine / WarDeployment 派生层
  -> General / Marshal / Ruler / Diplomacy 草案
  -> TheaterDirective / ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> UI / SpriteKit / 日志 / WarDirectiveRecord
```

当前代码和文档中已经确认这些事实：

- `HexTile.controller` 和 `Division.coord` 是战术层权威。
- `RegionNode.controller` 是从 hex 聚合出来的战略快照。
- `regionToTheater` 是初始/基础战区，不是运行时推进权威。
- `hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- 当前默认 AI 文档口径是 `RulerAgent -> StrategicPostureEnvelope -> StrategicPostureDecoder -> MarshalAgent -> TheaterDirective JSON -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- Legacy Agent D 管线保留作回归参考，默认战争 AI 主路径不得退回旧管线。
- v3.1 已把 `Faction` 扩展为 legacy `.germany/.allies` 加拿战兼容 `.france/.angloAllied/.prussia/.austria/.russia/.spain/.neutral`；`Faction.opponent` 仅作为 legacy helper 保留，主路径敌我关系开始迁移到 `DiplomacyState.isHostile/isFriendly`。
- v3.1 已新增 `GamePhase.aiCommand/playerCommand`、`allowsCommands` 和多势力 turn order helper；旧 `.germanAI/.alliedPlayer` raw value 仍保留旧数据兼容。
- 当前单位源码类型叫 `Division`；legacy `tank` / `motorizedInfantry` / `infantry` / `artillery` 仍保留兼容，v3.3 已新增 `lineInfantry`、`lightInfantry`、`cavalry`、`guardInfantry`、`engineer`、`supplyTrain`。
- 当前经济底层仍是 `manpower / industry / supplies`，`ProductionKind` raw case 仍保留 `panzerDivision`、`motorizedDivision` 等兼容名；v3.5 起 France / Anglo-Allied / Prussia 等拿战 faction 的 UI 与规则日志已显示为 `Recruits`、`Ammunition/Horses`、`Reserves`、`Guard Detachment`、`Cavalry Reserve` 等预备队语义，Waterloo 数据切片已有 French Imperial Guard / Prussian IV Corps delayed reinforcement schedule。`Division` 也已有最小 `morale` / `fatigue` / `ammunition` 战术字段，移动、攻击、反击、HOLD、resupply/rest、低士气攻防惩罚、broken morale move / attack 拒绝、staff offensive dispatch 对 broken morale formation 降级 Hold 休整、低弹药火力惩罚和 UI / Marshal 摘要警告已接入。
- Prussian IV Corps 当前由 `commander_bulow` 归属，从 q5,r1 Wavre Road 抽象后方入口入场，但仍由 q4,r1 Prussian Arrival Road objective 控制权触发；Wavre Road 不是完整 Wavre 后方地图，Bulow 当前只是目录 / 展示 / 偏好 / 增援归属数据。
- v3.6 已新增 `NapoleonicDesignTokens`，并让 HUD、单位详情、tooltip 和预备队面板用文字加颜色表达 morale / fatigue / ammunition / readiness 状态；HUD 标题、RootGameView accessibility label 和 SpriteKit empty board title 已改读 `ScenarioCatalog.displayName(for:)`，不再硬编码 `Ardennes V0`；HUD 拿战路径 active faction 指标显示为 Active Power。拿战 faction 下 map layer picker、compact tabs、dispatch 分类、interactionLog、`CommandResult.message`、规则事件日志、tooltip/VoiceOver、UnitNode formation symbols、reinforcement entry marker、objective marker、WarDirectiveRecord recent replay + tactic marker、AI 空状态以及单位/地域/命令/将军/指挥官档案/外交/AI 复盘面板内标签已开始脱离二战占位，显示 Sector、Active Wing、Contact、Corps、Formation、Formation Strength、Orders、Corps Order、Order executed/rejected、Hold Line、Withdrawal、Commander Profile、Coalition、Staff、Command Dispatch、Simulated Staff、Dispatch Audit 等术语；完整地图美术、完整炮击/冲锋路径、指挥官头像、完整战报回放面板和视觉验收仍未完成。
- EventLog 分类展示已覆盖 Engagement / Withdrawal / Logistics / Isolation / Dispatch，仍只在 Standard / Concise 层做展示净化，Full raw 审计值保留。
- v3.7 已起步新增新局配置入口、最小保存/继续路径、最小 slot label、基础试玩设置、非阻塞短引导、无可行动反馈、AI dispatch issue 可见诊断、诊断/拒绝原因预览和 AI 回放摘要：`NewGameSetupView` 从 HUD 打开，默认列出非 legacy scenario，打开 `Archived Campaigns` 后才显示 `ScenarioCatalog.all` 中的 legacy entry，按所选 scenario JSON 派生玩家可选非中立阵营，并通过 `AppContainer.startNewGame(scenario:playerFaction:startsAtPlayerFaction:)` 重载场景、将领目录和玩家阵营；sheet 玩家可见选择显示为 Player Power / Power，`Opening Turn` toggle 可决定玩家所选 power 是否先进入 orders phase，Reset 说明显示 campaign data / dispatch history / rules-guided orders path，空存档提示显示 No saved campaign，清理和坏存档提示不再暴露 snapshot / schema 工程词，开局日志显示 Opening orders assigned，底层仍保留 `Faction` / `playerFaction` schema 和 API；sheet 也暴露 Save Slot、Slot Name / Rename Slot、Observer Mode、Map Layer、Dispatch Detail、Staff Pace、Staff Control、Guide Notes、Reduce Motion 和 Text Size，底层仍由 `AICommandPace` / `PlaytestAIControlMode` 持久化。HUD phase 会按 active faction、玩家阵营、Staff Control 和 observer 状态显示 Your Orders / Staff Dispatch / Manual Dispatch / Manual Observation；HUD active faction 指标在拿战路径显示 Active Power。拿战 JSON 已加入 iOS / macOS bundle resources，可从新局入口选择 Waterloo 数据切片。`GameSaveSnapshot` 当前以 schemaVersion 1 把 `GameState`、scenario、玩家 faction 和开局顺序存入 `GameSaveSlot` 的 Slot 1 / Slot 2 / Slot 3 本地 `UserDefaults` key，Slot 1 兼容读取旧单槽 key `WWIIHexV0.savedGameSnapshot.v1`；`GameSaveSlot` 另以独立 `UserDefaults` key 保存 32 字以内 slot label，label 不写入 snapshot、不升级 schemaVersion；拿战路径 slot summary 显示 Current / Your Power，legacy fallback 仍保留 Active / Player；继续时必须匹配当前 `ScenarioCatalog` 中存在的 snapshot scenario，找不到 scenario 时按 slot 显示不可用原因；恢复成功会重载对应将领目录、重新 bootstrap / assign generals，并调用现有 `runAIIfNeeded()` eligibility gate；坏快照或 schema 不兼容时 Continue 区块会按 slot 显示不可用原因，并可 Clear Saved 清理坏快照或旧试玩快照；legacy snapshot 在归档开关关闭时只显示中性占位和清理入口，打开后才显示 forces 详情和继续入口；sheet 内 Status 区块会显示 Start / Save Current / Continue Saved / Clear Saved / Rename Slot 的最近操作结果，开始或继续失败时保留 sheet 并显示 `AppContainer.lastCommandMessage`。`PlaytestSessionSettings` 当前把 observer、map layer、`ReplayDetailLevel`、`AICommandPace`、`PlaytestAIControlMode`、Guide Notes、Reduce Motion 和 `PlaytestTextSize` 存到 `UserDefaults` key `WWIIHexV0.playtestSessionSettings.v1`；偏好数据无法解码时会移除损坏值、恢复标准设置并显示提示。`PlaytestAIControlMode` 默认 Staff 保持旧行为：非 observer 下玩家 faction 手动，其它非 neutral faction 自动走 simulated staff / MockAI fallback；`runAISequence` 以当前 turn order faction 数量为有限上限，连续处理非玩家 AI faction 直到回到玩家方或 AI 资格失效；Manual 只停用自动 dispatch，非 observer 下回合推进仍通过 End Orders / `Command.endTurn` 进入 `RuleEngine` 推进当前 active faction，observer + Manual 保持只读，`AppContainer.submit(_:)` 会拒绝 observer 直接命令，不允许直接操控其它 faction 单位。`ReplayDetailLevel` 当前控制事件日志条数、AI directive 条数、Staff Summary、Issue Preview、Recent Dispatch Timeline、context summary、逐条明细和 Dispatch Audit / raw JSON 审计显示；`PlaytestTextSize` 当前提供 Compact / Standard / Large 三档，用 Dynamic Type 字体样式调整 `EventLogView` 与 `AgentPanelView` 的标题、metadata、正文、审计文本和行距；`AICommandPace` 只控制 simulated staff 行动前短延迟，Reduce Motion 开启时跳过这段本地等待；`AgentPanelView` 从 `AgentDecisionRecord` 与最近 `WarDirectiveRecord` 只读聚合执行、拒绝、问题、focus sector / target 和最新 tactic，并把最近 directive 按 turn、scope、target、tactic、执行/拒绝/问题数和首要拒绝或诊断原因摘要成 Recent Dispatch Timeline，Concise 下隐藏逐条 command / directive 明细但保留短摘要、Issue Preview 与时间线，Full 下拿战路径显示 Dispatch Audit，directive 结果摘要显示 carried out / refused，并净化 `zone directives` / `mock directives` 等可见审计文本，底层 `rawJSON` 仍保留。`runAISequence` 会聚合连续 AI faction 的 record-level 错误并写入 `Staff dispatch issue` / `AI issue` interaction log，有限步数 guard 结束后仍 AI-eligible 时追加 dispatch paused 诊断；默认 directive 管线的 AI end-turn 失败也会同步进诊断型 `WarDirectiveRecord`。`PlaytestGuideCue` 当前在首次选择 formation、炮兵/远程单位、骑兵和首次结束命令时写入短 `Staff note`，不弹 modal、不阻塞地图，并受 Guide Notes 本地设置控制；命令面板会显示本方剩余可行动 formation / unit 数量，Manual 非玩家 active faction 会提示用 End Orders 手动推进，observer + Staff 会提示用 End Orders 触发 staff dispatch，observer + Manual 保持 orders disabled，macOS Orders 菜单也跟随 `canAdvanceOrders` 禁用，AI 无有效战场命令时会追加 Staff note / AI note。
- v3.8 已起步发布候选收口：`ScenarioCatalog.defaultPlayable` 已切到 Waterloo 1815 数据切片，`ScenarioCatalogEntry` 记录 `defaultPlayerFaction`，当前默认玩家阵营为 France；`AppContainer.bootstrap()` 按默认场景读取 Waterloo 将领目录和默认玩家阵营，默认加载失败时不再自动打开 Ardennes legacy，而是保留 Waterloo 元数据、构造 1x1 inert 恢复地图并提示打开 `New Campaign` 切换到可用 scenario；将领目录加载失败不再在新局/继续路径静默变成空 registry，新局或继续会保留当前状态并显示失败原因，启动恢复态只允许无将领目录的恢复提示；`DataLoader.loadGameState` 会复用已加载并校验过的 `GeneralRegistry` 做部署层将领分配，不再二次 `try?` 读取。`ScenarioCatalog.entry(for:)` 会把阿登 catalog id `ardennes_v0` 与 MapEditor legacy JSON runtime id `mapeditor_scenario` 解析到同一 legacy 场景，`loadGameState(ScenarioCatalogEntry)`、保存和继续会把 `GameState.scenarioId` 归一到 catalog id，存档继续、slot 摘要、HUD/棋盘标题和 legacy 校验不再分裂；`DataLoader.loadInitialGameState()` 仍保留为 legacy / probe fallback，不作为主 app 默认启动入口；`DataLoader.loadGameState` 会校验 `initialPhase`、`playerFaction`、`aiFaction`、terrain rules、raw hexToRegion key / tile region 反向映射、riverEdges、victory objective / target faction、general catalog、keyLocations、unit template maxHP/components/weight、unit/reinforcement hp/facing/supply/retreat mode 和资源引用，不再用 Germany / Allies fallback 吞坏 JSON；scenario JSON 的 `victoryConditions` 已映射进 `GameState.victoryConditions`，Waterloo 分支会按 `french_break_center` / `coalition_hold_until_prussia` 读取 objective id、target faction 和决定回合，旧存档缺字段时保留 fallback；`RegionVictoryRules` 只在 legacy 阿登 / MapEditor legacy runtime id 下评估 Bastogne / St. Vith region 胜负；`napoleonic_terrain_rules` 已映射进 `GameState.terrainRules`，Waterloo 主路径移动、战斗防御、渡河修正和 AI breakthrough / defensive sorting 已读取 runtime rule set；默认入口不预先创建 Guderian/Germany turn manager，stored Guderian manager 兼容特例会同时校验当前 scenario 与 runtime `GameState.scenarioId` 都匹配 Ardennes legacy；`AgentPanelView` / `AppContainer` 在拿战 faction 下把 raw `*_mock_commander` / `MockAI` / `MockAI+MarshalDirective` 包装为 Command Staff / Simulated Staff 展示，Standard context summary 使用 staff display name，EventLog phase metadata 显示 Orders / Staff Dispatch；`NapoleonicMessageSanitizer` 统一供 EventLog、AgentPanel、CommandPanel 和 AppContainer interaction log 净化 raw AI / MockAI / legacy pipeline / Germany / Allies / front zone、region、theater id / diagnostic / validation rawValue，并覆盖 Full 详情和诊断中可见的 raw JSON / raw command / pipeline / schemaVersion / snapshot 工程词，`TurnManager` 和 `WarCommandExecutor` 的默认诊断/规则拒绝事件也会优先写 Staff / Corps / End Orders 与 `CommandValidationError.displayName(for:)` 文案，AppContainer 拿战路径的 AI completion / resolved / issue / guard paused 可见文案显示为 Staff dispatch，连续 AI faction 诊断正文按实际 acting faction 做 sanitizer，Full raw JSON 和底层记录仍保留 schema 审计内容；`CommandResultSummary` 和 `HexNode` 也已补拿战展示名 / 供给源短码；MapEditor 资源桥和 UI 已把旧 default wording 收口为 Legacy 阿登资源，旧 default API 只作兼容 wrapper，MapEditor 导出的 `factions/initialPhase/playerFaction/aiFaction` 和新单位 id 前缀会按实际 faction 派生；玩家军团 directive 回写也会经过 `refreshGeneralAssignments` / `normalizeCommandPhase`；阿登 legacy 仍保留在 `ScenarioCatalog.all` 中，但默认隐藏在 `Archived Campaigns` 后，旧 legacy 存档摘要默认也不显示 Germany / Allies forces 或继续按钮。默认入口已经是拿战剧本，Waterloo 数据切片已补入 Plancenoit、Anglo-Allied Rear Road q2,r1 marker、Prussian Approach q4,r0 road marker 和 La Haye Sainte / Papelotte / Plancenoit 最小初始守备，但仍不是完整战役；通用 victory condition DSL、完整 terrain DSL、完整地图规模、发布级 UI、发布级命名存档/迁移器、文件导出、云同步、完整教学流程、完整动画回放、完整运行时错误恢复和人工授权重验证尚未完成。
- 当前主要默认数据已切向 Waterloo；阿登、Germany、Allies、Bastogne、Guderian、Montgomery 等二战语义仍作为 legacy 兼容路径、历史文档或源码兼容名残留。滑铁卢剧本仍是最小数据骨架，拿战玩家可见语义只在多势力、单位模板、Agent 姿态、经济/预备队展示、战术士气/疲劳/弹药、UI 状态 token、AI replay staff 展示、供给源 marker、delayed reinforcement、Waterloo 最小胜负节奏、新局/默认入口等切片中起步接入。
- 当前工作树可能混有 v0.4、v0.5、v0.7、v0.8、v0.9、v1.0、v1.1 等未提交改动。任何实现前必须做分支和文件冲突审查，不能回滚他人改动。

迁移目标不是“换一套文字和颜色”，而是把这个工程逐步迁移为一个可发布的 AI Agent 驱动拿破仑战争战棋。

---

## 1. 最终产品目标

暂定产品名：`拿破仑战棋 Agent`。英文工作名可用 `Napoleon Command Agent` 或 `Napoleonic Command Hex`。

最终首发体验应达到以下效果：

1. 打开应用后直接进入可玩的拿破仑战争战役，不做营销落地页。
2. 第一批可发布战役建议选择范围可控、辨识度高、Agent 行为明显的战役：
   - 首选：`滑铁卢 1815`。阵营清晰，联军协同、普军迟到、法军机动、英荷防线、村庄据点、炮兵与骑兵冲锋都能体现。
   - 备选：`奥斯特里茨 1805`。适合表现拿破仑诱敌、中央突破、联军多国协同、右翼弱点和高地争夺。
   - 不要第一版就做完整欧洲大战略、半岛战争全图或 1805-1815 全战役沙盒。
3. 玩家可选择一个阵营或国家；其他阵营由 AI Agent 驱动。
4. 地图以 hex 为战术权威，以村庄/高地/道路节点/战役区块为 region 聚合层，以军团/翼/军区为 AI 调度层。
5. 玩家既能微操具体部队，也能通过元帅/军团长面板下达宏观命令。
6. AI 不直接改 `GameState`。皇帝、君主、总司令、元帅、军团长、参谋等 Agent 只能输出结构化 directive，经 decoder/validator/compiler 后落到规则系统。
7. UI 视觉要摆脱当前调试原型感：应有 19 世纪军事地图质感，包含羊皮纸/战役地图、军旗、军团色、红蓝铅笔进军箭头、村庄/桥梁/高地/林地/炮兵阵地图标、军团长头像、战报和命令回放。
8. UI 不能堆说明卡片。第一屏核心是地图、部队、命令、回合和战报。
9. 发布前必须没有主要二战文案残留：Germany、Allies、Ardennes、Bastogne、Panzer、tank、motorized、WWII、Division 等不应出现在主游戏 UI、默认数据、日志和玩家可见面板中。源码兼容名可分阶段保留，但必须在文档中声明。
10. 发布前必须有一个可演示闭环：开局、选择阵营、查看军团和指挥官、移动、炮击、骑兵冲锋、步兵进攻/方阵、防守村庄、占领目标、AI 回合、战报复盘、胜负判断。

首发战役建议规格：

```text
scenarioId: waterloo_1815
displayName: 滑铁卢 1815
地图范围：滑铁卢战场核心区，可抽象包含 Mont-Saint-Jean、La Haye Sainte、Hougoumont、Papelotte、Plancenoit、Wavre/普军来援方向
主要阵营：France、Anglo-Allied、Prussia
首版规模：约 80-160 个 hex，20-45 个 region，4-8 个 army wing / corps zone
首版回合：12-24 回合，代表战役日内关键时段
胜利条件：法军突破联军中心/占领关键据点/阻止普军会合；联军守住关键线并消耗法军，或普军抵达后夺取法军侧后方
```

---

## 2. 迁移总原则

### 2.1 保留的工程骨架

必须保留并迁移这些成熟资产：

- Hex 坐标、移动、攻击、占领、视野、补给落点的战术权威。
- Region 作为战略聚合层，不替代 hex。
- Dynamic Theater、FrontLine、WarDeployment 的派生关系。
- `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一执行管线。
- `WarDirectiveRecord`、`AgentDecisionRecord`、`RulerDecisionRecord` 等审计/复盘记录。
- MapEditor 的稀疏 hex、region、theater、unit 编辑与导出能力。
- iOS 主游戏、macOS 主游戏和 macOS 地图编辑器三个方向。
- 当前轻量检查规范和禁止重测试规则。

### 2.2 必须替换或抽象的二战语义

必须逐步替换这些题材绑定点：

- `Faction.germany/allies`：迁移为拿战国家/阵营体系，至少支持 `france`、`angloAllied`、`prussia`、`austria`、`russia`、`spain`、`neutral`。首发滑铁卢可先只启用 France / Anglo-Allied / Prussia / neutral。
- `Faction.opponent`：多方敌我必须来自 `DiplomacyState` / `CoalitionState` / `PowerRelation`，不能继续用二元 opponent。
- `GamePhase.germanAI/alliedPlayer`：迁移为通用 phase，例如 playerCommand / aiCommand / resolution，或至少抽出显示与控制逻辑，避免 Germany/Allies 绑定。
- `Division` 显示语义：源码可短期保留兼容名，但 UI 应显示为军团、师、旅、部队或 formation。拿破仑时代也有 division，但不得沿用二战“装甲师/摩步师”语义。
- `ComponentType.tank/motorizedInfantry/infantry/artillery`：迁移为 lineInfantry、lightInfantry、cavalry、artillery、guard、engineer/sapper、supplyTrain 等。
- `EconomyResources.manpower/industry/supplies`：战役首版可显示为 recruits / treasury / supplies / ammunition / forage / horses，短期源码字段可兼容但 UI 不显示 Industry/Panzer 等现代语义。
- `ProductionKind.panzerDivision/motorizedDivision`：迁移为 line infantry reserve、cavalry reserve、artillery battery、supply wagon、guard detachment 等；滑铁卢短战役可弱化生产，改为援军/预备队到达。
- `Theater` 显示为 Army / Wing / Corps Sector，不显示二战战区。
- `FrontZone` 显示为军团防区/翼/sector。
- `RulerAgent` 显示为皇帝/君主/联军政治层，只能位于总司令上游。
- `MarshalAgent` 显示为总司令/元帅/参谋长，负责战役意图。
- `ZoneCommanderAgent` 显示为军团长/翼指挥官，负责把战役意图转成战术行动。
- 阿登 JSON：迁移为拿战剧本 JSON。
- 默认 UI 文案：中文优先，必要时保留英文开发字段和内部 id。

### 2.3 拿破仑战争核心玩法方向

首发版本要体现拿战特色，但不能一次性把模拟做得过重。优先级如下：

1. **线列步兵与士气**：战斗不只看 strength，至少要有 morale / cohesion 的轻量模型或战斗修正。没有字段也可先通过 supplyState、retreatMode 和日志表现。
2. **炮兵**：有射程、火力准备、Grand Battery 这类战术；炮兵不能像装甲一样推进突破。
3. **骑兵**：机动高、适合追击和冲锋，但对方阵或村庄/森林/高地有明显限制。
4. **方阵/队形**：最小实现可先用 stance / retreatMode / tactic 表达 line / column / square / skirmish，不要第一轮就做复杂 formation state machine。
5. **村庄与据点**：Hougoumont、La Haye Sainte、Plancenoit 这类目标应有防御价值和战役意义。
6. **命令摩擦**：AI 指令可以被拒绝、延迟、降级或只部分执行；必须记录原因。
7. **联军协同**：Prussia 与 Anglo-Allied 可以是不同国家/阵营成员，外交/联军状态可先影响 AI 目标和增援到场，不必首版做完整外交系统。
8. **补给与疲劳**：短战役中表现为 ammunition / fatigue / supply warning，而不是现代工业生产。

### 2.4 不能做的事

- 不要一次性大规模重命名所有类型再凭感觉修编译。先建立兼容层和迁移合同，再分版本替换。
- 不要让任何 Agent 直接修改 `HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater`、`hexToFrontZone` 或经济账本。
- 不要绕过 `WarCommandExecutor`、`CommandValidator`、`RuleEngine`。
- 不要恢复旧 Cabinet / Minister / StrategicDirective 污染。拿战可以有皇帝、君主、元帅、军团长、参谋，但必须是新 schema 和新管线。
- 不要删除 Legacy Agent D；只隔离和保留回归参考。
- 不要把 region 当成战术权威；进军、攻击、占领仍必须落到 hex。
- 不要第一版就做完整欧洲地图、完整 1805-1815 大战略、海军、殖民地、复杂外交、完整内政。
- 不要使用受版权保护的游戏素材、电影剧照、商业将领头像或未经授权地图。可使用自制、生成、公共领域或明确授权素材。
- 不要硬编码 API key、模型路径或云端 LLM 请求。真实 LLM 接入必须单独版本，有 deterministic fallback。
- 未获人工授权，不跑 Xcode / XCTest / 模拟器 / macOS app 启动 / Probe / Smoke / Stage Regression / Full / 性能测试。

---

## 3. 多 Agent 并发工作流

主 Agent 负责总体架构、接口合同、冲突整合和最终验收。子 Agent 只能在明确边界内并发，不得同时改同一 public API 或同一文件。

### 3.1 并发前主 Agent 必做

1. 读完必读文档和本文件。
2. 执行轻量只读审计：

```sh
git branch --show-current
git status --short
rg -n "Germany|Allies|germany|allies|Ardennes|ardennes|Bastogne|Panzer|tank|motorized|Division|Guderian|Montgomery|Faction\\.opponent|germanAI|alliedPlayer" WWIIHexV0 MapEditor README.md md
rg -n "enum Faction|struct Division|enum ComponentType|EconomyResources|ProductionKind|DiplomacyState|ZoneDirective|WarCommandExecutor|RuleEngine" WWIIHexV0
```

3. 写出本轮实际版本目标和非目标。
4. 定义本轮公共接口合同。没有接口合同前，不要让多个子 Agent 同时改 `Core/`、`Commands/`、`Rules/`。
5. 明确 `WWIIHexV0.xcodeproj/project.pbxproj` 只能由主 Agent 或唯一指定的 Project Agent 修改。
6. 如果当前工作树已有不属于本轮的 dirty 文件，先记录并绕开，不要回滚。

### 3.2 推荐子 Agent 分工

每轮最多并发 3-5 个子 Agent。优先减少冲突，不追求数量。

#### Audit / Docs Agent

范围：

- `README.md`
- `update_log.md`
- `md/flow/`
- `md/test/test.md`
- `md/prompt/v3.0-拿战迁移/`

职责：

- 扫描二战硬编码、二元阵营、旧 phase、旧资源、旧单位。
- 维护迁移词汇表、版本审计表、风险清单。
- 更新 flow / flowchart，使它们描述当前真实代码。
- 记录轻量检查和未跑重测试原因。

禁止：

- 不改 Swift 业务逻辑。
- 不把未验证运行时行为写成已验证。

#### Data Agent

范围：

- `WWIIHexV0/Data/*.json`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `WWIIHexV0/Data/DataLoader.swift`

职责：

- 迁移剧本、地图、地形、兵种、指挥官、国家/阵营数据。
- 建立 `waterloo_1815_scenario.json`、`waterloo_1815_regions.json`、`napoleonic_unit_templates.json`、`napoleonic_generals.json`、`napoleonic_terrain_rules.json`。
- 保证 JSON key 稳定，id 使用 ASCII，例如 `power_france`、`region_hougoumont`、`commander_napoleon`。
- 中文只放在 `displayName`、`localizedName`、`biography` 等展示字段。

禁止：

- 不改 `RuleEngine`。
- 不改 UI。
- 不改 project 文件，除非主 Agent 明确指定。

#### Rules Agent

范围：

- `WWIIHexV0/Core/`
- `WWIIHexV0/Commands/`
- `WWIIHexV0/Rules/`

职责：

- 将二元阵营、二战单位、二战补给经济迁移为拿战可用的规则抽象。
- 保持 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一入口。
- 落地士气、疲劳、方阵、炮兵准备、骑兵冲锋、村庄防御时必须先给最小可解释版本。
- 处理 neutral 不再 fallback 到 allies 的历史债。

禁止：

- 不改 SpriteKit/SwiftUI 视觉。
- 不新增真实网络 LLM 调用。
- 不用复杂状态机替代已有命令管线。

#### AI Agent

范围：

- `WWIIHexV0/Agents/`
- `WWIIHexV0/Turn/`
- 只读 `Core/Commands/Rules`

职责：

- 设计并实现皇帝/君主、总司令/元帅、军团长、参谋、外交官等 Agent 分层。
- 所有输出必须是 JSON / Codable directive。
- 上游 Agent 只能调整战略姿态、目标优先级、增援/预备队倾向或 directive envelope，不能直接执行底层命令。
- MockAI 必须有 deterministic fallback，不依赖真实模型。

禁止：

- 不直接改 `GameState`。
- 不绕过 `WarCommandExecutor`。
- 不把真实 API key 或模型路径写进仓库。

#### UI / SpriteKit Agent

范围：

- `WWIIHexV0/UI/`
- `WWIIHexV0/SpriteKit/`
- `Assets.xcassets` 如存在或由主 Agent 创建

职责：

- 迁移为拿破仑战争视觉系统。
- 建立共享设计 token：字体、颜色、材料、间距、圆角、线宽、动效。
- 地图、部队、指挥官、据点、炮兵阵地、战线、命令箭头、战报都要有发布级可读性。

要求：

- 44pt 触控目标。
- 不在 SwiftUI body 内做重复排序/过滤。
- 大列表用 `LazyVStack` / `LazyHStack`。
- 不使用一整屏单色羊皮纸；羊皮纸只能作底，需有墨线、军团色、红蓝铅笔线、金属/皮革色、旗帜色形成层次。
- 图标按钮优先使用系统符号或已有图标系统；陌生图标需要 tooltip/accessibility label。

禁止：

- 不把规则写进 View。
- 不让 SpriteKit 直接改 `GameState`。
- 不使用商业游戏或影视素材。

#### MapEditor Agent

范围：

- `MapEditor/`
- 只读 `Data/` schema

职责：

- 将编辑器术语迁移为地块、战役区、军团防区、部队/指挥官。
- 支持拿战地形：高地、村庄、林地、道路、桥梁、河流、沼泽、农庄、炮兵阵地、补给点。
- 支持初始指挥官、军团归属、增援入口和默认剧本资源切换。

禁止：

- 不破坏主游戏 JSON 加载格式。
- 不单独发明另一套 map schema。

#### Project / Assets Agent

范围：

- `WWIIHexV0.xcodeproj/project.pbxproj`
- `Assets.xcassets`
- 新增资源文件引用

职责：

- 仅在主 Agent 明确指定时修改 project 文件。
- 检查重复 UUID、缺失引用、target membership、bundle resource。
- 接入新 JSON 和资产。

禁止：

- 不同时让其他子 Agent 改 project 文件。
- 不做 Xcode build，除非人工授权。

### 3.3 并发整合规则

子 Agent 完成后，主 Agent 必须检查：

- 是否多个子 Agent 改了同一文件。
- 是否出现 public API 分叉。
- 是否出现 JSON schema 分叉。
- 是否出现 `Faction`、`PowerId`、`CountryId`、`CoalitionId` 多套概念混乱。
- 是否出现 `project.pbxproj` 重复引用、缺失引用或 UUID 冲突。
- 是否出现 README、`md/flow/*`、阶段记录口径不一致。
- 是否有人绕过 `RuleEngine` 修改状态。
- 是否有玩家可见二战文案残留。

没有完成这些检查前，不得声称“多 Agent 工作可合并”。

---

## 4. 版本路线

### v3.0：迁移审计、兼容合同和拿战产品定义

建议分支：`codex/v3.0-napoleonic-audit-contract`

目标：

- 建立拿战迁移的工程合同。
- 找出所有二战硬编码和二元阵营假设。
- 明确首发剧本、最终效果、非目标和并发分工。
- 不急着实现完整拿战玩法。

范围：

- 新增或更新阶段记录：`md/prompt/v3.0-拿战迁移/v3.0_audit_and_contract.md`。
- 新增迁移词汇表和命名约定：
  - `Faction` 当前源码兼容名，目标语义为 power / coalition side。
  - `Division` 当前源码兼容名，目标显示为 corps / brigade / formation。
  - `Theater` 显示为 army wing / corps sector。
  - `Region` 显示为 village / ridge / sector / battlefield region。
  - `FrontZone` 显示为 corps sector / wing sector。
- 抽出 UI 显示名，不要让主要面板继续硬编码 Ardennes、Germany、Allies。
- 记录所有必须在 v3.1-v3.4 处理的硬编码点。

推荐并发：

- Audit / Docs Agent：硬编码扫描、审计表、词汇表。
- UI Agent：只读定位 UI 硬编码，不实现大 UI。
- Rules Agent：只读定位 `Faction.opponent`、二元 switch、二战兵种耦合。
- Data Agent：只读定位默认资源和 JSON schema。

验收：

- 有完整审计清单。
- 有拿战迁移词汇表。
- 有版本拆分和风险清单。
- 没有大范围重命名导致不确定风险。

轻量检查：

- 文档尾随空白检查。
- 冲突标记扫描。
- 不跑 Xcode / XCTest / 模拟器。

### v3.1：国家、联军、多方敌我和通用回合阶段

建议分支：`codex/v3.1-napoleonic-powers-coalitions`

目标：

- 从二元 `germany/allies` 迁移到可支持多国家/多联军的拿战架构。
- 首发至少支持 France、Anglo-Allied、Prussia、neutral。
- 为后续 Austria、Russia、Spain、Ottoman 等留扩展空间。
- 保持旧数据可兼容加载或有明确迁移 fallback。

设计建议：

1. 审计 `Faction` 的所有使用点。
2. 如果短期发布优先，可先扩展 `Faction` enum：
   - `france`
   - `angloAllied`
   - `prussia`
   - `austria`
   - `russia`
   - `spain`
   - `neutral`
3. 如果改为数据驱动 `PowerId`，必须先做兼容桥，不要一轮内强行改完全项目。
4. 移除或弃用 `Faction.opponent`。敌我必须来自 `DiplomacyState` / `CoalitionState` / relation helper。
5. `DiplomacyState` 可迁移为拿战联军关系：
   - allied / coalitionPartner / coBelligerent / neutral / hostile / atWar / truce
6. 中立地块/region 不能 fallback 到某个玩家阵营。
7. `GamePhase` 要从 `germanAI/alliedPlayer` 脱钩。可以保留 raw value 兼容旧存档，但 UI 和新数据必须用通用语义。
8. `AppContainer.shouldRunAI` 必须基于 active power 是否由 AI 控制，而不是 germany/allies 写死。

推荐文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/OccupationRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/FrontLineManager.swift`
- `WWIIHexV0/Rules/StrategicStateSynchronizer.swift`
- `WWIIHexV0/App/AppContainer.swift`

推荐并发：

- Rules Agent：敌我判断、phase、active faction。
- Data Agent：power / coalition profile JSON 草案。
- AI Agent：只读确认 agent config 对多势力的影响。
- Docs / QA Agent：文档和检查。

验收：

- 多国家/多阵营可以被 JSON 表达。
- 敌我判断不再依赖 `.opponent`。
- 中立地块/region 不会被错误算给某个势力。
- `CommandValidator` 对玩家与 AI 仍对称。
- 旧二战数据如果仍保留，必须通过兼容路径，不污染新默认剧本。

轻量检查：

- `jq empty` 检查改动 JSON。
- 对直接改动且可单文件 parse 的 Swift 文件运行 `swiftc -parse`；如果跨文件依赖导致不可行，停止并记录。
- `plutil -lint` 仅在 project 文件变更时运行。

### v3.2：滑铁卢剧本、拿战数据和地图编辑器迁移

建议分支：`codex/v3.2-waterloo-scenario-map`

目标：

- 建立第一张可玩拿战剧本地图。
- 保留 MapEditor 导出链路。
- 默认新局加载滑铁卢剧本，而不是阿登。
- 当前 v3.2-v3.8 起步已建立并切换 `ScenarioCatalog`：`defaultPlayable` 与 `napoleonicTarget` 均指向最小 `waterloo_1815_scenario` / `waterloo_1815_regions` / `napoleonic_terrain_rules` / `napoleonic_unit_templates` / `napoleonic_generals` 数据骨架，`ardennesLegacy` 作为兼容可选剧本保留。`ScenarioCatalogEntry.defaultPlayerFaction` 当前让默认 Waterloo 以 France 作为玩家阵营；Waterloo 数据切片当前已覆盖 La Haye Sainte、Hougoumont、Mont-Saint-Jean、Papelotte、Plancenoit 和 Prussian Arrival Road 目标口径，并新增 q5,r1 Wavre Road 作为普军来援方向的抽象后方入口、补给和 region 数据，La Haye Sainte region 将领种子已对齐 Wellington，La Haye Sainte 初始守军已复用 `strongpoint_guard` 模板，Papelotte 也已有 Anglo-Allied 左翼预备，Mont-Saint-Jean 后方 q2,r1 也已有非 objective 的 Anglo-Allied Rear Road marker，Prussian Approach q4,r0 也已有复用 `prussian_vanguard` 模板和 Blucher 归属的开局 screen，并有非 objective 的 road marker；Prussian Approach region 保留后方轴线名称，q4,r1 key location / region objective 显示名与 scenario objective 统一为 Prussian Arrival Road；这些都未扩成完整 Waterloo / Wavre 地图或完整 Prussian arrival arc。`napoleonic_terrain_rules` 已进入运行时 `TerrainRuleSet`，Waterloo 移动/战斗主路径读取 `GameState.terrainRules`；`BaseTerrain` 保留为 legacy fallback 和未数据化特化规则来源；`napoleonic_generals` 已有 Napoleon / Wellington / Blucher / Bulow 将领目录，Bulow 当前只是目录 / 展示 / 偏好 / 增援归属数据，不代表完整 CorpsCommander Agent。v3.3 已新增 `lineInfantry`、`lightInfantry`、`cavalry`、`guardInfantry`（raw value 为 `guard`）、`engineer`、`supplyTrain` 等 `ComponentType` case，`napoleonic_unit_templates` 已使用这些拿战 raw value，`CombatRules` 已有最小骑兵/炮兵地形修正。v3.4 已起步接入 `RulerAgent -> StrategicPostureEnvelope -> StrategicPostureDecoder -> MarshalAgent`。v3.5 已起步接入拿战后勤展示、战术 morale / fatigue / ammunition 字段与消耗/恢复、broken morale move / attack 拒绝、delayed reinforcement schedule 和 Waterloo 专用最小胜负节奏。v3.6 已起步建立 `NapoleonicDesignTokens`、HUD/单位面板状态可读性基础、map layer picker、interactionLog、CommandResult / event log 术语、Commander Profile、Command Dispatch、目标点/增援入口 marker、WarDirectiveRecord recent replay + tactic marker 和面板内 Formation / Sector / Orders / Corps Order / Coalition 术语收口。v3.7 已起步新局入口、Waterloo 数据切片选择、三槽本地试玩快照、最小 slot label、基础试玩设置持久化、AI Control、短引导、无行动反馈、AI issue 可见诊断、Issue Preview 和 Recent Dispatch Timeline。但完整 ammunition / horses 经济账本、概率式命令摩擦、ChiefOfStaff / CorpsCommander / Diplomat 独立 Agent、真实 LLM、完整拿战 agent personality、完整 terrain DSL、发布级地图美术、发布级命名存档/迁移器、完整错误恢复、可玩地图规模和人工授权运行时验收仍未完成；后续仍需补齐高级士气、队形、完整骑兵冲锋、炮兵准备和完整 Waterloo 战役规模。

默认剧本建议：

```text
id: waterloo_1815
displayName: 滑铁卢 1815
地图范围：滑铁卢核心战场和普军来援方向的抽象区域
主要势力：France、Anglo-Allied、Prussia、Neutral
主目标：Mont-Saint-Jean、La Haye Sainte、Hougoumont、Papelotte、Plancenoit、Brussels Road、French Ridge
首版规模：80-160 个 hex，20-45 个 region，4-8 个 army wing / corps zone
```

拿战地形建议：

- plain -> open ground / 平原
- forest -> woodland / 林地
- hill -> ridge / 高地
- city -> village / village strongpoint
- fortress -> fortified farm / chateau / strongpoint
- road -> road / chaussée
- river edge -> stream / bridge crossing
- 可后置：marsh、orchard、sunkenRoad、field、mud

拿战 JSON 文件建议：

- `WWIIHexV0/Data/waterloo_1815_scenario.json`
- `WWIIHexV0/Data/waterloo_1815_regions.json`
- `WWIIHexV0/Data/napoleonic_unit_templates.json`
- `WWIIHexV0/Data/napoleonic_generals.json`
- `WWIIHexV0/Data/napoleonic_terrain_rules.json`

MapEditor 迁移：

- `province` UI 改为战役区/地段。
- `theater` UI 改为军团防区/翼。
- `unit` UI 改为部队/军团/旅。
- 支持 `assignedGeneralId` 显示为指挥官。
- 支持村庄、高地、桥梁、农庄、炮兵阵地、补给点、增援入口；如果 schema 暂不支持，先记录后置，不要塞到无关字段。

推荐并发：

- Data Agent：新 JSON 和 DataLoader 默认入口。
- MapEditor Agent：编辑器中文术语和导出字段兼容。
- UI Agent：地图层显示名和 accessibility label。
- Docs / QA Agent：同步 flow 和 README。

验收：

- 默认新局加载滑铁卢剧本路径。
- `MapEditorExporter` 可以导出拿战语义地图而不丢 region/theater/unit。
- 默认数据不再出现阿登主剧本名。
- 所有 id 使用 ASCII，展示名可为中文。

轻量检查：

- 对新/改 JSON 跑 `jq empty`。
- 如果改 project，跑 `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`。
- 文档尾随空白和冲突标记扫描。

### v3.3：拿战部队、士气、炮兵、骑兵和队形规则

建议分支：`codex/v3.3-napoleonic-war-rules`

目标：

- 把二战单位和战术转换为拿战战棋规则。
- 保留 hex 战术权威和统一命令管线。
- 首版规则要可解释、可调参，不追求复杂模拟。

单位模型建议：

- 源码可短期保留 `Division`，但 UI 显示为军团、师、旅、炮兵连或 formation。
- `ComponentType` 迁移为：
  - lineInfantry
  - lightInfantry
  - cavalry
  - artillery
  - guardInfantry（raw value 为 guard）
  - engineer
  - supplyTrain
- stats 仍可保留 attack / defense / movement / range / vision。
- 新增 morale / fatigue / cohesion / ammunition 可分阶段；首版若字段风险过大，可先用 strength + supplyState + retreatMode + combat modifiers 兼容。

战术映射建议：

- `standardAttack` -> 线列进攻 / 普通进攻
- `spearhead` -> 纵队突击
- `breakthrough` -> 中央突破
- `pincerMovement` -> 两翼合围
- `fireCoverage` -> 炮兵准备 / Grand Battery
- `feint` -> 佯攻
- `guerrillaWarfare` -> 散兵袭扰 / 侧翼骚扰
- `holdPosition` -> 固守
- `elasticDefense` -> 弹性退守
- `defenseInDepth` -> 纵深防御
- `lastStand` -> 死守据点

新增或迁移规则：

- 炮兵：range > 1，优先打密集步兵和据点；炮兵准备不主动占领。
- 骑兵：高移动和追击优势；攻击方阵、村庄、森林、高地时受惩罚。
- 方阵：可作为 defensive stance 或 `allowRetreat/hold` 之外的新姿态；对骑兵强，对炮兵和步兵火力弱。
- 线列/纵队：线列防御和火力更强，纵队移动/冲击更强但受炮火影响更大。
- 士气：战斗损失、侧翼、包围、补给不足、指挥官技能影响 morale；低士气增加撤退和拒绝命令概率。
- 疲劳：连续行动、冲锋、困难地形增加 fatigue；休整或补给恢复。
- 村庄/据点：强化步兵防御，骑兵惩罚，炮兵可压制。
- 指挥官影响：首版可通过 `GeneralAssignment` 的 skill 调整 tactic 选择或小幅战斗修正，不能直接跳过规则。

推荐文件：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/SupplyState.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`

推荐并发：

- Rules Agent：部队、战斗、士气、疲劳、炮兵、骑兵、队形。
- AI Agent：战术分类器拿战化。
- Data Agent：unit templates。
- UI Agent：只做术语显示，不做大 UI。

验收：

- 玩家和 AI 的移动、攻击、防守、补给仍经 `RuleEngine`。
- 炮兵、骑兵、方阵、村庄防御的日志能被解释。
- 战术名称在 UI 和 `WarDirectiveRecord` 中拿战化。
- 没有 Panzer / tank / motorized 作为玩家可见文本残留。

轻量检查：

- 改 JSON 跑 `jq empty`。
- 少量 Swift 文件可尝试单文件 parse；失败则记录依赖风险。
- 禁止跑全项目 build/test。

### v3.4：皇帝、总司令、元帅、军团长 AI Agent 分层

建议分支：`codex/v3.4-napoleonic-agent-command`

目标：

- 构建真正有拿战味道的 AI Agent 层级。
- Agent 之间可以协作，但最终都必须输出结构化 directive。
- 让 AI 行为可审计、可回放、可调参。

推荐层级：

```text
SovereignAgent / EmperorAgent
  -> 决定国家/联军总战略：速胜、守势、等待援军、分兵、争夺交通线

CommanderInChiefAgent / MarshalAgent
  -> 把总战略变成战役目标：夺取 La Haye Sainte、压制 Hougoumont、等待 Prussia、攻 Plancenoit

ChiefOfStaffAgent
  -> 处理命令优先级、预备队、行军路线、增援时机

CorpsCommanderAgent
  -> 把方面目标变为 ZoneDirective：进攻、防守、炮兵准备、骑兵冲锋、方阵、撤退

DiplomatAgent / CoalitionAgent
  -> 输出联军协同姿态：守到普军抵达、避免孤军突进、协同反攻
```

执行链路要求：

```text
SovereignAgent / EmperorAgent / CoalitionAgent
  -> StrategicPostureEnvelope
  -> CommanderInChiefAgent / MarshalAgent
  -> TheaterDirectiveEnvelope
  -> decoder / validator / compiler
  -> ZoneDirective / Command
  -> WarCommandExecutor / RuleEngine
  -> WarDirectiveRecord / AgentDecisionRecord / RulerDecisionRecord
```

结构化输出要求：

- 所有 Agent 输出必须 Codable。
- 所有外部模型输出必须 fenced JSON 或纯 JSON，由 decoder 校验。
- decoder 必须校验 schemaVersion、turn、issuerId、power/faction、zone、region、tactic。
- decoder 失败时走安全 fallback，不执行半成品。
- Agent prompt 中不能要求模型“直接修改状态”。

Mock / 本地 LLM 要求：

- 首版仍可用模拟 LLM / MockAI。
- 真实本地 LLM 接入必须单独版本，不能把 API key 或模型路径硬编码进仓库。
- 网络或本地模型不可用时，必须有 deterministic fallback。

Agent 个性建议：

- Napoleon：进取、重视中央突破、集中炮兵和近卫预备队，接受较高风险。
- Ney：猛烈进攻、骑兵冲锋倾向强，可能过早投入预备队。
- Wellington：防守、利用反斜面和村庄据点，等待联军时机。
- Blucher：积极会合，偏好强行军和侧翼压迫。
- Grouchy：谨慎追击和迟滞，可用于后续剧本。
- Austrian / Russian commanders：可后置，用于 Austerlitz 或 Leipzig 版本。

推荐并发：

- AI Agent：Agent schema、prompt builder、fallback。
- Rules Agent：新增 directive 的 validator 和 executor 边界。
- UI Agent：AI 决策复盘面板显示层。
- Docs / QA Agent：更新 flowchart。

验收：

- AI 回合能解释“皇帝/总司令想要什么、军团长做了什么”。
- 玩家能在 AI 面板看到 raw JSON、编译后的 directive、命令结果和拒绝原因。
- Agent 决策失败不会破坏回合。
- 仍未绕过 `RuleEngine`。

### v3.5：战役后勤、增援、弹药、疲劳和胜负节奏

建议分支：`codex/v3.5-napoleonic-logistics-reinforcement`

目标：

- 让滑铁卢首发从“单位互打”变成有战役节奏的拿战体验。
- 以轻量方式表现后勤、弹药、疲劳、增援和联军到场。

设计建议：

- 短战役不做现代生产，优先做 reserve / reinforcement schedule。
- `EconomyState` 可保留兼容，但 UI 显示为：
  - Recruits / 兵员
  - Ammunition / 弹药
  - Supplies / 补给
  - Horses / 马匹
  - Command points / 命令点，可后置
- 增援规则：
  - Prussian reinforcement 按 turn 或 objective 条件出现。
  - French reserve / Imperial Guard 作为延迟可投入力量。
  - 增援进入必须走安全 hex 和规则系统。
- 疲劳规则：
  - 连续移动、冲锋、困难地形、低补给增加疲劳。
  - 休整、后方、安全补给减少疲劳。
- 弹药规则：
  - 炮兵准备和远程攻击消耗 ammunition。
  - 弹药不足降低炮兵效果。
- 胜负节奏：
  - 法军需在固定回合前突破或夺取关键目标。
  - 联军可通过坚守、普军会合、消耗法军获得胜利。

推荐文件：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Data/waterloo_1815_*.json`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/HUDView.swift`

推荐并发：

- Rules Agent：后勤、增援、疲劳、胜负。
- Data Agent：增援和目标数据。
- UI Agent：HUD/战报显示。
- Docs / QA Agent：同步文档。

验收：

- 战役关键节奏可被日志解释。
- 增援不直接塞进状态，必须经规则或 bootstrap 明确入口。
- 经济 UI 不再显示 Industry / Panzer 等二战语义。
- 胜负条件与滑铁卢目标一致。

### v3.6：发布级拿战 UI、美术和交互收口

建议分支：`codex/v3.6-napoleonic-ui-polish`

目标：

- 把当前工程从开发调试界面提升到可发布演示界面。
- 不靠说明文字，而靠地图、面板、状态、动效让玩家理解战局。

视觉方向：

- 主地图：19 世纪战役地图/羊皮纸风格，但避免单一米色。用墨线、地形色、红蓝铅笔箭头、军旗色、金属/皮革色形成层次。
- 部队：军牌/棋子能区分步兵、轻步兵、骑兵、炮兵、近卫、补给车，显示 strength、morale、fatigue、行动状态、弹药警告。
- 指挥官：头像、姓名、军衔、国家、风格、技能、忠诚/主动性/谨慎度。
- 据点：村庄、农庄、桥梁、高地、林地、炮兵阵地有不同图标。
- 战线：敌我接触线、计划箭头、炮击目标、骑兵冲锋路径、撤退路线、增援入口清晰可读。
- 战报：展示本回合关键行动、拒绝原因、占领变化、增援、士气崩溃、AI 指令。

主界面布局建议：

```text
顶部：回合、时段、当前阵营、士气/弹药/预备队、胜利状态、结束回合
中央：SpriteKit 战场地图，全屏优先
左侧或底部：选中部队/据点摘要，移动端可折叠
右侧或底部：军团长/命令/战报/AI/后勤 tabs
地图上：选中、可移动、可攻击、炮击范围、冲锋路径、前线、计划线、增援入口
```

SwiftUI 要求：

- 建立 `NapoleonicDesignTokens` 或类似共享设计常量。
- 44pt 最小触控区。
- 使用 `Label` 替代不必要的手写 icon+text。
- 避免 body 内重复排序、过滤、JSON 格式化。
- 大列表用 Lazy 容器。
- 复杂面板拆成独立 View，不要继续膨胀 `RootGameView`。
- 不引入第三方框架，除非人工确认。

SpriteKit 要求：

- 地图必须在桌面和移动端都可缩放、平移、点击。
- 文字不能重叠到不可读。
- 单位和据点图标有稳定尺寸，不因状态变化造成跳动。
- 图层切换清晰：地形、战役区、军团防区、前线、补给、AI 计划。
- 视觉资产必须是自制、生成、公共领域或明确授权。

推荐并发：

- UI Agent：SwiftUI 面板、设计 token。
- SpriteKit Agent：地图绘制、单位、图层、箭头。
- Data / Art Agent：头像占位、旗帜、图标资源和 asset catalog。
- Docs / QA Agent：截图检查清单和未跑重测试风险。

验收：

- 主游戏第一屏不再像调试板。
- 主要 UI 无二战文案残留。
- 移动端和 macOS 布局都有明确约束。
- UI 只读状态，操作仍走 `AppContainer` 和规则系统。

### v3.7：新手引导、存档、设置、macOS/iOS 试玩闭环

建议分支：`codex/v3.7-napoleonic-playtest-loop`

目标：

- 从“规则和 UI 迁移完成”收口到“玩家能理解并完成一局短战役”。
- 补齐新局、继续、设置、重置、战报回放和错误恢复。

范围：

- 新局：选择战役、选择阵营、选择 AI 控制选项。当前已起步实现战役、玩家阵营选择和最小 AI Control；默认 Staff 保持“其他非 neutral 阵营由 simulated staff / MockAI fallback 控制”，Manual 只关闭自动 dispatch；非 observer Manual 下回合推进仍走 End Orders / `Command.endTurn` 推进当前 active faction，observer + Manual 保持只读。
- 继续：当前已起步 `UserDefaults` 三槽 `GameSaveSnapshot` 和独立 `UserDefaults` slot label，Slot 1 兼容旧单槽 key，坏快照、schema 不兼容或未知 scenario 快照会按 slot 显示不可用原因；恢复成功后会按现有 `runAIIfNeeded()` eligibility gate 决定是否 dispatch，Staff 模式（包括 observer + Staff）可续跑 AI，非 observer 下 Manual 需由 End Orders 推进，observer + Manual 保持只读；slot label 只用于本地槽名显示，不写入 snapshot schema。后续若要发布级体验，还需要发布级命名存档、迁移器、失败恢复、文件导出或云同步策略。
- 设置：当前已起步 observer mode、地图图层、日志/AI 回放详细度、AI Pace、AI Control、Reduce Motion、Text Size 和持久化默认值；后续继续更完整的全 app 可读性适配、AI 控制治理和动画治理。
- 引导：当前已起步首次选中 formation、炮兵/远程单位、骑兵和结束命令的 event log `Staff note`；后续补齐更完整的短引导状态、可关闭策略和视觉验收，不做大篇说明页面。
- AI 回放：当前已起步 Staff Summary、Issue Preview 和 Recent Dispatch Timeline，只读聚合执行数、拒绝数、问题数、focus sector / target、最新 tactic 和首要拒绝/诊断原因，并把最近 directive 摘要为 turn / scope / target / tactic / status（executed / rejected / issues）；AI 无有效战场命令时会追加 Staff note / AI note；record-level AI 错误、默认 directive end-turn 失败、被拒绝命令原因和 AI 连跑 guard 暂停会进入事件日志、Issue Preview 或诊断型 `WarDirectiveRecord`；后续继续元帅意图、军团长命令、执行结果、拒绝原因的完整时间线与错误恢复。
- 错误恢复：当前已有坏快照/坏设置/未知 scenario 快照、本方无可行动数量、AI 无有效战场命令、最小 AI issue 和拒绝原因预览的可读反馈；后续 JSON 加载失败、AI 解码失败、命令被拒绝等仍需更完整玩家可读反馈。

推荐并发：

- UI Agent：新局/设置/引导/回放。
- Rules/State Agent：存档 schema 与兼容。
- AI Agent：AI 回放摘要。
- Docs / QA Agent：试玩检查单。

验收：

- 玩家能从新局进入滑铁卢并完成多个回合。
- AI 失败有 fallback，不会卡死。
- 存档/重置不会污染默认资源。
- 引导不遮挡地图核心交互。

### v3.8：发布候选和发布前验收

建议分支：`codex/v3.8-napoleonic-release-candidate`

目标：

- 从“可玩迁移版”收口到“可发布候选版”。
- 补齐版本说明、残留扫描、资源检查、人工授权重验证清单。

发布候选必须具备：

- App 名称、图标、默认剧本、主界面、基础设置。
- 新局 / 继续 / 重置。
- 一个完整可玩滑铁卢剧本。
- AI 回合不会卡死或静默失败。
- 玩家可理解的命令反馈。
- 关键 JSON 数据可解析。
- README 和 flow 文档准确描述当前拿战架构。
- `update_log.md` 记录 v3.0-v3.8 每版完成内容、关键文件、轻量检查和未跑重测试。
- 玩家可见层面无主要二战残留。

发布前需要人工授权的重验证：

- Xcode build。
- iOS Simulator 或真机启动。
- macOS target 启动。
- 至少 10-20 回合观察者模式。
- 基础 UI 点击烟测。
- SpriteKit 截图或人工视觉检查。
- 性能体感检查。

在未获授权前，不得声称“已发布”或“可发布已验证”。只能写“发布候选代码和文档已准备，运行时验证未授权，风险未验证”。

---

## 5. 数据 schema 方向

实际实现可沿用现有结构，但必须在阶段文档写明哪些字段是兼容旧名、哪些字段已经拿战化。

### Power / Coalition

```json
{
  "id": "power_france",
  "displayName": "France",
  "localizedName": "法兰西第一帝国",
  "shortName": "France",
  "coalitionId": "coalition_french_empire",
  "rulerAgentId": "emperor_napoleon",
  "bannerAsset": "banner_france_1815",
  "primaryColor": "#1D4E89",
  "secondaryColor": "#D8B35A",
  "warSupport": 84,
  "commandDoctrine": "central_breakthrough"
}
```

### Commander

```json
{
  "id": "commander_napoleon",
  "name": "Napoleon Bonaparte",
  "localizedName": "拿破仑",
  "rank": "Emperor",
  "power": "france",
  "commandStyle": "aggressive",
  "attributes": {
    "command": 98,
    "initiative": 95,
    "logistics": 82,
    "caution": 35,
    "charisma": 96
  },
  "skills": ["central_position", "grand_battery", "reserve_commitment"],
  "portrait": "portrait_napoleon_generated",
  "biography": "A decisive commander who concentrates force, exploits weak centers, and accepts risk for operational tempo.",
  "preferredZoneIds": ["zone_french_center", "zone_french_reserve"],
  "baseLoyalty": 100,
  "baseSatisfaction": 86
}
```

### Unit Template

```json
{
  "id": "line_infantry_brigade",
  "displayName": "Line Infantry Brigade",
  "localizedName": "线列步兵旅",
  "maxStrength": 10,
  "morale": 7,
  "components": [
    { "type": "lineInfantry", "weight": 0.85 },
    { "type": "lightInfantry", "weight": 0.15 }
  ],
  "allowedFormations": ["line", "column", "square"]
}
```

### Region / Battlefield Sector

```json
{
  "id": "region_hougoumont",
  "name": "Hougoumont",
  "localizedName": "乌古蒙",
  "owner": "angloAllied",
  "controller": "angloAllied",
  "terrain": "fortress",
  "theaterId": "zone_anglo_right",
  "displayHexes": [{ "q": 4, "r": 6 }],
  "representativeHex": { "q": 4, "r": 6 },
  "city": {
    "name": "Hougoumont",
    "victoryPoints": 4,
    "isCapital": false
  },
  "infrastructure": 2,
  "supplyValue": 2,
  "resources": [
    { "type": "supplies", "amount": 2 },
    { "type": "ammunition", "amount": 1 }
  ],
  "coreOf": ["angloAllied"],
  "isPassable": true
}
```

### Theater Directive

```json
{
  "schemaVersion": 6,
  "issuerId": "marshal_napoleon",
  "turn": 6,
  "power": "france",
  "strategicIntent": "Fix the Allied right, prepare a grand battery against the center, then commit cavalry if the line wavers.",
  "directives": [
    {
      "id": "directive_french_center_6",
      "zoneId": "zone_french_center",
      "category": "offense",
      "tactic": "grandBattery",
      "priority": 92,
      "targetTheaterId": "zone_anglo_center",
      "weightedRegions": ["region_la_haye_sainte", "region_mont_saint_jean"],
      "focusRegionId": "region_la_haye_sainte",
      "supportRegionIds": ["region_hougoumont"],
      "reserveBias": 2,
      "intensity": "limitedCounter",
      "maxCommittedUnits": 3,
      "rationale": "Artillery can weaken the center before committing infantry."
    }
  ]
}
```

---

## 6. 文档更新要求

每个版本完成后至少更新：

- `update_log.md`：版本号、完成日期、核心变更、关键文件、轻量检查、未跑重测试、遗留风险。
- `md/flow/flow.md`：当前真实核心逻辑。
- `md/flow/flowchart.md`：关键流程图，尤其是数据加载、动态战区、AI 指令链。
- `README.md`：当前项目定位、玩法、AI 管线、检查规则。
- 当前阶段提示词或实现记录：放在 `md/prompt/v3.0-拿战迁移/`。

若源码行为、检查规则、核心流程、分支策略或版本状态改变，相关文档必须同步更新。

---

## 7. 轻量检查和禁止项

执行前必须读 `md/test/test.md`。当前默认不做 Xcode / XCTest / 模拟器 / 性能类测试。

允许的轻量检查：

```sh
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/v3.0-拿战迁移
rg -n "<<<<<<<|=======|>>>>>>>" AGENTS.md README.md update_log.md md/flow WWIIHexV0 MapEditor md/prompt/v3.0-拿战迁移
rg -n "Germany|Allies|Ardennes|Bastogne|Panzer|tank|motorized|germanAI|alliedPlayer" WWIIHexV0 MapEditor README.md md/flow md/prompt/v3.0-拿战迁移
jq empty WWIIHexV0/Data/waterloo_1815_scenario.json
jq empty WWIIHexV0/Data/waterloo_1815_regions.json
jq empty WWIIHexV0/Data/napoleonic_unit_templates.json
jq empty WWIIHexV0/Data/napoleonic_generals.json
jq empty WWIIHexV0/Data/napoleonic_terrain_rules.json
plutil -lint WWIIHexV0.xcodeproj/project.pbxproj
```

Swift 单文件 parse 只在少量纯 Swift 改动且不会触发项目构建时使用：

```sh
swiftc -parse path/to/ChangedFile.swift
```

禁止主动执行：

- `xcodebuild test`
- `xcodebuild build`
- `xcodebuild build-for-testing`
- `xcrun simctl ...`
- Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full
- XCTest、UI test、性能测试、快照测试
- 启动 iOS Simulator
- 启动 app 做人工烟测
- 全项目 Swift 编译、全量 lint、全量格式化

如果某问题必须依赖重测试才能确认，只记录风险，不擅自运行。

---

## 8. 发布级验收清单

发布候选前必须逐项确认：

- 默认场景是拿战剧本，不是阿登。
- 主 UI 第一屏是可操作战场，不是说明页。
- 玩家可选择阵营或至少明确扮演方。
- AI 能通过结构化 directive 行动，失败有 fallback。
- 玩家和 AI 都经 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine`。
- `HexTile.controller` 和 `Division.coord` 仍是战术权威。
- `regionToTheater` 仍是初始/基础映射，不表示运行时推进。
- `hexToTheater` 和 `hexToFrontZone` 仍是动态权威。
- 炮兵、骑兵、方阵/防守姿态、村庄据点、士气/疲劳至少有一个可解释的首版实现。
- AI 面板能展示 raw JSON、编译后 directive、命令结果、拒绝原因。
- 战报能解释关键战斗、占领、撤退、增援、命令失败。
- UI 没有主要二战文案残留。
- 新 JSON 都通过 `jq empty`。
- project 文件如改动通过 `plutil -lint`。
- 文档准确描述当前真实状态。
- 未跑重测试的范围和风险写清楚。

---

## 9. 风险清单

实现前必须主动关注这些风险：

- 当前工作树很脏，且历史记录显示分支多次漂移；合并前必须重新确认分支、基点、dirty 文件和冲突。
- `Faction` 二元模型是最大风险点；如果一次性强改，容易连锁破坏 AI、补给、前线、部署、UI 和数据加载。
- `Faction.opponent` 残留会直接破坏多方联军和中立逻辑。
- `GamePhase.germanAI/alliedPlayer` 残留会让新阵营控制权表现错误。
- `RegionDataSet.toRegions()` 中 owner/controller nil fallback 到 `.allies` 是历史债，拿战迁移时必须修或隔离。
- `DataLoader` 默认入口已切 Waterloo，但 fallback components、legacy scenario、历史 agent fallback 和部分 validation/文档仍保留阿登 / Guderian 兼容债。
- `project.pbxproj` 已多次被多分支修改，只能由一个 Agent 处理。
- UI/SpriteKit 改动需要视觉验证，但当前规范禁止主动启动 app；必须记录未验证风险。
- 真实 LLM 接入、模型输出质量、长回合稳定性必须单独版本验证。
- 历史准确性和玩法可读性要平衡：首版可抽象，但不能把拿战变成换皮二战。

---

## 10. 给后续 Agent 的交付格式

每个实现 Agent 最终必须简洁说明：

1. 完成了什么。
2. 改了哪些关键文件。
3. 跑了哪些轻量检查，具体结果是什么。
4. 哪些重测试没跑，原因是什么。
5. 还剩什么风险或下一步。

如果进行了 git stage / commit / push，只能在实际成功后按 Codex 桌面规范输出对应 directive。
