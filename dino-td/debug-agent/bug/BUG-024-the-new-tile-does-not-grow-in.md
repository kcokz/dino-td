# BUG-024 右下角新按钮出现时没有"从 0.7 倍弹到原大"，只有金光

- 状态: open
- 严重度: 低（金光在，只是少了一半的动静）
- 发现: 2026-09-29 · f3fbc72（TASK-026 第 1 条）
- 复现: `GODOT_PROJECT=$(bash debug-agent/tools/snapshot.sh f3fbc72) bash debug-agent/tools/run_check.sh probe:corner_look`

## 现象

"吃饭"按钮第一次出现（有了一顿饭）以后，每一帧读它自己的 `scale` 和 `modulate`：

```
0:vist s1.00 m(1.54,1.35,0.90)  1:vist s1.00 m(1.54,1.34,0.90) ... 23:vist s1.00 m(1.47,1.30,0.92)
```

- 金色的 modulate 在，从 1.54 慢慢褪（对）。
- **`scale` 从第一帧起就是 1.00**，没有从 0.7 长大。火把按钮在第一个黄昏出现时也一样（0.10 s、0.13 s 都是 1.00）。

## 猜的原因（没改代码）

按钮在 HBoxContainer 里。`UiKit.come_in` 把 `scale` 设成 0.7、开一个补间；可是 `_come` 里刚 `move_child` + `visible = true`，容器下一帧重排，Godot 的 `Container.fit_child_in_rect` 会把子节点的 `scale` 重置成 1（还有 rotation）。补间只在它自己的时长（0.36 秒）里写 scale，而重排在它之后又把它压回 1，所以看不到长大。

## 期望

真的"弹"出来：比如等容器排好（`await get_tree().process_frame` 或者接 `sort_children` 信号）再开补间；或者动按钮里面的一层（图标 / 一个包着内容的 Control），不动容器直接管的那一层。
