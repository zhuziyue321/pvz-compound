<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `src/levels/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：进入 / 新建 / 改动 `src/levels/` 下任何关卡脚本（`.gd`）或关卡资源之前
> **读完你能**：知道本目录装什么、改关卡前该先读哪份文档、关卡路径从哪拿
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：不知道 `docs/` 里有必读规范，改坏关卡数据 / 引用路径
> **关联**：仓库唯一入口 [../AGENTS.md](../../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../../docs/README.md) ｜ 必读规范 [../docs/项目规范.md](../../docs/项目规范.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../AGENTS.md](../../AGENTS.md) | 任何改动之前（任务路由表 + 8 条硬约束速查） |
| 2 | [../docs/项目规范.md](../../docs/项目规范.md) | 新增 / 改关卡（§1-5：`res://` 绝对路径、移动要带 `.uid`；**§1-8：一关专属机制留在关卡脚本，不进本体**） |
| 3 | [../docs/参考存档/关卡格式V2.md](../../docs/参考存档/关卡格式V2.md) | 改关卡资源字段 / 加新玩法（参考） |
| 4 | [../docs/参考存档/关卡时间轴.md](../../docs/参考存档/关卡时间轴.md) | 改开场流程 / 波次与对话顺序（参考） |
| 5 | [../docs/参考存档/关卡数据与出怪表.md](../../docs/参考存档/关卡数据与出怪表.md) | 改出怪表 / 关卡数值（参考） |

## 本目录是什么

内置关卡目录，**根目录 `res://src/levels/`**（2026-10-03 从 `res://data/level_date_resource/` 移出并改名）。

| 子目录 | 内容 |
|------|------|
| `mode_adventure/` | 冒险模式关卡（目录名即模式，注册表靠目录认模式） |
| `mode_minigame/` | 小游戏关卡 |
| `mode_puzzle/` | 解谜关卡 |
| `mode_survival/` | 生存关卡 |
| `core/` | 关卡脚本基类与工具（2026-10-03 从 `script/` 改名）：`level_data.gd` `level_script_base.gd` `level_prefabs.gd` `level_registry.gd`（关卡 id ↔ 路径注册表）`level_timeline_data.gd` `level_timeline_event.gd`；**不是关卡**，`LevelRegistry._scan_dir()` 会跳过本目录（旧名 `script/` 同样跳过） |
| `core/timeline_event/` | 时间轴事件脚本 |
| `core/zomboss/` | 僵王关专属 UI（血条 `zomboss_hp_bar.gd/.tscn`），由「生成僵王」事件创建、僵王死亡时自毁 |
| `script/mini_game/` | **只服务某一关的 UI / 脚本**（关卡专属逻辑不进游戏本体，硬约束 §1-8）：按迷你游戏分子目录，如 `beghouled/`、`slot_machine/` |

## 三条硬约定

- **一关专属机制写在关卡脚本里，不进游戏本体**：只有这一关（或极少数关）用到的特殊机制**必须**写在本目录 `mode_*/<关卡>.gd`（继承 `LevelScriptBase`）里 —— 属性 `_init()`、流程 `run_flow()`、专属物品与格子限制 `init_level_items()`；被 ≥2~3 关复用时才上浮成通用字段 / 组件 / 规则（硬约束 §1-8；细则见 [规范细则存档 D-07](../../docs/参考存档/规范细则存档.md#d-07-关卡脚本-vs-游戏本体一次性机制的落位)）。
- **关卡路径不要硬编码**：一律走 `LevelRegistry`（`src/levels/core/level_registry.gd`，`LEVEL_DIR = "res://src/levels"`），业务代码不散落 `res://` 关卡路径（硬约束 §1-4）。
- **关卡 id = 文件名 basename**，与玩家自制关卡（`data/levels/params/`）共用一套 id 规则。

> 批量改名 / 移动**必须先关闭 Godot 编辑器**（否则 `.uid` 与引用会错乱）—— 见 [../docs/项目规范.md](../../docs/项目规范.md) §1-5。
