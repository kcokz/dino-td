# BUG-021 测试套件退出时泄漏：63 个对象、9 个资源（dev 上次说 51 / 7，在涨）

- 状态: open
- 严重度: 低（测试卫生；游戏本身不受影响，但泄漏会掩盖以后真的泄漏）
- 发现: 2026-09-29 · 7f8ee65（`run_check.sh tests`，全部测试通过）
- 复现: `godot --headless --verbose --path <项目> -s res://tests/test_runner.gd`，看最后的 "Leaked instance" 和 "Resource still in use"

## 现象

```
ERROR: 1 RID allocations of type 'P10JoltBody3D' were leaked at exit.
ERROR: 2 RID allocations of type 'N16RendererViewport8ViewportE' were leaked at exit.
ERROR: 2 RID allocations of type 'N17RendererSceneCull8ScenarioE' were leaked at exit.
WARNING: 2 RIDs of type "Canvas" were leaked.
WARNING: 63 ObjectDB instances were leaked at exit
ERROR: 9 resources still in use at exit
```

`--verbose` 里按类数（前面几项）：GDScript 8、AudioStreamPlaybackWAV 4、AudioStreamPlaybackRandomizer 4、Image 3、**SceneTree 2、Window 2、World3D 2、World2D 2、ViewportTexture 2**、**GDScriptFunctionState 2**、**StaticBody3D 1**、Node3D 1、FontFile 1……

还在用的资源：`Wall.gd`、`Building.gd`、`hull_hit.wav`、`wood_break.wav`，和几个测试脚本（test_base、test_runner_smoke、test_eventbus_challenge、test_victory_auditor_probes、test_auditor2_independent_verification）。

## 猜的两处（没改代码）

1. **整棵树没放掉**：两个 SceneTree、两个 Window、两套 World/Viewport 一起漏，还有两个 `GDScriptFunctionState`（挂着没走完的 `await`）。像是退出（`quit()`）的时候还有协程在等，协程抓着树，树上所有东西都留着。可以看看哪个测试 `await` 了一个信号/计时器、没等到就结束了。
2. **一段墙没 free**：一个 StaticBody3D + Node3D，连着 `Wall.gd`、`Building.gd` 和它的两个声音（hull_hit、wood_break）。像是某个测试 `remove_child` 了一段墙，没 `free()` / `queue_free()`。

## 期望

退出时 0 泄漏；或者至少数字不再涨。可以在 test_runner 最后打印 `Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)`，哪个测试之后涨了就是哪个。
