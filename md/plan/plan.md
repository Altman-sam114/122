# 拿破仑战争迁移项目 md 大纲

本文是 `md/` 目录下的项目规划索引。它只描述当前从 `WWIIHexV0` 迁移到拿破仑战争题材的文档和版本路线，不代表源码已经完成拿战迁移。

依据文件：

- `AGENTS.md`
- `update_log.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`

## 1. 当前工程基线

当前代码仍是 Swift + SwiftUI + SpriteKit 的 `WWIIHexV0` 二战 hex 战棋工程。现有成熟骨架必须保留并迁移：

- Hex 是战术权威：`HexTile.controller`、`Division.coord` 决定真实占领、移动、攻击和单位位置。
- Region 是战略聚合层：资源、补给、胜利点和控制比例从 hex 聚合，不替代 hex。
- `regionToTheater` 只作初始/基础战区映射；`hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威；前线由双方动态战区的真实 hex 邻接派生。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- Legacy Agent D 保留作回归参考，默认战争 AI 主路径不得退回旧管线。

当前代码仍有大量二战语义：Germany / Allies、Ardennes、Bastogne、Panzer、tank、motorized、Guderian、Montgomery、旧 `germanAI` / `alliedPlayer` raw value 等。v3.1 已建立 France / Anglo-Allied / Prussia / Austria / Russia / Spain / Neutral 兼容 case、`DiplomacyState` 敌我 helper、通用 command phase helper 和 neutral fallback；v3.8 已把默认 playable 入口切到 Waterloo 数据切片；后续仍要继续清理 legacy / fallback / 玩家可见残留、单位规则和发布级体验。

## 2. 产品目标

目标产品暂定为 `拿破仑战棋 Agent`，英文工作名可用 `Napoleon Command Agent` 或 `Napoleonic Command Hex`。

首发体验目标：

- 打开应用直接进入可玩的拿破仑战争战役，不做营销落地页。
- 首发剧本优先 `滑铁卢 1815`，备选 `奥斯特里茨 1805`。
- 玩家选择一个阵营或国家，其他势力由 AI Agent 驱动。
- 地图以 hex 为战术权威，以村庄、高地、道路、桥梁、战役区块作为 region 聚合层，以军团/翼/军区作为 AI 调度层。
- 玩家既能微操具体部队，也能通过元帅/军团长面板下达宏观命令。
- AI 只能输出结构化 directive，不得直接改 `GameState`。
- UI 形成 19 世纪军事地图质感，第一屏以地图、部队、命令、回合和战报为核心。

首发剧本建议规格：

```text
scenarioId: waterloo_1815
displayName: 滑铁卢 1815
主要势力：France、Anglo-Allied、Prussia、Neutral
地图范围：Mont-Saint-Jean、La Haye Sainte、Hougoumont、Papelotte、Plancenoit、Wavre/普军来援方向
规模：约 80-160 个 hex，20-45 个 region，4-8 个 army wing / corps zone
回合：12-24 回合，代表战役日内关键时段
```

## 3. 迁移边界

必须逐步替换或抽象的二战绑定点：

- `Faction.germany/allies` -> France、Anglo-Allied、Prussia、Austria、Russia、Spain、Neutral 等多势力/联军模型。
- `Faction.opponent` -> 由 `DiplomacyState` / `CoalitionState` / relation helper 判断敌我。
- `GamePhase.germanAI/alliedPlayer` -> 通用 playerCommand / aiCommand / resolution 等阶段语义。
- `Division` 玩家可见语义 -> 军团、师、旅、formation；源码兼容名可分阶段保留。
- `ComponentType.tank/motorizedInfantry` -> lineInfantry、lightInfantry、cavalry、artillery、guardInfantry（raw value 为 `guard`）、engineer、supplyTrain。
- `EconomyResources.manpower/industry/supplies` -> recruits、treasury、supplies、ammunition、forage、horses 等展示语义。
- `Theater` / `FrontZone` 展示 -> Army / Wing / Corps Sector / 军团防区。
- 默认 playable JSON 已切到 Waterloo 1815 数据切片；后续补完整 Waterloo 战役规模，并继续隔离阿登 legacy 资源。

禁止项：

- 不让任何 Agent 直接修改 `HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater`、`hexToFrontZone` 或经济账本。
- 不绕过 `WarCommandExecutor`、`CommandValidator`、`RuleEngine`。
- 不恢复旧 Cabinet / Minister / StrategicDirective 污染。
- 不删除 Legacy Agent D。
- 不把 region 当成战术权威。
- 不第一版就做完整欧洲大战略、复杂外交、海军、殖民地、完整内政或真实网络 LLM。
- 未获人工授权，不跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试。

## 4. v3.0-v3.8 版本路线

| 版本 | 主题 | 主要交付 | 文档产物 |
|---|---|---|---|
| v3.0 | 迁移审计、兼容合同和拿战产品定义 | 硬编码扫描、二元阵营风险表、迁移词汇表、首发剧本边界、并发分工 | `md/prompt/v3.0-拿战迁移/v3.0_audit_and_contract.md` |
| v3.1 | 国家、联军、多方敌我和通用回合阶段 | France / Anglo-Allied / Prussia / Austria / Russia / Spain / Neutral 兼容层，`DiplomacyState` 敌我 helper，通用 phase 与部署/战区敌我迁移 | `md/prompt/v3.0-拿战迁移/v3.1_powers_coalitions_foundation.md` |
| v3.2 | 滑铁卢剧本、拿战数据和地图编辑器迁移 | `ScenarioCatalog`、最小 `waterloo_1815_*` JSON slice、`napoleonic_terrain_rules` 数据入口、`napoleonic_unit_templates` 兼容模板、`napoleonic_generals` 将领目录、MapEditor 术语迁移 | `md/prompt/v3.0-拿战迁移/v3.2_waterloo_data_entry.md` 起步 |
| v3.3 | 拿战部队、士气、炮兵、骑兵和队形规则 | 已起步：新增拿战 `ComponentType` case 并迁移 `napoleonic_unit_templates`；`CombatRules` 已有最小骑兵/炮兵地形修正；`Division` 已有最小 morale 字段、低士气攻防惩罚和撤退触发；后续继续 line / column / square、完整炮兵准备、显式骑兵冲锋、村庄防御和高级士气模型 | `md/prompt/v3.0-拿战迁移/v3.3_component_types_foundation.md` 起步 |
| v3.4 | 皇帝、总司令、元帅、军团长 AI Agent 分层 | 已起步：`RulerAgent -> StrategicPostureEnvelope -> MarshalAgent` 战略姿态 schema、decoder、fallback 和审计记录；后续继续 ChiefOfStaff / CorpsCommander / Diplomat 独立 Agent | `md/prompt/v3.0-拿战迁移/v3.4_agent_hierarchy_foundation.md` 起步 |
| v3.5 | 战役后勤、增援、弹药、疲劳和胜负节奏 | 已起步：拿战 faction 下的经济 UI / 日志显示为后勤与预备队术语，完成排产生成拿战 component formation；Waterloo 数据已有 French Imperial Guard / Prussian IV Corps delayed reinforcement schedule，规则层按安全入口部署；`Division` 已有最小 morale / fatigue / ammunition 字段，移动、攻击、反击、HOLD、resupply/rest、低士气撤退、broken morale 拒绝 move/attack、低弹药火力惩罚和 UI/AI 警告已接入；VictoryRules 已有 Waterloo 最小胜负节奏；后续继续完整 ammunition / horses 账本、高级命令摩擦、高级队形和完整战役节奏 | `md/prompt/v3.0-拿战迁移/v3.5_logistics_reinforcement_foundation.md` 起步 |
| v3.6 | 发布级拿战 UI、美术和交互收口 | 已起步：`NapoleonicDesignTokens`、HUD/单位详情/tooltip/预备队面板状态可读性，HUD/RootGameView/BoardScene 场景标题去硬编码，拿战 map layer picker / compact tabs / dispatch 分类 / interactionLog / CommandResult / 规则事件日志 / tooltip VoiceOver / UnitNode formation symbols / reinforcement entry marker / objective marker / WarDirectiveRecord recent replay + tactic marker / AI 空状态文案迁移，单位/地域/命令/将军/指挥官档案/外交/AI 复盘面板内 Formation / Sector / Orders / Corps Order / Order executed/rejected / Hold Line / Withdrawal / Commander Profile / Coalition / Command Dispatch 术语收口；后续继续 19 世纪战役地图视觉、军团色、指挥官面板、完整战报、完整炮击/冲锋路径、可读图层 | `md/prompt/v3.0-拿战迁移/v3.6_napoleonic_ui_polish_foundation.md` 起步 |
| v3.7 | 新手引导、存档、设置、试玩闭环 | 已起步：HUD 新局按钮打开 `NewGameSetupView`，可选择阿登 legacy 或 Waterloo 1815 数据切片、按 scenario JSON 选择玩家阵营，并通过 `AppContainer.startNewGame` 重载场景/将领目录、清空本地选择与回放状态；`Opening Turn` toggle 可决定玩家所选 faction 是否先行动，HUD phase 会显示 Your Orders / Staff Dispatch / Manual Dispatch / Manual Observation；拿战 JSON 已纳入 iOS/macOS bundle resources；`GameSaveSnapshot` 已提供 `GameSaveSlot` 三个 `UserDefaults` 本地试玩槽保存/继续快照，Slot 1 兼容读取旧单槽 key，最小 slot label 独立存入 `UserDefaults`，坏快照、schema 不兼容或未知 scenario 快照会按 slot 显示原因，Continue 区块可 Clear Saved，继续成功后复用现有 AI eligibility gate，sheet 内 Status 会在 Start / Continue 成功后关闭 sheet，失败时显示提示，Save Current / Rename Slot / Clear Saved 结果会留在 sheet 内显示；基础设置已暴露 observer mode、map layer、`ReplayDetailLevel` 回放详细度、AI Pace、AI Control、Guide Notes、Reduce Motion 和 Text Size，并通过 `PlaytestSessionSettings` 持久化，坏设置会重置为标准设置并提示，`PlaytestAIControlMode` 默认 Staff 保持其它非 neutral faction 自动 simulated staff，Manual 只关闭自动 dispatch；非 observer Manual 通过 End Orders / `Command.endTurn` 手动推进当前 active faction，observer + Manual 保持只读，`PlaytestTextSize` 会调整日志/AI 复盘的动态字体层级和行距，Reduce Motion 开启时跳过本地 simulated staff pacing delay；`PlaytestGuideCue` 已提供首次 formation / artillery / cavalry / end orders 的可关闭非阻塞 staff note；命令面板已显示本方剩余可行动 formation / unit 数量、Manual 非玩家手动推进提示和 observer Staff dispatch 提示，AI 无有效战场命令会追加 Staff note / AI note；record-level AI 错误、directive end-turn 失败和 AI 连跑 guard 暂停会进入事件日志或诊断型 `WarDirectiveRecord`；`AgentPanelView` 已有只读 Staff Summary、Issue Preview 和 Recent Dispatch Timeline，聚合执行/拒绝/问题/focus/latest tactic/首要拒绝或诊断原因，并把最近 directive 摘要成 turn/scope/target/tactic/status/issue，Concise 隐藏逐条明细但保留短摘要与时间线。后续继续发布级命名存档/迁移器、完整设置治理、完整引导、完整动画回放和完整运行时错误恢复 | `md/prompt/v3.0-拿战迁移/v3.7_napoleonic_playtest_loop_foundation.md` 起步 |
| v3.8 | 发布候选和发布前验收 | 已起步：默认 playable 场景切到 Waterloo 1815 数据切片，`ScenarioCatalogEntry` 记录 `defaultPlayerFaction`，`AppContainer.bootstrap()` 按默认场景读取 France 玩家阵营和 Waterloo 将领目录；阿登 legacy 保留为可选剧本。后续继续残留扫描、资源授权检查、发布说明、人工授权重验证清单和完整滑铁卢数据规模 | `md/prompt/v3.0-拿战迁移/v3.8_napoleonic_release_candidate_foundation.md` 起步 |

v3.0 是第一步。它只做审计、合同和大纲，不急着实现完整拿战玩法。当前 v3.0-v3.8 起步记录已落地到 `md/prompt/v3.0-拿战迁移/`；默认启动已切到 Waterloo 数据切片，但阿登 legacy 仍可从新局入口选择；已有 3 个本地试玩保存/继续 slot、最小 slot label、坏快照/未知 scenario 快照 Clear Saved、基础试玩设置持久化、坏设置标准重置提示、最小 AI Control、Text Size、Reduce Motion 本地 pacing 起步、可关闭的非阻塞短引导和最小 AI issue 可见诊断和拒绝原因预览。完整拿战规则、完整滑铁卢规模、发布级 UI、发布级命名存档/迁移器、完整设置和运行时视觉验收仍未完成。

## 5. 并发工作流大纲

每轮最多并发 3-5 个子 Agent，主 Agent 必须先定义文件边界和公共接口合同。

| 分工 | 默认范围 | 职责 | 禁止 |
|---|---|---|---|
| Audit / Docs Agent | `README.md`、`update_log.md`、`md/flow/`、`md/test/test.md`、`md/prompt/v3.0-拿战迁移/` | 审计硬编码、维护迁移词汇表、风险清单和文档口径 | 不改 Swift 业务逻辑 |
| Data Agent | `WWIIHexV0/Data/`、DataLoader / scenario schema | 新剧本、新地形、新单位、新指挥官、JSON 稳定 key | 不改 RuleEngine / UI / project 文件 |
| Rules Agent | `Core/`、`Commands/`、`Rules/` | 多势力、敌我关系、拿战战斗规则、validator / executor 边界 | 不改 SpriteKit/SwiftUI 视觉 |
| AI Agent | `Agents/`、`Turn/`，只读 Core/Commands/Rules | 拿战 Agent 分层、schema、prompt、deterministic fallback | 不直接改 `GameState` |
| UI / SpriteKit Agent | `UI/`、`SpriteKit/`、资产 | 拿战视觉、地图图层、命令面板、战报、指挥官展示 | 不把规则写进 View |
| MapEditor Agent | `MapEditor/`，只读 Data schema | 术语、地形、初始指挥官、增援入口、导出兼容 | 不发明另一套 map schema |
| Project / Assets Agent | `project.pbxproj`、asset catalog | 文件引用、bundle resource、target membership | 只能唯一指定修改 project 文件 |

整合前必须检查同一文件冲突、public API 分叉、JSON schema 分叉、project UUID 冲突、文档口径冲突，以及是否绕过统一规则管线。

## 6. md 目录大纲

```text
md/
├── plan/
│   └── plan.md
│       当前文件：拿战迁移项目大纲与版本路线索引。
├── flow/
│   ├── flow.md
│   ├── flowchart.md
│   └── *.mermaid
│       当前真实核心逻辑和流程图。只有源码行为改变或 Agent C 验收沉淀时更新。
├── test/
│   └── test.md
│       轻量检查、禁止重测试、云端结果包验收规范。
└── prompt/
    ├── README.md
    │   Agent A/B/C 提示词与验收工作流说明。
    ├── v3.0-拿战迁移/
    │   ├── codex-v3.0-拿战aiagent迁移总提示词.md
    │   ├── v3.0_audit_and_contract.md
    │   ├── v3.1_powers_coalitions_foundation.md
    │   └── v3.x 阶段审计/实现/验收记录
    ├── v2.0-三国迁移/
    ├── v3.0-隋唐迁移/
    ├── v4.0-明末迁移/
    └── old/ 与 v0.x（已完成）/
        历史提示词、回退记录和归档资料。
