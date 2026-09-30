# BUG-027 小山谷重新开始一局，手绘地图还挂在右上角（没做就有）

- 状态: open
- 严重度: 低～中（新一局一开始就有地图，等于白送；地图也会跟新一局的状态不符）
- 发现: 2026-09-30 · b631095（TASK-028 第 10 条）
- 复现: `GODOT_PROJECT=$(bash debug-agent/tools/snapshot.sh b631095) bash debug-agent/tools/run_check.sh probe:hand_map`（小山谷）；加 `DA_MAP=valley_large` 是好的

## 现象

在工作台做出手绘地图（1 皮、10 秒），然后 `Main.restart_game()`（和"再来一局"、菜单里的重新开始一样）：

| 图 | 重新开始 1 秒后 |
|---|---|
| 小山谷 | 地图**还显示着**，`has_unlock("hide_map")` 是 false（跑了两次都这样） |
| 大山谷 | 地图不显示（对） |

## 猜的原因（没改代码）

`HUD._refresh_minimap()` 按 `has_unlock("hide_map")` 设 `minimap.visible`，但重新开始以后它大概只在解锁变化时才被调用；新 HUD 里 minimap 的初始 `visible` 如果是 true、又没人叫一次 refresh，它就一直显示着。两张图结果不一样，可能是刷新时机赶巧不同。

## 期望

新一局开始时刷新一次，没有 `hide_map` 就不显示。
