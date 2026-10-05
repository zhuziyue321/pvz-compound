<!-- AGENT-DOC: pointer -->
# src/levels/ —— 内置关卡数据层

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../../AGENTS.md)，**文档总目录** [../docs/README.md](../../docs/README.md)。

按模式分目录放内置关卡（`mode_adventure/` `mode_minigame/` `mode_puzzle/` `mode_survival/`），`script/` 放关卡脚本基类与时间轴事件脚本。

- 关卡资源类型：`ResourceLevelData`（`script/level_data.gd`），现役关卡**已经是 `.gd` 脚本关卡**。
- 取关卡走注册表 `LevelRegistry`（`script/level_registry.gd`），不要硬编码 `res://` 路径。
- 玩家自制关卡不在这里，在根目录 `data/levels/params/`。

**规则与约定不写在这里**，一律在 [docs/](../../docs/README.md)。
