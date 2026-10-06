# 恐龙塔防 — Version 0.0 开发计划书

> 这是 v0.0 的开发计划书，留作历史记录；里面的不少规则（行动点、阶段制、一条固定路径）已经被后来的版本推翻。游戏现在的完整设计见 [GAME-DESIGN.md](GAME-DESIGN.md)。

> 引擎：Godot 4.x / GDScript / 3D 固定斜俯视摄像机 / 目标平台 Steam (PC) 本文档三条原则：**先丑后美**（全部方块，无模型无动画）；**所有数值都是占位符**（集中放在一个配置文件里）；**每个子任务可独立完成、独立测试**。

---

## 1\. v0.0 一句话

一个原始人，用行动点在固定路径旁建造自动防御；结束行动后恐龙从巢穴沿路来袭；撑过去，建筑产出资源；清掉巢穴就赢，营火被毁就输。

## 2\. 已定规则（v0.0 的"宪法"）

**回合结构（一回合 \= 一天）**

1. **规划阶段**（不限时）：你有若干行动点（AP）。走路不花 AP。**AP 不分类别**，任何动作都可以花：建造、升级、拆除、（如启用）手动采集。  
2. **结束行动 → 进攻阶段**（自动播放）：本波恐龙从巢穴沿固定路径走向营火，遇到挡路建筑就啃，到达就打营火。你造的一切自动运作，**不可操控**。  
3. **产出阶段**：进攻结束后，所有存活的生产建筑各自产出资源。  
4. **AP 重置** \= 基础值 \+ 建筑加成。回到第 1 步。

**人口**：**只有你一个原始人**，永远不会有第二个。提升 AP 的唯一途径是建筑（茅屋 → 木屋 → 营房 之类的升级链）。

**资源**：木头、石头、食物三种，每种都有对应的生产建筑。

**波次**：每次结束行动都有一波。**每 3 波一次大波**；大波结束后**恐龙增强一档**（属性倍率上调）。

**胜利**：所有巢穴被摧毁（你的防御覆盖范围推到巢穴上，哨位把巢当目标打掉）。 **失败**：营火 HP 归零。

**单位控制**：你只能控制原始人（走动、执行动作）。建筑与防御放下即自动运作。

## 3\. v0.0 明确不做

- 不做任何 3D 模型、贴图、动画——一切都是彩色方块  
- 不做植食恐龙、生态、饥饿、季节、迁徙  
- 不做第二个原始人  
- 不做昼夜视觉、天气、音效、音乐  
- 不做存档  
- 只做 **1 种恐龙、1 个巢穴、1 条路径**（架构支持多个，内容只做一个）  
- 不做教程、主菜单、设置  
- 不做 Steam 相关任何东西

## 4\. 架构（保证子任务互不干扰的关键）

### 4.1 三个 Autoload

| Autoload | 职责 |
| :---- | :---- |
| Config | 唯一的数值与内容表：建筑表、恐龙表、波次规则、资源列表。**设计只改这里。** |
| EventBus | 全局信号总线。系统之间只通过信号说话，不直接引用对方。 |
| GameState | 运行时状态：当前阶段、AP、资源、波数、恐龙倍率、剩余巢穴数。 |

### 4.2 EventBus 信号清单（先全部声明好，各子任务只管发/收）

\# event\_bus.gd

signal phase\_changed(phase: int)            \# PLAN / ATTACK / PRODUCE

signal ap\_changed(current: int, max: int)

signal resources\_changed(res: Dictionary)

signal building\_placed(building)

signal building\_destroyed(building)

signal wave\_started(n: int, is\_big: bool)

signal wave\_ended(n: int)

signal produce\_phase()

signal dino\_spawned(dino)

signal dino\_died(dino)

signal dino\_reached\_core(dino)

signal nest\_destroyed(nest)

signal game\_won()

signal game\_lost()

### 4.3 场景树

Main (Node3D)

├── Camera3D            固定斜俯视，不可操控

