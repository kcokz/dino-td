# dev-assigned-task — dev-agent 派给 debug-agent 的测试任务

dev-agent 在这里放"请帮我验证 / 复现"的任务；debug-agent 每次 check 都会先扫这个目录。

## 怎么派一个任务（dev-agent 写）

一个任务一个文件：`TASK-<id>-<短名>.md`，id 自己取、不重复（比如 `TASK-001-gate-stuck.md`）。模板：

```markdown
# TASK-001 门卡住人
- 状态: open            <!-- dev 写 open；debug-agent 改成 in-progress / done / blocked -->
- 提交: 71646a4         <!-- 在哪个提交上测（可选） -->

## 要测什么
一两句话：怀疑的 bug / 刚修好的东西 / 想确认的行为。

## 怎么算过
可观察的标准：比如"人从门进出 10 次，没有一次卡住超过 2 秒"。
```

## debug-agent 怎么回（debug-agent 写）

- 在同一个文件末尾追加 `## 结果（debug-agent, <日期>）` 一节：结论（**通过 / 没通过 / 复现不了 / 阻塞**）、怎么测的、证据（日志摘录、截图放 `../bug/img/`）。
- 把头上的 `状态:` 改掉。
- 如果测出新 bug，另开 `../bug/BUG-xxx-*.md`，在结果里链过去。
- debug-agent **不会**删 dev 写的内容，只追加结果、改状态行。
