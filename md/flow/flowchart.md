# WWIIHexV0 Mermaid 核心流程图

> 本图参照 `md/flow/flow.md`。每个图块都用“中文解释 + 关键代码名”标注：先看中文理解逻辑，再用代码名回到源码定位。

## 0. 读图总纲

项目当前最重要的逻辑是：

```text
地图编辑器/JSON 数据
  -> 游戏启动加载为 GameState
  -> hex 是真实战术权威
  -> region / theater / front / deploy 都是从 hex 和单位位置派生出来的战略层
  -> economy 是 faction 级经济总账，收入仍从真实控制的 hex/region 聚合
  -> v0.5 元帅层是战略意图层，不替代战术权威
  -> 玩家和 AI 都必须把命令交给 RuleEngine
  -> 命令执行后再同步刷新战略层和 UI
```

图里颜色含义：

- 红色：权威状态，不能被下游反向覆盖。
- 绿色：派生状态，可以重建，但来源必须清楚。
- 蓝色：初始快照/基准状态，不是运行时推进状态。
- 紫色：命令管线，玩家、AI、未来聊天命令都要走这里。

## 0.1 云端协作验证闭环

这张图是项目协作和验证流，不是游戏运行时逻辑。默认只使用 `main` 直推触发云端验证；Agent C 必须下载未加密结果包复核。