├── Map                 地面、格子、路径点、巢穴位、营火位

│   ├── Ground (MeshInstance3D \+ StaticBody3D)

│   ├── Path (Node3D)   下面按顺序放 Marker3D 作为路径点

│   ├── NestSpawn (Marker3D)

│   └── CoreSpawn (Marker3D)

├── Caveman             原始人

├── Buildings (Node3D)  所有建筑实例的父节点

├── Dinos (Node3D)      所有恐龙实例的父节点

├── WaveManager         波次生成

└── HUD (CanvasLayer)

### 4.4 数据驱动：Config 的形状

所有"类型"都是字典，新增一种建筑/恐龙 \= 加一条数据，不改代码。

\# config.gd  (Autoload: Config)

const BASE\_AP := 3

const RESOURCES := \["wood", "stone", "food"\]

&nbsp;

const BUILDINGS := {

    "core": {

        "name": "营火", "kind": "core", "hp": 10,

        "cost": {}, "ap\_cost": 0,

    },

    "tower": {

        "name": "哨位", "kind": "tower", "hp": 20,

        "cost": {"wood": 4}, "ap\_cost": 1,

        "range": 5.0, "damage": 1.0, "fire\_rate": 1.0,

        "upgrades\_to": "",

    },

    "wall": {

        "name": "木墙", "kind": "wall", "hp": 30,

        "cost": {"wood": 2}, "ap\_cost": 1,

    },

    "lumber\_hut": {

        "name": "伐木屋", "kind": "producer", "hp": 10,

        "cost": {"wood": 3}, "ap\_cost": 1,

        "produces": {"wood": 2},

    },

    "hut": {

        "name": "茅屋", "kind": "ap", "hp": 10,

        "cost": {"wood": 3}, "ap\_cost": 1,

        "ap\_bonus": 0, "upgrades\_to": "wood\_house",

    },

    \# ...其余见第 7 节设计表，由你填

}

&nbsp;

const DINOS := {

    "raptor": {

        "name": "迅猛龙", "hp": 3.0, "speed": 4.0,

        "damage": 1.0, "attack\_rate": 1.0,

        "targeting": "blocker\_then\_core",

    },

}

&nbsp;

const WAVES := {

    "base\_count": 2,          \# 第 1 波数量

    "count\_per\_wave": 1,      \# 每波递增

    "big\_every": 3,           \# 每 N 波一次大波

    "big\_multiplier": 2.0,    \# 大波数量倍率

    "enhance\_after\_big": {"hp": 1.3, "damage": 1.2, "speed": 1.0},

    "spawn\_interval": 0.8,    \# 同一波内恐龙间隔（秒）

}

&nbsp;

const NEST := {"hp": 30.0}

### 4.5 建筑与恐龙的"行为挂件"

Building.tscn 是一个基类场景，根据 kind 在 \_ready() 里挂上对应的子节点/脚本：tower 挂攻击圈，producer 挂产出，ap 挂 AP 加成。这样"新增一种建筑类别"只需要新增一个挂件脚本，不动基类。恐龙同理。

---

## 5\. 子任务清单

每个子任务包含：**目标 / 验收标准 / 依赖 / 独立测试桩**。 "独立测试桩"的意思是：依赖没做完时，用什么临时东西顶上，让这个任务照样能单独做完、单独验证。

### 阶段 A — 地基

**A1 项目骨架与总线**

- 目标：新建 Godot 4 项目；创建三个 Autoload（Config、EventBus、GameState）；创建 Main.tscn 及第 4.3 节的空节点树；GameState 里有 phase / ap / ap\_max / resources / wave\_n / dino\_multipliers / nests\_alive。  
- 验收：运行不报错；在 \_ready() 打印 AP 和资源字典。  
- 依赖：无。  
- 桩：无需。

**A2 地图与格子**

