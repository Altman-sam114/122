# WWIIHexV0 v 版本更新记录

本文档记录项目从 v0 到 v0.37 的正式 v 版本演进。资料来源包括 `git log`、`README.md`、阶段文档与测试/验收报告。

维护规则：

- 每完成一个新的 v 版本任务后，必须在本文档追加对应版本记录。
- 记录应包含：版本号、完成日期、核心变更、关键文件/系统、验证结果、遗留事项。
- 若本轮只是文档整理、目录迁移、回滚或打捞，不应伪装成新 v 版本；可写入“历史维护记录”。
- 若 README、测试规范或源码语义发生变化，应同步更新本日志。

## v0 - 六角格测试板

完成日期：2026-06-14 至 2026-06-15

核心更新：

- 建立 iOS 二战回合制战棋原型，技术栈为 Swift + SwiftUI + SpriteKit。
- 创建阿登测试战场，使用 11x9 左右的 axial hex 地图。
- 落地地形、移动、战斗、占领、补给、包围、胜利条件、回合流程。
- 建立德军 MockAI 将领 `guderian`，按局势摘要生成结构化命令，再经规则系统校验执行。
- 建立 SwiftUI HUD、命令面板、事件日志、单位详情和 SpriteKit 六角格渲染。

关键系统：

- `Core/HexCoord.swift`
- `Core/MapState.swift`
- `Core/Division.swift`
- `Rules/RuleEngine.swift`
- `Rules/MovementRules.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/VictoryRules.swift`
- `SpriteKit/BoardScene.swift`
- `UI/RootGameView.swift`

备注：

- v0 的核心边界是“可玩测试板”，不做空军、海军、经济、生产、外交、多级指挥链和真实 LLM。
- 后续所有版本都必须保留 hex 作为战术层权威。

## v0.1 - strength、撤退与补员

完成日期：2026-06-15 前后

核心更新：

- `Division` 战斗模型升级为 `strength/maxStrength`，保留 `hp/maxHP` 兼容。
- 战斗伤害从 HP 语义转向兵力语义，后续明确不恢复 organization。
- 引入撤退状态与 `RetreatMode`：`retreatable` 可自动撤退，`hold` 获得防御加成。
- 撤退失败会施加额外惩罚；无补给、包围会影响战斗与回合损耗。
- `resupply/rest` 能恢复兵力。
- UI 和日志补充 Strength、Retreating、combat/retreat/reinforce/encircle/supply 分类。

关键系统：

- `Core/Division.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/RuleEngine.swift`
- `UI/UnitInspectorView.swift`
- `UI/HUDView.swift`

备注：

- v0.1 最终模型只看兵力，不引入 organization。
- `HOLD` 防御约 +20%，`RETREATABLE` 在单次损失比例达到阈值时自动撤退。

## Agent D - AI/Agent 决策管线

完成日期：2026-06-15

核心更新：

- 打捞并恢复早期 Agent D 管线，修复此前异常删除。
- 建立 `DecisionProvider` 协议，为 MockAI 与未来本地 LLM 共用。
- 建立 `AgentContext` / `AgentContextBuilder`，只传 Codable 摘要，不暴露 UI/SpriteKit 对象。
- 建立 `AgentDecisionEnvelope` / `AgentOrder` JSON schema。
- 建立 parser、command mapper、decision record 与 AI 决策展示面板。
- `TurnManager` 负责德军 AI 回合编排，`AppContainer.runAIIfNeeded()` 接入启动流程。

关键系统：

- `Agents/DecisionProvider.swift`
- `Agents/AgentContexts.swift`
- `Agents/AgentDecision.swift`
- `Agents/AgentDecisionParser.swift`
- `Agents/AgentCommandMapper.swift`
- `Agents/MockAIClient.swift`
- `Agents/LocalLLMDecisionProvider.swift`
- `Turn/TurnManager.swift`
- `UI/AgentPanelView.swift`
- `Tests/AgentPipelineTests.swift`

备注：

- Agent D 是重要历史管线，但 v0.37 后默认战争 AI 主路径已改为 ZoneDirective。
- 后续不得删除 Legacy Agent D；只能隔离、退役或作为回归参考。

## v0.2 - Region 战略层叠加

完成日期：2026-06-15 至 2026-06-16

核心更新：

- 明确废弃旧版“用 province 替换 hex”的方案，改为 Region 战略层叠加。
- `MapState` 同时持有 hex 与 region：`regions`、`hexToRegion`、`regionEdges`。
- 新增 `RegionId`、`RegionNode`、`RegionEdge`、`RegionGraph` 与校验错误类型。
- 建立阿登 v0.2 省份数据：17 省、41 边、99 hex 全覆盖、零重叠。
- `DataLoader` 加载 `ardennes_v02_regions.json` 并反向填充 `HexTile.regionId`。
- 新增 Region 规则层：移动、战斗、占领、补给、视野、胜利、pathfinder、rule system。
- 新增 `RegionCommand`、`CommandIntentAdapter`、AgentOrder schema v2，支持 region 命令与 hex 命令互转。
- UI 增加 `MapDisplayAdapter`、Region overlay 与 `RegionInspectorView`，hex 仍为唯一渲染对象。

关键系统：

- `Core/Region.swift`
- `Core/MapState.swift`
- `Data/RegionDataSet.swift`
- `Data/ardennes_v02_regions.json`
- `Rules/RegionRuleSystem.swift`
- `Rules/RegionMovementRules.swift`
- `Rules/RegionCombatRules.swift`
- `Rules/RegionOccupationRules.swift`
- `Rules/RegionSupplyRules.swift`
- `Rules/RegionVisibilityRules.swift`
- `Rules/RegionVictoryRules.swift`
- `Commands/RegionCommand.swift`
- `Commands/CommandIntentAdapter.swift`
- `SpriteKit/MapDisplayAdapter.swift`
- `UI/RegionInspectorView.swift`

验证记录：

- v0.2 Agent 6 验收：132 tests, 0 failures。
- 关键覆盖：RegionGraph、ArdennesV02Data、Region rules、Agent region command、MapDisplayAdapter、Board interaction、RuleEngineCore。

备注：

- v0.2 达成 Hex x Region 双轨架构稳定状态。
- 技术债：中立省 owner/controller 为 null 时仍回退到 `.allies`，因为 `Faction` 暂无 neutral case。

## v0.21 - 界面优化与重置流程

完成日期：2026-06-16

核心更新：

- 新增 `InfoPanelToggle`，信息面板默认收起，通过 `[ INFO ]` 展开。
- 新增 `UnitTooltipView`，右下角固定展示选中单位摘要。
- 新增 `NewGameButton` 与 `AppContainer.resetGame()`，支持重载初始地图/单位/Region 并清空选择与日志。
- `RootGameView` 在常规、竖屏、横屏布局中接入 Info toggle 与单位 tooltip。
- 任务 6 zoom 按设计跳过，保留固定放大 hex 与 camera drag。

关键系统：

- `UI/InfoPanelToggle.swift`
- `UI/UnitTooltipView.swift`
- `UI/NewGameButton.swift`
- `UI/RootGameView.swift`
- `UI/HUDView.swift`
- `App/AppContainer.swift`

验证记录：

- 135 tests, 0 failures。
- `swiftc -parse`、`plutil -lint`、`git diff --check` 通过。
- 模拟器烟测通过，截图记录为 `/tmp/wwiihex_v021_smoke2.png`。

## v0.31 - Theater 战区系统

完成日期：2026-06-17

核心更新：

- 新增战区数据结构：`TheaterId`、`TheaterNode`、`TheaterState`、支援请求和 AI 摘要。
- 新增 `TheaterSystem`，从 v0.2 Region 生成四个固定战区。
- 建立 `hex -> region -> theater` 映射与控制比例/胜利点聚合。
- 引入 70% 控制阈值，用于战区扩张正式化、退役和单位池重分配。
- 在 `GameState` 中加入 `theaterState`，兼容旧存档解码。
- `DataLoader` 在加载 Region 后自动生成 v0.31 四战区。

关键系统：

- `Core/Theater.swift`
- `Rules/TheaterSystem.swift`
- `Core/GameState.swift`
- `Data/DataLoader.swift`
- `Tests/TheaterSystemTests.swift`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。
- 全量测试：146 tests, 0 failures。

备注：

- v0.31 不做 FrontLine、自动布防、攻势规划、LLM 决策、UI 重构或战斗/hex 规则改动。

## v0.32 - FrontLine 前线层

完成日期：2026-06-17

核心更新：

- 新增前线模型：`FrontLine`、`FrontSegment`、`RegionFrontState`、`FrontLineState`。
- 新增 `FrontLineManager`，支持 turn rebuild 与 event-driven dirty update。
- 建立 `enemyNeighborCache`，简化包围识别。
- 单战区面对多敌战区时，仍暴露一条主 `FrontLine` 给 AI/UI 聚合使用。
- `GameState` 增加 `frontLineState` 并兼容旧存档 empty。
- `DataLoader` 初始加载 Region/Theater 后生成 FrontLine。

关键系统：

- `Core/FrontLine.swift`
- `Core/FrontSegment.swift`
- `Core/RegionFrontState.swift`
- `Core/FrontLineState.swift`
- `Rules/FrontLineManager.swift`
- `Tests/FrontLineCreationTests.swift`
- `Tests/FrontLineUpdateTests.swift`
- `Tests/MultiEnemyFrontTests.swift`

验证记录：

- v0.32 专项测试：9 tests, 0 failures。
- 全量测试：155 tests, 0 failures。
- `project.pbxproj` lint 通过。

备注：

- v0.32 未改 UI、SpriteKit、AI agent、LLM、命令系统、RegionGraph 或 TheaterSystem 结构。

## v0.33 - WarDeployment 部署层

完成日期：2026-06-17

核心更新：

- 新增 `FrontZone`、`FrontZoneSegment`、`WarDeploymentState` 与 `WarDeploymentManager`。
- 从 v0.31 Theater 生成 v0.33 `FrontZone`。
- 建立 region 粒度前线 segment 与 `FRONT / DEPTH / GARRISON` 三层单位池。
- 支持推进、崩溃、战区消亡与事件更新。
- dirty region + neighbor zone 局部重建，避免每次全图前线扫描。
- 新增前线、segment、部署、战争演化和局部更新性能测试。

关键系统：

- `Core/FrontZone.swift`
- `Core/FrontZoneSegment.swift`
- `Core/WarDeploymentState.swift`
- `Core/WarDeploymentTypes.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/WarDeploymentFrontLineTests.swift`
- `Tests/WarDeploymentSegmentTests.swift`
- `Tests/WarDeploymentDeploymentTests.swift`
- `Tests/WarEvolutionTests.swift`

验证记录：

- v0.33 选定测试：13 tests, 0 failures。
- 全量测试：168 tests, 0 failures。
- `plutil -lint` 通过。

备注：

- v0.33 未改 UI/SpriteKit、AI/LLM/命令系统，也未引入复杂路径搜索。

## v0.331 - v0.31 至 v0.33 总测试

完成日期：2026-06-18

核心更新：

- 对 v0.31 战区、v0.32 前线、v0.33 部署进行阶段集成测试。
- 清理和巩固测试 fixture，使战区、前线、部署三层能稳定共同回归。
- 优化探针检测，准备后续地图编辑器和战争命令系统接入。

关键系统：

- `Tests/TheaterSystemTests.swift`
- `Tests/FrontLine*Tests.swift`
- `Tests/WarDeployment*Tests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段主要是集成验收和测试基线整理，不是新玩法版本。

## v0.34 - 地图编辑器

完成日期：2026-06-18 至 2026-06-19

核心更新：

- 在 `MapEditor/` 下加入项目专属地图编辑器骨架。
- 使用 SwiftUI 管理工具面板，SpriteKit 管理六角格交互视口。
- 编辑器直接导出项目自有 `ScenarioDefinition` 与 `RegionDataSet` JSON，不再引入 Tiled 中间件。
- 新增 macOS 独立 target `MapEditorMac`。
- 支持地块、省份、战区、初始部队编辑。
- `DataLoader` 增加任意文件名加载入口和 MapEditor 输出专用加载路径。
- 地形补充 `hill`，并同步 `terrain_rules.json`、颜色和 inspector 显示。

关键系统：

- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorHexMath.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorMacApp.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `Tests/MapEditorOutputTests.swift`

验证记录：

- `MapEditorOutputTests` 覆盖编辑器输出到 `GameState` 的集成链路。

## v0.341 - macOS 独立编辑器

完成日期：2026-06-18

核心更新：

- 新增 `MapEditorMac` target，作为独立 macOS app 运行。
- 默认窗口适配宽屏/全屏地图编辑。
- 左侧 SwiftUI split panel 管理地图、模式、参数、文件操作。
- 右侧 SpriteKit canvas 渲染六角格。
- 支持鼠标拖拽连续涂色、滚轮/触控板缩放、右键/中键/Option+左键平移。
- 默认工作流读写 `WWIIHexV0/Data/ardennes_v0_scenario.json` 与 `ardennes_v02_regions.json`。

备注：

- MapEditor 不接入 iOS 主入口，避免污染游戏 app 启动流程。

## v0.342 - 地图编辑器中文化与显式编辑流

完成日期：2026-06-18

核心更新：

- 地图编辑器左侧面板改为中文。
- 模式拆成：地块、省份、战区、部队。
- 各模式采用统一 `添加 / 删除 / 完成 / 取消` 显式编辑会话。
- 切换模式会取消当前编辑会话，避免误操作。
- 分层显示只突出当前模式相关数据。
- `MapEditorOutputTests.testEditorSessionActionsReflectInGameState` 覆盖地块、省份、战区、部队完整编辑与导出读取。

## v0.343 - 地图编辑器视口稳定、稀疏扩图与快捷键

完成日期：2026-06-18

核心更新：

- 平移改用 view-space 指针增量，避免 camera 移动导致拖动抖动。
- 滚轮/触控板缩放以鼠标所在 scene point 为锚点，减少视口漂移。
- `MapEditorDocument.contains(_:)` 改为判断实际存在 hex，支持稀疏地图。
- 地块模式新增扩展地块动作，允许在已有 hex 邻位生成新 hex。
- 删除 hex 会清理该 hex 上的初始部队，并移除空 region/theater assignment。
- region/theater 名称由 UI 输入，内部 ID 自动递增。
- 新增快捷键：`N` 添加，`M` 完成。

验证记录：

- `MapEditorOutputTests` 扩展覆盖自动 ID、邻接扩展、虚空造地失败、删除清理、平移/缩放数学。

## v0.344 - 地图编辑器交互修复、信息面板与底图层

完成日期：2026-06-19

核心更新：

- macOS 画布改用 `NSViewRepresentable + SKView`，直接接收 `keyDown`。
- 修复 SpriteKit 抢焦点后 SwiftUI `Button.keyboardShortcut` 不稳定的问题。
- 滚轮缩放与水平/Shift 滚轮平移接入 `SKView.scrollWheel`。
- 右键短按选择 hex，并在左侧信息面板展示/编辑坐标、地形、道路、region、theater 信息。
- Region/Theater 颜色改用固定高对比色板按 ID hash 取色。
- 新增编辑器底图层：导入图片、设置透明度、缩放和位置；底图不写入游戏 JSON。

验证记录：

- `MapEditorOutputTests` 扩展覆盖快捷键、右键信息选择、名称保存、底图文档状态与移动增量。

## v0.351 - 初步战争命令系统

完成日期：2026-06-19

核心更新：

- 新增战争指令协议：`DirectiveEnvelope` / `ZoneDirective`。
- 新增 `WarCommandExecutor`，将 zone 级 attack/defend 意图翻译为底层 `Command`。
- 新增 `MockAICommander`，按兵力比阈值输出 attack/defend。
- AI 指令与玩家命令最终都走 `RuleEngine` / `CommandValidator` 校验执行。
- 为后续 LLM 输出 JSON 指令预留协议层。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`

备注：

- v0.351 只是初级战争命令，不做复杂战术、撤退命令、装甲差异化或真实 LLM。

## v0.352 - 新管线唯一化、观察者模式与分层 UI

完成日期：2026-06-19

核心更新：

- 新增/强化 `WarPipelineMode.zoneDirective`，默认战争 AI 走新 ZoneDirective 管线。
- Legacy Agent D 保留但不作为默认战争 AI 主路径。
- 引入观察者模式，支持双方由 AI 自动对战，但回合推进仍受玩家操作控制。
- 新增 `WarDirectiveRecord`，记录 directive、结果、诊断和 UI 回放信息。
- UI 支持 hex/province/theater/frontLine 等图层切换。
- `MockAICommander` attack 阈值从 1.5 调整到 1.2，使战局更容易推进。

关键系统：

- `Core/WarPipelineMode.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Core/WarDirectiveRecord.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

## v0.353 - 默认地图验收与归属权威重构

完成日期：2026-06-19

核心更新：

- 默认地图接入真实战局模拟验收。
- 确立 hex controller 为归属权威。
- region controller、theater 控制比例、补给站归属改为从 hex controller 派生。
- 避免继续依赖静态阵营标签判断动态占领结果。
- 观察者模式下新地图可用于战争模拟和回归测试。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/TheaterSystem.swift`
- `Rules/RegionOccupationRules.swift`
- `Tests/ObserverModeIntegrationTests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段是后续 v0.354/v0.355 修复“AI 不动、联动不及时、占领不对称”的地基。

## v0.354 - 联动修复、拒绝率治理与玩家/AI 对称性

完成日期：2026-06-19 至 2026-06-20

核心更新：

- 修复占领后 region、theater、frontline、visibility 不在同一回合联动的问题。
- 修复 ZOC 友军穿越误判，避免友军互相阻挡。
- 定位“德军若干回合后不动”的真实病灶：推进过深的部队被部署层误判为 garrison，从前线兵力池消失。
- 统一玩家与 AI 的占领判定入口，避免 AI 能占玩家地、玩家不能占 AI 地的不对称。
- 改善 RuleEngine 拒绝率诊断，避免非法命令被静默吞掉。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/WarDeploymentManager.swift`
- `Rules/CommandValidator.swift`
- `Commands/WarCommandExecutor.swift`
- `Tests/WarEvolutionTests.swift`
- `Tests/ObserverModeIntegrationTests.swift`

