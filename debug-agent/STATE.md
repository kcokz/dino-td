# debug-agent 状态（记忆）

每次 check 结束更新这一页。最新的在上面。

## 报告一览

| id | 标题 | 严重度 | 状态 | 首次发现 |
|---|---|---|---|---|
| [BUG-001](bug/BUG-001-stage-wave-shrinks-next-raid.md) | 修好一段信标，反而让下一波（包括大波）变小 | 中 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-002](bug/BUG-002-launch-button-stays-after-launch.md) | 启动以后"启动信标"按钮还在卡片上 | 低 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-003](bug/BUG-003-ambience-leaks-at-exit.md) | 退出时环境音还被占着（冒烟测试 ERROR） | 低 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-004](bug/BUG-004-stage-raid-comes-without-its-warning.md) | 信标小波的预警被别的来袭盖住，到的时候没有再预警 | 低 | **fixed** ea36313 | 2026-09-28 |
| [BUG-005](bug/BUG-005-raid-mills-at-the-open-end.md) | 背后半圈栅栏时，来袭挤在船舱开口一头原地打转 | 中 | open（f65f8ea 复测：好了一部分，还没过，见 TASK-011） | 2026-09-28 |
| [BUG-007](bug/BUG-007-bare-cabin-raid-twitches-at-the-back-wall.md) | 一点不围，普通大波也挤在船舱背面抖 | 中 | **fixed** 5ad2d35 | 2026-09-28 |
| [BUG-013](bug/BUG-013-raid-mills-at-a-blocked-waypoint.md) | 大山谷：中间口子封了，绕过来的挤在原路点上转 | 中 | open | 2026-09-29 |
| [BUG-014](bug/BUG-014-small-valley-raid-steps-out-in-his-sight.md) | 小山谷：站在巢前看着，来袭在他眼前的边缘点出生 | 中 | open | 2026-09-29 |
| [BUG-015](bug/BUG-015-twitch-watch-calls-the-dusk-turn-a-mill.md) | 抽搐监视把黄昏掉头回巢报成 mill（误报） | 低 | open | 2026-09-29 |
| [BUG-016](bug/BUG-016-night-thick-mist-is-black.md) | 夜里没去过的浓雾是纯黑（又像黑色战争迷雾） | 中 | fixed 772b9c9 | 2026-09-29 |
| [BUG-017](bug/BUG-017-torch-flame-trails-behind-him.md) | 举着火把走路，火苗拖出一串 3 米长的火球 | 低 | open | 2026-09-29 |
| [BUG-018](bug/BUG-018-phytosaur-stays-in-the-torchlight-when-cornered.md) | 火把把植龙逼到场地边，它就停在火光里贴着人 | 低～中 | open | 2026-09-29 |
| [BUG-012](bug/BUG-012-raid-goes-back-to-the-nest-after-a-breach.md) | 整圈栅栏咬开口子以后，整群先跑回巢边转圈 | 中 | open | 2026-09-28 |
| [BUG-011](bug/BUG-011-defeat-screen-does-not-say-why.md) | 失败画面不说是船舱没了还是人死了 | 低 | **fixed** 72b27c8 | 2026-09-28 |
| [BUG-010](bug/BUG-010-waiting-raider-swings-its-head.md) | 等位置的恐龙在人群外面原地甩头（半圈栅栏、人在门外） | 低～中 | **fixed** 357b603 | 2026-09-28 |
| [BUG-009](bug/BUG-009-full-ring-raid-piles-on-one-crossbow.md) | 整圈栅栏 + 窝弩：来袭全冲同一架窝弩，堆在栅栏角外转圈、顶 | 中 | open | 2026-09-28 |
| [BUG-008](bug/BUG-008-twitch-watch-misses-a-slow-swing.md) | 抽搐监测漏报：原地不动、每秒甩一次头 22 秒 | 中 | **fixed** 5ad2d35 | 2026-09-28 |
| [BUG-006](bug/BUG-006-raid-stepping-out-at-dusk-never-goes-home.md) | 天快黑时出发的来袭，黄昏后才出巢的那些不回巢，照咬船舱 | **高** | **fixed** d2c30d5 | 2026-09-28 |
| [DOC-004](design-doc/DOC-004-nest-stone-is-now-deadly.md) | 巢边石头：0c1f442 以后三只守卫一起上，满血 6 秒倒下（需要拍板） | — | open | 2026-09-28 |
| [DOC-005](design-doc/DOC-005-fog-line-still-says-black.md) | 9.3 第 625 行还写着"没去过的是黑的" | — | open | 2026-09-28 |
| [DOC-001](design-doc/DOC-001-meals-no-longer-speed-walking.md) | 饭已经不管走路，设计书七处还写着 | — | **applied** ba2ca49 | 2026-09-28 |
| [DOC-002](design-doc/DOC-002-prime-meat-left-on-station-1.md) | 第 1 站没有珍贵肉了，五处还写着 | — | **applied** ba2ca49 | 2026-09-28 |
| [DOC-003](design-doc/DOC-003-small-stale-facts.md) | 栅栏段数、待定 2 的指向、9.3 的机器人数据 | — | **applied** ba2ca49 | 2026-09-28 |