```

文档职责：

- `AGENTS.md`：入口规则、基本架构边界和 A/B/C 工作流。
- `update_log.md`：正式版本历史与历史维护记录。
- `md/flow/*`：当前真实核心逻辑，不写未落地功能。
- `md/test/test.md`：允许的轻量检查与禁止执行项。
- `md/prompt/v3.0-拿战迁移/`：拿战迁移总提示词和各阶段记录。

## 7. 轻量检查大纲

每轮实现或验收前必须读 `md/test/test.md`。当前默认只做轻量检查，不做本机重测试。

文档类默认检查：

```sh
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/v3.0-拿战迁移 md/plan/plan.md
git diff --check
```

冲突标记扫描按 `md/test/test.md` 的当前模板执行；如文档包含命令示例导致误报，应使用行首锚定复核真实冲突标记。如果改 JSON，只对改动 JSON 跑 `jq empty`。如果改 project 文件，跑 `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`。未获人工授权，不跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full。

## 8. 下一步

下一轮建议继续 v3.6 / v3.7 收口：

1. 扩展 `RootGameView` 与 Info tabs 的拿战主界面布局，但保持 UI 只读状态和命令入口不变。
2. 继续清理玩家可见的二战残留文案，优先处理 HUD 标题、事件日志、AI 复盘和默认场景展示名。
3. 在 SpriteKit 层继续设计可读的前线、目标点、增援入口、计划线、炮击目标和骑兵路径视觉；若需要新增资源或改 project 文件，先单独记录边界。
4. 继续扩展 `waterloo_1815_*` 到可玩规模，并让 UI 能表达战役目标、预备队和普军来援。
5. 继续 v3.7 的发布级命名存档/迁移器、完整设置治理、AI 回放、完整错误恢复和完整引导；新局选择、Opening Turn、3 个 `UserDefaults` 本地试玩快照 slot、Slot 1 旧 key 兼容读取、最小 slot label、坏快照/未知 scenario 快照提示 / Clear Saved、坏设置标准重置、基础设置持久化、AI Pace、AI Control、Reduce Motion 本地 pacing、Text Size、基础回放详细度、Issue Preview、Recent Dispatch Timeline、可关闭首次 staff note、玩家剩余行动提示、AI 无有效命令 note、最小 AI issue 可见诊断和拒绝原因预览已起步，不提前引入大规模存档 schema 改造。
6. 只做 `md/test/test.md` 允许的轻量检查，并记录未跑重测试和未做视觉验收的风险。
