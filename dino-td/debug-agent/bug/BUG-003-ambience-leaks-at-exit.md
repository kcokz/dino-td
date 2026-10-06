# BUG-003 退出时山谷环境音还被占着（开图冒烟测试报 ERROR）

- 状态: fixed（ba2ca49，2026-09-28 复测通过，见 TASK-005）
- 严重度: 低（只在退出时出现，但 AGENT-TASKS.md 要求冒烟测试不许有报错）
- 发现: 2026-09-28 · 提交 71646a4 + 未提交改动（Fx.gd 的未提交改动不涉及这里）
- 复现: `godot --headless --verbose --path . --quit-after 400`

## 现象

开图冒烟测试（AGENT-TASKS.md 第 0 节规定的那条命令）退出时有 1 条 ERROR：

```
WARNING: 2 ObjectDB instances were leaked at exit
ERROR: 1 resources still in use at exit.
```

加 `--verbose` 能看到是哪一个：

```
Leaked instance: AudioStreamPlaybackWAV ... Reference count: 1
Leaked instance: AudioStreamWAV ... Reference count: 1
Resource still in use: res://assets/audio/ambience_valley.wav (AudioStreamWAV)
```

完整日志：`runs/20260928-122041/smoke.log`、`runs/20260928-122041/smoke-verbose.log`。

## 线索（没改代码）

环境音由 `scripts/autoload/Fx.gd` 的 `_ambience` 播放。`_exit_tree()` 里已经做了 `_ambience.stop()` 和 `stream = null`，但泄漏的是一个 **playback** 对象，说明退出时还有东西拿着这次播放。`_process` 里 `_want_ambience` 为真、又没在播时，会调 `_start_ambience_now()` 重新开始播，值得查一下退出那一帧有没有又开了一次。

测试套件本身是干净的：全过，`SCRIPT ERROR` 0 条。

## 复测（2026-09-28，ba2ca49）

通过。`godot --headless --verbose --path . --quit-after 400` 连跑 3 次，都是退出码 0，没有 "leaked"、"still in use"、ERROR。