```mermaid
flowchart TD
    HUMAN["人工提出目标<br/>说明范围、禁止项、验收标准"]:::input
    A["Agent A<br/>读 AGENTS / flow / test / 源码<br/>写版本化实现提示词"]:::agent
    B0["Agent B 开始<br/>git fetch origin<br/>确认当前分支 main"]:::git
    B1["Agent B 实现<br/>只改本轮相关文件<br/>不做业务外扩"]:::agent
    LOCAL["本机轻量检查<br/>git diff --check / plutil / YAML / JSON<br/>不跑本机 xcodebuild 和模拟器"]:::check
    COMMIT["main commit<br/>git add + git commit<br/>记录本轮改动"]:::git
    PUSH["main push<br/>git push origin main<br/>触发云端验证"]:::git
    GHA["GitHub Actions<br/>.github/workflows/ci-results.yml<br/>静态检查 + 云端 Xcode build"]:::cloud
    ART["未加密结果包 artifact<br/>manifest / junit / xcodebuild.log<br/>failure summary / xcresult"]:::artifact
    C0["Agent C 下载<br/>gh auth login<br/>gh run download 到 /private/tmp/wwiihexv0-c-review-run/"]:::agent
    C1["Agent C 核对<br/>branch=main<br/>commitSha / runId / runAttempt 匹配 origin/main"]:::check
    PASS{"Actions 与结果包通过?"}:::decision
    ACCEPT["验收通过<br/>更新 flow / update_log<br/>人工复核进入下一轮"]:::ok
    REJECT["退回清单<br/>列失败日志路径、manifest 差异、修复要求"]:::warn
    FIX["Agent B 追加修复 commit<br/>仍在 main 上提交<br/>再次 push origin/main"]:::git

    HUMAN --> A --> B0 --> B1 --> LOCAL --> COMMIT --> PUSH --> GHA --> ART --> C0 --> C1 --> PASS
    PASS -->|是| ACCEPT
    PASS -->|否| REJECT --> FIX --> PUSH

    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef agent fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef git fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef check fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef cloud fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef artifact fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef ok fill:#dcfce7,stroke:#15803d,color:#052e16
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 1. 总主线：从地图数据到游戏行动

这张图看全局。左上是地图数据怎么进入游戏；中间是 hex、region、theater、front、deploy 的分层关系；右侧是玩家/AI 命令如何统一进入规则系统；底部是 UI 和日志怎么读取结果。

```mermaid
flowchart TD
    ME["地图编辑器<br/>MapEditor<br/>用来画格子、省份、战区、初始部队"]:::editor
    JSON["游戏数据 JSON<br/>ScenarioDefinition + RegionDataSet<br/>保存地图、单位、省份、初始战区"]:::data
    SCAT["场景目录<br/>ScenarioCatalog<br/>defaultPlayable 指向 Waterloo 1815 数据切片；Archived Ardennes 作为 legacy 可选剧本保留；defaultPlayerFaction 为 France；目标切片已覆盖 Plancenoit；Wavre Road 是普军后方入口抽象；Papelotte 有 Anglo-Allied 左翼预备；Mont-Saint-Jean 后方 q2,r1 有 Anglo-Allied Rear Road marker；Prussian Approach q4,r0 有开局 screen 和非目标 road marker；q4,r1 目标显示为 Prussian Arrival Road"]:::loader
    SETUP["新局/继续/设置<br/>NewGameSetupView<br/>New Campaign 默认显示 Waterloo、玩家可见为 Player Power / Power / Opening Turn，底层仍是 Faction；Archived Campaigns 才显示 legacy 新局和旧 legacy 存档详情；AppContainer 按玩家控制权归一拿战 phase；Saved Campaign 可选 Slot 1/2/3，可编辑 campaign name，坏快照/未知 scenario/command staff 失败显示原因并可 Clear Campaign；继续成功后走现有 AI eligibility gate；Status 显示操作结果；Settings 调整 Observer Mode、Map View、Dispatch Detail、Staff Pace、Staff Control、Guide Notes、Text Size"]:::input
    SAVE["本地试玩快照<br/>GameSaveSnapshot + GameSaveSlot + UserDefaults<br/>schemaVersion 1，保存 scenario / player faction / GameState；内部仍是 3 个 slot，默认显示 Campaign 1/2/3，Slot 1 兼容旧单槽 key；campaign name 独立保存；拿战摘要显示 Current / Your Power；加载区分 missing / loaded / unavailable；恢复后 Staff 模式含 observer + Staff 可续跑 AI，非 observer Manual 需由 End Orders 推进，observer Manual 为 Observation only / 只读"]:::data
    PSET["试玩偏好<br/>PlaytestSessionSettings + UserDefaults<br/>Observer Mode / Map View / Dispatch Detail / Staff Pace / Staff Control / Guide Notes / Reduce Motion / Text Size；坏设置重置为标准设置并显示 Campaign settings 提示"]:::data
    REPLAY["试玩回放详细度<br/>ReplayDetailLevel<br/>Concise 保留 Staff Summary / Staff Reason / Issue Preview / Recent Dispatch Timeline；Standard / Full 的 Situation 可显示完整 selected staff rationale；控制日志条数、directive limit、metadata、context、明细卡和 Staff Record（底层 rawJSON 保留）审计显示"]:::ui
    GUIDE["非阻塞短引导与 AI 反馈<br/>PlaytestGuideCue + playerOrdersStatus + aiNoActionFeedback + aiDiagnosticFeedback<br/>首次 formation / artillery / cavalry / end orders 写入 Staff note；infantry-heavy formation 提示 square-ready Hold Contact Line；玩家无可行动、AI 无有效命令、record-level issue 和 dispatch paused 给可读提示"]:::ui
    DL["数据加载器<br/>DataLoader.loadGameState<br/>校验 initial phase / faction / terrain / victory；把 JSON 变成可运行 GameState"]:::loader
    TERR["运行时地形规则<br/>TerrainRuleSet / GameState.terrainRules<br/>Waterloo 移动/战斗读取 napoleonic_terrain_rules；旧状态 fallback legacy"]:::rules
    GS["运行时总状态<br/>GameState<br/>一局游戏所有状态都在这里"]:::state

    HEX["战术权威：六角格和单位位置<br/>HexTile.controller + Division.coord<br/>谁占哪个格、单位在哪，先看这里"]:::authority
    REGION["省份战略层<br/>RegionNode<br/>资源、补给、胜利点；控制权由 hex 聚合"]:::derived
    INIT["开局战区快照<br/>TheaterInitialSnapshot<br/>记录地图编辑器给的初始战区"]:::snapshot
    R2T["基础战区映射<br/>regionToTheater<br/>只作初始/基准，不表示战线推进"]:::snapshot
    H2T["动态战区权威<br/>hexToTheater<br/>运行时推进只改具体 hex"]:::authority
    FRONT["前线层<br/>FrontLine / FrontSegment<br/>按双方动态战区的真实相邻 hex 生成"]:::derived
    DEPLOY["部署层<br/>WarDeploymentState<br/>用 hexToFrontZone 把单位分成前线/纵深/驻军"]:::derived
    ECO["经济总账<br/>EconomyState / EconomyRules<br/>收入、维护费、生产队列、自动补员"]:::economy
    DIP["外交敌我关系<br/>DiplomacyState<br/>hostile / friendly 查询统一补给、前线、部署和 AI 口径"]:::rules
    PLAYER["玩家输入<br/>点击地图、移动、攻击、结束回合"]:::input
    AI["AI 战略上游<br/>RulerAgent + MarshalAgent<br/>先定国家姿态，再做大战役级规划"]:::input
    POST["战略姿态 JSON<br/>StrategicPostureEnvelope<br/>offensive / defensive / coalition / stabilize"]:::command
    PDEC["战略姿态解码<br/>StrategicPostureDecoder<br/>校验 schema / issuer / turn / faction / zone / region"]:::command
    DEC["元帅 JSON 解码<br/>TheaterDirectiveDecoder<br/>提取 fenced JSON、校验 id 与 schema"]:::command
    COMP["元帅意图编译<br/>TheaterDirectiveCompiler<br/>把 TheaterDirective 降级成 ZoneDirective<br/>已选 rationale 汇入 theaterContext"]:::command
    ZD["战争指令<br/>ZoneDirective<br/>战区级 attack/defend 意图"]:::command
    WCE["指令翻译器<br/>WarCommandExecutor<br/>把战区意图翻成具体单位命令"]:::command
    CMD["底层命令<br/>Command<br/>move / attack / hold / resupply / queueProduction / endTurn"]:::command
    RE["规则引擎<br/>RuleEngine<br/>先校验，再真正修改 GameState"]:::rules
    SYNC["战略同步器<br/>StrategicStateSynchronizer<br/>占领后刷新省份、战区、前线、部署"]:::rules

    UI["地图和面板显示<br/>SpriteKit / SwiftUI Overlay<br/>显示 hex、省份、初始战区、动态战区、前线、部署"]:::ui
    LOG["日志和复盘记录<br/>EventLog / WarDirectiveRecord / AgentDecisionRecord / RulerDecisionRecord<br/>用于 UI 展示和后续调试"]:::ui

    ME --> JSON --> SCAT --> SETUP --> DL --> GS
    SETUP --> SAVE --> GS
    PSET --> SETUP
    SETUP --> PSET
    SETUP --> REPLAY --> UI
    REPLAY --> LOG
    GS -.Save Campaign.-> SAVE
    GS --> HEX
    HEX --> REGION
    HEX --> ECO
    REGION --> ECO
    REGION --> INIT
    INIT --> R2T
    R2T -.->|缺失时只用来补初始值| H2T
    HEX --> H2T
    H2T --> FRONT --> DEPLOY
    GS --> ECO
    GS --> DIP
    GS --> TERR

    PLAYER --> CMD
    PLAYER --> GUIDE --> LOG
    AI --> POST --> PDEC --> DEC --> COMP --> ZD --> WCE --> CMD
    CMD --> RE --> HEX
    RE --> ECO
    TERR --> RE
    RE --> SYNC
    SYNC --> REGION
    SYNC --> H2T
    SYNC --> FRONT
    SYNC --> DEPLOY

    GS --> UI
    HEX --> UI
    REGION --> UI
    INIT --> UI
    H2T --> UI
    FRONT --> UI
    DEPLOY --> UI
    ECO --> UI
    DIP --> UI
    RE --> LOG
    WCE --> LOG

    classDef editor fill:#f6d365,stroke:#8a5a00,color:#1f1b10
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef snapshot fill:#e0f2fe,stroke:#0284c7,color:#082f49
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef economy fill:#fef9c3,stroke:#ca8a04,color:#292107
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
```

## 2. 占领与动态推进：一个单位移动后发生什么

这张图只看最容易出 bug 的链路：单位移动到敌控空格后，游戏如何占领这个 hex，并且只推进这个 hex 的动态战区和部署归属。

核心原则：占一个 hex，只改这个 hex 的 `hexToTheater` / `hexToFrontZone`；不能把整个 region 的 `regionToTheater` 改掉。

```mermaid
flowchart TD
    A["移动命令进入<br/>Command.move<br/>来源可以是玩家，也可以是 WarCommandExecutor"]:::command
    B["移动合法性检查<br/>CommandValidator.validateMove<br/>检查阶段、阵营、行动力、路径、目标是否被占"]:::rules
    C{"移动是否合法?"}:::decision
    R["命令被拒绝<br/>CommandResult rejected<br/>GameState 不变，只记录拒绝原因"]:::stop
    M["执行移动<br/>CommandExecutor.executeMove<br/>更新单位坐标、朝向、已行动标记"]:::rules
    O{"能否占领目标 hex?<br/>OccupationRules.canOccupy<br/>目标可占、非己方控制、没有其他单位"}:::decision
    NO["普通移动<br/>只改变单位位置<br/>不改变目标 hex 控制权"]:::state
    HC["改写真实占领权<br/>HexTile.controller = division.faction<br/>这是占领的权威来源"]:::authority
    SA{"是否需要推进动态战区?<br/>目标属于敌方 zone 或仍是敌控 hex 时才推进"}:::decision
    ET["推进动态战区<br/>TheaterSystem.expandDynamicTheater<br/>只把目标 hex 写入进攻方 hexToTheater"]:::authority
    AF["推进部署归属<br/>WarDeploymentManager.advanceHex<br/>只把目标 hex 写入进攻方 hexToFrontZone"]:::authority
    SS["占领后同步战略层<br/>StrategicStateSynchronizer<br/>把 hex 变化传导到 region/theater/front/deploy"]:::rules
    RO["刷新省份控制权<br/>RegionOccupationRules.aggregateControl<br/>按 region 内 hex 控制权加权计算"]:::derived
    TU["刷新动态战区摘要<br/>TheaterSystem.updateTheaters(force)<br/>重算控制比例、战区邻接、单位池"]:::derived
    FU["刷新前线<br/>FrontLineManager.update<br/>重新扫描动态战区之间的真实 hex 接触"]:::derived
    DU["刷新部署层<br/>WarDeploymentManager.update<br/>重分前线、纵深、驻军单位"]:::derived
    UI["刷新显示和日志<br/>UI overlay / inspector / EventLog<br/>玩家看到地图颜色、前线和面板变化"]:::ui

    A --> B --> C
    C -->|否| R
    C -->|是| M --> O
    O -->|否| NO --> UI
    O -->|是| HC --> SA
    SA -->|目标已经是己方动态战区| SS
    SA -->|目标仍属敌方动态战区| ET --> AF --> SS
    SS --> RO --> TU --> FU --> DU --> UI

    WARN1["绝对不要这样做<br/>占一个 hex 就把整个 regionToTheater 改掉<br/>会导致前线跳到敌军身后"]:::warn
    WARN2["也不要这样做<br/>只改 Region.controller<br/>却不改 HexTile.controller<br/>会破坏玩家/AI 对称性"]:::warn
    ET -.守住.-> WARN1
    HC -.守住.-> WARN2

    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 3. v0.8 经济、生产与补员链路