- 目标：一块平面地面；把世界坐标换算成格子坐标（floor(pos / TILE\_SIZE)）；鼠标点击地面得到格子坐标；一个高亮方块跟随鼠标所在格子；在 Path 下按顺序摆好路径点 Marker3D；摆好 NestSpawn、CoreSpawn。  
- 验收：点击地面，控制台打印格子坐标；高亮块跟随；能在编辑器里看到一条由路径点连成的折线。  
- 依赖：A1（弱）。  
- 桩：无需。

**A3 回合管理器**

- 目标：GameState 实现 PLAN → ATTACK → PRODUCE → PLAN 的状态机；一个"结束行动"按钮触发 PLAN → ATTACK；ATTACK 结束时进入 PRODUCE（发 produce\_phase），然后回 PLAN 并重置 AP；每次切换发 phase\_changed。  
- 验收：反复按按钮，日志按顺序打印三个阶段；AP 每回合回满。  
- 依赖：A1。  
- 桩：波次系统（D2）没做完时，ATTACK 阶段用一个 2 秒 Timer 直接结束。

### 阶段 B — 原始人与行动点

**B1 行动点系统**

- 目标：GameState.spend\_ap(n) \-\> bool；reset\_ap() 把 ap 设为 BASE\_AP \+ 所有存活建筑的 ap\_bonus 之和；改动时发 ap\_changed。  
- 验收：调试按钮扣点、扣到 0 返回 false；重置后回到上限。  
- 依赖：A1。  
- 桩：建筑加成没做完时，加成总和先写死为 0。

**B2 原始人移动**

- 目标：Caveman.tscn（CharacterBody3D \+ 方块）；点击地面就走过去（v0.0 用直线 lerp 即可，之后可换 NavigationAgent3D）。走路不消耗 AP。  
- 验收：点哪走哪，不穿过建筑（v0.0 可以先允许穿过）。  
- 依赖：A2。  
- 桩：其他任务不需要它——原始人位置在 v0.0 不影响任何规则（见第 8 节待定项）。

**B3 建造菜单与放置**

- 目标：HUD 上列出 Config.BUILDINGS 里可建的条目；选中后地面显示半透明预览；点击格子 → 检查该格为空、AP 够、资源够 → 实例化 Building.tscn 并传入 type → 扣 AP 与资源 → 发 building\_placed。  
- 验收：能放下一个方块建筑，AP 和资源正确扣除，重复放置被拒绝。  
- 依赖：A2、B1、C1。  
- 桩：C1 没做完时，先实例化一个空的 Node3D 方块。

### 阶段 C — 建筑

**C1 建筑基类**

- 目标：Building.tscn（StaticBody3D \+ CollisionShape3D \+ 方块）；setup(type: String) 从 Config.BUILDINGS 读数据；有 hp / level / kind；take\_damage(amount)；HP 归零 → 发 building\_destroyed → queue\_free()；\_ready() 按 kind 挂对应行为挂件。  
- 验收：手动实例化一个建筑，调试扣血到 0 后消失并发信号。  
- 依赖：A1。  
- 桩：无需。

**C2 生产建筑挂件**

- 目标：kind \== "producer" 的建筑监听 EventBus.produce\_phase，把 produces 加进 GameState.resources，发 resources\_changed。  
- 验收：放一个伐木屋，结束行动后木头增加。  
- 依赖：C1、A3。  
- 桩：A3 没做完时，用调试按钮手动发 produce\_phase。

**C3 哨位（自动攻击挂件）**

- 目标：kind \== "tower" 挂一个 Area3D \+ SphereShape3D（半径 \= range）；body\_entered / body\_exited 维护目标列表；Timer 按 fire\_rate 对最近目标调用 take\_damage(damage)。目标可以是恐龙**或巢穴**（为 D3 预留）。  
- 验收：放一个哨位，让一只恐龙走进圈子，恐龙掉血直到死亡。  
- 依赖：C1、D1。  
- 桩：D1 没做完时，用任何带 take\_damage() 方法的方块 CharacterBody3D 手动推进圈子。

**C4 木墙**