## dev-assigned-task

| 任务 | 内容 | 状态 |
|---|---|---|
| TASK-001 | 暂停就是定格 | **done** 通过 |
| TASK-002 | 船舱背后半圈栅栏，来袭要绕过去咬 | **done**，没完全通过 → BUG-005 |
| TASK-003 | 人身上那一行；人在舱里不自己出去 | **done** 通过 |
| TASK-004 | 鼠标碰边缘平移；院子里的机关 | **done**：第 2 条过；第 1 条逻辑过，"开局光标已在窗口里"要人手测 |
| TASK-005 | 复测 BUG-001～003 | **done**（三个都过；另开 BUG-004） |
| TASK-006 | 白天、黄昏、夜晚 | **done**，没完全通过 → BUG-006 |
| TASK-007 | 复测 BUG-004 | **done** 通过 |
| TASK-008 | 战争迷雾和找巢 | **done** 通过 |
| TASK-009 | 复测 BUG-006 | **done** 通过 |
| TASK-010 | 抽搐监测：找漏报和误报 | **done**（BUG-007；建议加 stall） |
| TASK-011 | 复测 BUG-005；整圈栅栏的抽搐 | **done**，没通过（BUG-005 仍 open）；另开 BUG-009 |
| TASK-012 | 迷雾：没去过的全黑，远景也遮住 | **done** 通过 |
| TASK-013 | 复测 BUG-007、BUG-008 | **done** 两个都过；另开 BUG-010 |
| TASK-014 | 迷雾改成山谷里的雾 | **done** 功能都过；观感：正午太白、黄昏夜里雾比视野亮 |
| TASK-015 | 人的面板平时不开，建造吃饭固定在右下角 | **done** 通过；观感：徽章的 C 太小、吃饭图标两个数字 |
| TASK-016 | 复测 BUG-011 | **done** 通过 |
| TASK-017 | 复测 BUG-009（第二步）、BUG-010 | **done**：BUG-010 过；BUG-009 没少一半；另开 BUG-012 |
| TASK-018 | 大山谷和后台烘导航 | **done** 大部分过；另开 BUG-013 |
| TASK-019 | 守卫先示威；巢里只出一小群，其余从边缘来 | **done** 1、2、3、5 过；第 4 条小山谷另开 BUG-014 |
| TASK-020 | 迷雾的亮度跟着时辰 | **done** 正午、白斑、闪、帧率过；夜里浓雾纯黑 → BUG-016 |
| TASK-021 | 火与夜、怕火的植龙 | **done** 大体过；另开 BUG-017、BUG-018 |

## 检查记录

### 2026-09-29 第 9 次（自由找 bug，d9b75e9）