备注：

- v0.354 期间有多轮 debug 与修复提交，包括 `v0.354 优化1`、`v0.354修复`、`0.354debug`。

## v0.355 - 动态/初始战区分离、前线 UI 与观察者收尾

完成日期：2026-06-20 至 2026-06-23

核心更新：

- 正式分离 `TheaterState.initialSnapshot` 与运行时动态战区状态。
- 修复战区阵营身份不能从动态控制比例反推的问题。
- 图层拆分为 `hex`、`province`、`initialTheater`、`dynamicTheater`、`frontLine`。
- 前线 overlay 改为按 `FrontSegment` 连线绘制。
- 观察者模式开关接入主界面 UI。
- 执行 20 回合观察者模式模拟与阶段分析，记录 directive、拒绝原因、省份换手和补给/包围趋势。

关键系统：

- `Core/Theater.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`
- `Tests/Stage035CampaignSimulationTests.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

验证记录：

- 历史记录显示 v0.355 阶段曾达到 Probe 9/0、Smoke 4/0、Stage Regression 63/0、Full 198/0。
- 20 回合观察者模拟：57 条 directive，拒绝率约 10%，主要拒绝原因为移动力不足与无路径。

备注：

- 文档 `0.355-迄今概览.md` 记录该阶段架构总结与后续注意事项。

## v0.356 - 默认资源一致性与前线 UI 修正

完成日期：2026-06-24

核心更新：

- DEBUG 下 `DataLoader` 优先读取源码 `WWIIHexV0/Data/*.json`，避免编辑器覆盖保存后游戏仍读取旧 bundle 资源。
- 新增默认资源一致性测试，确保编辑器 document、导出 JSON、游戏加载后的 `hexToRegion`、`regionToTheater`、`tile.regionId`、`region.name` 一致。
- 前线 UI 改为在我方动态战区侧绘制，用 `segment.regionA` 内接敌 hex 的中心点连线。
- 不同 theater 前线使用固定不同基色。
- 每个 segment 单独绘制，并在 segment 起点加分隔符，避免被看成一整条红线。

验证记录：

- 定向 MapEditorOutputTests + Stage0355DynamicTheaterTests：10 tests, 0 failures。
- Probe：9 tests, 0 failures。
- Smoke：4 tests, 0 failures。
- Full regression：200 tests, 0 failures。
- `git diff --check` 通过。

备注：

- 如果模拟器中仍运行旧 app 进程，需要重新运行 app 才会读到 DEBUG 源码 JSON。

## v0.357 - 地图视角、开局单位与前线 UI 修正

完成日期：2026-06-24

核心更新：

- 修复地图编辑器与游戏内视角上下颠倒/不一致问题。
- 修复部队初始部署异常与跨阵营战区问题。
- 修正开局不应立即让 AI 自动行动的行为，开局应先显示真实初始部队状态。
- 继续优化前线 UI，使动态战区、segment 与视觉表达一致。

关键系统：

- `MapEditor/*`
- `Data/DataLoader.swift`
- `App/AppContainer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

## v0.358 - 动态 hex 战区语义收口

完成日期：2026-06-24

核心更新：

- 确认核心语义：`regionToTheater` 是初始/基础战区映射，`hexToTheater` 是运行时动态战区权威。
- 单位占领一个 hex 只推进该 hex 的动态战区归属，不能把整个 region 拖入进攻方 theater。
- 部署层同步引入/强化 `hexToFrontZone`，避免 region 粒度误判 FRONT/DEPTH/GARRISON。
- 前线改按动态 hex 邻接生成，测试 fixture 必须构造真实相邻 hex，不能只声明 region 邻接。
- AI target、WarDeployment、overlay、probe 和 stage tests 同步适配动态 hex 语义。

关键系统：

- `Core/Theater.swift`
- `Core/WarDeploymentState.swift`
- `Rules/TheaterSystem.swift`
- `Rules/FrontLineManager.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

备注：

- 这是 v0.3 主线的重要铁律：运行时动态战区跟 hex 走，不跟 region 走。

## v0.359 - 前线 UI 优化

完成日期：2026-06-25

核心更新：

- 继续优化前线 overlay 的可读性。
- 强化不同战区/不同 segment 的视觉区分。
- 保留 encirclement/collapsing 等警示状态的红色与加粗表达。
- 使前线 UI 更接近真实动态战区接触，而不是静态 region/theater 边界。

关键系统：

- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`

## v0.3510 - 颜色优化

完成日期：2026-06-25

核心更新：

- 优化地图分层 UI 的颜色表达。
- 强化 province、initialTheater、dynamicTheater、frontLine 等 layer 的辨识度。
- 避免相邻 region/theater 颜色过近导致误判。

关键系统：

- `SpriteKit/TerrainStyle.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

备注：

- 该版本号沿用提交历史中的 `v0.3510`，语义上属于 v0.35x UI 收尾序列，不是 v0.351 的子补丁。

## v0.3511 - UI 修复优化

完成日期：2026-06-25

核心更新：

- 继续修复和优化主游戏 UI。
- 配合 v0.359/v0.3510 的颜色和前线显示调整，改善可读性。
- 为 v0.36 命令层扩展前的界面状态收口。

关键系统：

- `UI/*`
- `SpriteKit/*`

备注：

- 该版本号同样来自提交历史，属于 v0.35x 收尾序列。

## v0.36 - 命令层扩展与多将领 MockAI

完成日期：2026-06-25

核心更新：

- `ZoneDirective` 扩展 `CommandCategory`、`TacticName`、`DirectiveTarget`。
- 新增 `ZoneCommanderAgent`，每个动态战区可由独立将领 agent 生成 directive。
- 新增 `BinaryTacticClassifier`，在 `standardAttack` 与 `holdPosition` 之间做初步分类。
- 新增 `TheaterCommanderPool`，为动态战区提供将领配置，未知新战区使用 fallback commander。
- `WarDirectiveRecord` 增加 category、tactic、commanderAgentId、commandTarget 等字段，便于回放和审计。
- `MockAICommander` 转为兼容 facade，不作为未来扩展主入口。
- 修复旧测试 fixture，使其符合 v0.358 动态 hex 邻接语义。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Core/WarDirectiveRecord.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：17 tests, 0 failures。
- Stage Regression：63 tests, 0 failures。
- Full Regression：213 tests, 0 failures。
- 静态检查：`plutil`、`xmllint`、`jq`、`git diff --check` 通过。

备注：

- `AttackIntensity` 字段仍存在，但没有实际分流执行逻辑。
- 战区互助接口仍无调用方。
- 真 LLM 尚未接入。

## v0.37 - 命令层统一整合

完成日期：2026-06-27

核心更新：

- 默认战争 AI 路径收口为：

```text
TheaterCommanderPool -> ZoneCommanderAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine -> WarDirectiveRecord
```

- 移除 `TurnManager` 中 `MockAICommander` fallback，避免默认路径语义模糊。
- `.zoneDirective` 分支只通过显式 `commanderPool` 或 `TheaterCommanderPool.automatic(for:)` 产生 envelope。
- Legacy Agent D 只在显式 `.legacyAgentOrder` 或测试回归中使用。
- 保留 `MockAICommander` 作兼容/阈值行为测试用途，但不再作为 `TurnManager` 默认备用入口。
- 确认 `WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 可直接执行。
- 新增 v0.37 手写 directive 探针，为 v0.4 玩家 UI 共用命令管线预留后端能力。
- 决定将撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 实际分流推迟到 1.x。

关键系统：

- `Turn/TurnManager.swift`
- `Commands/WarCommandExecutor.swift`
- `Commands/WarDirective.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：18 tests, 0 failures。
- CommandSystemTests：15 tests, 0 failures。
- Stage Regression：69 tests, 0 failures。
- Full Regression：226 tests, 0 failures。

备注：

- v0.37 是命令层地基工程，不新增玩法机制。
- v0.4 可以在此基础上接玩家聊天/命令 UI，但必须继续共用 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

## v0.5 - 元帅层、模拟 LLM JSON 与决策链规范化

完成日期：2026-07-04

目标分支：`v0.5-marshal-decision-chain`

分支审计：本轮开始时创建并切换过该分支；后续轻量审计中当前 checkout 先后显示为 `v0.9-ruler-diplomacy`、`v0.4-generals-command-ui-resume`、`v1.1-macos-main-game`、`v1.0-ui-ai-playtest` 等非 v0.5 分支，且工作树已有多批其他版本未提交改动。用户同意切换后，当前 checkout 已确认回到 `v0.5-marshal-decision-chain`；合并前仍必须审查 dirty worktree 中非 v0.5 文件归属和文件级冲突。

核心更新：

- 新增元帅层 `MarshalAgent`，在战区将军上游读取降维战场摘要并产出战役级意图。
- 默认战争 AI 管线升级为：

```text
MarshalAgent
  -> MarshalBattlefieldSummarizer
  -> SimulatedMarshalLLMClient
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
```

- 新增 `TheaterDirectiveEnvelope` / `TheaterDirective` 作为 v0.5 LLM-facing JSON schema。
- 新增 `TheaterDirectiveDecoder`，支持 fenced JSON 提取、`JSONDecoder` 解码、schemaVersion / issuer / turn / faction / zone / region / tactic-category 校验。
- 新增 `SimulatedMarshalLLMClient`，只模拟 LLM 接口和 JSON 输出，不接真实网络、本地模型或云端 API。
- 新增 `TheaterDirectiveCompiler`，把元帅意图降级为现有 `ZoneDirective`；缺失或失败时 fallback 到 `TheaterCommanderPool`。
- `WarPipelineMode` 新增 `.marshalDirective`，`AppContainer` 和 `TurnManager` 默认使用该模式；旧 `.zoneDirective` 和 `.legacyAgentOrder` 仍保留为显式路径。
- `TurnManager` 抽出公共 `executeDirectiveEnvelope`，确保元帅链路和旧将军池链路共享同一执行、记录和 endTurn 逻辑。
- v0.5 收口时移除 v0.9 旁支曾插入的 `RulerAgent` 塑形调用；当时 `.marshalDirective` 与显式 `.zoneDirective` 都不写统治者记录。v3.4 起已重新以 `StrategicPostureEnvelope` 形式接入默认元帅上游。
- 新增实现记录文档，详细写明本分支算法、边界、fallback 和轻量验证。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/WarPipelineMode.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `git rev-parse --abbrev-ref HEAD`：`v0.5-marshal-decision-chain`。
- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`
  - `swiftc -parse WWIIHexV0/App/AppContainer.swift`
  - `swiftc -parse WWIIHexV0/Core/WarPipelineMode.swift`
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty` 已通过：
  - `WWIIHexV0/Data/ardennes_v02_regions.json`
  - `WWIIHexV0/Data/general_agents.json`
  - `WWIIHexV0/Data/generals.json`
  - `WWIIHexV0/Data/terrain_rules.json`
  - `WWIIHexV0/Data/unit_templates.json`
- 文档尾随空白扫描：无命中。
- 旧默认测试口径扫描（`AGENTS.md`、`md/flow/flow.md`）：无命中。
- Cabinet/Minister 旧污染源码扫描：无命中。
- v0.5 当前文档与 `TurnManager` 的 `RulerAgent` 默认接入残留扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

备注：

- 本轮没有恢复历史回退的 `CabinetState`、`DirectiveBoard`、`MinisterDecisionProvider`、`RulerDirectiveFactory`、`national_cabinet.json` 或部长系统。
- 当时 v0.5 未启用统治者姿态层；v3.4 起已改为 `StrategicPostureEnvelope` 上游姿态层。
- 当前工作树还存在不属于本 v0.5 核心目标的高级战术、外交、经济、UI 和地图编辑器方向未提交改动；v0.5 实现选择兼容现有工作树，不回滚其他改动。

## v0.8 - 初级经济、生产、城市、地形与补兵

完成日期：2026-07-04

目标分支：`codex/v0.8-economy-production`

分支审计：本轮早期创建 v0.8 分支曾因 `.git` 写入权限受限失败；期间当前 checkout 先后观察到其他版本分支，且工作树已有多批其他版本未提交改动。最终已通过受控审批成功创建 `codex/v0.8-economy-production`，但创建后仍观察到外部 checkout 漂移。因此本记录描述当前工作树中的 v0.8 经济系统实现，合并前必须重新确认当前分支、分支基点、文件级冲突、public API 冲突和 Xcode project 引用。

核心更新：

- 新增 `EconomyState`，建立 faction 级 manpower、industry、supplies 总账、生产队列、上回合收入/维护费/补员消耗。
- 新增 `EconomyRules`，从真实己方 hex 控制证据、region 城市、工厂、基础设施和补给值聚合收入。
- `GameState` 增加 `economyState`，旧存档缺失时 fallback `.empty`。
- `StrategicStateBootstrapper` 与 `RuleEngine` 在需要时 bootstrap 经济总账，保证旧状态第一次执行命令也有经济账本。
- `Command` 新增 `queueProduction(kind:)`，经 `CommandValidator` 检查 phase 和资源，经 `CommandExecutor` 调 `EconomyRules.queueProduction` 预付成本并入队。
- `CommandExecutor.executeEndTurn` 增加 active faction 经济结算：收入、战略补给维护费、短缺降级、自动补兵、生产队列推进和完成部署。
- 自动补兵只处理本阵营、未毁灭、未撤退、supplied、非敌邻、strength 未满的单位，每回合每单位最多恢复 2 strength，按兵种权重扣资源。
- 生产完成单位只能部署到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex；找不到安全部署点时订单保留。
- `BaseTerrain`、`MovementRules`、`CombatRules` 增加地形加成：装甲进困难地形额外移动成本，装甲攻击平原加成，攻击困难地形惩罚，步兵在森林/城市/堡垒防御加成。
- 新增 `EconomyPanelView`，`RootGameView` 接入 Economy tab，`HUDView` 展示经济摘要，Region inspector 展示城市等级和经济产出。
- `project.pbxproj` 当前已有 `EconomyState.swift`、`EconomyRules.swift`、`EconomyPanelView.swift` 引用，未新增重复 UUID。
- 新增 v0.8 实现记录，详细写明规则算法、接入点、非目标、轻量检查和风险。

关键系统：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `md/prompt/anti生成/v0.8/anti/0.80_v0.8_economy_implementation_record.md`
- `md/prompt/anti生成/v0.8/anti/0.80_overall_analysis_report.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 轻量 Swift parse 通过：
  - 核心规则集合，含 `EconomyState.swift`、`EconomyRules.swift`、`GameState.swift`、`Command.swift`、`CommandValidator.swift`、`CommandExecutor.swift`、`RuleEngine.swift`、`StrategicStateBootstrapper.swift`、`MovementRules.swift`、`CombatRules.swift` 等。
  - 核心规则集合 + `PlatformStyles.swift` + `EconomyPanelView.swift`。
  - 核心规则集合 + `MapDisplayAdapter.swift` + `PlatformStyles.swift` + `EconomyPanelView.swift` + `HUDView.swift` + `RegionInspectorView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过。
- 改动文档尾随空白检查：通过。
- 旧默认测试口径残留检查：通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范和用户要求均禁止本轮主动跑 Xcode 与重测试。

备注：

- v0.8 不接真实 LLM 经济部长、不做完整商品价格网、不恢复 organization、不做空军/海军/战略轰炸/工厂损毁。
- `RegionDataSet.toRegions()` 仍有历史 fallback：owner/controller 缺失最终落到 `.allies`。v0.8 经济收入已加真实 hex 控制守卫，但数据层中立语义建议后续单独修。
- 当前 AI 不会主动排产；规则层已支持 active faction 通过统一 `Command` 排产，AI 经济策略留后续版本。

## v1.0 - UI / AI / 初版试玩收口

完成日期：2026-07-04

分支：`v1.0-ui-ai-playtest`

分支审计：续接收尾时当前 checkout 曾显示为 `v1.1-macos-main-game`，切回 `v1.0-ui-ai-playtest` 后又在轻量检查期间漂到 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`。`v1.0-ui-ai-playtest` 分支已存在且与当前基线一致；交付前最后一次即时核对显示当前分支为 `v1.0-ui-ai-playtest`。由于当前工作树存在外部 checkout 漂移风险，合并前必须重新做分支与冲突审查。

核心更新：

- 创建并切换到 1.0 分支，围绕主游戏 UI、MockAI 行为、轻量性能和试玩记录做收口。
- `AgentPanelView` 接入 `WarDirectiveRecord`，AI tab 现在展示 zone、directive type、tactic、成功/拒绝命令数、目标 region 和 diagnostics。
- `EventLogView` 改为 `LogDisplayEntry` 展示模型，最近 60 条日志每条只计算一次分类，并补充 diplomacy 日志分类。
- `BoardScene.drawUnits` 缓存单位显示 hex 后排序，部署图层复用同一个 `WarDeploymentManager` 计算 role。
- `WarCommandExecutor` 开始解释 `AttackIntensity.infiltration`，无显式投入上限时限制默认投入单位数；佯攻/袭扰保留低投入策略。
- `PlatformStyles` 补充跨平台面板样式；Economy / Diplomacy 面板收口到跨平台背景和更可读字号。
- 新增 1.0 分支实现记录，写明 UI、性能、MockAI、试玩观察点、风险和未跑重测试原因。

关键系统：

- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `git branch --show-current`：切回后曾返回 `v1.0-ui-ai-playtest`，但后续轻量检查期间又返回 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`；分支漂移未完全消除。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（AGENTS.md、README.md、update_log.md、md/flow、WWIIHexV0、MapEditor）：无命中。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑重测试。

备注：

- 本轮并发子 agent 中 UI 只读定位完成，AI / 性能子 agent 因外部 503 失败，主线程接回实现。
- 当前工作树仍含 v0.5 / v0.7 / v1.1 等方向未提交改动，合并前必须做文件级、public API、schema、Xcode project 和文档口径冲突审查。

## v0.9 - 统治者、多国家、阵营集团与初步外交状态

完成日期：2026-07-04

分支：`v0.9-ruler-diplomacy`

核心更新：

- 新增 `DiplomacyState`，在 `GameState` 中保存国家、阵营集团、国家间外交关系和统治者决策记录。
- 新增 `CountryProfile`、`DiplomaticBloc`、`DiplomaticRelation`、`DiplomaticStatus`、`RulerStrategicPosture`、`RulerDecisionRecord` 等数据结构。
- 开局外交种子：
  - Germany 规则阵营：`German Reich`，`Axis`，`ruler_germany`。
  - Allies 规则阵营：`United States`、`United Kingdom`、`Belgium`，`Allied Coalition`，主统治者 `ruler_allies`。
  - 同阵营关系为 `allied`，跨阵营关系为 `atWar`。
- 新增 `RulerAgent`：读取外交、前线、部署、历史战争指令记录，生成 `RulerStrategicSnapshot`，选择 `offensive` / `defensive` / `coalitionMaintenance` / `stabilizeFront` 姿态。
- `RulerAgent` 只塑形 `DirectiveEnvelope`：
  - offensive：攻击强度提升为 `allOut`，按 region priority 重排目标。
  - defensive：攻击 directive 转为 `holdLine` 防御 directive。
  - coalitionMaintenance：提高防御预备队。
  - stabilizeFront：降低 `allOut` 为 `limitedCounter`，或采用 `flexible` 防御。
- `TurnManager` 在 `.marshalDirective` 与显式 `.zoneDirective` 路径中执行 `applyRuler`，写入 `RulerDecisionRecord` 和 `.diplomacy` 日志后，再交给 `WarCommandExecutor -> RuleEngine`。
- `DataLoader` 和 `StrategicStateBootstrapper` 会为新局或旧存档补齐外交状态。
- 新增 `DiplomacyPanelView`，`RootGameView` 增加 `Diplomacy` 面板，`AgentPanelView` 展示最近统治者 posture / focus。
- `GameLogCategory` 新增 `diplomacy`。
- 修复 `RulerStrategicSnapshot` 静态去重调用；修复 `hostileCountryIds(to:)` 在多盟友共享同一敌国时重复计数的问题。
- 新增 v0.9 实现记录，详细写明本分支算法、边界、冲突情况和未跑重测试原因。

关键系统：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`

验证记录：

- `git branch --show-current`：`v0.9-ruler-diplomacy`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（README.md、update_log.md、md/flow、v0.9 实现记录与相关 Swift 文件）：无命中。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与本轮用户要求均禁止主动跑 Xcode 和重测试。

备注：

- 本轮尝试把国家/外交、AI 管线、文档三块拆给子 Agent 并行，但子 Agent 调用返回 503，没有可用产物；最终由主 Agent 在当前分支内完成实现和整合。
- 当前工作树已有 v0.5 元帅层、经济层、v1.1 macOS target、地图编辑器和 UI 等未提交改动；v0.9 选择兼容当前源码，不回滚其他改动。合并前仍需做文件级冲突审查。
- 多国家当前是战略身份层，底层规则阵营仍是 `Faction.germany` / `Faction.allies`。后续若要国家级参战、中立、投降、宣战或外交行动，需要先设计国家级权限和命令入口。

## v1.1 - 主游戏 macOS target

完成日期：2026-07-04

分支：`v1.1-macos-main-game`

核心更新：

- 新增独立主游戏 macOS app target `WWIIHexV0Mac`，区别于既有 iOS 主游戏 target `WWIIHexV0` 和地图编辑器 target `MapEditorMac`。
- 新增 macOS 主入口 `WWIIHexV0MacApp`，复用 `AppContainer.bootstrap()` 与 `RootGameView(container:)`，默认窗口 1440x900，最小内容区域 1200x760。
- `WWIIHexV0Mac` resource phase 接入主游戏默认 JSON：`ardennes_v0_scenario.json`、`ardennes_v02_regions.json`、`general_agents.json`、`generals.json`、`terrain_rules.json`、`unit_templates.json`。
- `BoardSceneView` 增加 macOS `NSViewRepresentable` 分支，用 `BoardEventSKView` 承载 `BoardScene`，iOS 继续使用 `UIViewRepresentable` 分支。
- `BoardScene` 增加 macOS 鼠标点击、拖拽平移、滚轮/触控板缩放；点击仍只回调 `onHexTapped`，后续由 `AppContainer.handleBoardTap -> RuleEngine` 处理。
- 新增 `PlatformStyles`，将主游戏 UI 的 `Color(.systemBackground)` / `Color(.tertiarySystemBackground)` 替换为 iOS/macOS 条件背景色。
- 因当前工作树已有经济、外交、统治者、将领 registry 等源码引用，`project.pbxproj` 同步把这些已被引用的支持文件和 `generals.json` 接入相关 target phase，但本轮不改这些业务逻辑。
- 新增 v1.1 实现记录，详细写明 target 设计、输入桥接算法、资源加载、轻量检查和风险。

关键系统：

- `WWIIHexV0.xcodeproj/project.pbxproj`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/anti生成/v1.1/anti/1.10_v1.1_macos_main_game_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / macOS app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与用户要求均禁止本轮主动跑 Xcode 和重测试。

备注：

- v1.1 是平台承载和输入桥接分支，不改变 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 规则权威链路。
- 当前工作树存在多条其他方向的未提交改动；v1.1 选择兼容当前源码引用并记录风险，不回滚其他人改动。

## v0.7 - 高级战术与命令扩展

完成日期：2026-07-04

目标分支：`v0.7-tactical-upgrade`

分支审计：本轮曾创建并切换到 `v0.7-tactical-upgrade`，但连续接力时当前 checkout 多次显示为其他分支，且工作树已有多批 v0.5 / v1.0 / v1.1 / UI / 经济 / 外交方向未提交改动。按项目规则，本轮未回滚这些改动；合并前必须重新确认分支归属和文件级冲突。

核心更新：

- `TacticName` 扩展为进攻 8 类、防御 4 类：
  - 进攻：`standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`。
  - 防御：`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand`。
- `AttackParameters` 新增 `focusRegionId`、`supportRegionIds`、`convergenceRegionId`、`coordinatedZoneIds`、`maxCommittedUnits`、`exploitDepth`，支持定点突破、钳形会师、投入上限和纵深目标意图。
- `DefenseParameters` 新增 `fallbackRegionIds`、`counterattackRegionIds`、`strongpointRegionIds`、`maxFrontCommitment`，支持弹性防御、纵深防御和死守口径。
- `TheaterDirective` 新增 `convergenceRegionId` / `coordinatedZoneIds`，并补自定义 decode，旧 JSON 缺字段时仍兼容。
- `TheaterDirectiveDecoder` 校验 convergence region 和 coordinated zone 存在性，继续校验 tactic/category 一致性。
- `BinaryTacticClassifier` 从二元分类升级为读取兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告的战术分类器。
- `TacticConditionChecker` 从恒 true 改为按战术最低条件放行：机动战术要求机动单位，火力覆盖要求炮兵/远程单位，佯攻要求前线单位，纵深防御要求 depth 预备队。
- `WarCommandExecutor` 新增 `AttackTacticProfile`，按战术控制单位来源、机动优先、炮兵优先、只攻击不推进、弱点聚焦、深目标候选、非矛头单位 hold 和投入上限。
- 定点突破弱点评分落地：

```text
enemyStrength 越低越优先
terrain.movementCost 越低越优先
region 内有 road 越优先
city.victoryPoints + supplyValue + factories 越高越优先
guerrillaWarfare 额外参考 infrastructure
```

- `defenseInDepth` 新增独立执行路径：一线 `allowRetreat`，保留预备队，其余 depth 机动单位尝试反击，否则向 fallback / strongpoint 防御地形移动。
- `fireCoverage` 落地为炮兵/远程优先、能打则打、无目标则 hold，不主动推进。
- `feint` 落地为少量前线单位牵制，默认约 1/3 前线投入。
- `blitzkrieg` / `spearhead` 落地为机动优先、集中弱点、可使用 depth 单位，非矛头前线单位 hold。
- `pincerMovement` 落地为 convergence / coordinated 数据层和单 zone 执行器 profile；多 zone 会师由元帅层或人工下发多条 directive，包围效果交给动态战区/前线/补给派生。
- `MockAICommander` 保留新增 attack 参数，避免 allOut 包装时丢失 focus/convergence/coordinated 字段。
- 新增 v0.7 实现记录文档，详细写明算法、边界、冲突风险和轻量检查口径。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Agents/MockAICommander.swift`
- `md/prompt/anti生成/v0.7/anti/0.70_v0.7_tactical_upgrade_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/03_ai_zone_directive_pipeline.mermaid`
- `README.md`

验证记录：

- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift`

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

遗留风险：

- 未做运行时战局验证，战术效果和 AI 行为只通过源码与轻量 parse 检查确认语法层可用。
- 当前工作树混有其他版本改动，合并前必须做文件/API/schema/文档冲突检查。

## v0.4 - 将军养成初步、将军 UI 与玩家双轨命令

完成日期：2026-07-04

目标分支：`v0.4-generals-command-ui-final`

分支审计：本轮从一个已混入 v0.9 / v0.5 / v1.x 外部未提交改动的工作树创建 0.4 续作分支。期间 checkout 又被外部切到 `codex/v0.8-economy-production`，最终已重新固定到 `v0.4-generals-command-ui-final`。按项目规则，本轮没有回滚外部改动；只在当前分支继续补齐 0.4 将军和玩家命令链路。合并前必须重新审查 project、public API、JSON schema 和文档口径冲突。

核心更新：

- 新增实体将军数据链：`generals.json`、`GeneralData`、`GeneralRegistry`、`GeneralDispatcher`。
- `RegionNodeDefinition` / MapEditor region draft 支持 `assignedGeneralId`，默认阿登 region JSON 已给蒙哥马利、魏刚、古德里安、里布写入初始种子。
- `FrontZone` 增加 `generalAssignment`，记录将军 id、HQ region、辖下 division、忠诚、满意度和玩家干预次数。
- `WarDeploymentState.preservingGeneralAssignments` 与 AppContainer 刷新逻辑保留/补齐将军分配，避免部署层重建后将军丢失。
- `TheaterCommanderPool` 在 AppContainer 构造时可由 `GeneralDispatcher.commanderPool` 使用真实将军配置，缺失时仍 fallback 到自动 commander。
- 新增 `PlayerCommandState` 和 `PlayerPlannedOperation`，保存本回合微操锁和玩家战区计划。
- 玩家微操 move/attack/hold/resupply/allowRetreat 成功后锁定该师，降低所属将军满意度并增加干预次数；结束回合或阵营/回合变化时清空锁。
- `WarCommandExecutor.execute` 新增兼容参数 `excluding excludedDivisionIds`，在进攻、防御、纵深防御和非矛头 hold 阶段跳过玩家微操部队。
- `AppContainer` 新增玩家宏观将军命令：`Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，执行后不自动结束回合。
- 新增 `GeneralCommandPanelView` 与 `GeneralProfileView`，展示将军头像占位、军衔、风格、技能、履历、忠诚/满意度、HQ 状态、辖下部队和计划操作。
- `RootGameView` 新增 `General` tab，Unit tab 也嵌入将军命令面板。
- `BoardScene` 根据 `PlayerPlannedOperation` 画进攻箭头/防御圆环，`UnitNode` 对本回合玩家微操单位画金色圈。
- `WarDirectiveRecord` 记录玩家宏观指令结果，AI 面板与日志可继续共用同一复盘数据。

关键系统：

- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Core/PlayerCommandState.swift`
- `WWIIHexV0/Core/FrontZone.swift`
- `WWIIHexV0/Core/WarDeploymentState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/anti生成/0.4/v0.4_generals_command_ui_branch_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `jq empty WWIIHexV0/Data/generals.json` 通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json` 通过。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- `git diff --check` 通过。
- 文档尾随空白检查无匹配。
- 单文件轻量 parse 通过：`PlayerCommandState.swift`、`GeneralAssignment.swift`、`GeneralRegistry.swift`、`GeneralCommandPanelView.swift`、`GeneralProfileView.swift`、`WarCommandExecutor.swift`、`AppContainer.swift`、`BoardScene.swift`、`UnitNode.swift`、`RootGameView.swift`。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑 Xcode 与重测试。

遗留风险：

- 未做运行时 UI 点击和 SpriteKit 视觉验证，按钮行为、sheet 展示、计划线位置仍需后续人工或授权轻量运行确认。
- 当前工作树混有其他版本改动，合并前必须重新做文件/API/schema/project 冲突审查。

## v3.0 - 拿破仑战争迁移审计与兼容合同

完成日期：2026-07-04

核心更新：

- 完成 v3.0 文档阶段：从 `WWIIHexV0` 迁移到拿破仑战争题材前，先建立审计清单、迁移词汇表和兼容合同。
- 扫描并记录当前运行时中的主要二战绑定点：`Faction.germany/allies`、`Faction.opponent`、`GamePhase.germanAI/alliedPlayer`、阿登默认数据、Guderian/Montgomery、Panzer/tank/motorized、Industry/Production 等。
- 明确 v3.1 的高风险接口边界：敌我关系必须转向 `DiplomacyState` / relation helper；回合阶段必须从具体 Germany/Allies 解耦；neutral 不得 fallback 到 `.allies`。
- 明确 v3.2-v3.6 后续拆分：滑铁卢数据、拿战单位和地形、皇帝/总司令/军团长 Agent、后勤/增援/弹药、发布级 UI。
- 更新 README 和 `md/plan/plan.md`，说明当前仍是阿登二战运行时，拿战迁移只完成 v3.0 审计合同，不声称已有滑铁卢可玩行为。

关键文件：

- `md/prompt/v3.0-拿战迁移/v3.0_audit_and_contract.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮只做文档和只读源码审计，轻量检查记录见本轮交付。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- 运行时仍是二战/阿登主路径；拿战规则、滑铁卢数据、多势力回合、拿战 UI 均未实现。
- 当前工作树已有未提交文档改动，本轮只追加相关文档，不回滚既有改动。

## v3.1 - 国家、联军与敌我关系基础

完成日期：2026-07-04

核心更新：

- 在 `Faction` 中新增拿战兼容 case：`.france`、`.angloAllied`、`.prussia`、`.austria`、`.russia`、`.spain`、`.neutral`，旧 `.germany/.allies` 保留兼容。
- 在 `DiplomacyState` 中新增 `isHostile`、`isFriendly`、`hostileFactions`，作为多国家/联军迁移的统一敌我关系查询入口。
- 新增 France / French Empire、第七次反法同盟、Neutral Powers 的初始国家/集团关系：France 与同盟默认 atWar，Anglo-Allied / Prussia / Austria / Russia / Spain 之间默认 coBelligerent，Neutral 不因缺 relation 被视为 hostile。
- 新增 `GamePhase.aiCommand/playerCommand`、`allowsCommands` 和 legacy phase helper；`CommandValidator`、`AppContainer.shouldRunAI`、`TurnManager.isAITurn` 不再把可执行阶段写死到 Germany / Allies。
- 新增 `GameState.participatingFactions` / `turnOrderFactions`，结束回合可从当前局面推导多势力轮转并排除 `.neutral`。
- 修复 `RegionDataSet.toRegions()` 的 nil -> `.allies` fallback，owner/controller 双 nil 现在映射为 `.neutral`；`RegionOccupationRules` 聚合控制权时忽略 neutral hex。
- 将更多核心运行时路径从直接 `Faction.opponent` 或 `faction != otherFaction` 改为 `DiplomacyState.isHostile/isFriendly`：
  - hex / region 补给通路与撤退安全判断。
  - region pressure 敌军统计。
  - Legacy Agent D 的 enemy divisions 与敌方补给摘要。
  - Marshal 摘要中的敌控目标、敌控 region、敌军存在和敌军强度统计。
  - `WarCommandExecutor` 战术目标 hex 排序、敌军强度、可见敌军和敌控 region 判断。
  - `CommandValidator` / `RegionCommandValidator` 攻击目标合法性。
  - `MovementRules` ZOC 和路径阻挡。
  - `OccupationRules` 和 `CommandExecutor.shouldAdvanceDynamicTheater` 的 friendly / coBelligerent 占领边界。
  - `FrontLineManager` 动态战区邻接过滤；coBelligerent theater 不再因 faction 不同自动形成 front line。
  - `WarDeploymentManager` 的 hostile zone、hostile presence、front/depth/garrison 分类、collapse depth zone 和 encirclement contact 判断。
  - `TheaterSystem` 的 `frontWeight` 与 theater retirement friendly neighbor 判断。
  - `ZoneCommanderAgent` / `GeneralRegistry` 的可见敌军、敌控 region、争夺前沿 presence 和 HQ under attack 判断。
  - `BoardScene` / `MapLayerOverlayCalculator` / `MapDisplayAdapter` 的 deployment role 显示计算。
- `FrontLineManager` 不再直接使用 `Faction.opponent` 填 `FrontLine.factionB`，而是从 segment 对侧 controller 推导；单字段 schema 仍保留兼容。
- 更新 v3.1 阶段记录和核心文档，说明本轮仍不代表滑铁卢剧本、拿战 UI 或完整部署层多联军语义完成。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Core/WarDeploymentState.swift`
- `WWIIHexV0/Rules/TheaterSystem.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/OccupationRules.swift`
- `WWIIHexV0/Rules/RegionCommandValidator.swift`
- `WWIIHexV0/Rules/RegionOccupationRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/RegionSupplyRules.swift`
- `WWIIHexV0/Rules/RegionCombatRules.swift`
- `WWIIHexV0/Rules/FrontLineManager.swift`
- `WWIIHexV0/Rules/WarDeploymentManager.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Rules/StrategicStateSynchronizer.swift`
- `WWIIHexV0/Agents/AgentContexts.swift`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/MapLayerOverlayCalculator.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/SpriteKit/TerrainStyle.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorExporter.swift`
- `md/prompt/v3.0-拿战迁移/v3.1_powers_coalitions_foundation.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 四组改动 Swift 文件：通过，无输出。
- 文档尾随空白检查：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。
- `.opponent` 残留扫描：只剩 `Core/Faction.swift` legacy helper。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `FrontLine.factionB` 仍是单一兼容字段，不是完整多敌方 schema。
- `FrontZone.faction` 仍是单一势力字段；联军共同防区、混编指挥区和多势力 HQ 还没有设计。
- `ZoneCommanderAgent` / `GeneralRegistry` 仍按 exact faction 筛选可指挥单位和将军，这是指挥权边界，不是敌我关系；后续如要同盟指挥权共享，需要单独 schema。
- 默认数据、胜利条件、主要 UI 和单位/生产语义仍是阿登/二战；滑铁卢 JSON 尚未建立。

## v3.2 - 滑铁卢数据入口与场景目录起步

完成日期：2026-07-05

性质：v3.2 分段实现记录。本节代表场景资源选择入口已经从裸字符串硬编码抽到 `ScenarioCatalog`，并新增最小 Waterloo 1815 schema slice；不代表完整滑铁卢战役、拿战规则或拿战 UI 已完成。

核心更新：

- 新增 `ScenarioCatalogEntry` 与 `ScenarioCatalog`，显式记录当前可玩 legacy 场景和后续拿战目标场景。
- `ScenarioCatalog.defaultPlayable` 仍指向 `ardennes_v0_scenario` / `ardennes_v02_regions`，保证现有启动路径不因缺少 Waterloo 资源而失败。
- `ScenarioCatalog.napoleonicTarget` 指向 `waterloo_1815_scenario` / `waterloo_1815_regions` / `napoleonic_terrain_rules` / `napoleonic_unit_templates` / `napoleonic_generals`，作为后续 v3.2 扩展 Waterloo JSON 的统一入口。
- 新增最小 `waterloo_1815_scenario.json`：12 个 sparse hex、France / Anglo-Allied / Prussia / Neutral 四方、La Haye Sainte / Hougoumont / Mont-Saint-Jean / Papelotte / Prussian Approach 关键点，并引用拿战模板 id。
- 新增最小 `waterloo_1815_regions.json`：6 个 region、12 个 hexToRegion 映射、region edges、region-level supply sources 和 objectives。
- 新增 `napoleonic_terrain_rules.json`：使用既有 `plain` / `forest` / `mountain` / `hill` / `city` / `fortress` raw value 承载 open ground、woodland、ridge、village 和 fortified farm / chateau。v3.2 当时它只作为数据合同和解析入口；后续 v3.8 已通过 `TerrainRuleSet` 接入 Waterloo 移动/战斗主路径。
- 新增 `napoleonic_unit_templates.json`：建立 `line_infantry_brigade`、`grand_battery`、`strongpoint_guard`、`prussian_vanguard` 和 `reserve_infantry_column`。v3.3 起已改用拿战 `ComponentType` raw value，真实骑兵冲锋、队形、士气和炮兵准备规则继续后置。
- 新增 `napoleonic_generals.json`：建立 Napoleon / Wellington / Blucher 三位 Waterloo 目标将领的专用目录。`generals.json` 中的同名条目当前作为兼容期重复存在，后续切默认和 bundle 资源稳定后再清理。
- `generals.json` 追加 `commander_napoleon`、`commander_wellington`、`commander_blucher`，与 Waterloo region 的 `assignedGeneralId` 种子对齐，让部署层将军分配不再只是占位 id。
- 新增 `DataLoader.loadGameState(_ scenario: ScenarioCatalogEntry)`，让后续切换默认场景或显式加载 Waterloo 不再散落资源名字符串。
- `ScenarioCatalogEntry` 增加 `terrainRulesName`、`unitTemplateName` 和 `generalCatalogName`；`DataLoader.loadGameState(_:)` 会先解析场景地形规则，并按场景读取单位模板和部署层将领目录。阿登仍读 `terrain_rules` / `unit_templates` / `generals` 并保留旧 fallback，Waterloo 读 `napoleonic_terrain_rules` / `napoleonic_unit_templates` / `napoleonic_generals`、要求 `templateId` 命中并使用模板 `maxHP`。
- `AppContainer.bootstrap()` 的默认 general registry 读取 `ScenarioCatalog.defaultPlayable`，为后续切换默认剧本时使用场景专属将领目录预留入口。
- `DataLoader.loadInitialGameState()` 改为通过 `ScenarioCatalog.defaultPlayable` 加载默认场景；旧 `GameState.initial()` fallback 保持不变。
- 更新 v3.2 阶段记录、README、flow/flowchart、plan 和总提示词，说明当前默认仍是阿登，Waterloo 只有最小数据骨架，尚不可作为默认可玩战役。

关键文件：

- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Data/napoleonic_generals.json`
- `WWIIHexV0/Data/napoleonic_terrain_rules.json`
- `WWIIHexV0/Data/napoleonic_unit_templates.json`
- `WWIIHexV0/Data/waterloo_1815_scenario.json`
- `WWIIHexV0/Data/waterloo_1815_regions.json`
- `md/prompt/v3.0-拿战迁移/v3.2_waterloo_data_entry.md`
- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/RegionDataSet.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/App/AppContainer.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_terrain_rules.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_generals.json`：通过，无输出。
- `jq -e '(.terrain | keys | sort) == ["city","forest","fortress","hill","mountain","plain"]' WWIIHexV0/Data/napoleonic_terrain_rules.json`：通过，输出 `true`。
- `jq -e '.map.tiles | length == 12' WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，输出 `true`。
- `jq -e '. as $root | ($root.regions | length == 6) and ($root.hexToRegion | length == 12)' WWIIHexV0/Data/waterloo_1815_regions.json`：通过，输出 `true`。
- `jq -e '([.map.tiles[].regionId] | unique | length) == 6 and ([.initialUnits[].id] | unique | length) == (.initialUnits | length)' WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，输出 `true`。
- `jq -e '([.templates[].id] | unique | length) == (.templates | length)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e 'all(.templates[]; ([.components[].weight] | add) == 1)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -s '.[0].initialUnits as $units | (.[1].templates | map(.id)) as $templates | all($units[]; .templateId as $id | $templates | index($id) != null)' WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e '([.generals[].id] | unique | length) == (.generals | length)' WWIIHexV0/Data/generals.json`：通过，输出 `true`。
- `jq -e '(["commander_napoleon","commander_wellington","commander_blucher"] - ([.generals[].id] | unique) | length) == 0' WWIIHexV0/Data/generals.json`：通过，输出 `true`。
- `jq -e '([.generals[].id] | unique | length) == (.generals | length)' WWIIHexV0/Data/napoleonic_generals.json`：通过，输出 `true`。
- `jq -e '(["commander_napoleon","commander_wellington","commander_blucher"] - ([.generals[].id] | unique) | length) == 0' WWIIHexV0/Data/napoleonic_generals.json`：通过，输出 `true`。
- `swiftc -parse WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- `rg -n "germany|allies|Ardennes|Bastogne|Panzer|Guderian|Montgomery" WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json`：无命中。
- `rg -n "commander_napoleon|commander_wellington|commander_blucher" WWIIHexV0/Data/generals.json WWIIHexV0/Data/napoleonic_generals.json WWIIHexV0/Data/general_agents.json WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json`：命中 `generals.json`、`napoleonic_generals.json` 与 Waterloo JSON，未命中 legacy `general_agents.json`。
- 文档尾随空白检查：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。
- `rg -n "waterloo_1815|ScenarioCatalog|defaultPlayable|napoleonicTarget" WWIIHexV0/Data README.md update_log.md md/flow md/plan md/prompt/v3.0-拿战迁移`：确认 Waterloo 目标资源名集中在 `ScenarioCatalog` 和文档记录中。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `waterloo_1815_scenario.json` 与 `waterloo_1815_regions.json` 只是最小 schema slice，不能把 `defaultPlayable` 切到 `napoleonicTarget`。
- `ScenarioDefinition` 和现有 terrain / objective schema 仍是阿登时代兼容结构；拿战单位模板已有独立文件并已改用拿战 `ComponentType` raw value。v3.2 当时地形规则 JSON 尚未成为运行时权威，后续 v3.8 已接入 Waterloo 移动/战斗主路径；士气/队形/骑兵冲锋/炮兵准备、指挥官 Agent prompt 和胜利节奏仍需后续阶段继续迁移。
- `napoleonic_generals.json` 已建立部署层将领目录，但尚未替代 legacy `general_agents.json`，真实拿战 Agent personality 仍待 v3.4。
- 未修改 Xcode project；后续若新增 JSON 需要打包到 app bundle，必须由唯一指定改 project 的步骤处理并跑 `plutil -lint`。

## v3.3 - 拿战兵种 ComponentType 基础

完成日期：2026-07-05

性质：v3.3 起步记录。本节代表拿战兵种 raw value 和模板数据已经开始脱离 legacy 二战 component，但不代表士气、疲劳、队形、骑兵冲锋、炮兵准备或完整拿战战斗规则已经完成。

核心更新：

- `ComponentType` 保留 legacy `.tank/.motorizedInfantry/.infantry/.artillery`，新增拿战兼容 case：
  - `.lineInfantry`
  - `.lightInfantry`
  - `.cavalry`
  - `.guardInfantry = "guard"`
  - `.engineer`
  - `.supplyTrain`
- 为新 case 提供首版 `EffectiveStats`，继续通过现有 `attack/defense/movement/range/vision` 参与战斗和移动，不新增 morale / fatigue / formation 字段。
- 新增 `ComponentType.isInfantryLike`、`isArtilleryLike`、`isCavalryLike`、`isMobileLike`，以及 `Division.isCavalry`、`Division.isMobileFormation`。
- `napoleonic_unit_templates.json` 改用拿战 raw value：`lineInfantry`、`lightInfantry`、`cavalry`、`guard`、`engineer`、`artillery`；新增 `cavalry_reserve` 模板。
- `DataLoader.makeDivisions` 不再静默丢弃未知 component raw value；模板出现未知 component type 会生成 `DataValidationError`。
- `WarCommandExecutor`、`ZoneCommanderAgent` 的机动判断改用 `Division.isMobileFormation`。
- `EconomyState` / `EconomyRules` 的 infantry / mobile / artillery 权重判断改为读取 helper，避免拿战组件被完全按普通 manpower-only 处理。
- `UnitInspectorView`、`UnitTooltipView`、`UnitNode` 增加拿战 component 短码或类型标记：`LINE`、`LIGHT`、`CAV`、`GUARD`、`ENG`、`SUP`。
- 更新 `waterloo_1815_scenario.json` 的 `dataNotes`、README、flow、plan、总提示词和 v3.3 阶段记录。

关键文件：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/napoleonic_unit_templates.json`
- `WWIIHexV0/Data/waterloo_1815_scenario.json`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `md/prompt/v3.0-拿战迁移/v3.3_component_types_foundation.md`
- `README.md`
- `md/flow/flow.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/Division.swift WWIIHexV0/Core/EconomyState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/RegionDataSet.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Rules/EconomyRules.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/UnitTooltipView.swift WWIIHexV0/SpriteKit/UnitNode.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，无输出。
- `jq -e '([.templates[].id] | unique | length) == (.templates | length)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e 'all(.templates[]; ([.components[].weight] | add) == 1)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e '([.templates[].components[].type] | unique - ["artillery","cavalry","engineer","guard","lightInfantry","lineInfantry"] | length) == 0' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -s '.[0].initialUnits as $units | (.[1].templates | map(.id)) as $templates | all($units[]; .templateId as $id | $templates | index($id) != null)' WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `rg -n "motorizedInfantry|tank" WWIIHexV0/Data/napoleonic_unit_templates.json WWIIHexV0/Data/waterloo_1815_scenario.json`：无命中。
- 文档尾随空白检查：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- 新 `ComponentType` 只接入基础属性和轻量 helper，尚未实现拿战专属 morale / fatigue / formation / cavalry charge / artillery preparation。
- `ProductionKind`、经济生产 UI 和自动生产单位仍是二战语义。
- `UnitNode` 对骑兵仍复用既有单位图形结构，只改短码和机动斜线；发布级拿战军标需要后续 UI 切片。
- 未修改 Xcode project；新增 JSON 如果要进入 app bundle，仍需唯一指定 project 步骤处理。

## v3.4 - 拿战 Agent 分层基础

完成日期：2026-07-05

性质：v3.4 起步记录。本节代表默认 AI 上游已经从单纯元帅层扩展为“统治者战略姿态 -> 元帅战区指令”的数据合同；不代表完整 ChiefOfStaff / CorpsCommander / Diplomat Agent、真实 LLM、完整拿战 personality 或 UI 复盘都已完成。

核心更新：

- 新增 `StrategicPostureEnvelope`，记录 `schemaVersion`、`issuerId`、`turn`、`faction`、`countryId`、`posture`、`preferredFrontZoneId`、`targetRegionIds`、`attackThresholdAdjustment`、`reserveBias`、`strategicIntent`、`coalitionGuidance` 和 `rationale`。
- 新增 `StrategicPostureDecoder`，支持 fenced JSON / 纯 JSON，并校验 schema、issuer、turn、faction、front zone 归属和 region 存在性。
- `RulerAgent.resolvePosture(in:)` 生成 deterministic fenced JSON 后再经 decoder 校验；失败时只使用内部 deterministic fallback，不执行半成品外部输出。
- `TurnManager.runMarshalDirectiveTurn` 在默认 `.marshalDirective` 路径先调用 `RulerAgent.automatic(for:in:)`，把 `RulerDecisionRecord` 写入 `diplomacyState.rulerRecords`，再把姿态传给 `MarshalAgent`。
- `SimulatedMarshalLLMClient` 读取 `StrategicPostureEnvelope`，用 defensive / coalitionMaintenance / stabilizeFront / offensive 姿态调整攻守阈值、reserveBias、战略意图和 rationale。
- `AgentDecisionRecord.rawJSON` 现在串联展示 StrategicPosture JSON、TheaterDirective JSON 和编译后的 ZoneDirective JSON，便于审计“统治者想要什么、元帅做了什么”。
- 更新 README、flow、flowchart、plan、总提示词和 v3.4 阶段记录。

关键文件：

- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-拿战迁移/v3.4_agent_hierarchy_foundation.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/03_ai_zone_directive_pipeline.mermaid`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftuipro` 相关 Swift 语法检查：`swiftc -parse WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_terrain_rules.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_generals.json`：通过，无输出。
- `jq -e '([.templates[].id] | unique | length) == (.templates | length)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e 'all(.templates[]; ([.components[].weight] | add) == 1)' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -e '([.templates[].components[].type] | unique - ["artillery","cavalry","engineer","guard","lightInfantry","lineInfantry"] | length) == 0' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -s '.[0].initialUnits as $units | (.[1].templates | map(.id)) as $templates | all($units[]; .templateId as $id | $templates | index($id) != null)' WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- 旧 README / flow 统治者未接入口径扫描：无命中。
- 旧主链路统治者未接入口径扫描：无命中。
- 文档 / JSON 尾随空白扫描：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `StrategicPostureEnvelope` 当前来自 deterministic simulated output，尚未进入真实模型 prompt builder。
- 独立 ChiefOfStaff / CorpsCommander / Diplomat / Coalition Agent 仍未实现。
- `RulerDecisionRecord` 已写入状态，但 UI 复盘展示还未专门升级。
- 拿战战术名仍复用部分旧 `TacticName`；完整 line / column / square / cavalry charge / artillery preparation 仍需后续规则切片。

## v3.5 - 拿战后勤与预备队展示基础

完成日期：2026-07-05

性质：v3.5 起步记录。本节代表现有经济/生产兼容层已能在拿战 faction 下显示为后勤与预备队，并在完成排产时生成拿战 component formation；Waterloo 数据切片也已有最小 delayed reinforcement schedule 和 Waterloo 专用胜负节奏；`Division` 级最小 morale / fatigue / ammunition 战术消耗、恢复、UI 展示和 Marshal 前线警告已接入。不代表完整 ammunition / horses 经济账本、命令摩擦、高级士气/队形或完整滑铁卢战役规模已完成。

核心更新：

- 新增 `Faction.usesNapoleonicLogisticsVocabulary`，用于区分 legacy Germany / Allies 和 France / Anglo-Allied / Prussia / Austria / Russia / Spain 的后勤展示语义。
- `ProductionKind.displayName(for:)` 为拿战 faction 提供玩家可见预备队名：
  - `infantryDivision` -> `Line Infantry Reserve`
  - `panzerDivision` -> `Guard Detachment`
  - `motorizedDivision` -> `Cavalry Reserve`
  - `artilleryDivision` -> `Artillery Battery`
  - `supplyStockpile` -> `Supply Wagon`
- `EconomyResources.summary(for:)` 为拿战 faction 把底层 `manpower / industry / supplies` 显示为 `Recruits / Ammunition/Horses / Supplies`；legacy 路径仍显示 `MP / IC / SUP`。
- `EconomyRules.queueProduction`、回合结算日志、生产完成日志和无安全部署点日志改用 faction-aware 文案；拿战日志显示 `logistics` 而不是 `economy`。
- `EconomyRules.makeProducedDivision` 在拿战 faction 下改走 `makeNapoleonicProducedFormation`，完成排产后生成 line infantry、guard、cavalry、artillery、supply train 等拿战 component 组合；legacy faction 仍走旧 `.infantry / .panzer / .motorized / .artillery` factory。
- `EconomyPanelView` 在拿战 faction 下显示 `Reserves`、`Reserve Orders`、`Recruits`、`Ammunition/Horses`、`Supply Upkeep` 和拿战预备队按钮名；旧阿登路径保留原生产面板语义。
- 新增 `ReinforcementState` 和 `ScheduledReinforcement`，`GameState` 保存 pending delayed reinforcement 和已到场 id；旧存档缺字段时 decode 为 empty。
- `ScenarioDefinition` 新增可选 `reinforcements` 字段；旧阿登 JSON 不需要补字段。`DataLoader` 会解析并校验 reinforcement faction、unit template、entry hex 和可选 trigger controller。
- `EconomyRules.resolveFactionTurn` 新增 `resolveScheduledReinforcements`：只处理当前 active faction 的到期增援；入口必须在 entry hex 2 格内、己控、空置、passable 且非敌邻；不安全时保留 pending 并记录 reinforce 日志。
- `waterloo_1815_scenario.json` 新增 French Reserve Entry 后方入口 hex、`fr_imperial_guard_reserve` 第 5 回合到场和 `pr_bulow_iv_corps` 第 4 回合到场；`waterloo_1815_regions.json` 同步新增 French Ridge 后方入口 hex 映射。
- `VictoryRules` 按 `scenarioId` 分流，新增 Waterloo 最小胜负节奏：France 控制 Mont-Saint-Jean 即胜；到 `maxTurns` 时 Hougoumont、Mont-Saint-Jean 和 Prussian Arrival Road 未被 France 控制，则 Anglo-Allied 获胜。
- `Division` 新增 `morale`、`fatigue` 和 `ammunition` 字段，旧存档缺字段时分别按 component 默认值、0 和按 component 自动给满；低士气会降低 attack / defense 并可触发 retreatable 单位撤退，疲劳会降低 attack / defense / movement，低弹药或无弹药会降低弹药敏感单位火力。
- `CombatRules.effectiveAttack` 新增最小拿战战术地形修正：cavalry 在 plain 有轻量加成，攻击 hill / forest / mountain / city / fortress 受限；HOLD 重步兵可在 plain 压制 cavalry 冲击；ranged artillery 对 plain / hill 目标略有优势，对复杂/据点地形略受限。
- `CommandExecutor` 已把 move / attack / counterattack / hold 转成 morale / fatigue / ammunition 增减；`CommandValidator` 会用 `.moraleBroken` 拒绝 morale <= `Division.brokenMoraleThreshold` 的 move / attack，hold / allowRetreat / resupply 仍允许走各自校验；`SupplyRules.applyResupplyRest` 已按 supplied / lowSupply / encircled 分支恢复 strength、morale、fatigue 和 ammunition，撤退失败与包围损耗也会降低 morale。
- `HUDView`、`UnitInspectorView` 和 `UnitTooltipView` 已显示 pending reinforcements、平均 morale、平均 fatigue、readiness、单位 morale / fatigue / ammunition 和 shaken / broken / low ammunition 状态。
- `AgentContextBuilder` / `AgentPromptBuilder` 已把 morale / fatigue / ammunition 放入 legacy Agent D 摘要；`MarshalBattlefieldSummarizer` 已把 morale / fatigue / ammunition warning count 放入 `MarshalFrontSummary`，summary schema 升到 6，并用于防御优先级和状态说明。
- 新增 v3.5 阶段记录，并更新 README、flow、flowchart、plan 和总提示词。

关键文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Agents/AgentContexts.swift`
- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/waterloo_1815_scenario.json`
- `WWIIHexV0/Data/waterloo_1815_regions.json`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `md/prompt/v3.0-拿战迁移/v3.5_logistics_reinforcement_foundation.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Rules/CombatRules.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/EconomyRules.swift WWIIHexV0/Rules/SupplyRules.swift WWIIHexV0/Rules/VictoryRules.swift WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/UnitTooltipView.swift WWIIHexV0/Agents/AgentContexts.swift WWIIHexV0/Agents/AgentPromptBuilder.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，无输出。
- `jq -e '(.reinforcements | length) == 2 and ([.reinforcements[].id] | unique | length) == (.reinforcements | length)' WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，输出 `true`。
- `jq -s '.[0].reinforcements as $reinforcements | (.[1].templates | map(.id)) as $templates | all($reinforcements[]; .templateId as $id | $templates | index($id) != null)' WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `jq -s '.[0].map.tiles as $tiles | .[1].hexToRegion as $h2r | ($tiles | length) == 13 and ($h2r | length) == 13 and all($tiles[]; "\(.q),\(.r)" as $key | $h2r[$key] != null)' WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json`：通过，输出 `true`。
- `jq '(.map.tiles | map("\(.q),\(.r)")) as $tileKeys | all(.reinforcements[]; "\(.entryCoord.q),\(.entryCoord.r)" as $key | $tileKeys | index($key) != null)' WWIIHexV0/Data/waterloo_1815_scenario.json`：通过，输出 `true`。
- `jq -e '([.templates[].components[].type] | unique - ["artillery","cavalry","engineer","guard","lightInfantry","lineInfantry"] | length) == 0' WWIIHexV0/Data/napoleonic_unit_templates.json`：通过，输出 `true`。
- `rg -n 'Panzer Division|Motorized Division|Label\(kind\.displayName,|Text\("Production"\)|Text\("Queue"\)|resourceSummary\(kind\.cost\)' WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/Rules/EconomyRules.swift`：无命中。
- `rg -n 'kind\.displayName[^\(]' WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/Rules/EconomyRules.swift`：无命中。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/v3.0-拿战迁移 md/plan/plan.md WWIIHexV0/Data/*.json`：无命中。
- `rg -n "^<<<<<<<|^=======|^>>>>>>>" AGENTS.md README.md update_log.md md/flow WWIIHexV0 MapEditor md/prompt/v3.0-拿战迁移 md/plan/plan.md`：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `EconomyResources.industry` 在拿战展示层暂时复用为 `Ammunition/Horses` 复合资源；后续若拆真实 ammunition / horses 经济字段，需要 schema 与存档迁移。
- `ProductionKind.panzerDivision`、`motorizedDivision` raw case 仍保留兼容，源码枚举名尚未迁移；玩家可见层已按拿战 faction 改名。
- 当前 delayed reinforcement schedule 只支持最小 turn / objective trigger 和安全入口部署；不支持随机迟到、道路阻塞、同盟命令摩擦、多入口优先级或完整普军来援曲线。
- 完整炮兵准备、显式骑兵冲锋命令、方阵/队形、高级士气、概率式命令拒绝、真实 ammunition / horses 经济账本和完整滑铁卢胜负节奏仍未落地。
- 单文件 `swiftc -parse` 只能确认语法，不等于 Xcode build、SwiftUI 预览或运行时验证。

## v3.6 - 拿战 UI token 与状态面板可读性基础

完成日期：2026-07-05

性质：v3.6 起步记录。本节代表发布级拿战 UI 收口开始从共享视觉 token、HUD、单位详情、tooltip 和预备队面板切入；不代表完整 19 世纪地图美术、计划箭头、指挥官头像、战报回放、移动端视觉验收或默认滑铁卢启动已经完成。

核心更新：

- 新增 `NapoleonicDesignTokens`，集中保存面板 padding、圆角、描边、拿战蓝、红、黄铜色以及 steady / warning / critical 状态色。
- `HUDView` 复用 token，拿战 faction 下标题使用拿战 tint；morale、fatigue 和 readiness 从纯数字改为 `Steady` / `Shaken` / `Broken`、`Fresh` / `Tired` / `Exhausted`、`Ready` / `Strained` 文案加颜色状态。
- `HUDView` 对无单位状态做 faction-aware 显示：legacy 为 `No Units`，拿战为 `No Formations`，避免空列表平均 morale = 0 被误判为 broken；拿战路径还把顶部按钮和增援计数显示为 `End Orders`、`Reserve Arrivals`。
- `ScenarioCatalog.displayName(for:)` 成为 HUD、RootGameView accessibility label 和 SpriteKit empty board title 的场景标题来源；移除这些玩家可见位置的 `Ardennes V0` 硬编码。
- `GameState.initial()` fallback 日志从 `Ardennes V0 scenario initialized.` 改为中性 `Legacy scenario initialized.`，避免 fallback 路径继续暴露旧硬编码标题。
- `MapDisplayLayer.displayName(for:)` 保留 legacy 图层名，但在拿战 faction 下把主界面 map layer picker 显示为 `Sector`、`Initial Wing`、`Active Wing`、`Contact`、`Corps`。
- `RootGameView` compact info tabs 在拿战 faction 下显示 `Formation`、`Sector`、`Dispatches`、`Logistics`、`Coalition` 等术语；legacy faction 仍保留 Unit / Region / Log / Economy / Diplomacy。
- `EventLogView` 在拿战 faction 下把标题显示为 `Dispatches`，并把部分日志分类从 `Reinforce` / `Theater` / `Region` / `Diplomacy` 显示为 `Reserve` / `Wing` / `Sector` / `Coalition`。
- `AgentPanelView` 的空状态不再显示 `guderian` / `MockAI` 占位，改为 `No agent selected` / `No provider` 和中性 raw JSON placeholder。
- `UnitInspectorView`、`RegionInspectorView`、`CommandPanelView`、`GeneralCommandPanelView` 和 `DiplomacyPanelView` 在拿战 faction 下继续收口面板内术语：Formation Details、Sector、Orders、Corps Command、Coalition、Active Wing、Corps Sector、Contact Line、Withdrawal Orders、Attack Sector 等；legacy faction 保留旧显示。
- `GeneralProfileView` 和 `AgentPanelView` 接收 active faction，拿战 faction 下将 `General Profile` / `Assigned Units` / `AI Decision` / `Zone Directives` 等显示为 `Commander Profile` / `Assigned Formations` / `Command Dispatch` / `Corps Directives`；`EventLogView` 的 front change 分类显示为 `Contact`。
- `AppContainer` 的 `interactionLog` 写入改为 faction-aware 显示：拿战 faction 下玩家命令、军团命令、选择反馈和 AI 回合摘要显示为 `Order`、`Formation`、`Sector`、`Corps Order`、`Reserve Order`、`Command Dispatch`、`Simulated Staff` 等术语；legacy faction 保留旧显示。
- `RuleEngine`、`CommandExecutor` 和 `WarCommandExecutor` 的玩家可见结果/事件也切换拿战术语：`CommandResult.message` 显示 `Order executed` / `Order rejected`，校验错误显示 formation / sector / reserves 语义，HOLD / allow retreat / dynamic theater / front change 事件显示 `Hold Line`、`Withdrawal`、`active wing`、`Contact`；`WarCommandExecutor` 的动态推进判断同步使用 `DiplomacyState.isFriendly`。
- `UnitInspectorView` 复用 token 和带 SF Symbol 的 `Label` 展示 morale、fatigue、ammunition 和 status；状态不只靠颜色，也带 `Broken`、`Shaken`、`Low`、`Empty` 等文字。
- `UnitTooltipView` 同步 morale / fatigue / ammunition 的状态文案和 token 描边；拿战 faction 下 tooltip label / VoiceOver 使用 Formation、Formation Strength、Withdrawal、Orders，并把兵种码切到 LINE / LIGHT / CAV / ART / GUARD / ENG / SUP。
- `UnitNode` 保留 legacy NATO/二战符号路径，但拿战 faction 下改绘拿战 formation symbol：线列步兵双线、轻步兵散点、骑兵 V、炮兵轮炮、近卫星标、工兵桥线、补给车；棋子底部状态码把 retreatable 从 legacy `R` 切为拿战 `W`。
- `BoardScene` 从 `ReinforcementState.pending` 只读绘制增援入口 marker：非 observer 只显示当前 viewer faction 或友军 pending 增援入口，observer 显示全部非 neutral pending 入口；拿战 faction marker 显示 `RES` 和最早到达回合，不改变规则层安全入口部署。
- `BoardScene` 从 `MapState.objectives` 只读绘制目标点 marker：按现有 `ObjectiveType` 显示村庄、据点/农庄和道路/补给目标图标；marker 读取 visibility，frontLine 图层隐藏，不改变胜利、占领或补给规则。
- `BoardScene` 从 `WarDirectiveRecord` 只读绘制 recent directive replay：跳过玩家计划线已有的 `issuerId == "player"` 记录，非 observer 只显示 viewer faction 或友军记录，observer 显示全部非 neutral 记录；攻击记录画轻量箭头，防御/无目标记录画圆环，`fireCoverage` / breakthrough / pincer / feint 等 tactic 在终点显示瞄准圈、楔形、钳形或扰动 marker，不改变 directive 生成或执行。
- `EconomyPanelView` 复用 token，拿战 faction 下的 reserves 面板标题、按钮 tint、资源数值和 ready 状态有统一视觉语义。
- 新增 v3.6 阶段记录，并更新 README、flow、plan、总提示词和 update_log。

关键文件：

- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/MapDisplayLayer.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `md/prompt/v3.0-拿战迁移/v3.6_napoleonic_ui_polish_foundation.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/Core/PlayerCommandState.swift WWIIHexV0/Core/FrontZone.swift WWIIHexV0/Core/FrontZoneId.swift WWIIHexV0/Core/FrontZoneSegment.swift WWIIHexV0/Core/WarDeploymentState.swift WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Core/WarDirectiveRecord.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/Rules/RuleEngine.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/SpriteKit/MapDisplayAdapter.swift WWIIHexV0/SpriteKit/UnitNode.swift WWIIHexV0/UI/PlatformStyles.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/CommandPanelView.swift WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/UnitTooltipView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/SpriteKit/BoardScene.swift`：通过，无输出。
- `rg -n "Ardennes V0" WWIIHexV0/UI WWIIHexV0/SpriteKit WWIIHexV0/Core`：无命中。
- `rg -n "guderian|MockAI" WWIIHexV0/UI WWIIHexV0/SpriteKit WWIIHexV0/Core`：仅命中 `AgentPanelView` 中把 raw provider `MockAI` 映射为 `Simulated Staff` 的兼容判断，不是拿战可见文案。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/flow/03_ai_zone_directive_pipeline.mermaid md/prompt/v3.0-拿战迁移 md/plan/plan.md WWIIHexV0/Data/*.json`：无命中。
- `rg -n "^<<<<<<<|^=======|^>>>>>>>" AGENTS.md README.md update_log.md md/flow WWIIHexV0 MapEditor md/prompt/v3.0-拿战迁移 md/plan/plan.md`：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `swiftc -parse` 只能确认语法，不等于 Xcode build、SwiftUI preview、运行时布局或真实视觉验收。
- `NapoleonicDesignTokens` 为避免改 project 文件暂放在已入 target 的 `PlatformStyles.swift`；后续若统一 project 维护，可拆成独立文件并更新 `.pbxproj`。
- 当前 UI 仍保留默认阿登入口、源码兼容命名和部分 legacy 英文；发布级 v3.6 还需要继续清理 RootGameView 布局、SpriteKit 图层、事件日志、AI 复盘和主界面布局。

## v3.7 - 拿战试玩闭环新局基础

完成日期：2026-07-05

性质：v3.7 起步记录。本节代表新局配置入口、玩家阵营选择、开局顺序选项、Waterloo 资源打包路径、3 个本地试玩保存/继续 slot、Slot 1 旧单槽 key 兼容读取、最小 slot label / 槽名自定义、基础试玩设置持久化、本地坏快照/坏设置恢复提示、可关闭的非阻塞短引导、无可行动反馈、AI dispatch issue 可见诊断、诊断/拒绝原因预览和 AI 回放可读摘要 / Recent Dispatch Timeline 已经起步；不代表发布级命名存档、完整迁移器、文件导出、云同步、完整设置、完整引导、完整战斗时间线/动画回放、完整运行时错误恢复或完整滑铁卢试玩闭环已经完成。

核心更新：

- `AppContainer` 新增 `currentScenario`，并将 `playerFaction` 与 `generalRegistry` 改为可随新局切换的 published state；既有外部读取仍保持 `private(set)`。
- 新增 `AppContainer.startNewGame(scenario:playerFaction:)`，按所选 `ScenarioCatalogEntry` 重载 `GameState`、对应 `GeneralRegistry` 和玩家控制阵营，清空 selection、highlight、interaction log、agent decision record 与 recent directive replay，并保留所有行动仍走既有命令管线。
- `resetGame()` 不再固定重载 `DataLoader.loadInitialGameState()`，而是按当前 scenario 和当前玩家阵营重载。
- `AppContainer` 新增 `startsNewGameAtPlayerFaction`；`startNewGame` 新增 `startsAtPlayerFaction` 参数，开启时在新局装配阶段把 active faction / phase 指定到玩家所选 faction，清空本回合玩家锁定，并重置该 faction 已部署 formation 的 `hasActed`。
- `AppContainer.normalizeCommandPhase` 会在试玩 runtime refresh、继续恢复和保存 snapshot 前，把拿战 active faction 的 phase 按当前 `playerFaction` 归一：玩家控制 faction 为 `.playerCommand`，其它非 neutral 拿战 faction 为 `.aiCommand`；legacy Germany / Allies phase 仍保留旧 raw value 兼容。
- 新增 `AppContainer.availablePlayerFactions(for:)`，从 scenario JSON 的 `factions` 派生可选非 neutral 阵营，并按 `Faction.turnOrderPriority` 排序；读取失败时 fallback 到 Waterloo 或 legacy faction 列表。
- 新增 `GameSaveSlot` 与 `GameSaveSnapshot`，以 schemaVersion 1 保存 `scenarioId`、`playerFaction`、`startsAtPlayerFaction`、`savedAt` 和 `GameState`；当前存储为 Slot 1 / Slot 2 / Slot 3 三个 `UserDefaults` 本地试玩 slot，Slot 1 兼容读取旧单槽 key `WWIIHexV0.savedGameSnapshot.v1`；slot label 另存到独立 `UserDefaults` key，不写入 snapshot，不升级 schemaVersion。
- `AppContainer.saveCurrentGame(to:)` 写入目标 slot snapshot 并更新 `savedGameSummaries` / `lastCommandMessage` / interaction log；`AppContainer.setSaveSlotLabel(_:for:)` 会持久化 32 字以内 slot label，保存/继续/清理消息优先显示自定义 label；`continueSavedGame(from:)` 只接受当前 schemaVersion，恢复时必须匹配当前 `ScenarioCatalog` 中存在的 snapshot scenario，找不到 scenario 时把该 slot 标为不可用并显示原因；恢复成功时重载 `GeneralRegistry`、重新 bootstrap / assign generals，清空 selection、highlight 和本地 replay state，然后调用现有 `runAIIfNeeded()` eligibility gate，使 Staff 模式（包括 observer + Staff）在恢复到 AI-eligible active faction 时可继续 simulated staff，Manual 仍不自动 dispatch，observer + Manual 仍只读。
- `GameSaveSnapshot.load(slot:)` 区分 missing / loaded / unavailable；不可解码、schema 不兼容或引用当前构建不存在 scenario 的快照会通过 `AppContainer.savedGameRecoveryMessages` 与 `NewGameSetupView` Continue 区块按当前 slot 显示原因，并保留 `Clear Saved` 清理入口。
- 新增 `ReplayDetailLevel`，提供 Concise / Standard / Full 三档，控制事件日志条数、metadata 粒度、AI 面板 directive 条数、Staff Summary / Issue Preview / Recent Dispatch Timeline、context summary 和 raw JSON 显示。
- 新增 `AICommandPace`、`PlaytestAIControlMode` 与 `PlaytestSessionSettings`；`AppContainer.bootstrap()` 读取 `UserDefaults` key `WWIIHexV0.playtestSessionSettings.v1`，把 observer mode、map layer、`ReplayDetailLevel`、AI Pace、AI Control、Guide Notes、Reduce Motion 和 Text Size 作为试玩偏好持久化。AI Pace 只在 simulated staff 行动前插入短延迟，不改变 AI 输出、命令校验或规则执行；Reduce Motion 开启时跳过这段本地等待。
- `PlaytestSessionSettings.loadResult` 区分 missing / loaded / resetToStandard；偏好数据无法解码时会删除损坏值、恢复标准设置，并通过 `AppContainer.sessionSettingsRecoveryMessage` 在 interaction log 与 Settings 区块提示。
- 新增 `PlaytestGuideCue`，在玩家首次选择 formation、首次选择炮兵/远程单位、首次选择骑兵、首次结束命令时向 interaction log 追加一次性 `Staff note`；提示不弹 modal、不阻塞地图，也不改变规则状态。
- `AppContainer` 新增 `replayDetailLevel`、`aiCommandPace`、`aiControlMode`、`playtestGuideCuesEnabled`、`playtestTextSize`、`reduceMotionEnabled` 和 `applySessionSettings(observerModeEnabled:mapDisplayLayer:replayDetailLevel:aiCommandPace:aiControlMode:playtestGuideCuesEnabled:playtestTextSize:reduceMotionEnabled:)`，把 observer mode、当前 map layer、回放详细度、AI 节奏、AI 自动触发模式、短引导开关、文本大小和减少动态效果作为本地试玩设置统一应用并持久化。
- 新增 `PlaytestTextSize`，提供 Compact / Standard / Large 三档；`NewGameSetupView` 的 Text Size picker 会持久化该设置，`EventLogView` 与 `AgentPanelView` 会使用 Dynamic Type 字体样式调整标题、metadata、正文、raw JSON 和行距。
- `NewGameSetupView` 新增 `Guide Notes` toggle；关闭后 `AppContainer.appendPlaytestCueIfNeeded` 不再写入首次 formation / artillery / cavalry / ending orders 的短 `Staff note`。
- `AppContainer.playerOrdersStatusMessage` 会在玩家命令阶段统计本方未毁灭且未 acted 的 formation / unit；`CommandPanelView` 未选中单位时显示仍有几支可行动或全部已用完；Manual 模式且当前 active faction 是非玩家时，空态会提示用 End Orders 手动推进该 faction；observer + Staff 会提示用 End Orders 触发 staff dispatch，observer + Manual 保持 orders disabled，macOS End Turn 菜单也跟随 `canAdvanceOrders` 禁用。
- `AppContainer.aiNoActionFeedbackMessage` 会在 AI 回合结束后检查 `AgentDecisionRecord.commandResults`，若没有非 End Turn 的已执行战场命令，则向 interaction log 追加 `Staff note` / `AI note`；record-level 诊断会先由 `aiDiagnosticFeedbackMessages` 统一写入可见的 `Command dispatch issue` / `AI issue`。
- `AppContainer` 新增本地 `deliveredPlaytestCues`，新局或继续时清空，只用于控制短引导重复次数；不写入 `GameState` 或存档。
- `AppContainer.clearSavedGame(slot:)` 会删除当前 slot 快照、清空对应 `savedGameSummaries` / `savedGameRecoveryMessages` 并写入 interaction log；Slot 1 清理时也会删除旧单槽 key，用于坏快照或旧试玩快照恢复；清理快照不会删除 slot label。
- `NewGameSetupView` 会把 Start、Save Current、Continue Saved 和 Clear Saved 的回调结果显示在 sheet 内 Status 区块；开始或继续失败时 sheet 保持打开并显示 `AppContainer.lastCommandMessage`，保存或清理成功也会给出本地确认。
- 新增 `NewGameSetupView`，从 HUD 新局按钮打开 sheet，默认显示 Waterloo 1815 数据切片并隐藏 legacy scenario，打开 `Archived Campaigns` 后才显示 `ScenarioCatalog.all` 中的阿登 legacy；玩家可选择控制阵营，并用 `Opening Turn` toggle 决定是否由玩家所选 faction 先行动；sheet 也暴露 Save Slot、Slot Name / Rename Slot、Observer Mode、Map Layer、Dispatch Detail、AI Pace、AI Control、Guide Notes、Reduce Motion、Text Size、坏设置恢复提示、坏快照 Clear Saved 和最近操作 Status，通过 `AppContainer` 调用新局、slot label 持久化、保存、继续、清理快照和 settings setter，不直接修改 `GameState`。
- AI Control 已起步：`PlaytestAIControlMode.simulatedStaff` 为默认，保持非 observer 下玩家 faction 手动、其它非 neutral faction 自动 simulated staff；observer + Staff 可触发 staff dispatch；`runAISequence` 以当前 turn order faction 数量为有限上限，连续处理非玩家 AI faction 直到回到玩家方或 AI 资格失效；`.manualAdvance` 只停用自动 dispatch 触发，非 observer 下 HUD / CommandPanel End Orders 仍提交 `Command.endTurn` 并由 `RuleEngine` 推进当前 active faction；observer + Manual 保持只读并禁用 End Orders，`AppContainer.submit(_:)` 也会拒绝 observer 直接命令；非玩家 active faction 在 Manual 下会显示 Manual Dispatch / 手动推进提示；Manual 切回 Staff、开启 observer 或 Continue 恢复到 AI-eligible active faction 后会重新调用 `runAIIfNeeded()` gate 恢复自动触发，不改变 AI 输出、directive schema、`WarCommandExecutor` 或 `GameState`。
- `EventLogView` 和 `AgentPanelView` 接收 `ReplayDetailLevel` 与 `PlaytestTextSize`：Concise 降低日志/复盘密度，Standard 保持默认可读性，Full 展示 raw JSON 和 record id 等审计信息；Text Size 只调整本地日志/复盘面板的动态字体层级和行距。
- `AgentPanelView` 新增只读 Staff Summary / Dispatch Summary、Issue Preview 和 Recent Dispatch Timeline，从当前 `AgentDecisionRecord` 与最近 `WarDirectiveRecord` 聚合执行数、拒绝数、问题数、focus sector / target、最新 tactic、`AgentDecisionRecord.errors`、`CommandResultSummary.errors` 和 `WarDirectiveRecord.diagnostics`，并把最近 directive 按 turn / scope / target / tactic / status / 首要拒绝或诊断原因摘要成可读时间线；Concise 下隐藏逐条 command result / directive card，只保留短摘要、时间线与最多一条全局问题预览，Full 下可看完整明细和 raw JSON。
- `AppContainer.runAISequence` 会聚合连续 AI faction 的 `AgentDecisionRecord.errors`，避免多 faction 自动 dispatch 时早期错误被最后一个 record 覆盖；若有限步数 guard 结束后当前 active faction 仍符合 AI 自动触发条件，会追加 dispatch paused 诊断，提示自动处理已停止以避免循环。
- `TurnManager.executeDirectiveEnvelope` 会把默认 directive 管线的 AI end-turn 失败同步进诊断型 `WarDirectiveRecord`，让 Staff Summary / Issue Preview / Recent Dispatch Timeline 除了 `AgentDecisionRecord.errors` 外也能看到该问题。
- `HUDView` 接收 `playerFaction`、`PlaytestAIControlMode` 和 observer 状态，phase 显示改为由 active faction、玩家阵营、AI Control 和 observer 共同推导：玩家回合显示 `Your Orders` / `Player Command`，非玩家 Staff 显示 `Staff Dispatch`，Manual 显示 `Manual Dispatch`，observer Manual 显示 `Manual Observation`，避免拿战玩家回合仍显示 `AI Command` 或手动推进阶段被误读成自动 staff。
- `Faction` 和 `ScenarioCatalogEntry` 增加 `Identifiable`，支撑 SwiftUI picker / ForEach 的稳定 id。
- `WWIIHexV0.xcodeproj/project.pbxproj` 将 `NewGameSetupView.swift` 加入 iOS 与 macOS target sources，并将 Waterloo 与 napoleonic JSON 加入 iOS 与 macOS bundle resources，保证 `DataLoader` 的 `Bundle.main` 加载路径可用。
- 新增 v3.7 阶段记录，并更新 README、flow、flowchart、plan、总提示词和 update_log。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/App/AICommandPace.swift`
- `WWIIHexV0/App/GameSaveSnapshot.swift`
- `WWIIHexV0/App/PlaytestSessionSettings.swift`
- `WWIIHexV0/App/ReplayDetailLevel.swift`
- `WWIIHexV0/App/PlaytestGuideCue.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/NewGameSetupView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `WWIIHexV0/Data/waterloo_1815_scenario.json`
- `WWIIHexV0/Data/waterloo_1815_regions.json`
- `WWIIHexV0/Data/napoleonic_terrain_rules.json`
- `WWIIHexV0/Data/napoleonic_unit_templates.json`
- `WWIIHexV0/Data/napoleonic_generals.json`
- `md/prompt/v3.0-拿战迁移/v3.7_napoleonic_playtest_loop_foundation.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/PlayerCommandState.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/App/AICommandPace.swift WWIIHexV0/App/ReplayDetailLevel.swift WWIIHexV0/App/PlaytestSessionSettings.swift WWIIHexV0/App/PlaytestGuideCue.swift WWIIHexV0/App/GameSaveSnapshot.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/App/WWIIHexV0MacApp.swift WWIIHexV0/Turn/TurnManager.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/NewGameSetupView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/CommandPanelView.swift`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json WWIIHexV0/Data/napoleonic_unit_templates.json WWIIHexV0/Data/napoleonic_generals.json WWIIHexV0/Data/napoleonic_terrain_rules.json`：通过，无输出。
- `rg -n "Staff [/] observer|Staff[/]observer|Manual[[:space:]]仍等待|Manual[[:space:]]等待|玩家仍.{0,2}通过" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/plan/plan.md md/prompt/v3.0-拿战迁移`：无命中。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/flow/03_ai_zone_directive_pipeline.mermaid md/prompt/v3.0-拿战迁移 md/plan/plan.md WWIIHexV0/App/AppContainer.swift WWIIHexV0/App/WWIIHexV0MacApp.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/CommandPanelView.swift WWIIHexV0/UI/RootGameView.swift`：无命中。
- `rg -n "^<<<<<<<|^=======|^>>>>>>>" AGENTS.md README.md update_log.md md/flow WWIIHexV0 MapEditor md/prompt/v3.0-拿战迁移 md/plan/plan.md`：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- `swiftc -parse` 只能确认语法，不等于 Xcode build、SwiftUI sheet 行为、Bundle resource 运行时加载或 macOS/iOS 视觉验收。
- `Opening Turn` 只处理新局开始时的 active faction；若关闭该选项，仍依赖既有 `advanceOrRunAI()` / `runAIIfNeeded()` 让 scenario 开局的非玩家 faction 走 AI。继续存档成功后也会调用同一个 AI eligibility gate，但尚未做运行时视觉/交互重测试。
- `GamePhase.legacyCompatibleCommandPhase(for:)` 对拿战 faction 仍会返回 `.aiCommand` 作为规则层旧 helper；`AppContainer.normalizeCommandPhase` 已在试玩 runtime / save 边界按玩家控制权归一拿战 phase，但还不是全项目 schema 级 phase 迁移。
- Waterloo 仍是小规模数据切片；可从新局加载不等于完整可玩滑铁卢战役。
- 保存/继续仅有 schemaVersion 1 三槽本地试玩快照、Slot 1 旧 key 兼容读取、最小 slot label、坏快照/未知 scenario 快照可见提示和 Clear Saved 清理入口，没有发布级命名存档、文件导出、云同步、自动 schema 迁移器或运行时恢复验收；当前设置持久化 observer / map layer / replay detail / AI Pace / AI Control / Guide Notes / Reduce Motion / Text Size，坏设置只会重置为标准设置；AI Control 尚未跑运行时视觉/交互重测试，Manual 只停用自动 dispatch，非 observer 下依赖 End Orders 规则推进，observer + Manual 保持只读，当前仅补充 HUD / CommandPanel 可读提示和禁用状态；Text Size 尚未覆盖全 app，只覆盖日志和 AI replay 面板；Reduce Motion 只覆盖本地 AI pacing delay，尚未覆盖未来 SpriteKit timed animation；短引导只覆盖四类一次性 staff note 且可关闭；无行动反馈只覆盖本方可行动数量和 AI 无有效战场命令；AI issue 诊断只覆盖 record-level 错误、directive end-turn 失败、拒绝原因预览和 AI 连跑 guard 暂停提示；AI 回放只新增只读摘要、Issue Preview、Recent Dispatch Timeline 和明细密度控制；完整引导、完整战斗回放、完整错误恢复、完整 Waterloo 规模和运行时视觉验收仍需后续版本补齐。

## v3.8 - 拿战发布候选默认入口起步

完成日期：2026-07-05

性质：v3.8 起步记录。本节代表默认 playable 场景已从阿登 legacy 切到 Waterloo 1815 数据切片，并同步发布候选文档口径；不代表完整滑铁卢战役、发布级 UI、Xcode build、模拟器/真机启动、长回合观察者模式或发布候选运行时验收已经完成。

核心更新：

- `ScenarioCatalogEntry` 新增 `defaultPlayerFaction`；阿登 legacy 默认为 `.allies`，Waterloo 1815 默认为 `.france`。
- `ScenarioCatalog.defaultPlayable` 已切到 `waterloo1815DataSlice`，`ScenarioCatalog.napoleonicTarget` 继续指向同一 Waterloo 数据切片；`ScenarioCatalog.all` 现在把 Waterloo 放在阿登前面，阿登仍作为 legacy scenario 保留，但 `NewGameSetupView` 默认只展示非 legacy scenario，需打开 `Archived Campaigns` 才显示 legacy 新局入口。
- `ScenarioCatalog.waterloo1815DataSlice.displayName` 从 `Waterloo 1815 Data Slice` 调整为 `Waterloo 1815`，但文档继续说明它仍是小规模数据切片，不是完整发布战役。
- `ScenarioCatalog.entry(for:)` 新增 runtime id alias 解析；阿登 legacy 的 catalog id 仍是 `ardennes_v0`，但 MapEditor legacy JSON 的 `id/scenarioId` 是 `mapeditor_scenario`，两者现在会解析到同一个 `ScenarioCatalog.ardennesLegacy`；`DataLoader.loadGameState(ScenarioCatalogEntry)`、保存 snapshot 和继续恢复都会把 `GameState.scenarioId` 归一为 catalog id，用于存档恢复、slot summary、`ScenarioCatalog.displayName(for:)`、legacy 数据校验和未来 scenario-specific 规则判断；`DataLoader.loadInitialGameState()` 仍保留为 legacy / probe fallback，不作为主 app 默认启动入口。
- `AppContainer.bootstrap()` 改为按 `ScenarioCatalog.defaultPlayable` 读取默认场景、默认玩家阵营和场景专用 `GeneralRegistry`；若默认 Waterloo 加载失败，不再自动打开阿登 legacy，而是保留 Waterloo 场景元数据、构造 1x1 inert 恢复地图并提示玩家打开 `New Campaign` 切换到可用 scenario，避免默认发布候选入口静默暴露 Germany / Panzer / Guderian 等 legacy 内容，也避免 0x0 map 进入 SpriteKit layout/camera 产生非有限坐标。
- 将领目录错误改为可见：启动恢复态若场景已坏，可降为空 `GeneralRegistry` 并写入诊断；默认场景已成功加载但启动阶段二次读取将领目录失败时，会改用同一 1x1 inert 恢复态，不再让正常 Waterloo 局面带 `.empty` commander registry 继续运行；`startNewGame` 和 `continueSavedGame` 的将领目录加载失败会保留当前状态并返回失败，继续 slot 保留摘要并显示 recovery message，不再静默打开无将领分配的局面。
- `GameSaveSnapshot.Summary` 新增非持久化 `scenarioId`，用于 UI 判断 slot 是否属于 archived scenario；默认 Waterloo sheet 下旧阿登 / Germany / Allies 存档只显示中性归档占位、`Show Archived` 和 `Clear Saved`，打开 `Archived Campaigns` 后才显示 forces 详情和 `Continue Saved`，并把 scenario / player faction picker 同步到 snapshot，不删除旧 key 或禁用恢复路径。
- `NewGameSetupView` 不再在默认 Campaign 区块展示 raw `migrationStage`，避免 `v3.2_data_slice` / `legacy_wwii` 这类迁移字段进入玩家默认 UI。
- `DataLoader.loadGameState` 会复用已加载并校验过的 `GeneralRegistry` 做部署层将领分配，`assignGenerals` 不再二次 `try? loadGeneralRegistry(...) ?? .empty`，避免校验通过后因第二次读取失败而静默清空部署层将领。
- 默认 Waterloo replay 展示继续收口：`MockAI+MarshalDirective` 等 provider 在拿战 UI / interaction log 下包装为 `Simulated Staff`，Standard context summary 使用 staff display name 而不是 raw `*_mock_commander` id，EventLog phase metadata 在拿战 faction 下显示 `Orders` / `Staff Dispatch`。
- Legacy stored Guderian `TurnManager` 兼容特例现在同时校验 `currentScenario` 和 runtime `GameState.scenarioId` 都匹配 Ardennes legacy，避免外部注入状态误触发旧德军 manager；默认 Waterloo 仍走动态 simulated staff / marshal directive 管线。
- `DataLoader.loadGameState` 会校验 scenario 的 `initialPhase`、`playerFaction` 和 `aiFaction` 是否可解析并属于 declared factions，不再用 Germany / Allies fallback 吞掉坏 Waterloo JSON。
- `DataLoader.loadGameState` 在构造 `GameState` 前新增 catalog-agnostic 资源校验：scenario/region id alias、tile controller、supplyFaction、riverEdges、raw `hexToRegion` key、tile region 反向映射、initial/reinforcement unit faction、坐标重叠、缺失 tile/template/objective/general 引用、victory target faction、region displayHex / representativeHex 和 unit template component 权重都会被拦截，避免默认 Waterloo 静默吞掉坏 JSON。
- `DataLoader` 继续补齐 Waterloo 资源自校验：将领目录在构造 `GeneralRegistry` 前会检查重复 general id、空 id/name、loyalty/satisfaction 范围；场景校验会检查将领 faction、preferred region/theater、keyLocations 的重复 id / coord / faction / objective / kind、unit template maxHP / 空 components / component weight、initial unit 与 reinforcement 的 hp/facing/supplyState/retreatMode，避免重复 id trap 或构造阶段默认值掩盖坏 JSON。
- `DataLoader.loadGameState` 会把 scenario JSON 的 `victoryConditions` 映射为 `GameState.victoryConditions`；`GameState` 旧存档 decode 缺字段时回落 `[]`；`VictoryRules` 的 Waterloo 分支按 `french_break_center` / `coalition_hold_until_prussia` 读取 objective id、target faction 和决定回合，旧存档缺 runtime condition 时补内置 fallback。
- `DataLoader.loadGameState(ScenarioCatalogEntry)` 会把场景 terrain JSON 映射为 `GameState.terrainRules`；旧存档缺字段时回落 `.legacy`；Waterloo 主路径 `MovementRules` / `CombatRules` 读取 scenario movement / road / river / defense 值，`WarCommandExecutor` 和 `ZoneCommanderAgent` 的 breakthrough / defensive sorting 也同步读取同一 rule set。
- `RegionVictoryRules` 加入 `ScenarioCatalog.ardennesLegacy` guard，只在阿登 legacy / MapEditor legacy runtime id 下评估 Bastogne / St. Vith region 胜负；Waterloo 或后续拿战 scenario 即使未来误接 `RegionRuleSystem.analyze`，也不会泄漏阿登胜负口径。
- `VictoryRules` 的主回合 legacy Bastogne / St. Vith / unit elimination / German armor supply 判定也加入 `ScenarioCatalog.ardennesLegacy` guard；非 Waterloo、非阿登的新 scenario 若尚未接通 victory DSL，会保持 ongoing，不再掉入阿登胜负条件。
- 默认入口改为不预先创建旧德军 stored `TurnManager`。AI 回合仍通过 `turnManager(for:state:)` 按当前 active faction 动态构建，并继续走 `WarCommandExecutor` / `RuleEngine`；stored Guderian manager 兼容特例只允许在 Ardennes legacy 场景内触发。
- `AppContainer.startNewGame` 与 `NewGameSetupView.reconcileSelectedFaction()` 在当前选中 faction 不属于目标 scenario 时，优先回落到该 scenario 的 `defaultPlayerFaction`，再退到可选阵营列表首项，避免从 Waterloo 切回阿登时默认落到 Germany。
- `AppContainer.availablePlayerFactions` 读取 scenario faction 失败时不再给 Waterloo 硬编码 France / Anglo-Allied / Prussia fallback；只有阿登 legacy 继续回退 Germany / Allies，非 legacy scenario 只回到 catalog `defaultPlayerFaction`，避免坏 Waterloo JSON 仍显示完整可选阵营。
- `AgentPanelView` 在拿战 faction 下把 raw `*_mock_commander` / `MockAI` 包装为 Command Staff / Simulated Staff 展示，避免 Standard replay 面板暴露 mock commander id；raw id 仍保留在底层记录和 Full raw JSON 中。
- `CommandResultSummary` 的 `commandDisplayName` 改为按执行 faction 生成，拿战 replay 中的 production / end-turn 记录显示 Reserve Order / End Orders，而不是 legacy QueueProduction / End Turn。
- `HexNode` 的供给源 marker 不再把所有非 Allies 都显示成 `SUP G`；Waterloo 下 France / Coalition / Prussia 会显示 `SUP F` / `SUP C` / `SUP P`。
- `MapEditorGameResourceBridge` 新增 `loadLegacyArdennesDocument` / `overwriteLegacyArdennesGameResources`，MapEditor UI 和 ViewModel 改显示 `Legacy 阿登资源`；旧 `loadDefaultDocument` / `overwriteDefaultGameResources` 保留为兼容 wrapper，避免把编辑器 legacy 资源误读成当前 playable 默认入口。
- `MapEditorExporter` 导出的 `factions`、`initialPhase`、`playerFaction` 和 `aiFaction` 会按文档中的实际 faction 派生，并保留显式 neutral-only 文档的 `.neutral` faction；MapEditor 新建单位 id 前缀也按 faction 和已有 id suffix 生成，避免 France / Prussia 等非 Germany 单位继续被压成 `all_*` 或替换单位时发生 id 碰撞。
- `MapEditorGameResourceBridge` 读取 legacy 资源时对 tile controller、supplyFaction、unit facing、retreatMode、supplyState 和 region `hexToRegion` raw key 改为显式抛错，不再用 nil、`.west`、`.retreatable` 或 `.supplied` 静默覆盖坏数据。
- `MapEditorCanvasScene` 的单位缩写优先识别 cavalry / guard / battery / supply / light infantry / line infantry，拿战模板在画布上显示为 CAV / GD / BAT / SUP / LGT / LINE；panzer / tank / motorized 缩写只作为 legacy fallback。
- `AppContainer.submitPlayerDirective` 的玩家军团指令回写改为走 `refreshGeneralAssignments(in:)`，让玩家 directive 路径也经过拿战 `normalizeCommandPhase`，避免未来该路径推进状态后绕过 AppContainer 的 phase 归一化。
- `MockAIClient` 的 fallback 启发式不再写死 Bastogne，而是选择当前未控制 objective；拿战 faction 的 intent / reason 输出 formations、contact sector、corps deployment 口径。`AgentPromptBuilder` 的旧 LLM prompt 改为 historical hex command game / assigned formations。
- `AppContainer.handleBoardTap`、`handleDivisionTap`、`selectedAttackTarget`、`selectedGeneralSourceZone` 和 `attackHighlights` 改用 `DiplomacyState.isHostile` / `isFriendly` 判定攻击目标、友军选择和高亮，避免 Anglo-Allied / Prussia 等 co-belligerent 被当成敌军。`GeneralCommandPanelView` 只在 `canAttackRegion` 为 true 时显示 target。
- `SupplyRules.canSupplyPass` 的单位阻挡和敌方 ZOC 例外改用 `DiplomacyState.isHostile` / `isFriendly`；co-belligerent formation 不再阻断彼此补给。`RulerAgent` 计算 front zone 邻近敌军强度时也改用 `DiplomacyState.isHostile`，避免把友好联军计为敌军压力。
- Xcode app display name 改为 `Waterloo Command`；地图据点 marker 从 `FORT` 改为 `SP`；RegionInspector 拿战下把 fortress terrain 包装为 Strongpoint；UnitInspector 拿战部署角色显示 Contact Line / Reserve / Strongpoint；AgentPanel 普通摘要和时间线把 tactic/category/commander raw id 包装为可读拿战命令名，Full raw JSON 仍保留 schema 审计信息。
- UnitInspector 与 UnitTooltip 在拿战 faction 下把 Supply 标签显示为 Logistics，并把 supply state 展示为 Ready / Short / Isolated；legacy 场景仍保留 Supplied / Low Supply / Encircled。
- 并发子 Agent 扫描默认 Waterloo 玩家可见残留后，继续收口 macOS/HUD 菜单、设置 sheet、compact tab、旧 Agent prompt 和诊断文本：拿战路径显示 Orders / End Orders / New Campaign、Staff Pace / Staff Control、Staff、formation、corps sector、command directive、command wing/contact line 和 staff step；legacy faction 仍保留 Game / End Turn / New Game、AI、Division、FrontZone、Theater 等兼容 schema 或旧场景口径。
- 并发子 Agent 继续扫描 EventLog / AgentPanel / TurnManager / AppContainer 的 raw diagnostic 泄漏后，`EventLogView` 在拿战 faction 下对 Standard / Concise 事件正文和 metadata 做显示层净化，把 raw `AI`、`MockAI`、`legacy pipeline`、Germany / Allies 和 JSON 审计标签转成 Staff / Simulated Staff / Archived / Coalition 口径；底层 `GameLogEntry.message` 不改写。
- `AgentPanelView` 在拿战 faction 下继续净化 Issue Preview、Recent Dispatch Timeline、Zone Directives 和 Staff Summary 中的 raw front zone / region / theater id、record error、directive diagnostic、validation rawValue 和 raw staff id；展示为 sector / wing / staff note / Simulated Staff / Command Staff，Full raw JSON 仍保留底层 schema 审计内容。
- `EventLogView` 展示事件正文时优先用 `GameLogEntry.faction` 选择拿战 sanitizer；`AgentPanelView` 展示 ruler focus、directive badge / target / diagnostics 和 focus summary 时优先用 `RulerDecisionRecord.faction` / `WarDirectiveRecord.faction`，避免回合已推进到其它 active faction 后把 Waterloo directive 重新暴露成 raw id 或 legacy diagnostic。
- 新增共享 `NapoleonicMessageSanitizer`，供 EventLog、AgentPanel、CommandPanel 和 AppContainer interaction log 复用同一套拿战展示净化，避免 Standard / Concise 面板各自维护不同 raw AI / MockAI / legacy / validation rawValue 替换表。
- `TurnManager` 默认 staff 失败、end orders 失败、空 directive、directive 拒绝和缺失 corps sector 诊断改写为 Staff / Corps / End Orders 口径，`WarCommandExecutor` 写入 event log 的 directive 拒绝原因改用 `CommandValidationError.displayName(for:)` 和 `Command.displayName(for:)`；`DataLoader` 初始日志只写 `Campaign loaded.` / `Archived campaign loaded.`，不再暴露 scenario id 或 MapEditor-compatible JSON 来源。
- `AppContainer.recoveryState` 的默认加载失败恢复态继续保留 1x1 inert 地图，并把 `victoryState` 固定为 `.ongoing`，避免恢复态误触发胜负状态。
- `AgentPanelView`、`DiplomacyPanelView` 和 `AppContainer` 继续收口默认拿战可见 raw id：ruler/focus sector 与玩家 corps order interaction log 会显示为可读 commander / sector 文案，不再直接暴露 `ruler_*` 或 raw `zoneId`；`GeneralCommandPanelView` 和 `GeneralProfileView` 在拿战 faction 下把 VoiceOver profile / portrait placeholder 文案收口为 Commander profile / commander portrait placeholder；legacy faction 保持原文。
- 并发子 Agent 继续扫描默认 Waterloo 玩家可见 raw id、legacy fallback 和回合控制边界后，本轮补齐 display-only 收口：`RegionInspectorView` / `UnitInspectorView` 的 Sector、Active Wing、Corps Sector、Contact Line 不再直接显示 raw region/theater/front-zone/front-line id；`AppContainer` 选中 sector 的 interaction log 不再显示 raw `regionId`；`CommandExecutor`、`WarCommandExecutor` 和 `StrategicStateSynchronizer` 的拿战动态推进、front change 和 region controller event log 会优先显示 region/theater/front-zone 名称或格式化 sector/wing 文案，legacy 路径继续保留 raw id 调试口径。
- 并发子 Agent 继续扫描 diplomacy / general command / directive decoder / MapEditor fallback 后，本轮补齐默认拿战可见 raw id 与坏数据兜底：`DiplomacyPanelView` 的 country bloc、relations 和 ruler rationale 改显示可读 coalition/country/sector 文案；`GeneralCommandPanelView` 的 zone 名称和 planned operation target 改显示 region/front-zone 名称或格式化 sector；`StrategicPostureDecoderError`、`TheaterDirectiveDecoderError`、legacy `CommandIntentAdapterError` 和 legacy AI order refusal 摘要不再直接拼 region/theater/front-zone id 或 validation rawValue；`MapEditorGameResourceBridge` 读取 unknown unit faction 时抛错，不再静默兜底 `.allies`。Full raw JSON 和底层 schema 审计值仍按设计保留。
- 并发子 Agent 继续扫描默认 Waterloo 命令日志、MapEditor fallback 和最小玩法缺口后，本轮补齐：`Command.displayName(for:in:)` 在玩家命令、RuleEngine 结果、WarCommandExecutor 诊断和 AgentPanel command results 中用 formation name 替代 raw unit id；`AppContainer` 的 no-action 反馈会正确排除 `End Orders`；MapEditor 纯 neutral / blank 文档导出不再注入 Germany / Allies，而是写 `.neutral` 与 `.resolution`；Waterloo 增援表新增 French Cavalry Reserve，复用既有 `cavalry_reserve` 模板和骑兵战斗修正，让默认数据切片暴露骑兵预备队玩法。
- 并发子 Agent 继续扫描拿战玩法缺口后，本轮补齐小范围战术增强：`MockAIClient` 现在把 `cityName` / `fortressName` 地块也视为 objective-like 炮兵目标，避免 Mont-Saint-Jean 这类 hill + cityName 目标被低估；`WarCommandExecutor` 的 breakthrough / spearhead 会优先炮兵准备，fire coverage 有炮兵或远程单位时只提交这些单位；`MovementRules` 对骑兵进入 hill / forest / city / fortress 加 1 移动惩罚、mountain 加 2；`reserve_infantry_column` 的 guard 权重提高到 0.25，让 Imperial Guard Reserve 达到既有 guard morale 阈值。
- 并发子 Agent 继续扫描 AI 目标选择后，本轮补齐 `MockAIClient` 的 objective 偏好排序和拿战部署文案：fallback move 目标先按 city、fortress、supply 排序，再在排序后的目标中选择未控制目标，避免默认 Waterloo AI 被 JSON 顺序牵引到 La Haye Sainte，而优先朝 Mont-Saint-Jean 这类 city 关键点推进；同类型目标继续按 name / id 稳定排序；contact formation attack / hold reason 优先显示 region name 或格式化 sector 名，不再直接拼 raw `regionId`。
- 并发子 Agent 继续扫描 AgentPanel / EventLog raw 展示后，本轮补齐默认拿战 replay 展示净化：`AgentPanelView` 和 `EventLogView` 的缺省 active faction 从 `.allies` 改为 `.france`，AgentPanel 的 Standard context summary 与 intent 会走 `NapoleonicMessageSanitizer`，缺失 `commandDisplayName` 的 move / attack / hold / resupply fallback 会显示为 Movement Order / Attack Order / Hold Line / Rest and Supply；sanitizer 同步覆盖 `wwii`、`ardennes`、`bastogne`、`germanAI`、`alliedPlayer`、lowercase `germany/allies`、`panzer`、`tank` 和 `motorized` 等默认拿战玩家可见残留。
- `Faction.opponent` 已标记为 legacy 二元兼容 helper，新运行时敌我关系应继续使用 `DiplomacyState.isHostile/isFriendly` 或 `hostileFactions(to:)`；`GamePhase.commandPhase(for:)` 成为当前通用 command phase helper，`legacyCompatibleCommandPhase(for:)` 只保留为旧命名包装，现有 App / Rule 层调用已切到新 helper。
- 默认入口隔离继续加固：`availablePlayerFactions` 读取场景 faction 失败时只让阿登 legacy fallback 到 Germany / Allies，未知或后续非 legacy 场景优先使用 catalog `defaultPlayerFaction`；非阿登 scenario 中即使出现 `.germany` active faction，也不会自动创建 Guderian agent，而是走普通 sample command staff；`DataLoader.loadInitialGameState()`、无参阿登 loader 和 MapEditor `Default` wrapper 已补 legacy-only 注释，避免被误解为当前 playable 默认入口。
- `DiplomacyState.isHostile/isFriendly` 的缺国家/缺关系 fallback 改为拿战联军成员之间 friendly、France 与联军成员 hostile、neutral 不 hostile，避免坏快照或半迁移状态把 Anglo-Allied / Prussia 等 co-belligerent 误当敌军。
- `VictoryRules` 的 Waterloo 分支不再只认裸 `scenarioId == "waterloo_1815"`；现在通过 `ScenarioCatalog.napoleonicTarget.matches(state.scenarioId)` 或 Waterloo victory condition id 进入最小 Waterloo 胜利节奏，降低后续 Waterloo 变体 / 数据切片掉回 Bastogne legacy 逻辑的风险。
- `md/flow/01_overall_core_flow.mermaid` 补充 `ScenarioCatalog`、`TerrainRuleSet / GameState.terrainRules`、`ScenarioVictoryCondition / GameState.victoryConditions`、`DiplomacyState` 与经济/增援节点；`md/flow/flow.md` 修正过期的“terrain 未注入运行时规则”描述，明确 v3.8 起 Waterloo 主路径读取运行时地形规则。
- README、flow、flowchart、plan、v3 总提示词、v3.7 阶段记录和新增 v3.8 阶段记录已同步：当前默认入口是 Waterloo 1815，阿登仅为 legacy 可选路径。

关键文件：

- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `WWIIHexV0/Agents/GameAgent.swift`
- `WWIIHexV0/Agents/MockAIClient.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/Rules/RegionVictoryRules.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Commands/CommandIntentAdapter.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Rules/StrategicStateSynchronizer.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/SpriteKit/HexNode.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/NewGameSetupView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/01_overall_core_flow.mermaid`
- `md/plan/plan.md`
- `md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`
- `md/prompt/v3.0-拿战迁移/v3.7_napoleonic_playtest_loop_foundation.md`
- `md/prompt/v3.0-拿战迁移/v3.8_napoleonic_release_candidate_foundation.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/PlayerCommandState.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/App/AICommandPace.swift WWIIHexV0/App/ReplayDetailLevel.swift WWIIHexV0/App/PlaytestSessionSettings.swift WWIIHexV0/App/PlaytestGuideCue.swift WWIIHexV0/App/GameSaveSnapshot.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/App/WWIIHexV0MacApp.swift WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Turn/TurnManager.swift WWIIHexV0/SpriteKit/HexNode.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/NewGameSetupView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/CommandPanelView.swift`：通过，无输出。
- `swiftc -parse MapEditor/MapEditorViewModel.swift MapEditor/MapEditorCanvasScene.swift MapEditor/MapEditorView.swift MapEditor/MapEditorDocument.swift MapEditor/MapEditorExporter.swift MapEditor/MapEditorHexMath.swift MapEditor/MapEditorGameResourceBridge.swift WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/HexCoord.swift WWIIHexV0/Core/HexDirection.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Core/Theater.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/SupplyState.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/RegionDataSet.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json WWIIHexV0/Data/napoleonic_unit_templates.json WWIIHexV0/Data/napoleonic_generals.json WWIIHexV0/Data/napoleonic_terrain_rules.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/waterloo_1815_scenario.json WWIIHexV0/Data/waterloo_1815_regions.json WWIIHexV0/Data/napoleonic_unit_templates.json WWIIHexV0/Data/napoleonic_generals.json WWIIHexV0/Data/napoleonic_terrain_rules.json WWIIHexV0/Data/ardennes_v0_scenario.json WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `rg -n "waterloo_1815_scenario|waterloo_1815_regions|napoleonic_terrain_rules|napoleonic_unit_templates|napoleonic_generals" WWIIHexV0.xcodeproj/project.pbxproj`：确认 Waterloo / napoleonic JSON 在 project resources / file references 中有记录。
- `rg -n "commandDisplayName: command\.displayName,|Command\.endTurn\.displayName," WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Turn/TurnManager.swift WWIIHexV0/App/AppContainer.swift`：无命中。
- `rg -n "loadInitialGameState\(\)" WWIIHexV0/App/AppContainer.swift`：无命中。
- `rg -n "ScenarioCatalog\.all\.first\(where: \{ \$0\.id ==|factions: Faction\.allCases|initialPhase: GamePhase\.alliedPlayer\.rawValue|playerFaction: Faction\.allies\.rawValue|aiFaction: Faction\.germany\.rawValue|let factionPrefix = selectedUnitFaction ==" WWIIHexV0 MapEditor`：无命中。
- `rg -n "SUP A|SUP G|SUP F|SUP C|SUP P|SUP AU|SUP R|SUP S|SUP N" WWIIHexV0/SpriteKit/HexNode.swift`：命中预期 faction 供给源短码。
- `rg -n "defaultPlayable[[:space:]]仍|默认启动[[:space:]]仍|默认仍保持[阿]登|默认.{0,8}[阿]登 legacy 数据|默认 Waterloo 启动仍[需]|再切[默]认|DataLoader.*默认资源.*[阿]登|Guderian [/] Germany 的 stored" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/plan/plan.md md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md md/prompt/v3.0-拿战迁移/v3.7_napoleonic_playtest_loop_foundation.md md/prompt/v3.0-拿战迁移/v3.8_napoleonic_release_candidate_foundation.md WWIIHexV0`：无命中。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/flow/03_ai_zone_directive_pipeline.mermaid md/prompt/v3.0-拿战迁移 md/plan/plan.md WWIIHexV0/App/AppContainer.swift WWIIHexV0/App/WWIIHexV0MacApp.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/UI/NewGameSetupView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/CommandPanelView.swift WWIIHexV0/UI/RootGameView.swift`：无命中。
- `rg -n "^<<<<<<<|^=======|^>>>>>>>" AGENTS.md README.md update_log.md md/flow WWIIHexV0 MapEditor md/prompt/v3.0-拿战迁移 md/plan/plan.md`：无命中。
- `git diff --check`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Core/HexCoord.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Core/Theater.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/SupplyState.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/WarDeploymentState.swift WWIIHexV0/Core/FrontZoneId.swift WWIIHexV0/Core/FrontZoneSegment.swift WWIIHexV0/Core/FrontZone.swift WWIIHexV0/Core/PlayerCommandState.swift WWIIHexV0/Core/GeneralAssignment.swift WWIIHexV0/App/AICommandPace.swift WWIIHexV0/App/ReplayDetailLevel.swift WWIIHexV0/App/PlaytestSessionSettings.swift WWIIHexV0/App/PlaytestGuideCue.swift WWIIHexV0/App/GameSaveSnapshot.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Agents/DecisionProvider.swift WWIIHexV0/Agents/AgentContexts.swift WWIIHexV0/Agents/AgentDecision.swift WWIIHexV0/Agents/AgentPromptBuilder.swift WWIIHexV0/Agents/MockAIClient.swift WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Rules/MovementRules.swift WWIIHexV0/Rules/SupplyRules.swift WWIIHexV0/Rules/CombatRules.swift WWIIHexV0/Rules/VictoryRules.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/RuleEngine.swift WWIIHexV0/Rules/WarDeploymentManager.swift WWIIHexV0/SpriteKit/MapDisplayAdapter.swift WWIIHexV0/UI/PlatformStyles.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/App/AppContainer.swift`：通过，无输出。
- `rg -n "\bBastogne\b|WWII hex strategy prototype|No allied front zone selected|Guderian MockAI|armor on roads" WWIIHexV0/Agents/MockAIClient.swift WWIIHexV0/Agents/AgentPromptBuilder.swift WWIIHexV0/UI/GeneralCommandPanelView.swift README.md`：无命中。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/HexCoord.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Core/Theater.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/SupplyState.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/WarDeploymentState.swift WWIIHexV0/Core/WarDirectiveRecord.swift WWIIHexV0/Core/FrontZoneId.swift WWIIHexV0/Core/FrontZoneSegment.swift WWIIHexV0/Core/FrontZone.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/App/ReplayDetailLevel.swift WWIIHexV0/App/PlaytestSessionSettings.swift WWIIHexV0/UI/PlatformStyles.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/AgentPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/HexCoord.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Core/Division.swift WWIIHexV0/SpriteKit/TerrainStyle.swift WWIIHexV0/SpriteKit/HexNode.swift WWIIHexV0/UI/PlatformStyles.swift WWIIHexV0/UI/RegionInspectorView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Core/HexCoord.swift WWIIHexV0/Core/HexDirection.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Core/Theater.swift WWIIHexV0/Core/Division.swift WWIIHexV0/Core/SupplyState.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/MapDisplayLayer.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/WarDeploymentState.swift WWIIHexV0/Core/FrontZoneId.swift WWIIHexV0/Core/FrontZoneSegment.swift WWIIHexV0/Core/FrontZone.swift WWIIHexV0/Core/GeneralAssignment.swift WWIIHexV0/Core/WarDirectiveRecord.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/RegionDataSet.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/Rules/MovementRules.swift WWIIHexV0/Rules/CombatRules.swift WWIIHexV0/Rules/SupplyRules.swift WWIIHexV0/Rules/OccupationRules.swift WWIIHexV0/Rules/RegionOccupationRules.swift WWIIHexV0/Rules/FrontLineManager.swift WWIIHexV0/Rules/TheaterSystem.swift WWIIHexV0/Rules/WarDeploymentManager.swift WWIIHexV0/Rules/EconomyRules.swift`：通过，无输出。
- 云端验证：`main` / commit `d368529482e5ff9a21db2292115cf875cf51a02a` / GitHub Actions `WWIIHexV0 CI Results` run `28775496470` attempt `1` 成功；artifact `wwiihexv0-ci-cloud-main-ci-v1-main-d368529-run28775496470-attempt1` 已下载到 `/private/tmp/wwiihexv0-c-review-28775496470/` 并核对 `ci-artifact-manifest.json`、`junit.xml`、`static-checks.log`、`ci-failure-summary.md` 和 `xcodebuild.log`：`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`，`xcodebuild.log` 为 `BUILD SUCCEEDED`。
- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范默认禁止本机重测试，本轮也未获人工授权。

遗留风险：

- Waterloo 仍是小规模 schema / data slice；默认入口切换不等于完整可玩滑铁卢战役。
- 默认入口的真实 bundle resource 加载、SwiftUI sheet 行为、SpriteKit 视觉和多回合 AI 稳定性仍需云端 build 或人工授权运行时验证。
- Legacy 阿登、Germany / Allies、Guderian / Montgomery 等仍保留在兼容场景、历史阶段文档、fallback 或源码兼容名中；发布候选仍需继续做玩家可见残留扫描和资源授权检查。
- 并发只读扫描仍发现默认 Waterloo 路径的后续数据风险：terrain runtime 已接入但还不是完整 terrain DSL；SupplyRules、RegionMovementRules、RegionSupplyRules 等非主战术路径仍保留独立硬编码或 `BaseTerrain` 语义；Waterloo victory 只完成当前两类条件的 runtime 接入，尚未形成通用 victory condition DSL；Full raw JSON 仍按设计保留 schema raw value 供审计调试。

## 历史维护记录

以下提交不作为正式 v 版本，但影响项目资料完整性：

- 2026-06-15：重整 `md` 目录，添加 README，补充 v0.1-v1.0 提示词。
- 2026-06-15：打捞 Agent D 与误删代码，恢复 AI 决策管线。
- 2026-06-15：记录 v0.5 擅自编程与回退资料，保留为历史警示；当前主线不得引入 Cabinet/StrategicDirective/Minister 污染。
- 2026-06-18：整理文档结构，将已完成阶段文档迁入 `md/prompt/...（已完成）`。
- 2026-06-24 至 2026-06-25：补充 0.36 提示词、0.355 截止分析、20 回合文档更新。
- 2026-06-27：创建 `AGENT.md`，写入后续 Codex 接手项目时的架构、测试、文档维护和交付规则。
- 2026-07-04：更新当前协作规范：默认禁止 Xcode / XCTest / 模拟器 / 性能类重测试，只做轻量语法/格式检查；新增多版本分支、并发子 Agent 和合并前冲突检查规则。关键文件：`AGENTS.md`、`md/test/test.md`、`md/flow/flow.md`、`README.md`、`md/prompt/v0.f/fable-5-重构优化总提示词.md`。
- 2026-07-04：新增拿破仑战争迁移总提示词，规划 v3.0-v3.8 从 WWIIHexV0 迁移为 AI Agent 驱动拿战游戏的版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`。
- 2026-07-04：新增明末迁移总提示词，规划 v4.0-v4.8 从 WWIIHexV0 迁移为 AI Agent 驱动明末历史策略游戏的产品目标、版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v4.0-明末迁移/codex-v4.0-明末aiagent迁移总提示词.md`。
- 2026-07-04：云端协作制度升级，不作为业务功能版本。新增 `main` 直推、GitHub Actions 云端 build、未加密 `ci-results` artifact、Agent C 下载复核 manifest/JUnit/log/failure summary 的规则；本机仍默认只跑轻量检查。关键文件：`AGENTS.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/prompt/README.md`、`README.md`、`.github/workflows/ci-results.yml`。
- 2026-07-04：根据拿破仑战争迁移总提示词重写项目 md 大纲，将 `md/plan/plan.md` 从旧 v0.x 后续计划更新为 v3.0-v3.8 拿战迁移路线、md 目录职责、并发分工和轻量检查索引。本轮只改文档大纲，不改源码或运行时行为。
- 2026-07-06：Waterloo data follow-up。`waterloo_1815_regions.json` 补齐 Hougoumont / Papelotte region objectives，使 region objectives 与 scenario objectives 覆盖同一批关键战场点；`waterloo_1815_scenario.json` 将 `pr_bulow_iv_corps` 显式绑定 `objective_prussian_arrival` + `triggerController=prussia`，表达 Prussian Arrival Road 入口路控制权触发。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md`。本轮按人工要求未运行本地测试、构建、lint 或 parse；JSON 一致性和构建结果需由 GitHub Actions artifact 验收确认。
- 2026-07-06：Waterloo data follow-up。`waterloo_1815_scenario.json` / `waterloo_1815_regions.json` 补入 Plancenoit 作为法军持有的地图 objective / region objective，并为 La Haye Sainte、Papelotte、Plancenoit 增加最小初始守备；La Haye Sainte 初始控制权从 neutral 调整为 Anglo-Allied，`napoleonic_generals.json` 同步将领 preferred regions。Plancenoit 当前不进入 `VictoryRules` 的 Waterloo runtime condition，仅作为地图目标、region 摘要和 AI 排序口径。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint 或 parse；JSON 一致性和构建结果需由 GitHub Actions artifact 验收确认。
- 2026-07-06：Waterloo data follow-up。`waterloo_1815_scenario.json` 将地图宽度扩到 6，并新增 q5,r1 Wavre Road 作为普军后方 road / supply / reinforcement entry hex；`pr_bulow_iv_corps.entryCoord` 改到 q5,r1，但仍由 q4,r1 `objective_prussian_arrival` + `triggerController=prussia` 触发。`waterloo_1815_regions.json` 同步新增 `region_wavre_road`、region edge 和 region supply source；`napoleonic_generals.json` 新增 `commander_bulow` 并把 Prussian IV Corps 归属给 Bulow；`EventLogView` 在拿战 faction 下把 combat / retreat / supply / event 分类显示为 Engagement / Withdrawal / Logistics / Dispatch，Full/raw 审计值仍保留。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；JSON 一致性和构建结果需由 GitHub Actions artifact 验收确认。
- 2026-07-06：Waterloo data follow-up。`waterloo_1815_scenario.json` 新增 `aa_papelotte_left_reserve`，复用现有 line infantry 模板和 Wellington 归属，补强 Anglo-Allied 左翼初始数据但不新增 objective、region、template 或胜负条件；`EventLogView` / `NapoleonicMessageSanitizer` 将拿战 encirclement 类日志展示为 Isolation / isolated / isolation losses，底层 category、message 和 Full/raw 审计值不改写。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；JSON 一致性和构建结果需由 GitHub Actions artifact 验收确认。
- 2026-07-06：New Campaign wording follow-up。`NewGameSetupView` 将玩家可见的新局选择从 Player Faction / Faction 收口为 Player Power / Power，Opening Turn 说明改为 selected power / orders phase / other powers，Reset 说明改为 campaign data / dispatch history / normal rules path，避免普通玩家界面暴露 JSON、local replay state 和 command pipeline 原型词。底层仍保留 `Faction` / `playerFaction` schema、`AppContainer.startNewGame(...)` 和 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 规则入口，不改运行时数据、胜负、增援或存档 schema。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；SwiftUI 编译和 UI 行为需由 GitHub Actions artifact / 后续人工运行时验收确认。
- 2026-07-06：Replay / save wording follow-up。`HUDView` 在拿战路径把 active faction 指标显示为 Active Power；`GameSaveSnapshot.Summary` 在拿战路径显示 Current / Your Power，legacy fallback 仍保留 Active / Player；`AgentPanelView` 在拿战 Full 详情把 Raw JSON 标题显示为 Dispatch Audit，空态改为 `No dispatch audit recorded.`，并对可见审计正文走 `NapoleonicMessageSanitizer`，但底层 `AgentDecisionRecord.rawJSON` 与 legacy raw JSON 展示不改写。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；SwiftUI 编译、Full 审计文本显示和存档摘要 UI 需由 GitHub Actions artifact / 后续人工运行时验收确认。
- 2026-07-06：Waterloo data follow-up。`waterloo_1815_scenario.json` 新增 `pr_blucher_approach_screen`，位于 Prussian Approach q4,r0，复用 `prussian_vanguard` 模板和 Blucher 归属，作为开局前卫 screen；它不新增 objective、region、template、reinforcement schedule、胜负条件或独立 AI Agent，也不改变 q4,r1 `objective_prussian_arrival` / q5,r1 Wavre Road / Prussian IV Corps delayed reinforcement 口径。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；JSON 一致性、构建和运行时加载需由 GitHub Actions artifact 验收确认。
- 2026-07-06：AI rules follow-up。`WarCommandExecutor` 在 staff offensive dispatch 中遇到 morale 已 broken 的 formation 时，先走现有 `Command.hold` / `RuleEngine` 路径休整恢复，而不是生成会被 `CommandValidator` 拒绝的 attack / move；不改 schema、不改 victory / terrain DSL、不绕过规则系统。同步更新 `README.md`、`md/flow/flow.md` 和 `md/flow/flowchart.md`。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；Swift 编译、replay 计数和运行时 AI 节奏需由 GitHub Actions artifact / 后续人工运行时验收确认。
- 2026-07-06：Waterloo data maintenance。`waterloo_1815_scenario.json` 将 `fr_cavalry_reserve.hp` 从 10 调整为 9，使 French Cavalry Reserve delayed reinforcement 不超过 `napoleonic_unit_templates.json` 中 `cavalry_reserve.maxHP = 9` 的数据校验上限；不改 reinforcement turn、entryCoord、trigger、objective、victory condition 或模板 schema。本轮按人工要求未运行本地测试、构建、lint、parse 或 jq；JSON 解析、运行时加载和构建需由 GitHub Actions artifact 验收确认。
- 2026-07-06：Waterloo data / UI wording follow-up。`waterloo_1815_regions.json` 将 La Haye Sainte 的 `assignedGeneralId` 对齐为 `commander_wellington`，并把 q4,r1 region objective 显示名统一为 Prussian Arrival Road；`waterloo_1815_scenario.json` 同步把 q4,r1 key location 显示名统一为 Prussian Arrival Road，保留 Prussian Approach region 名作为后方轴线口径，不改 objective id、victory condition、reinforcement trigger、entryCoord 或 schema。`NewGameSetupView` 和 `AppContainer` 继续收口玩家可见文案：空存档提示不再显示 snapshot，Reset 说明改为 rules-guided orders path，开局日志改为 Opening orders assigned。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 v3 总提示词。本轮按人工要求未运行本地测试、构建、lint、parse、jq 或 `git diff --check`；JSON 解析、Swift 编译、UI 行为和构建需由 GitHub Actions artifact 验收确认。