- 目标：kind \== "wall"，本身没有额外行为，只是一个有 HP 的 StaticBody3D。它的意义在于：恐龙（D1）检测到前方有建筑时会停下来啃它。  
- 验收：在路径格子上放一堵墙，恐龙停在墙前攻击，墙塌后继续走。  
- 依赖：C1、D1。  
- 桩：无需（它就是最简单的建筑）。

**C5 营火（核心）**

- 目标：kind \== "core"；开局自动在 CoreSpawn 生成；HP 归零发 game\_lost。恐龙到达路径终点时对它造成伤害。  
- 验收：调试扣血到 0，触发 game\_lost。  
- 依赖：C1。  
- 桩：无需。

**C6 升级系统**

- 目标：building.upgrade()：读 Config.BUILDINGS\[upgrades\_to\]，检查 AP 与资源，通过后替换自身数据（名称/HP/加成等），level \+= 1；ap\_bonus 变化后通知 GameState 重算 ap\_max。UI 上选中建筑出现"升级"按钮。  
- 验收：茅屋 → 木屋 → 营房，AP 上限逐级上涨。  
- 依赖：C1、B1。  
- 桩：无需。

### 阶段 D — 恐龙

**D1 恐龙基类**（**里程碑 1：会走的方块**）

- 目标：Dino.tscn（CharacterBody3D \+ 方块）；setup(type, multipliers) 从 Config.DINOS 读数据并乘以倍率；持有路径点数组，依次朝下一个点移动；前方用 RayCast3D（或小 Area3D）检测建筑，检测到就停下按 attack\_rate 调用它的 take\_damage(damage)；到达最后一个点后攻击营火；自身 take\_damage()，HP 归零发 dino\_died 并 queue\_free()。  
- 验收：调试按钮生成一只，沿路径走到终点，打印"到达"；路上放一堵墙它会停下啃。  
- 依赖：A2（路径点）。  
- 桩：墙/营火没做完时，先只验证"走到终点并打印"。

**D2 巢穴与波次管理器**

- 目标：Nest.tscn（StaticBody3D \+ 方块，有 HP）在 NestSpawn 生成。WaveManager 监听 phase\_changed \== ATTACK：wave\_n \+= 1；count \= base\_count \+ count\_per\_wave \* (wave\_n \- 1\)；is\_big \= wave\_n % big\_every \== 0，大波则 count \*= big\_multiplier；按 spawn\_interval 逐只生成恐龙（传入 GameState.dino\_multipliers）；发 wave\_started(n, is\_big)；当本波恐龙全部死亡或到达 → 发 wave\_ended，通知 GameState 进入 PRODUCE；**如果是大波**，结束后把 enhance\_after\_big 乘进 GameState.dino\_multipliers。  
- 验收：连续结束行动，恐龙数量递增；第 3 波数量翻倍；第 4 波恐龙明显更硬。  
- 依赖：A3、D1。  
- 桩：无需。

**D3 清巢与胜利**

- 目标：哨位（C3）的目标筛选允许把 Nest 当目标；巢穴 HP 归零 → 发 nest\_destroyed；GameState.nests\_alive \-= 1；归零 → 发 game\_won。  
- 验收：把哨位一路建到巢穴旁，几回合后巢消失，触发胜利。  
- 依赖：C3、D2。  
- 桩：无需。

### 阶段 E — 界面与收尾

**E1 HUD**

- 目标：显示资源、AP（当前/上限）、波数、下一波是否大波、营火 HP、当前阶段、"结束行动"按钮。全部通过监听 EventBus 更新，不直接读取其他节点。  
- 验收：数值随游戏实时变化。  
- 依赖：A1（信号）。  
- 桩：可以用调试按钮手动发信号来验证。

**E2 胜负画面与重开**

- 目标：监听 game\_won / game\_lost，弹出覆盖层与"重新开始"按钮（get\_tree().reload\_current\_scene()）。  
- 验收：输赢都能重开。  
- 依赖：C5、D3。  
- 桩：调试按钮手动发信号。