这张图看 v0.8 初级经济和 v3.5 起步的拿战后勤展示兼容层。经济总账是 faction 级资源池，但收入和部署资格仍回到真实 hex 控制和 region 聚合；生产命令仍走 `RuleEngine`，UI 不直接改 `GameState`。v3.5 还新增最小 delayed reinforcement schedule、`Division` 级 morale / fatigue / ammunition 战术消耗和 Waterloo 专用胜负节奏；仍不新增完整 ammunition / horses 经济账本字段。

```mermaid
flowchart TD
    BOOT["经济启动补账<br/>EconomyRules.bootstrapIfNeeded<br/>旧状态缺 economyState 时从地图推导账本"]:::economy
    HEX["真实控制权<br/>HexTile.controller<br/>经济收入必须有己方控制 hex 证据"]:::authority
    REGION["战略聚合<br/>RegionNode<br/>city / factories / infrastructure / supplyValue"]:::derived
    INCOME["收入计算<br/>EconomyRules.income<br/>manpower / industry / supplies<br/>拿战展示为 recruits / ammunition-horses / supplies"]:::economy
    LEDGER["阵营总账<br/>FactionEconomyLedger<br/>库存、上回合收入、维护费、补员消耗、队列"]:::economy

    UI["经济/后勤面板<br/>EconomyPanelView<br/>legacy 显示 Production<br/>拿战显示 Reserves"]:::ui
    QUEUE["生产命令<br/>Command.queueProduction<br/>玩家/未来 AI 共用底层命令"]:::command
    VALIDATE["生产校验<br/>CommandValidator.validateProduction<br/>检查 phase 与资源是否足够"]:::rules
    PAY["预付成本并入队<br/>EconomyRules.queueProduction<br/>扣底层三资源<br/>按 faction 显示成本摘要"]:::economy
    RESTCMD["休整命令<br/>Command.resupply<br/>玩家/AI 都经 RuleEngine"]:::command
    ACTION["行动命令<br/>Command.move / attack / hold<br/>玩家/AI 都经 RuleEngine"]:::command

    END["结束当前阵营回合<br/>Command.endTurn<br/>CommandExecutor.executeEndTurn"]:::command
    SUPPLY["补给状态刷新<br/>SupplyRules.updateSupplyStates"]:::rules
    RESOLVE["经济结算<br/>EconomyRules.resolveFactionTurn<br/>收入、维护费、短缺、补员、生产推进"]:::economy
    SHORT{"补给库存够吗?"}:::decision
    LOW["战略补给短缺<br/>supplied 单位降为 lowSupply"]:::rules
    REINF["自动补员<br/>安全后方 supplied 非敌邻单位<br/>每回合最多 +2 strength"]:::rules
    PROD["推进生产/预备队队列<br/>remainingTurns - 1<br/>legacy 部署旧单位<br/>拿战部署拿战 component formation"]:::economy
    SCHED["延迟增援表<br/>ReinforcementState.pending<br/>按 turn / objective trigger 到期<br/>Waterloo 普军 IV Corps 从 Wavre Road 入场，仍绑定 Prussian Arrival Road 控制权；q4,r0 screen 是初始单位"]:::economy
    ENTRY["安全入口检查<br/>entryCoord 2 格内<br/>己控、空置、非敌邻"]:::rules
    DEPLOY{"有合格后方部署点吗?"}:::decision
    SPAWN["部署新单位<br/>首都/城镇/工厂/高基建/高补给或 supply source<br/>必须己控、空置、非敌邻"]:::rules
    RSPAWN["增援到场<br/>append Division<br/>mark arrived<br/>写 reinforce 日志"]:::rules
    WAIT["保留订单<br/>本回合无安全 hex，等待后续回合"]:::economy
    RWAIT["保留增援<br/>无安全入口时等待后续回合"]:::economy
    REST["战术休整<br/>SupplyRules.applyResupplyRest<br/>恢复 strength / morale / fatigue / ammunition"]:::rules
    WEAR["行动消耗<br/>move / attack / counterattack / hold<br/>改变 Division morale / fatigue / ammunition"]:::rules
    VICTORY["胜负节奏<br/>VictoryRules<br/>legacy Ardennes / Waterloo runtime JSON conditions<br/>Waterloo scenario objectives 与 region objectives 保持目标点口径同步"]:::rules
    NEXT["切换阵营并刷新运行时层<br/>StrategicStateBootstrapper.refreshRuntimeState"]:::rules

    BOOT --> LEDGER
    HEX --> REGION --> INCOME --> LEDGER
    UI --> QUEUE --> VALIDATE --> PAY --> LEDGER
    UI --> RESTCMD --> REST
    UI --> ACTION --> WEAR
    END --> SUPPLY --> RESOLVE
    LEDGER --> RESOLVE
    RESOLVE --> SHORT
    SHORT -->|不足| LOW --> REINF
    SHORT -->|足够| REINF
    REINF --> PROD --> DEPLOY
    DEPLOY -->|有| SPAWN --> VICTORY
    DEPLOY -->|没有| WAIT --> VICTORY
    REINF --> SCHED --> ENTRY
    ENTRY -->|安全| RSPAWN --> VICTORY --> NEXT
    ENTRY -->|不安全| RWAIT --> VICTORY
    RESOLVE --> LEDGER

    WARN["边界<br/>经济系统不能直接占 hex<br/>也不能把中立/空控制 region 收入算给某阵营"]:::warn
    HEX -.守住.-> WARN
    VALIDATE -.守住.-> WARN

    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef economy fill:#fef9c3,stroke:#ca8a04,color:#292107
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 4. AI / 统治者-元帅决策链：AI 怎么下命令

这张图看 v0.5/v3.4 当前默认 AI 主路径。AI 不直接控制单位，也不直接改地图；统治者先生成 `StrategicPostureEnvelope`，元帅再读取降维战场摘要和 posture，模拟 LLM 输出 `TheaterDirectiveEnvelope` JSON，经 decoder 校验和 compiler 降级后，形成战区级 `DirectiveEnvelope`。`WarCommandExecutor` 再把这些战术翻译成底层 `Command`，最后交给 `RuleEngine`。

当前默认 AI 主线是 `RulerAgent -> StrategicPostureEnvelope -> StrategicPostureDecoder -> MarshalAgent -> TheaterDirective JSON -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> ZoneDirective -> WarCommandExecutor -> RuleEngine`。旧 v0.37 `TheaterCommanderPool -> ZoneCommanderAgent` 作为 fallback 和显式 `.zoneDirective` 路径保留。敌我摘要、攻击校验、ZOC、占领、前线邻接、部署分类和战区压力已开始读取 `DiplomacyState.isHostile/isFriendly`。统治者层只写战略姿态和审计记录，不直接执行命令。旧 Agent D 管线仍保留，但默认不走。

```mermaid
flowchart TD
    START["触发 AI 行动<br/>AppContainer.advanceOrRunAI / runAIIfNeeded<br/>玩家点下一回合、命令后轮到 AI，或继续存档恢复后"]:::input
    CHECK{"当前 activeFaction 该自动触发 AI 吗?<br/>phase.allowsCommands<br/>Staff Control = Staff<br/>非 observer 下不是 playerFaction<br/>observer 可让玩家方也自动跑"}:::decision
    STOP["不运行 AI<br/>Manual 非 observer 可用 End Orders 推进当前 activeFaction<br/>observer Manual 保持 Observation only / 只读"]:::stop
    REFRESH["行动前刷新运行时战略层<br/>StrategicStateBootstrapper.refreshRuntimeState<br/>避免 AI 读到旧前线/旧部署"]:::rules
    TM["AI 回合编排器<br/>TurnManager.runAITurn<br/>默认 pipelineMode = marshalDirective"]:::rules
    DIPREL["敌我/友军关系查询<br/>DiplomacyState.isHostile / isFriendly<br/>给补给、目标、ZOC、占领和前线统一口径"]:::rules
    RULER["统治者战略姿态<br/>RulerAgent.resolvePosture<br/>生成 StrategicPostureEnvelope 和 RulerDecisionRecord"]:::ai
    SPDEC["姿态解码校验<br/>StrategicPostureDecoder<br/>schema / issuer / turn / faction / zone / region"]:::command
    SUM["战场摘要<br/>MarshalBattlefieldSummarizer<br/>读取 front/deploy/目标/补给/士气/疲劳/弹药/敌骑兵摘要<br/>敌我判断来自 DiplomacyState"]:::ai
    LLM["模拟 LLM 客户端<br/>SimulatedMarshalLLMClient<br/>输出 fenced JSON，不接真实网络或模型"]:::ai
    DEC["元帅 JSON 解码器<br/>TheaterDirectiveDecoder<br/>提取 JSON、解码、校验 schema/zone/region/tactic"]:::command
    COMP["元帅意图编译器<br/>TheaterDirectiveCompiler<br/>TheaterDirective -> ZoneDirective<br/>传递 focus/convergence/coordinated 参数<br/>最多 3 条已选 rationale 写入 theaterContext"]:::command
    ENV["指令信封<br/>DirectiveEnvelope<br/>收集编译后的 ZoneDirective"]:::command
    TACTIC["高级战术路由<br/>TacticName<br/>blitzkrieg / cavalryCharge / spearhead / breakthrough / pincer / artilleryPreparation / fire / feint / guerrilla / hold / elastic / depth / lastStand<br/>敌骑兵压力偏向 Hold Line"]:::command
    WCE["指令执行器<br/>WarCommandExecutor.execute<br/>按战术 profile 选择单位、目标和 fallback；broken morale offensive order 降级为 Hold"]:::command
    BOTTOM["具体单位命令<br/>Command<br/>attack / move / hold / allowRetreat"]:::command
    RE["统一规则校验执行<br/>RuleEngine<br/>AI 和玩家共用同一套规则"]:::rules
    RECORD["指令复盘记录<br/>WarDirectiveRecord<br/>记录 tactic、target、结果、diagnostics<br/>AgentPanel 拒绝原因预览来源"]:::ui
    END["AI 自动结束回合<br/>RuleEngine.execute(.endTurn)<br/>切换 activeFaction / phase"]:::rules

    START --> CHECK
    CHECK -->|否| STOP
    CHECK -->|是| REFRESH --> TM --> DIPREL --> RULER --> SPDEC --> SUM --> LLM --> DEC --> COMP --> ENV
    ENV --> TACTIC --> WCE --> BOTTOM --> RE --> RECORD --> END

    FALLBACK["Fallback 将军池<br/>TheaterCommanderPool + ZoneCommanderAgent<br/>元帅 JSON 无效或某 zone 无指令时使用"]:::ai
    DEC -.解码失败.-> FALLBACK --> ENV
    COMP -.zone 缺指令.-> FALLBACK

    LEGACY["旧 Agent D 管线<br/>AgentContext -> DecisionProvider -> AgentCommandMapper<br/>只在 legacyAgentOrder 显式分支或测试中使用"]:::legacy
    TM -.默认不走.-> LEGACY

    MANUAL["手写战区指令<br/>手工 ZoneDirective<br/>玩家聊天命令也可以直接指定 tactic/focus/convergence"]:::input
    MANUAL --> TACTIC

    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef legacy fill:#f3f4f6,stroke:#6b7280,stroke-dasharray:5 5,color:#111827
