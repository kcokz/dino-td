# debug-agent 状态（记忆）

每次 check 结束更新这一页。最新的在上面。

## 报告一览

| id | 标题 | 严重度 | 状态 | 首次发现 |
|---|---|---|---|---|
| [BUG-001](bug/BUG-001-stage-wave-shrinks-next-raid.md) | 修好一段信标，反而让下一波（包括大波）变小 | 中 | open，需要设计拍板 | 2026-09-28 |
| [BUG-002](bug/BUG-002-launch-button-stays-after-launch.md) | 启动以后"启动信标"按钮还在卡片上 | 低 | open | 2026-09-28 |
| [BUG-003](bug/BUG-003-ambience-leaks-at-exit.md) | 退出时环境音还被占着（冒烟测试 ERROR） | 低 | open | 2026-09-28 |
| [DOC-001](design-doc/DOC-001-meals-no-longer-speed-walking.md) | 饭已经不管走路，设计书七处还写着 | — | open | 2026-09-28 |
| [DOC-002](design-doc/DOC-002-prime-meat-left-on-station-1.md) | 第 1 站没有珍贵肉了，五处还写着 | — | open | 2026-09-28 |
| [DOC-003](design-doc/DOC-003-small-stale-facts.md) | 栅栏段数、待定 2 的指向、9.3 的机器人数据 | — | open | 2026-09-28 |

## dev-assigned-task

（还没有任务。）

## 检查记录

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

## 下次要查的

- [ ] 门：人来回进出 10 次会不会卡住；恐龙会不会把门当墙咬。
- [ ] 守卫恐龙（3 章）：人躲进围墙以后，守卫会不会冲着墙去；岗位被围住以后会不会在最近处安家。
- [ ] "放置不看人"（3 章）：人或恐龙站在格子上时，建筑停在差一点造完，面板写"有东西站在它的位置上"。
- [ ] 维修价 = 造价 × 缺血比例，向上取整，永远不比重造贵。
- [ ] 游戏赢了（跳走）以后，世界是不是还在动（掉落还被捡、恐龙还在走）。
- [ ] 中文界面整局截一遍（`lang:zh_CN`），看有没有没翻译的键、文字溢出。
- [ ] 围栏里摆绊索弓（3 章"想打的东西被墙整个围住"）：恐龙会不会站在外面挨打不咬墙。`siege:...:inside` 场景。
- [ ] 能力槽悬停文字、空格子的提示（3 章）。
- [ ] 鼠标碰窗口边缘平移视角（3 章，最新提交 71646a4）。
