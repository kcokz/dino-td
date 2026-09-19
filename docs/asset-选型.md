# 场景资产选型决策报告 (S1 Asset Survey & Decision)

> 选型铁律：**风格一致性高于单个模型的精细度**。宁可用一套稍简朴但同作者同画风的资产，也绝不跨源混拼高低多边形与不同 texel 密度的模型。

---

## 一、各分类候选评估矩阵

### 1. 恐龙 (Dinosaurs) — 核心焦点
- **候选 A（首选推荐）：Quaternius Dinosaurs Pack**
  - **来源**: https://quaternius.com/packs/dinosaurs.html
  - **许可**: CC0 1.0 Universal (Public Domain)
  - **规格**: 1500–3000 三角面/体，带通用骨架 Armature，每种恐龙包含 Idle, Walk, Run, Attack, Death 5个动画。
  - **覆盖度**: 包含 T-Rex（对应 `big_theropod`）、Raptor（对应 `raptor`）、Pterodactyl（对应 `pterosaur`）、Triceratops、Stegosaurus、Ankylosaurus。
  - **风格**: 步进式几何平滑（low-poly with bevels），顶点法线圆润，与低饱和 PBR 场景环境（WorldEnvironment）完美契合。
- **候选 B：项目自建生成器 `tools/generate_dino.py` (t_rex.glb)**
  - **规格**: 1200 面，带 18 根骨骼，5 个动画切片。目前已作为管线跑通与 S1 试装的核心基准。
- **候选 C：Kenney Mini Dinosaurs**
  - **缺点**: 尺寸过小且无骨骼动画，更适合棋盘棋子，不适合第三人称俯视战斗。

### 2. 人类 / 幸存者英雄 (Hero & Survivor)
- **候选 A（首选推荐）：Quaternius Modular Men / Characters**
  - **来源**: https://quaternius.com/packs/modularmen.html
  - **许可**: CC0
  - **规格**: 1000–1800 面，标准 Humanoid 骨骼，带挥击/建造/砍伐/跑动动画。
  - **风格统一性**: 与 Quaternius 恐龙同出自一个建模师之手，头身比（6.5头身）与多边形切角完全一致，无视觉跳脱。
- **候选 B：Kenney Animated Characters 1 & 2**
  - **许可**: CC0
  - **缺点**: 风格偏 Q 版极简胶囊人（4头身），与恐龙的拟真身体结构产生比例割裂。

### 3. 史前植被 (Vegetation: Trees, Palms, Cycads, Ferns)
- **候选 A（首选推荐）：Quaternius Nature Pack**
  - **来源**: https://quaternius.com/packs/naturepack.html
  - **许可**: CC0
  - **规格**: 150–500 面/株。
  - **优势**: 包含多种针叶树、苏铁（Cycad）、蕨类草丛（Ferns）和倒伏原木（Fallen Logs），非常适合《方舟/恐龙生存》题材。天然支持 MultiMesh 实例化与顶点摆动风力着色器。
- **候选 B：Poly Haven Stylized Plants**
  - **缺点**: 多边形密度过高（5000+面/株），成千上万株铺在 40x40 地面上会导致严重 DrawCall / 面数瓶颈。

### 4. 岩石、矿点与巢穴 (Rocks, Outcrops & Nests)
- **候选 A（首选推荐）：Quaternius Rocks Pack & Cliffs**
  - **来源**: https://quaternius.com
  - **许可**: CC0
  - **优势**: 块面切割感强，与低多边形恐龙与植被基底的硬朗阴影完全匹配。
- **候选 B：ambientCG 3D Rock Scans**
  - **缺点**: 高精度光度立体扫描，质感过写实，会显得低模恐龙像纸糊的。

### 5. 地形 PBR 贴图 (Terrain Materials)
- **候选 A（首选推荐）：ambientCG Ground / Dirt / Grass PBR 1K**
  - **来源**: https://ambientcg.com
  - **许可**: CC0
  - **配置**: Albedo, Normal, Roughness, AO 1K 分辨率贴图。
  - **优势**: 在俯视固定相机（18m高度）下，1K 分辨率提供了极其干净细腻的泥地、苔藓与岩石缝隙质感，三平面混合时不失真且内存极低。

### 6. 环境天空 (HDRI Sky)
- **候选 A（首选推荐）：Poly Haven Prehistoric Dawn / Low Sun**
  - **来源**: https://polyhaven.com/hdris
  - **许可**: CC0
  - **特点**: 低角度太阳光（15°-25°），提供强烈的侧向投影，让丘陵起伏与恐龙脚部接地阴影（SSAO）立体感倍增。

---

## 二、最终统一选型决策

> **主框架：“Quaternius 全家桶 (恐龙 + 人物 + 自然 + 岩石) + ambientCG 地形 PBR + Poly Haven 低角度 HDRI”**

### 选型核心理由：
1. **单一创作者闭环（铁律 2）**：恐龙、人、树木、岩石全部来自 Quaternius CC0 套件，具有完全相同的材质光滑度预设、多边形面数级别和顶点色风格，彻底消除“东拼西凑感”。
2. **纯粹 CC0 许可（铁律 1）**：商业发布零版权纠纷风险，无需担心归属遗漏。
3. **管线开箱即用**：全套包含标准 glTF/glb、带有完整骨架动画（直接服务于 S2 动画接口）。
4. **自适应装配（铁律 3、4）**：所有模型通过 `VisualLibrary.fit()` 装配，声明尺寸由 `Config.gd` 掌握，碰撞盒与物理逻辑永不受美术替换影响。
