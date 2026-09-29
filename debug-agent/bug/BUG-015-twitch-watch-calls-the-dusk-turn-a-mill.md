# BUG-015 抽搐监视把"黄昏掉头回巢"报成 mill（误报）

- 状态: open
- 严重度: 低（游戏本身没问题；是 TwitchWatch 的误报，一局大山谷 6 份，会让人白查）
- 发现: 2026-09-29 · d9b75e9（自由找 bug，`map:valley_large play:25`）
- 复现: `GODOT_PROJECT=$(bash debug-agent/tools/snapshot.sh d9b75e9) bash debug-agent/tools/run_check.sh map:valley_large play:25`，看 `twitch.txt` 里第 5 波黄昏刚开始的几份 mill

## 现象

第 3 天黄昏刚开始（day_clock 962.3～963.6，黄昏从 240 开始），第 5 波还在路上的 6 只一起报 mill：

```
#3 mill (-1.4, -8.9)  MARCH -> -  6 s: path 18.59 net 1.07
#4 mill (-0.7,-14.1)  MARCH -> -  6 s: path 22.04 net 1.3
...
#8 mill ( 0.2,-25.9)  MARCH -> -  6 s: path 27.6  net 1.21
```

可是报告那一刻的状态是：`going_home: true`，`nav_goal` 是巢 (1, −35)，速度 (0.4, −4.0)，正全速直奔巢。没有转圈。

## 原因

6 秒的窗口跨过了黄昏那一刻：前 3 秒往船舱走约 10 m，掉头后 3 秒往回走约 10 m，于是 path ≈ 20、net ≈ 1，正好符合 mill 的判据。

## 期望

`going_home` 从假变真（或者目标换了）的时候，把这只的窗口清掉重新算，这样掉头就不会被当成转圈。真正的"回家路上转圈"（比如 BUG-012）还是报得出来。

## 补充（2026-09-29, 7f8ee65）

天亮时植龙掉头回河边也一样：大山谷 `play:25` 里一份 `mill`，植龙在 (−19.6, 5.9)，`going_home: true`，目标是它的上岸点 (−41, 7)，速度 (−3.0, 0.16)，全速回去，不是转圈。
