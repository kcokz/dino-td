# BUG-029 恐龙的死亡动作从来没播过：死的那一帧就被删掉，只剩一团碎屑和掉的肉

- 状态: open
- 严重度: 中（TASK-029 说"动作照用（走、跑、咬、死……）""死亡动作重点看"；可是游戏里一次都看不到）
- 发现: 2026-09-30 · 6a387b1（TASK-029 第 1 条）
- 复现: `GODOT_PROJECT=$(bash debug-agent/tools/snapshot.sh 6a387b1) bash debug-agent/tools/run_check.sh probe:deaths`

## 现象

第 1 站五种（腔骨龙、腔骨龙头领、黄昏鳄、植龙、波斯特鳄）各放一只在空地上，打死：

```
coelophysis after death: 0.02 gone
coelophysis_alpha after death: 0.02 gone
hesperosuchus after death: 0.02 gone
phytosaur after death: 0.02 gone
postosuchus after death: 0.02 gone
```

死后第一帧，恐龙的节点就没了（`is_instance_valid` 为假）。0.35 秒和 1.9 秒的截图里只有掉下来的骨头和肉，没有倒下的身体。一局真实来袭里打死的也一样。

## 原因（读代码，没改）

`Dino.die()`：设 `is_dead`、关碰撞、`_on_death_fx()`（一团 `fx.debris` 碎屑 + 叫一声）、`spawn_death_drops()`、发 `dino_died`，然后**马上 `queue_free()`**。`Config` 里有 `DEAD → "death"` 的动作映射（第 4501、4554 行），可是节点当帧就删了，死亡动作没机会播。

## 期望

死了以后留一会儿：播完死亡动作（倒下），躺一两秒，再沉下去 / 淡掉，再删。碰撞照旧当帧关掉，不挡路。