**E3 数值收口与调参**

- 目标：检查项目里**没有任何一个数值散落在 Config 之外**；自己玩 5 局，调到"第 1-2 波轻松、第 3 波（大波）紧张、第 6 波要认真布局"的手感。  
- 验收：一局 10 分钟内能打到第 6 波或输掉，过程中有至少一次"要不要先造哨位还是先造伐木屋"的犹豫。  
- 依赖：全部。

---

## 6\. 推荐顺序与里程碑

因为每个任务都有桩，理论上可以按任意顺序做。但下面这个顺序能让你**最早看到东西在动**：

| 里程碑 | 子任务 | 你会看到什么 |
| :---- | :---- | :---- |
| **M1 会走的方块** | A1 → A2 → D1 | 一个红方块沿折线走到终点 |
| **M2 第一次击杀** | C1 → C3 | 蓝方块自动把红方块打死 |
| **M3 一个回合** | A3 → B1 → B3 → C5 | 花 AP 放哨位，按"结束行动"，恐龙来了 |
| **M4 经济** | C2 → E1 | 结束行动后资源涨，HUD 有数 |
| **M5 循环闭合** | D2 → D3 → E2 | **v0.0 可玩：能赢能输能重开** |
| **M6 完善** | B2 → C4 → C6 → E3 | 原始人会走、墙能挡、建筑能升级、数值调顺 |

**M5 完成即 v0.0 完成。** M6 是锦上添花，做不完也不影响"v0.0 可玩"这个判断。

如果在某个任务上卡了超过一个晚上，直接跳到另一个阶段的任务——架构保证它们互不影响。

---

## 7\. 设计留白（这些表由你来填）

下面是数据表的**字段定义 \+ 一行示例**。填好后直接誊进 config.gd。

### 7.1 资源表

| id | 名称 | 生产建筑 | 是否每日消耗 | 备注 |
| :---- | :---- | :---- | :---- | :---- |
| wood | 木头 | 伐木屋 | 否 | 基础建材，营地附近 |
| stone | 石头 | 采石场 | 否 | 升级用，离路径近 |
| food | 食物 | 猎屋/农田 | **待定**（见第 8 节） |  |

### 7.2 建筑表

字段：id / 名称 / kind / hp / cost{} / ap\_cost / range / damage / fire\_rate / produces{} / ap\_bonus / upgrades\_to / 放置限制 / 备注

kind 可选值：core tower wall producer ap（AP 加成）。新增 kind 就是新增一个挂件脚本。

| id | 名称 | kind | hp | cost | ap\_cost | 特有属性 | upgrades\_to | 备注 |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| core | 营火 | core | 10 | — | 0 | — | — | 开局自带 |
| tower | 哨位 | tower | 20 | wood 4 | 1 | range 5 / damage 1 / fire\_rate 1 |  | 唯一输出 |
| wall | 木墙 | wall | 30 | wood 2 | 1 | — |  | 只买时间 |
| lumber\_hut | 伐木屋 | producer | 10 | wood 3 | 1 | produces wood 2 |  |  |
| quarry | 采石场 | producer |  |  |  | produces stone ? |  | 你填 |
| hunting\_hut | 猎屋 | producer |  |  |  | produces food ? |  | 你填 |
| hut | 茅屋 | ap | 10 | wood 3 | 1 | ap\_bonus 0 | wood\_house |  |
| wood\_house | 木屋 | ap |  |  |  | ap\_bonus ? | barracks | 你填 |
| barracks | 营房 | ap |  |  |  | ap\_bonus ? | — | 你填 |
| （空行） |  |  |  |  |  |  |  | 陷阱坑 / 篝火 / 储藏 留给 v0.1 |

### 7.3 升级链

格式：A → B → C，每一级的 cost 与 ap\_cost 在建筑表里各自定义。

| 链 | 说明 |
| :---- | :---- |
| hut → wood\_house → barracks | AP 加成逐级上涨 |
| tower → ? → ? | 你填：射程/伤害/射速的升级路线 |
| wall → ? | 你填：木墙 → 石墙 |

