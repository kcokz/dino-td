# debug-agent

这个目录属于 **debug-agent**：它玩游戏、找 bug、对照设计书，**不改游戏代码**。它所有的写操作都只在 `debug-agent/` 下面。

| 目录 / 文件 | 放什么 | 谁写 |
|---|---|---|
| `bug/` | bug 报告，一个 bug 一个文件 `BUG-NNN-短名.md`；截图放 `bug/img/` | debug-agent |
| `design-doc/` | 设计书需要改的地方，一个主题一个文件 `DOC-NNN-短名.md`；截图放 `design-doc/img/` | debug-agent |
| `dev-assigned-task/` | dev-agent 派来的测试任务，格式见那里的 README | dev 派，debug-agent 回 |
| `STATE.md` | debug-agent 的记忆：上次查到哪、每条报告的状态、下次查什么 | debug-agent |
| `tools/` | 跑检查用的脚本 | debug-agent |
| `runs/` | 每次跑的原始日志和截图（git 忽略，随时可删） | 脚本自动 |

## 一次 "agent check" 做什么

1. **读** `STATE.md`，再扫 `dev-assigned-task/` 里状态是 `open` 的任务，先做这些。
2. **跑**（全部只读，输出都进 `runs/<时间>/`）：
   ```bash
   bash debug-agent/tools/run_check.sh tests smoke play:20 probe:all
   ```
   - `tests`：整套测试。要"ALL TESTS PASSED"，而且 `SCRIPT ERROR` 为 0。
   - `smoke`：开图冒烟测试，不许有 ERROR。
   - `play:<分钟>`：游戏自带的机器人（`tools/playtest.gd`）按玩家的方式玩一局，日志加截图。
   - `probe:<名字>` / `probe:all`：debug-agent 自己的针对性检查（`tools/probe.gd`），每条输出 PASS / FAIL / INFO。
   - 其他词会当成 playtest 场景名传进去（`open cabin ui kit paused beacon buildmenu menu ...`），用来截图看画面。
3. **看**：读日志（`STUCK`、`gave up`、`LOST`、`GAME LOST`、SCRIPT ERROR），看截图，把看到的和 `GAME-DESIGN.md` 的【已定】条目对照。
4. **写**：
   - 真 bug → `bug/BUG-NNN-*.md`。写法：一句话标题，现象，复现步骤或命令，期望和实际，证据（日志摘录或截图），可能的代码位置（只说位置，不改代码）。
   - 设计书过时，或者设计书和游戏对不上 → `design-doc/DOC-NNN-*.md`，写成"第几行 · 现在写的 · 建议改成"的表。
   - 已经报过的，只更新状态，不重复开新文件。
5. **更新** `STATE.md`：日期、提交、结果、每条报告的状态、下次要查的。

## 规矩

- 游戏代码、测试、设计书、`tools/playtest.gd` 一个字都不改。要"改设计书"就写进 `design-doc/`，由 dev 去改。
- 机器人是用来找 bug 的，不是用来调平衡的。平衡问题靠人自己玩，这里不报"太难 / 太简单"，只在跟设计意图明显相反时提一句。
- 报 bug 之前先确认：能复现，而且不是测试工具自己造成的（比如机器人直接设了 `Engine.time_scale`，速度按钮的高亮不会跟着变，这不是游戏的 bug）。
- 游戏在不断开发，工作区经常有未提交的改动：报告里写上是在哪个提交上测的。

## 工具

- `tools/run_check.sh`：上面那条命令。Godot 路径可以用环境变量 `GODOT` 换掉。
- `tools/sync_harness.sh`：把 `tools/playtest.gd` 复制成 `tools/agent_play.gd`，只改一处：截图写到 `debug-agent/runs/`。`run_check.sh` 每次都会自动同步一遍。
- `tools/contact_sheet.gd`：把一次运行的截图拼成几张 2×3 的总览图（放 scratchpad），一次看完一整轮。
  `godot --headless --path . --script res://debug-agent/tools/contact_sheet.gd -- <截图目录> <输出前缀>`
- `tools/probe.gd`：自己写的探针。加一个新的：写一个 `_p_<名字>()` 函数，把它加进 `_init` 里的 `match`，再加进 `all` 列表。
