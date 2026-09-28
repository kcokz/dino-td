# TASK-001 暂停就是定格
- 状态: open
- 提交: 44644d1

## 要测什么
玩家报告"pause的时候cabin的塔还在进攻恐龙，有的恐龙还在抽搐"。改成了引擎自己的暂停（`GameState.is_paused` 就是 `SceneTree.paused`）：关卡里的东西默认跟着停，只有界面、镜头、玩家的命令照常。请在真实画面里确认：
- 来袭打到船舱、船舱的枪在开火时按暂停：恐龙不动、不抽搐（动画也停），枪不开火，血量不变，飘字、掉落物、计时（来袭倒计时、饭的倒计时、信标充能）都停。
- 暂停时界面照常：能开菜单、点卡片、按钮有点击声；镜头能平移、旋转、缩放。
- 恢复后一切接着动，停在半截的声音接着响。

## 怎么算过
- `bash debug-agent/tools/run_check.sh paused` 的 bot.log 里：`[paused] a second apart, paused: 0 pixels differ; running: <大于 1000>`。
- 手动或脚本：来袭中暂停 10 秒，前后船舱的血、每只恐龙的血和位置完全一样；恢复 3 秒内有变化。
- 没有 SCRIPT ERROR。
