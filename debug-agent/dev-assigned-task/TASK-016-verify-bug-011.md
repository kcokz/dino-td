# TASK-016 复测 BUG-011（失败画面说清楚输在哪）
- 状态: done
- 提交: 72b27c8

## 要测什么
BUG-011：人在巢边被守卫咬死、船舱满血，失败画面写"船舱被毁或角色阵亡！"。改成（设计书第 3 章"失败画面说清楚输在哪一条上"）：
- 船舱被攻破：标题"防线沦陷！"，写"船舱被攻破了，回去的路也跟着断了。"
- 人倒下：标题"倒下了！"，写他被什么咬死的——倒下时身边 3 米内（`HERO.killer_within`）最近的那只：守巢的写"工程师被守巢的腔骨龙咬死了。没人修信标，就回不去了。"；来袭的写"工程师被腔骨龙咬死了。……"；身边没有就只写"工程师倒下了。……"。

## 怎么算过
- 你那局的情形（`play:25`，人在东边巢边的石头那里被守卫咬死）：画面是"倒下了！"和"被守巢的腔骨龙咬死了"，不再提船舱。
- 最后一波把船舱咬破（或者 `siege` 场景里不管船舱）：画面是"防线沦陷！"和"船舱被攻破了"。
- 被来袭咬死（人出门迎战时）：写来袭的种类，没有"守巢的"。
- 中英文各拍一张，文字不溢出（英文那句比较长，会换两行）。
- 重开一局再输：画面按这一局的情形写，不带上一局的。

## 结果（debug-agent, 2026-09-28，在 72b27c8 的干净快照上测）

**通过**，BUG-011 已改成 fixed。

新探针 `probe:defeat_*`，在**同一次启动里连着输五局**（守卫 → 船舱 → 来袭 → 身边没有恐龙 → 再守卫），中英文各一遍。每局都是重开的新一局，所以这也顺便测了"重开再输不带上一局的"：

| 怎么输的 | 标题 | 说的 |
|---|---|---|
| 身边是守卫 | FALLEN! / 倒下了！ | The engineer was killed by Coelophysis guarding their nest. … / 工程师被守巢的腔骨龙咬死了。没人修信标，就回不去了。 |
| 船舱被咬破 | DEFEAT! / 防线沦陷！ | The cabin was broken open, and the way home with it. / 船舱被攻破了，回去的路也跟着断了。 |
| 身边是来袭的 | FALLEN! / 倒下了！ | …killed by Coelophysis. … / 工程师被腔骨龙咬死了。……（没有"守巢的"） |
| 身边 3 米内没有 | FALLEN! / 倒下了！ | The engineer fell. … / 工程师倒下了。…… |
| 再一次守卫（第五局） | 同第一行 | 同第一行，没有带上前面几局的话 |

截图：英文守卫 [../bug/img/BUG-011-fixed-guard-en.png](../bug/img/BUG-011-fixed-guard-en.png)（两行，放得下）；中文守卫 [../bug/img/BUG-011-fixed-guard-zh.png](../bug/img/BUG-011-fixed-guard-zh.png)；中文船舱 [../bug/img/BUG-011-fixed-cabin-zh.png](../bug/img/BUG-011-fixed-cabin-zh.png)。

说明：探针是直接让人或船舱受致命伤（人先摆到守卫 / 来袭身边），不是真打一场。凶手是按 `HERO.killer_within` 找最近的那只来定的，这样测的就是这一步。

**英文小问题**（不算不通过）：少了冠词，"killed by Coelophysis guarding their nest" 读着像是被整个物种咬死的，建议 "killed by a Coelophysis guarding its nest"；"killed by Coelophysis." 同样建议加 "a"。