### 7.4 恐龙表

字段：id / 名称 / hp / speed / damage / attack\_rate / targeting / 体型(占格数) / 备注

targeting 可选值：

- blocker\_then\_core：挡路就啃，否则走向营火（默认）  
- ignore\_walls：无视墙，直奔营火（翼龙用）  
- prefer\_buildings：优先攻击范围内任何建筑（大型兽脚类用）

| id | 名称 | hp | speed | damage | attack\_rate | targeting | 逼玩家做什么 |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| raptor | 迅猛龙 | 3 | 4.0 | 1 | 1.0 | blocker\_then\_core | 火力密度 |
| big\_theropod | 大型兽脚类 | ? | 慢 | 高 | ? | prefer\_buildings | 厚墙 \+ 陷阱（v0.1） |
| pterosaur | 翼龙 | ? | 快 | 低 | ? | ignore\_walls | 核心附近也要防（v0.2） |

**v0.0 只做第一行。** 后两行是路线图。

### 7.5 波次规则

| 参数 | 占位值 | 说明 |
| :---- | :---- | :---- |
| base\_count | 2 | 第 1 波恐龙数 |
| count\_per\_wave | 1 | 每波递增 |
| big\_every | 3 | 每 3 波一次大波 |
| big\_multiplier | 2.0 | 大波数量倍率 |
| enhance\_after\_big | hp ×1.3, damage ×1.2 | 大波后恐龙增强 |
| spawn\_interval | 0.8 s | 同波内出生间隔 |

如果想手调前几波，可以加一张显式波次表（第 N 波：哪些恐龙各几只），优先级高于公式。

### 7.6 尚未定义、给你留的设计位

- **大波之后的"增强"是否也给玩家一次奖励**（roguelite 三选一）？v0.0 默认只增强恐龙。  
- **多巢穴时路径是否汇合**：默认各自独立通向营火。  
- **哨位是否需要原始人驻守**：v0.0 默认**不需要**（你只有一个人，驻守会把他锁死）。  
- **拆除建筑**：返还多少资源、花不花 AP。

---

## 8\. 待定决策（做之前不必定，做到时再定）

| 问题 | v0.0 默认 | 什么时候必须定 |
| :---- | :---- | :---- |
| 食物是否每日消耗？消耗了没有会怎样？ | **不消耗**，食物只是建材 | 做 C2 时 |
| 建造是否要求原始人先走到目标格子？ | **不要求**（点哪建哪） | 做 B3 时；若要求，B2 变成 B3 的依赖 |
| 进攻阶段原始人会不会被攻击？ | **不会**（视为在营火里） | 做 D1 时 |
| 墙挡路时恐龙是绕路还是啃？ | **啃**（路径固定，永不绕路） | 已定 |
| 哨位打巢穴时巢穴会反击吗？ | **不会** | 做 D3 时 |

---

## 9\. v0.0 完成标准

满足以下全部，v0.0 即完成：

1. 一局能在 10 分钟内**玩到结束**（赢或输）  
2. 至少有一次让你**犹豫**的决定（先经济还是先防御）  
3. 第 3 波（大波）**明显比前两波紧张**  
4. 项目里**没有任何数值散落在 config.gd 之外**  
5. 你能给一个朋友解释规则，他 1 分钟内听懂

不需要满足：好看、有声音、有多种恐龙、有多个巢穴、能存档。

---

## 10\. 怎么用这份文档让 AI 帮你写代码

每次只做**一个子任务**。把以下三样贴给 AI：

1. 第 2 节（已定规则）+ 第 4 节（架构与信号清单）  
2. 你当前项目的节点树和相关脚本  
3. 这一个子任务的"目标 / 验收 / 依赖 / 桩"

不要一次贴整份文档让它"把游戏做出来"——那样得到的东西你看不懂也改不动。一次一个子任务，验收通过再下一个。

&nbsp;

&nbsp;