```

## 5. MapEditor 到游戏数据：地图怎么进入主游戏

这张图看地图编辑器的输出链路。编辑器里画的是初始地图和初始战区；运行时动态战区仍由游戏里的 `hexToTheater` 推进，不是编辑器脚本控制。

```mermaid
flowchart TD
    DOC["编辑器文档<br/>MapEditorDocument<br/>保存 hex、省份、战区分配、初始单位"]:::editor
    MODE1["地块编辑<br/>hexPainter<br/>画地形、道路、控制方、补给点"]:::editor
    MODE2["省份编辑<br/>regionBuilder<br/>把每个 hex 分配给一个 region"]:::editor
    MODE3["初始战区编辑<br/>theaterAssignment<br/>把 region 分配给开局 theater"]:::editor
    MODE4["初始部队编辑<br/>unitPlanner<br/>放置开局单位和模板"]:::editor
    EXPORT["导出器<br/>MapEditorExporter.export<br/>把编辑器文档转成游戏 JSON"]:::loader
    CHECK{"导出校验通过吗?<br/>每个 hex 必须有 region；region 不能为空"}:::decision
    ERR["导出失败<br/>unassignedHex / missingRegion / emptyRegion<br/>先回编辑器补数据"]:::stop
    SCEN["场景 JSON<br/>ScenarioDefinition<br/>保存 hex 地形、控制方、补给、目标、初始单位"]:::data
    REG["省份 JSON<br/>RegionDataSet<br/>保存 hexToRegion、省份、边、初始 theaterId"]:::data
    NEI["自动推导省份邻接<br/>真实 hex 邻接 -> Region.neighbors / RegionEdge<br/>避免手写邻接出错"]:::derived
    BRIDGE["归档阿登资源桥<br/>MapEditorGameResourceBridge<br/>读取或覆盖 Archived Ardennes / 归档阿登资源<br/>未知 unit faction 抛错，不再兜底 Allies"]:::loader
    FILES["MapEditor legacy 默认资源<br/>WWIIHexV0/Data<br/>ardennes_v0_scenario.json + ardennes_v02_regions.json<br/>不等于当前 playable 默认入口"]:::data
    LOAD["游戏启动加载<br/>DataLoader.loadGameState<br/>DEBUG 下优先读源码 JSON"]:::loader
    MAP["地图状态<br/>MapState<br/>tiles + hexToRegion + RegionGraph"]:::state
    THEATER["战区状态<br/>TheaterState<br/>捕获 initialSnapshot，并 seed hexToTheater"]:::state
    FRONT["初始前线<br/>FrontLineState<br/>按开局动态战区接触生成"]:::derived
    DEPLOY["初始部署<br/>WarDeploymentState<br/>按前线/纵深/驻军分配单位"]:::derived
    GAME["游戏可运行<br/>GameState ready<br/>主游戏 UI 和规则系统开始读取"]:::state

    DOC --> MODE1 --> EXPORT
    DOC --> MODE2 --> EXPORT
    DOC --> MODE3 --> EXPORT
    DOC --> MODE4 --> EXPORT
    EXPORT --> CHECK
    CHECK -->|失败| ERR
    CHECK -->|通过| SCEN
    CHECK -->|通过| REG
    REG --> NEI --> REG
    SCEN --> BRIDGE
    REG --> BRIDGE
    BRIDGE --> FILES
    FILES --> LOAD --> MAP --> THEATER --> FRONT --> DEPLOY --> GAME

    NOTE["重要提醒<br/>MapEditor 的 theater assignment 只定义开局战区<br/>运行时推进看 hexToTheater，不看 regionToTheater"]:::warn
    MODE3 -.语义.-> NOTE

    classDef editor fill:#f6d365,stroke:#8a5a00,color:#1f1b10
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 6. v1.1 主游戏 macOS 入口

