# debug-agent 状态（记忆）

每次 check 结束更新这一页。最新的在上面。

## 报告一览

| id | 标题 | 严重度 | 状态 | 首次发现 |
|---|---|---|---|---|
| [BUG-001](bug/BUG-001-stage-wave-shrinks-next-raid.md) | 修好一段信标，反而让下一波（包括大波）变小 | 中 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-002](bug/BUG-002-launch-button-stays-after-launch.md) | 启动以后"启动信标"按钮还在卡片上 | 低 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-003](bug/BUG-003-ambience-leaks-at-exit.md) | 退出时环境音还被占着（冒烟测试 ERROR） | 低 | **fixed** ba2ca49 | 2026-09-28 |
| [BUG-004](bug/BUG-004-stage-raid-comes-without-its-warning.md) | 信标小波的预警被别的来袭盖住，到的时候没有再预警 | 低 | open | 2026-09-28 |
| [DOC-001](design-doc/DOC-001-meals-no-longer-speed-walking.md) | 饭已经不管走路，设计书七处还写着 | — | **applied** ba2ca49 | 2026-09-28 |
| [DOC-002](design-doc/DOC-002-prime-meat-left-on-station-1.md) | 第 1 站没有珍贵肉了，五处还写着 | — | **applied** ba2ca49 | 2026-09-28 |
| [DOC-003](design-doc/DOC-003-small-stale-facts.md) | 栅栏段数、待定 2 的指向、9.3 的机器人数据 | — | **applied** ba2ca49 | 2026-09-28 |

## dev-assigned-task

| 任务 | 内容 | 状态 |
|---|---|---|
| TASK-001 | 暂停就是定格 | open |
| TASK-002 | 船舱背后半圈栅栏，来袭要绕过去咬 | open |
| TASK-003 | 人身上那一行；人在舱里不自己出去 | open |
| TASK-004 | 鼠标碰边缘平移；院子里的机关 | open |
| TASK-005 | 复测 BUG-001～003 | **done**（三个都过；另开 BUG-004） |

## 检查记录

### 2026-09-28 第 2 次（监控循环）· 提交 71646a4 + 未提交改动

- dev-assigned-task：没有任务。
- 探针 `gate_traffic` PASS：进出门 10 趟，最慢 1.5 秒；一只腔骨龙在门外 20 秒，没进到门线里（它把门咬掉了，符合"恐龙把门当成一段墙来咬"）。
- 探针 `build_under_him` PASS：在人站的格子上下单栅栏，他先走出来，1.3 秒造完。
- 探针 `after_the_jump` INFO：跳走以后恐龙不再动，资源不再变；只有人还会听命令走动（结算画面挡着，看不到，不算 bug）。
- 中文界面（`lang:zh_CN` 跑 ui kit buildmenu menu beacon eating legible summary，25 张）：没有漏翻的键，没有文字溢出。
- 插曲：第一次跑 gate_traffic 时，编辑器和 dev 的测试同时开在这个项目上，那一局的截图分辨率和局面都不对（2560×1440、没有栅栏圈），进程没有报错就退出了。重跑干净。**以后探针挨个跑，看到"不可能的局面"先重跑再下结论。**

### 2026-09-28 第 1 次 · 提交 71646a4 + 23 个未提交文件

- 测试：全过，SCRIPT ERROR 0。冒烟：1 条 ERROR → BUG-003。
- 机器人 `play:20`：16:22 跳走，7 波，打死 66 只，船舱 49/100。日志里没有 STUCK，也没有 gave up。
- 场景截图 14 个（open cabin ui kit paused beacon buildmenu menu summary legible eating kitchen ghost buildings）：43 张，0 报错。看过：厨房、工作台、建造菜单、设置页、信标充能。
- 探针：`stage_wave_size` FAIL → BUG-001；`pause_snapshot` PASS（暂停 3 秒，33 个值都没变）；`cabin_sortie` PASS（恐龙咬后墙，人 20 秒没出舱）；`launch_button` FAIL → BUG-002。

## 已经确认不是 bug 的（别再查）

- 厨房的"珍贵肉"菜：第 1 站拿不到这种材料，所以按 4.3 规则不会显示（`CraftingStation._materials_known`）。只有设计书过时（DOC-002）。
- 机器人日志里 "next raid 21s" 在最后一波期间一直不动：充能倒数期间 `WaveManager._process` 本来就不走普通来袭的计时。
- 机器人截图里速度按钮一直亮着"1×"：机器人直接设 `Engine.time_scale = 3`，没有走游戏的按钮。
- 双臂窝弩的升级价格是"差价"（+2 骨，`Config.upgrade_cost`），和 6.2 一致。

## 给 dev 的附注（不是游戏 bug）

- `tools/playtest.gd` 的 `ui` 场景伪造的来袭小结里还有"1 珍贵肉"，`eating` 场景也给了珍贵肉的饭：和第 1 站现在的掉落不一致（见 DOC-002），截图会误导人。
- `eating` 场景里 `eating_eating` 那张近景，镜头在船舱墙里面，只拍到墙。
- `lang:zh_CN` 只改引擎语言，设置页的语言下拉框还显示 English。这是工具的限制，不是游戏的问题。

## 下次要查的

- [x] 门：人来回进出 10 次会不会卡住；恐龙会不会把门当墙咬。（第 2 次 PASS）
- [ ] 守卫恐龙（3 章）：人躲进围墙以后，守卫会不会冲着墙去；岗位被围住以后会不会在最近处安家。
- [x] "放置不看人"：人站着的格子（第 2 次 PASS）。
- [ ] "放置不看人"：**恐龙**站着的格子——建筑停在差一点造完，面板写"有东西站在它的位置上"。
- [x] 维修价 = 造价 × 缺血比例，向上取整，封顶原价（读代码 `Building.repair_cost`，和 3 章一致）。
- [x] 跳走以后世界还动不动（第 2 次 INFO，不算 bug）。
- [x] 中文界面（第 2 次，干净）。
- [ ] 换几局机器人（不同时长 `play:25`），找 STUCK / gave up / 奇怪的 LOST。
- [ ] 最后一波从三个入口（西、东、南）来：入口附近有没有卡住、被地形堵住的恐龙。
- [ ] 围栏里摆绊索弓（3 章"想打的东西被墙整个围住"）：恐龙会不会站在外面挨打不咬墙。`siege:...:inside` 场景。
- [ ] 能力槽悬停文字、空格子的提示（3 章）。
- [ ] 鼠标碰窗口边缘平移视角（3 章，最新提交 71646a4）。→ 就是 TASK-004
- [ ] 测试套件退出时的 RID/ObjectDB 泄漏（dev 说有 51 个对象、7 个资源，是测试卫生问题，可以另开 BUG）。