- 绊弩摆在围栏里（`siege:4:12:3:inside`）：10 秒咬穿一段栅栏，从那一格排队进去，和 3 章一致。口子前挤一团，62 份抽搐报告 → 补进 BUG-005（同一个根，更窄的口子）。
- 一开始以为是退化（d9b75e9 船舱 100/100，4e24eb4 船舱被打掉），二分到一个只改 debug-agent 的提交，复跑发现是随机：同一提交结果差很多，30 秒截图两边一样。**教训：结果类数字（船舱剩多少）不能拿来二分；先各跑 3 次看分布、再看截图。**
- 新工具：`DA_SIEGE_SHOT=1` 让 siege 在 15/30/45 秒各拍一张（`tools/harness_extra.sed`，只进生成的 agent_play.gd）；游戏自带 `SIEGE_DEBUG=1` 在 15/60 秒打印每只来袭的路点、目标、卡住计数。

### 2026-09-29 第 8 次（自由找 bug，d9b75e9）

- `map:valley_large play:25`：23 分钟打赢（跳走），守住 9 波、杀 55，船舱 78/100；0 错、0 卡住。
- 抽搐报告 12 份：6 份 mill 全是黄昏掉头回巢被窗口跨过 → BUG-015（误报）；其余是船舱边的挤、巢口刚出来的抖，没有新问题。
- TASK-019 的观感里把"守卫头上加记号"改成"加大示威动作"（项目方向：线索来自世界，不加标记）。

### 2026-09-29 第 7 次（监控循环，TASK-019 第 2～5 部分，d9b75e9）

- 新探针 `edge_plain / edge_nest_watched / edge_edge_watched / edge_final`：记每只来袭的出生点、出生时在不在视野里、在视野里有没有快跑、有没有走回头路。
- 两张图：巢最多出 5 只（普通和最后一波都是），其余轮流从边缘来；0 只走回头路；站在边缘出口上那个出口不出。
- 小山谷站在巢前：巢后的两个边缘点也在他眼里，10～15 只在眼前出生 → BUG-014。
- "在视野里飞奔"：细采样（0.05 s）看到进视野后最多再快 0.05 s，是迷雾 0.1 s 一算的延迟，不算 bug。
- `siege:8:30:1:all` 两张图都守住；抽搐报告都在船舱边（最后一波 30 只挤一个没设防的船舱）。

### 2026-09-28 第 6 次（自由找 bug，7426dbc）

- `play:25` 机器人：第 4 分半在东边巢边的石头那里被三只守卫围死（满血），船舱 100/100。探针复现：东边那块两次里一次死（第一口到死 5.7 秒），西边那块两次都没事 → DOC-004（设计取舍，不算 bug）。
- 这一局抽搐报告 0 份（只到第 2 波）。
- 设计书 9.3 第 625 行还写着迷雾是黑的 → DOC-005。
- 那一局的失败画面写"船舱被毁或人阵亡"，船舱却是满血 → BUG-011。
- 最后一波从四面来（`siege:8:30:1:all`）：155 秒守住，没有卡在入口的，抽搐报告 0 份；8 架窝弩剩 2 架、船舱 45/100（平衡，不报）。

### 2026-09-28 第 5 次（自由找 bug，7817a1e 快照）

- dev 修了 BUG-005（7daf97e），没派任务，我先测了：一点不围的好了很多（1 份），半圈栅栏的没好（5～11 份）。写进 BUG-005 的复测。
- 找到抽搐监测的一个漏报 → BUG-008（原地不动、每秒甩一次头，每次甩完都停一会儿，`settle` 把每一摆都断开了）。
- 7817a1e 的迷雾：没去过的一直黑到谷壁和天空，开局六成画面是黑的（观感，写进 TASK-008）。

### 2026-09-28 第 4 次（自由找 bug，HEAD 0c1f442 快照）

- 新探针 `guards`（0c1f442："巢的守卫一起上"）：
  - A PASS：巢边岗位 3 米处造一架窝弩，守卫去咬，21 秒咬掉，没有"追 ↔ 回家"来回翻（最多 2 次状态变化）。（窝弩也会把守卫射死，后面的案例只剩 2 只。）
  - B PASS：人走到巢 7 米内，2 只守卫 5 秒内都追了出来；人从门进了船舱，20 秒后都回到岗位附近，栅栏圈一滴血没掉，也没有守卫站在圈外。
  - C 无效：想"把一只守卫的岗位围起来"，但离巢太近的 3 格不让造，圈没封死；而且离岗位这么近的墙本来就是守卫该咬的（`building_aggro_share`）。这个情况要换摆法才测得出来，先放着。