这张图只说明 v1.1 新增的 macOS 主游戏 target。它复用主游戏数据、UI、SpriteKit 棋盘和规则系统；macOS 输入只是平台桥接，不是新的规则入口。

```mermaid
flowchart TD
    TARGET["macOS 主游戏 target<br/>WWIIHexV0Mac<br/>独立于 iOS target 和 MapEditorMac"]:::platform
    APP["macOS App 入口<br/>WWIIHexV0MacApp<br/>WindowGroup + Game 菜单"]:::platform
    BOOT["游戏容器<br/>AppContainer.bootstrap<br/>优先 Waterloo；失败时保留 Waterloo 元数据并进入 1x1 inert 恢复态；初始化规则/AI"]:::state
    ROOT["主游戏界面<br/>RootGameView<br/>HUD、图层、Info、棋盘"]:::ui
    BRIDGE["macOS SpriteKit 桥<br/>BoardSceneView + BoardEventSKView<br/>NSViewRepresentable 承载 SKView"]:::platform
    SCENE["棋盘场景<br/>BoardScene<br/>鼠标点击、拖拽、滚轮/触控板缩放"]:::ui
    TAP["hex 点击回调<br/>onHexTapped(coord)<br/>只传坐标，不改 GameState"]:::input
    CONTAINER["输入解释<br/>AppContainer.handleBoardTap<br/>选中、移动、攻击意图判断"]:::rules
    COMMAND["统一命令<br/>Command / ZoneDirective<br/>玩家和 AI 共用入口"]:::command
    ENGINE["规则权威<br/>RuleEngine / WarCommandExecutor<br/>校验后修改 GameState"]:::rules
    DATA["默认资源<br/>WWIIHexV0/Data JSON<br/>DEBUG 优先源码文件，bundle 作 fallback"]:::data

    TARGET --> APP --> BOOT --> ROOT --> BRIDGE --> SCENE --> TAP --> CONTAINER --> COMMAND --> ENGINE
    DATA --> BOOT
    ENGINE --> ROOT

    WARN["禁止绕过<br/>AppKit / SpriteKit 不得直接改 GameState<br/>仍必须走规则系统"]:::warn
    SCENE -.守住.-> WARN

    classDef platform fill:#e0f2fe,stroke:#0284c7,color:#082f49
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 7. v1.0 UI / AI / 初版试玩链路

这张图说明 v1.0 分支的收口点：它不新增规则入口，只改善 UI 可读性、AI 回放、轻量性能和试玩记录。

```mermaid
flowchart TD
    STATE["运行时状态<br/>GameState + EventLog + WarDirectiveRecord"]:::state
    ROOT["主界面<br/>RootGameView + AppContainer interactionLog + CommandPanelView<br/>HUD + map layers + Info tabs<br/>拿战 faction 显示 Sector / Formation / Corps Order / Order result / Command Dispatch<br/>lastCommandMessage 走 NapoleonicMessageSanitizer"]:::ui
    LOG["日志面板<br/>EventLogView<br/>最近 60 条 LogDisplayEntry<br/>拿战分类显示 Engagement / Withdrawal / Logistics / Isolation / Dispatch；事件显示 active wing / Contact sector<br/>Standard / Concise 复用 NapoleonicMessageSanitizer 净化 raw AI、MockAI、legacy pipeline、validation rawValue 和 WWII faction 名；Full 保留 raw 审计值"]:::ui
    AIUI["AI / 外交 / 将军面板<br/>AgentPanelView + DiplomacyPanelView + GeneralCommandPanelView<br/>Staff Summary + Concise Staff Reason + Issue Preview + Recent Dispatch Timeline + corps order target + relations<br/>拿战显示 Command Dispatch / Staff Summary / Dispatch Issues / Corps Directives<br/>Standard / Concise 净化 raw id / diagnostic / country-bloc id；Full 显示 Staff Record，底层 rawJSON 保留"]:::ui
    BOARD["地图场景<br/>BoardScene + UnitNode<br/>缓存 unit display hex 后排序绘制<br/>拿战单位棋子显示 formation symbols<br/>pending 增援入口显示 RES marker<br/>目标点显示村庄/据点/道路 marker<br/>WarDirectiveRecord 显示 recent replay 线与 tactic marker<br/>玩家 defense planned operation 显示 HOLD marker"]:::ui
    MARSHAL["模拟元帅 / MockAI<br/>MarshalAgent + SimulatedMarshalLLMClient<br/>Waterloo fallback 目标按 objective-aware sorting 排序，只输出指令/命令意图"]:::ai
    ZD["战区指令<br/>ZoneDirective<br/>tactic / focus / intensity"]:::command
    WCE["执行解释<br/>WarCommandExecutor<br/>infiltration 限制默认投入"]:::command
    RULE["规则权威<br/>RuleEngine<br/>唯一修改 GameState"]:::rules
    PLAYTEST["初版试玩记录<br/>观察 UI、图层、AI diagnostics、拒绝原因"]:::doc

    STATE --> ROOT
    ROOT --> LOG
    ROOT --> AIUI
    ROOT --> BOARD
    MARSHAL --> ZD --> WCE --> RULE --> STATE
    AIUI --> PLAYTEST
    LOG --> PLAYTEST
    BOARD --> PLAYTEST

    WARN["边界<br/>UI / MockAI 不直接改 GameState<br/>仍必须走统一命令管线"]:::warn
    AIUI -.守住.-> WARN
    WCE -.守住.-> WARN

    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef doc fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 8. v0.4 将军与玩家双轨命令

