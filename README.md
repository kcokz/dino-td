# 恐龙游戏

这个仓库里有两个 Godot 游戏，外加一个共用文件夹：

| 文件夹 | 是什么 |
|---|---|
| `dino-td/` | 原来的塔防游戏 Defend Dinosaur（v0.7 暂停）。原样搬进来，一行没改，照常用 Godot 打开它的 `project.godot`。 |
| `dino-raid/` | 新游戏：恐龙军团打未来机器人。设计见 `dino-raid/GAME-DESIGN.md`。 |
| `common/` | 两个游戏共用、或者以后可能共用的东西：模型、音效、字体、界面贴图、着色器、建模工具、待改造的代码。说明见 `common/README.md`。 |

## 共用文件夹怎么用

Windows 上的 Godot 读不了 WSL 的符号链接，所以游戏不能直接打开 `../common`。
每个游戏里有一份 `common/` 的**复制品**（`dino-raid/common/`，不进 git），由这个命令生成：

```
python common/sync.py dino-raid
```

- **只在仓库根目录的 `common/` 里改**，改完同步一次。
- 在游戏里的复制品里改了东西，同步会停下来列出来，不会悄悄覆盖。
- Godot 自己写的导入设置（`.import`）和脚本编号（`.uid`）会自动收回 `common/`。

`dino-td` 现在还用它自己那一份资源，没有接 `common/`。以后回来做它时，可以改成同样的方式。
