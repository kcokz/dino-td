# 可并行交付的任务（给另一个 agent）

> 这个文件是**交接单**。每条任务都写成可以**冷启动**完成的样子：不需要读聊天记录，不需要问人，做完能自证。
>
> **给人看的用法**：把这个文件整份交给 agent，告诉它做**第几条**。它自己开分支、自己跑测试、自己提交。做完我来 review。
>
> 一次只派**一条**给一个 agent。每条任务下面都写了它会碰哪些文件，以及同时在进行的工作会碰哪些——目的就是让两边不撞车。

---

## 第 0 节：这个项目的"宪法"（每条任务都必须守）

**违反下面任何一条，review 会直接打回，即使功能是对的。**

1. **所有玩法数值只许写在 `scripts/autoload/Config.gd`**。代码里出现一个裸数字（血量、价格、速度、半径、时长、颜色）就是错的。新加一类东西就在 Config 里加一个块，并写清**为什么是这个数**。
2. **所有会被玩家看到的文字只许写在 `translations/strings.csv`**，且**必须同时给 `en` 和 `zh_CN` 两列**。代码里出现中文或英文字面量就是错的。
3. **模块之间通过 `EventBus` 通信**，不要让一个模块直接抓另一个模块的节点。已有的 autoload：`Config`、`EventBus`、`GameState`、`I18n`、`Fx`。
4. **测试从 Config 推导期望值，绝不复述数值**。`assert_eq(cost, 2)` 是错的；`assert_eq(cost, cost_of("wall"))` 是对的。理由：数值是要调的，复述了数值的测试会在调数值时假报警，于是没人再信它。
5. **一个测试必须真的断言过东西**。runner 现在会把「跑完 0 条断言」判成 **FAIL**——因为那通常意味着方法中途出错被打断了。如果你看到这种失败，去看它上面的 `SCRIPT ERROR`。
6. **注释写"为什么"，不写"是什么"**。代码已经说了是什么。这个仓库里的注释密度和语气请照着邻近文件抄。
7. **主语没了的测试要删，不要改成断言死代码还是死的**。

### 怎么跑

```bash
"C:/Users/jobzk/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd
```

必须是 **584 项全过、0 失败**（加上你自己新增的）。另外跑一遍开图冒烟测试，不许有报错：

```bash
"C:/Users/jobzk/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --quit-after 400
```

**两个坑**：新增带 `class_name` 的脚本、或改了 `translations/strings.csv` 之后，**必须**先跑一次下面这条重建缓存，否则会报「Identifier not declared」或翻译不生效：

```bash
"C:/Users/jobzk/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --editor --quit
```

### 分支与提交