这张图说明 v0.4 分支的新增主线：实体将军从 JSON / region 种子接入 FrontZone；玩家可以微操具体部队，也可以通过将军面板发战区宏观命令。两条路最终仍收口到规则系统。

```mermaid
flowchart TD
    GJSON["将军数据<br/>generals.json<br/>六位历史将军、倾向、技能、忠诚/满意度"]:::data
    RJSON["Region 种子<br/>ardennes_v02_regions.assignedGeneralId<br/>开局指定某 region 所属将军"]:::data
    DL["加载器<br/>DataLoader.loadGeneralRegistry<br/>读取 GeneralRegistry"]:::loader
    DISP["将军指派器<br/>GeneralDispatcher.assignGenerals<br/>种子 -> 偏好 -> 同阵营后备池"]:::rules
    FZ["战区部署<br/>FrontZone.generalAssignment<br/>generalId、HQ region、辖下 division、忠诚/满意度"]:::state
    POOL["将军池<br/>TheaterCommanderPool<br/>用 GeneralData 生成 ZoneCommanderAgentConfig"]:::ai

    TAP["玩家地图点击<br/>RootGameView / BoardScene<br/>选单位、选 region、选目标"]:::input
    MICRO["全微操<br/>AppContainer.submit(Command)<br/>move / attack / hold / resupply<br/>infantry-heavy hold = square-ready hold"]:::command
    LOCK["微操锁<br/>PlayerCommandState.micromanagedDivisionIds<br/>本回合玩家亲控单位"]:::state
    GENUI["将军面板<br/>GeneralCommandPanelView<br/>legacy Hold Line / Attack Region<br/>拿战 Corps Command / Hold Contact Line / Attack Sector<br/>最小 attack tactic menu + tactic brief<br/>Hold Contact Line 可形成 square-ready hold"]:::ui
    ZD["玩家战区指令<br/>ZoneDirective<br/>defense holdLine 或带 tactic 的 attack selected region"]:::command
    WCE["执行器<br/>WarCommandExecutor.execute(excluding lockedIds)<br/>跳过已微操单位"]:::command
    RE["规则权威<br/>RuleEngine<br/>校验并修改 GameState"]:::rules
    RECORD["记录<br/>WarDirectiveRecord + PlayerPlannedOperation<br/>Staff / Command Dispatch 面板、日志、计划线共用"]:::ui
    BOARD["视觉反馈<br/>BoardScene<br/>进攻箭头、防御圆环 + HOLD marker、tactic marker、微操单位金色圈"]:::ui
    PROFILE["将军档案<br/>GeneralProfileView<br/>legacy General Profile<br/>拿战 Commander Profile / Assigned Formations"]:::ui

    GJSON --> DL --> DISP
    RJSON --> DISP --> FZ --> POOL
    FZ --> GENUI --> PROFILE
    TAP --> MICRO --> RE --> LOCK
    LOCK --> WCE
    TAP --> GENUI --> ZD --> WCE --> RE --> RECORD --> BOARD
    FZ --> GENUI

    WARN["边界<br/>UI 和将军不直接改 hex / division<br/>行动必须走 Command 或 ZoneDirective"]:::warn
    GENUI -.守住.-> WARN
    WCE -.守住.-> WARN

    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```