- 新探针 `build_under_dino` PASS：一只腔骨龙站着的格子上下单栅栏，人造到 99% 停住，卡片写"盖不完 —— 有东西站在它的位置上"；恐龙一走，0.3 秒后造完。
- 顺带：现在存的设置是中文，所以不加 `lang:` 的截图也是中文。

### 2026-09-28 第 3 次（监控循环，dev 派了 7 个任务）

- 做了 TASK-001、002、003、005、007，见上表。
- **工作区有时候跑不起来**：dev 在改 `FogOfWar`（新文件、有 class_name、没提交），游戏一加载 `Main.gd` 就报 Parse Error。新工具 `tools/snapshot.sh <提交>` 把指定提交导出到本地（带导入缓存和当前的工具），`GODOT_PROJECT=<目录> run_check.sh ...` 在那上面测。任务写了"提交: X"的，就在 X 的快照上测。快照第一次要 `godot --headless --editor --quit --path <目录>` 重建类缓存。
- **我自己的错，已改**：探针的 `_build_at` 没付钱，`place_at` 扣不了钱，就什么也没造。第 2 次的 `gate_traffic` "PASS"其实没有栅栏圈，现在重跑过（24 段、门在），仍然 PASS。以后探针造东西，先数一下造出来几段再下结论。
- 新探针：`pause_raid`、`kit_row`、`boss_drops`、`half_fence`（+ `half_fence_bare`）、`stage_first`；`stage_wave_size` 改成跟完整条时间线，并且核对每条预警。

### 2026-09-28 第 2 次（监控循环）· 提交 71646a4 + 未提交改动

- dev-assigned-task：没有任务。
- 探针 `gate_traffic` ~~PASS~~ **无效**（栅栏圈没造出来，见第 3 次；重跑后 PASS）：进出门 10 趟，最慢 1.5 秒；一只腔骨龙在门外 20 秒，没进到门线里（它把门咬掉了，符合"恐龙把门当成一段墙来咬"）。
- 探针 `build_under_him` PASS：在人站的格子上下单栅栏，他先走出来，1.3 秒造完。
- 探针 `after_the_jump` INFO：跳走以后恐龙不再动，资源不再变；只有人还会听命令走动（结算画面挡着，看不到，不算 bug）。
- 中文界面（`lang:zh_CN` 跑 ui kit buildmenu menu beacon eating legible summary，25 张）：没有漏翻的键，没有文字溢出。
- 插曲：第一次跑 gate_traffic 时，编辑器和 dev 的测试同时开在这个项目上，那一局的截图分辨率和局面都不对（2560×1440、没有栅栏圈），进程没有报错就退出了。重跑干净。**以后探针挨个跑，看到"不可能的局面"先重跑再下结论。**

### 2026-09-28 第 1 次 · 提交 71646a4 + 23 个未提交文件

- 测试：全过，SCRIPT ERROR 0。冒烟：1 条 ERROR → BUG-003。
- 机器人 `play:20`：16:22 跳走，7 波，打死 66 只，船舱 49/100。日志里没有 STUCK，也没有 gave up。
- 场景截图 14 个（open cabin ui kit paused beacon buildmenu menu summary legible eating kitchen ghost buildings）：43 张，0 报错。看过：厨房、工作台、建造菜单、设置页、信标充能。
- 探针：`stage_wave_size` FAIL → BUG-001；`pause_snapshot` PASS（暂停 3 秒，33 个值都没变）；`cabin_sortie` PASS（恐龙咬后墙，人 20 秒没出舱）；`launch_button` FAIL → BUG-002。

## 每次跑局都要看的

- `runs/<时间>/twitch.txt`：抽搐监测的报告（TASK-010）。报告多的地方用 `probe:twitch_cam` 拍下来判断真假。
- 基准（7c86862）：半圈栅栏大波 6～7 份；一点不围的大波 4～6 份（BUG-007）；平静白天 0 份。