- 从 `main` 开分支，名字写在每条任务里。
- commit message 用现在这个仓库的风格：**小写祈使句的一行标题**（`feat(v0.5): ...`），然后空行，然后**说清为什么这样做、以及你否决了什么方案**。照着 `git log` 抄语气。
- 结尾加一行：`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- **不要 push，不要合并到 main。** 留在你的分支上，交给我 review。

### 背景：现在在做什么

v0.5 是**视觉 MVP**：不扩玩法，只把现在全是方块的画面换成一套统一风格的美术。范围就八样（一种恐龙、船舱、人、木栅栏、树木、地形、石头、巢穴），验收标准是**一张八样同框的截图**看起来像出自同一个游戏。完整计划见 [VERSION.md](VERSION.md) 的 v0.5 一节。

**动手做美术之前有三件代码事要先做**，因为少了它们，换上模型只会得到一堆僵直的雕像：

1. ~~让代码不关心美术~~ —— **已完成**（分支 `v0.5-art-as-data`）。现在 `Config.VISUALS` 声明每样东西的**美术在哪**，`scripts/fx/VisualLibrary.gd` 把它交出来并**按声明的尺寸装配好**。换模型 = 改 `Config.VISUALS` 里一行的 `scene`，**没有任何逻辑要动**。两条不变量由 `tests/test_v05_visual_library.gd` 盯着：**碰撞体和外形都从同一个声明尺寸来**（美术永远不许比拦得住恐龙的那个东西更宽），以及**买来的模型无论什么比例、什么原点都能装进去**。
2. 动画状态机接口——**正在由主 agent 做，不要碰**
3. `WorldEnvironment`（天空、环境光、雾、色彩分级）——**这就是下面的任务 1**

---

## 任务清单

| # | 任务 | 状态 | 分支 |
|---|---|---|---|
| 1 | 场景环境：`WorldEnvironment` —— **v0.5 里对"看起来写实"贡献最大的一步** | 待领取 | `v0.5-environment` |
| 2 | 丘陵看起来像丘陵 | **主 agent 已接手，不要派** | `v0.5-terrain` |
| 3 | 资源点的"采空"状态 | **已解除阻塞**（`v0.5-art-as-data` 进 main 之后即可开） | `v0.5-resource-states` |

---

## 任务 1：场景环境（`WorldEnvironment`）

**分支**：`v0.5-environment`

### 目标

`scenes/Main.tscn` 现在**没有 `WorldEnvironment`**：没有天空、没有环境光、没有雾、没有 SSAO、没有 bloom、没有色彩分级，**整张图只有一盏平行光**。统一风格有一半来自光照，所以这个必须先有——它是后面所有模型的"底片"。

### 为什么这是独立的一条

它不动任何实体的外形代码，只加一个节点和一块配置。所以它可以和「让代码不关心美术」同时进行，互不干扰。

### 要改的文件

- `scenes/Main.tscn`（加节点）
- `scripts/autoload/Config.gd`（**新增一个 `ENVIRONMENT` 块，不要动别的块，不要重排已有内容**）
- `tests/test_v05_environment.gd`（新建）

**同时在改的文件（不要碰）**：`scripts/entities/Building.gd`、`Dino.gd`、`Hero.gd`、`ResourceNode.gd`、`Nest.gd`、`scripts/entities/Wall.gd`。

### 风格已定：写实 PBR（这条任务因此变重要了）

美术方向已经拍板：**写实 PBR，目标是"风格化的写实"而不是照片级**（理由见 [VERSION.md](VERSION.md) 的 v0.5 一节）。

这件事直接决定这条任务的目标，请先读懂再动手：

> **在 PBR 里，"统一风格"主要由光照和后处理决定，不由模型决定。** 光照对了，模型参差不齐也能读成一体；光照不对，模型再匹配也像贴上去的。而游戏用的是**固定斜俯视相机、永远不贴脸**，所以毛孔级细节看不见——真正决定"像不像真的"的是**阴影接触、环境光遮蔽、远景雾、曝光与色调映射**。

也就是说：**这条任务是整个 v0.5 里对"看起来写实"贡献最大的一步**，比任何一个模型都大。请按这个标准做，而不是按"加个天空就算完"。

具体的倾向（不是硬规定，但偏离了要在 Config 注释里说明为什么）：

- **色调映射用 AgX 或 ACES**，不要留在 Linear/Reinhard——写实感的第一道门槛就在这里。
- **阴影要有接触感**：平行光的阴影参数（bias / normal bias / blur / 分屏距离）一并收进 Config，让"物体和地面接在一起"这件事可调。
- **SSAO 要开**，强度克制。这是俯视相机下最划算的一项：它把物体压在地上。
- **雾要有**，且是"远古、开阔"最便宜的一半。
- **glow 克制**，写实场景里过量的 bloom 立刻掉档。
- **尺度是 PBR 的一部分**：`Config.TILE_SIZE` 是 2 米、`Config.HERO.width` 是 0.8 米，环境的雾距、阴影距离请按这个真实尺度来定，不要按"看起来差不多"来定。

### 要做的事

1. 在 `Main.tscn` 里加一个 `WorldEnvironment` 节点，带一个 `Environment` 资源。
2. **它的每一项都从 `Config.ENVIRONMENT` 读**，不要把数值写死在 `.tscn` 里。做法：加一个小脚本挂在这个节点上（例如 `scripts/fx/SceneEnvironment.gd`），在 `_ready()` 里按 Config 把 `Environment` 建出来/覆盖掉。**理由**：`.tscn` 里的数字改起来要开编辑器，而且测试读不到；Config 里的数字是可测的、可调的、有注释的。
3. `Config.ENVIRONMENT` 至少要覆盖：
   - 天空（`ProceduralSkyMaterial` 的天顶色 / 地平线色 / 太阳曲线——先不要贴图）
   - 环境光（来源、强度）
   - 雾（开关、密度、颜色）——**远景雾是"远古、开阔"最便宜的一半**
   - 色调映射（`tonemap_mode`、曝光、白点）
   - SSAO 与 glow（开关 + 强度）
4. **注意船舱**。船舱内景（`scenes/CabinInterior.tscn`）是**实例化在地图下方 200 米**的同一个世界，只是切相机进去，它自带一盏 `OmniLight3D`。所以你加的天空和环境光**也会照到室内**。要求：进船舱之后画面仍然**读起来像室内**（不能被室外天光洗白，也不能黑得看不见工位）。如果做不到两头兼顾，就让船舱自己也有一份配置，并在 Config 里写清为什么需要两份。

### 验收（新建 `tests/test_v05_environment.gd`）

- `Main.tscn` 里**有且只有一个** `WorldEnvironment`，且它的 `environment` 不是 null。
- `Environment` 上的每一项**等于 `Config.ENVIRONMENT` 里对应的值**（这是这条任务最重要的断言：它证明数值真的只有一个来源）。
- 雾、SSAO、glow 的开关状态跟着 Config 走：把 Config 的开关理解成唯一真相，测试不要复述 true/false 字面量以外的东西。
- 进入船舱之后（`main.enter_cabin()`），相机切过去了，而且**室内仍然有光**——至少断言船舱那盏灯还在、还亮着，并且没有被环境设置顶掉。
- 冒烟测试无报错。

### 不在范围内

- 不要动摄像机的位置、角度、投影方式。
- 不要接任何模型、不要加贴图文件。
- 不要改 `DirectionalLight3D` 的角度（它现在的角度是有人调过的）；**可以**把它的颜色/强度也收进 Config，如果你这么做，在注释里说明。

---

## 任务 2：丘陵看起来像丘陵

**分支**：`v0.5-hill-mesh`

### 目标

丘陵的**规则**在 v0.4 就落地了（`GridManager.blocked_cells`：不可建造、不可通行，人和恐龙都挡），但**外观还是一个方块**——`Main.spawn_terrain()` 每格丢一个 `BoxMesh`。这条任务只做外观那一半：让它看起来像地形，而不是像一堆灰盒子。

### 为什么这是独立的一条

它只碰 `spawn_terrain()` 一个函数和 Config 的 `MAP` 块。不碰实体、不碰战斗、不碰经济。

### 要改的文件

- `scripts/core/Main.gd`（只改 `spawn_terrain()`）
- `scripts/autoload/Config.gd`（`MAP` 块里加你需要的数值，或新增一个 `TERRAIN` 块）
- `tests/test_v05_hill_mesh.gd`（新建）

**同时在改的文件（不要碰）**：`scripts/entities/*.gd` 全部。

### 要做的事

把每格一个方块换成看起来像丘陵的网格。**唯一的硬约束，也是这条任务真正的难点**：

> **外观边界必须和格子边界对得上。**

因为格子是真相——`is_cell_blocked()` 决定谁能走、能不能建。如果山坡画得比格子胖，玩家会看到「明明是空地却造不了」；画得比格子瘦，玩家会看到「明明能走过去却走不过去」。这两种都是这个项目反复在修的同一类 bug（看起来是一回事、实际是另一回事），不许再引入一个。

所以：
1. 网格的水平投影**不能超出**它所占的那些格子。
2. **相邻的丘陵格子之间不许有缝**——现在的方块是贴着的，换成有坡度的网格之后很容易在两格之间裂开一道口子。请让相邻格子在接缝处等高。
3. 高度用 `Config.MAP.hill_height`（现在是 2.2，比人高，看得出走不过去）。**不要**为了好看而降低它。
4. 碰撞体不用跟着变漂亮——它可以继续是那个盒子。**但要在注释里说清这个决定**：碰撞比外观略"方"是可以接受的（外观只会在格子内部收进去，不会溢出），而反过来不行。

做法建议（不强制）：用 `ArrayMesh` / `SurfaceTool` 按格子生成顶点，格子中心抬高、格子边缘落到地面，相邻格子共享边缘高度。**不要**引入外部资源或插件。

### 验收（新建 `tests/test_v05_hill_mesh.gd`）

- 每个 `Config.MAP.default_blocked_cells` 里的格子都有一个对应的地形节点（这条已有测试覆盖，别弄坏：见 `tests/test_v04_terrain.gd`）。
- **网格的 AABB 水平范围不超出该格子的范围**（用 `GridManager.cell_to_world_origin()` 和 `Config.TILE_SIZE` 算，不要写死 2.0）。
- 最高点等于 `Config.MAP.hill_height`。
- **相邻两个丘陵格子在共享边上等高**（这是"不许有缝"的可测形式）。
- `test_v04_terrain.gd` 整套仍然全过——尤其是「没有任何东西站在山里」和「丘陵不封死走廊」。

### 不在范围内

- 不要改哪些格子是丘陵（那是关卡设计，`Config.MAP.default_blocked_cells`）。
- 不要做贴图、不要做草木装饰。
- 不要碰 `Map/Ground` 那块大地面。

---

## 任务 3：资源点的"采空"状态

**分支**：`v0.5-resource-states`
**前置**：等 `v0.5-art-as-data` 进 `main`（那条已做完，seam 已经在了）。

### 目标

树和石头**会被采光**（`ResourceNode.is_depleted`），所以它们各需要**两个**外形：完整的、采空的。现在采空只是**改个颜色再压扁一点**——玩家要凑近看颜色才知道这棵树没了。v0.5 要让它一眼看得出来。

### 为什么这条现在很小了

seam 已经做好了：`ResourceNode._ensure_body()` 已经在按状态取外形——

```gdscript
var body: Node3D = VisualLibrary.make(key, "depleted" if is_depleted else "full")
```

——只是 `VisualLibrary` 目前**把两个 variant 都解析成同一个占位几何体**。所以这条任务就是让 variant 真的分叉。

### 要改的文件

- `scripts/autoload/Config.gd`（`VISUALS` 的 `node/*` 三项）
- `scripts/fx/VisualLibrary.gd`（让 `variant` 选到不同的 `scene` / `placeholder`）
- `scripts/entities/ResourceNode.gd`（采空时要重建 body，现在只改了颜色——见 `_update_visuals`）
- `tests/test_v05_resource_states.gd`（新建）

### 要做的事

1. 让 `VISUALS` 的一项能声明**按 variant 区分的外形**。形状由你定，但要满足：**不带 variant 的 key 写法不许改**（其他十几项都不需要 variant，不能被迫写样板）。一个够用的形状是让 `scene` / `placeholder` 既可以是字符串，也可以是 `{"full": ..., "depleted": ...}` 这样的字典；`VisualLibrary` 拿不到匹配的 variant 就退回默认那一个。**在 Config 的注释里写清你选了哪种写法、为什么。**
2. 让采空真的换外形而不只是换颜色：`ResourceNode` 在 `is_depleted` 翻转时要**重建 body**（`_ensure_body()`），不能只走 `_update_visuals()`。
3. 占位阶段也要**看得出区别**——不要等模型到了才有区别。树采空了应该明显变矮变秃（例如从 `cylinder` 变成矮一截的 `cone` 或更短的 `cylinder`），不是同一个圆柱换灰色。**采空后的尺寸也要从 Config 声明**，不许在代码里写死一个缩放系数。

### 验收（新建 `tests/test_v05_resource_states.gd`）

- 完整状态和采空状态的 body **几何上不同**：断言的是尺寸或网格类型不同，**不要只断言颜色不同**（颜色不同现在就成立，那样的测试证明不了这条任务做了事）。
- 采空之后 `_ensure_body()` 真的跑过了：例如断言 body 下的 mesh 数量或 mesh 类型变了。
- **没有 variant 的 key 一切照旧**：`VisualLibrary.make("hero")`、`make("building/tower")` 的结果和现在完全一样（`tests/test_v05_visual_library.gd` 整套必须继续全过，尤其 test_05「占位体正好是声明的尺寸」）。
- 采空后的尺寸来自 Config，测试从 Config 推导它，不复述数字。
- 三种资源点（wood / stone / water）都要覆盖——water 目前没有采集途径，但它在表里，不能因为没人采就崩。

### 不在范围内

- 不要接真模型、不要加美术文件（这条只做 seam 和占位体的分叉）。
- 不要改采集速率、储量这些玩法数值。
- 不要碰 `ResourceNode` 的碰撞体大小规则（碰撞从声明尺寸来，这是 v0.5 的不变量）。

---

## 加任务的格式

以后往这个文件里加任务，照上面的模板：**目标 / 为什么这是独立的一条 / 要改的文件（以及同时在改的、不要碰的）/ 要做的事 / 验收 / 不在范围内 / 分支名**。

「为什么这是独立的一条」和「不要碰的文件」这两栏不是客套——它们是这个文件能并行的全部原因。
