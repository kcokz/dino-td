# BUG-028 6baadac 起测试不全绿：raptor、big_theropod、raptor_alpha、pterosaur 没有头像

- 状态: open
- 严重度: 低（游戏里用不到这四种，玩家看不到；但测试红着会盖住以后真的退化）
- 发现: 2026-09-30 · 6baadac（没派任务，自己跑的 tests + smoke）
- 复现: `GODOT_PROJECT=$(bash debug-agent/tools/snapshot.sh 6baadac) bash debug-agent/tools/run_check.sh tests`

## 现象

```
[FAIL] test_01_everything_the_panels_can_show_has_its_portrait (8 failed assertions)
  dino/raptor has a portrait / 's portrait is there to look at
  dino/big_theropod ...
  dino/raptor_alpha ...
  dino/pterosaur ...
```

smoke 0 错，SCRIPT ERROR 0，别的测试都过。

## 原因

`assets/portraits/` 里（git 里和工作目录里都）只有 `dino_coelophysis`、`dino_coelophysis_alpha`、`dino_hesperosuchus`、`dino_phytosaur`、`dino_postosuchus`。`Config.DINOS` 里还留着 `raptor`、`raptor_alpha`、`big_theropod`、`pterosaur`，新测试要每一种都有头像。两张地图的来袭、首领、夜里的都不用这四种，所以游戏里不会缺。

## 期望

给这四种也渲染头像，或者测试只查地图里会出现的种类（或者把不再用的种类从 `DINOS` 里拿掉）。
