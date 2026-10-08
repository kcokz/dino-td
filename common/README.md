# common —— 共用的东西

原件放在这里，游戏用的是复制品。同步命令：`python common/sync.py <游戏文件夹>`（详见仓库根目录的 README）。
在游戏里，这里的东西出现在 `res://common/` 下，比如 `res://common/assets/models/dinos/tyrannosaurus.gltf`。

| 文件夹 | 内容 | 会同步进游戏吗 |
|---|---|---|
| `assets/models/` | 26 种恐龙（真实大小）、主角、植物、道具、船舱、残骸，还有 .blend 原件 | 会 |
| `assets/audio/` | 恐龙叫声、打斗、环境声、界面音效（不含 dino-td 的飞船配音） | 会 |
| `assets/fonts/` `ui/` `icons/` `shaders/` | 字体、界面贴图、图标、着色器 | 会 |
| `assets/portraits/` | 恐龙头像（不含 dino-td 的建筑头像） | 会 |
| `assets/source/` | Quaternius 原始模型 | 会 |
| `assets/CREDITS.md` | 素材来源和授权。**发布前必须带上** | 会 |
| `scripts/` | 改造好、能直接用的代码：`ArtDress.gd`（给植物、道具、恐龙眼睛上对材质） | 会 |
| `scripts-draft/` | 从 dino-td 抄来的、以后可能共用的代码。它们都还离不开 dino-td 的 `Config` 等，**不能直接用**；改造到不依赖 dino-td 后挪进 `scripts/` | 不会 |
| `tools/` | Blender 建模脚本（恐龙、主角、植物、道具）、图标/字体/配音生成脚本。输出写进 `common/assets/` | 不会 |

`assets/` 里的 `.import` 文件已经指向 `res://common/assets/...`。