## 工具的已知限制

- **测设置页会写玩家的 settings.cfg**（`%APPDATA%/Godot/app_userdata/dino/settings.cfg`）：先备份，测完原样放回，核对 md5。

- **不要在 `run_check.sh` 跑着的时候改它**：bash 是边跑边读脚本的，改了会让正在跑的那次出语法错或者直接不跑（第 4 次那局 25 分钟的机器人就是这样白跑的）。

- `warp_mouse` 不会让 Windows 发"鼠标进入窗口"，所以凡是依赖 `NOTIFICATION_WM_MOUSE_ENTER` 的行为，探针都测不出来，要真鼠标（人手，或者 computer-use，但那会在用户桌面上弹权限框，用户不在时别用）。
- 同时开两个游戏窗口时，焦点会被抢；要焦点、要光标的探针单独跑。

## 已经确认不是 bug 的（别再查）

- 厨房的"珍贵肉"菜：第 1 站拿不到这种材料，所以按 4.3 规则不会显示（`CraftingStation._materials_known`）。只有设计书过时（DOC-002）。
- 机器人日志里 "next raid 21s" 在最后一波期间一直不动：充能倒数期间 `WaveManager._process` 本来就不走普通来袭的计时。
- 机器人截图里速度按钮一直亮着"1×"：机器人直接设 `Engine.time_scale = 3`，没有走游戏的按钮。
- 双臂窝弩的升级价格是"差价"（+2 骨，`Config.upgrade_cost`），和 6.2 一致。

- 边缘来的恐龙进视野后还快跑 ≤ 0.05 s：迷雾每 0.1 s 算一次"看得见"，一帧的延迟，眼睛看不出（第 7 次）。

## 给 dev 的附注（不是游戏 bug）

- `tools/playtest.gd` 的 `ui` 场景伪造的来袭小结里还有"1 珍贵肉"，`eating` 场景也给了珍贵肉的饭：和第 1 站现在的掉落不一致（见 DOC-002），截图会误导人。
- `eating` 场景里 `eating_eating` 那张近景，镜头在船舱墙里面，只拍到墙。
- `lang:zh_CN` 只改引擎语言，设置页的语言下拉框还显示 English。这是工具的限制，不是游戏的问题。

## 下次要查的

- [x] 门：人来回进出 10 次会不会卡住；恐龙会不会把门当墙咬。（第 2 次 PASS）
- [x] 守卫恐龙：人躲进围墙以后不冲墙（第 4 次 PASS）。
- [ ] 守卫恐龙：岗位被围住以后在最近处安家。要换摆法：圈要离岗位 4.2 米以外（`aggro_radius × building_aggro_share`），还要避开巢边不让造的格子。
- [x] "放置不看人"：人站着的格子（第 2 次 PASS）。
- [x] "放置不看人"：恐龙站着的格子（第 4 次 PASS）。
- [x] 维修价 = 造价 × 缺血比例，向上取整，封顶原价（读代码 `Building.repair_cost`，和 3 章一致）。
- [x] 跳走以后世界还动不动（第 2 次 INFO，不算 bug）。
- [x] 中文界面（第 2 次，干净）。
- [ ] 换几局机器人（不同时长 `play:25`），找 STUCK / gave up / 奇怪的 LOST。
- [x] 最后一波从三个入口（西、东、南）来：入口附近有没有卡住、被地形堵住的恐龙。（第 7 次，两张图都没有）
- [x] 围栏里摆绊索弓（3 章"想打的东西被墙整个围住"）：恐龙会不会站在外面挨打不咬墙。`siege:...:inside` 场景。（第 9 次：会咬、会进去；口子前抖 → BUG-005 补充）
- [ ] 能力槽悬停文字、空格子的提示（3 章）。
- [x] 鼠标碰窗口边缘平移视角 → TASK-004（真鼠标那一半留给人）
- [ ] 测试套件退出时的 RID/ObjectDB 泄漏（dev 说有 51 个对象、7 个资源，是测试卫生问题，可以另开 BUG）。
