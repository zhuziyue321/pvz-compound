extends ResourceLevelData
class_name LevelScriptBase
## 关卡脚本基类 —— **关卡 = 一个 .gd（属性 + 流程），不再有 .tres**
##
## 一条关卡脚本同时承担两件事：
##   1. 关卡属性：在 _init() 里给继承来的字段赋值（start_sun = 150 …），
##      消费方（各 manager）照旧读 para.start_sun，**一处都不用改**
##   2. 关卡流程：run_flow()，一段顺序结构的协程，用 await 串起预制体
##
## 流程控制是 GDScript 本身：if / for / while / match 随便用，
## 不再需要「数据轴 + 控制流事件」那一层（Sequence / Repeat / Branch 已无必要）。
##
## 谁在用它：
##   LevelTimelineManager.run_timeline()  —— 注入 prefab 后 await run_flow(mg)
##   各 manager 读字段 —— 与读 ResourceLevelData 完全一致
##
## 老 .tres 关卡（ResourceLevelData 实例）没有 run_flow，执行器仍走旧的事件数组，
## 所以迁移可以逐关进行。

## 流程预制体门面，由执行器在 run_flow 之前注入（关卡脚本不要自己 new）
var prefab: LevelPrefabs

## true = run_flow 整关只跑一遍（跨轮继续往下跑，比如砸罐子三批写在同一段里）
## false（默认）= 每轮重跑一遍，一轮 = 这段流程，轮与轮之间由 MainGameManager 摆场
var is_one_shot_flow := false


## 进关时摆放本关专属的场景物品 / 给格子打规则标记 —— **关卡脚本可覆写**
##
## 调用时机：GameItemManager.init_manager() → GIM_Other.init_other_item()，
## 排在 plant_cell_manager.init_manager() **之后**（格子已经建好）、玩家能动手**之前**。
## 所以「这几格只能种某几种植物」这类限制必须写在这里，不能留到 run_flow()
## —— 那时玩家已经选完卡了，限制生效得太晚。
##
## 有了这个钩子，特殊玩法自己的场景物品（观星的星星轮廓这类）就不必在 GIM_Other 里
## 加 `if is_xxx` 分支：玩法逻辑留在关卡脚本里，通用代码不认识任何具体玩法。
##
## [mg] 主游戏管理器：解析格子、打限制这类要用宿主的覆写从这里取
## [item_root] 背景层的物品容器：本关要挂的节点 add_child 到这里，引用由脚本自己留一份
## 基类是空实现（两个参数都不用，故加下划线前缀），覆写时把名字改回 mg / item_root 直接用
func init_level_items(_mg: MainGameManager, _item_root: Node2D) -> void:
	pass


## 本波僵尸「怎么进场」 —— **关卡脚本可覆写**
##
## 波次管理器每波都会来问这里一次：僵尸清单（wave_spawn）是通用波次按战力算出来的，
## **关卡脚本只改进场方式，不改出什么怪** —— 想改出什么怪就改 zombie_refresh_types。
## 默认实现 = 通用进场（僵尸从场地边缘走进来，见 ZombieWaveCreateManager）。
##
## 有了这个钩子，「本关僵尸改由蹦极僵尸空投进场」这类一关专属玩法就不必在
## ZombieWaveCreateManager 里加 `if is_xxx` 分支：玩法留在关卡脚本里，通用波次代码
## 不认识任何具体玩法名（硬约束 §1-8）。
##
## 返回值必须是**本波真正参战的僵尸**：波次血量统计与提前刷新判定都按它算
## （所以「空投用的蹦极僵尸」也要算进去，它没离场前本波不会清完）。
##
## [create_manager] 波次生成管理器：覆写里要用它的通用能力（普通进场、选行）就从这个参数取
## [wave_spawn] 本波按战力算出来的僵尸清单
## [wave] 当前波次
func create_wave_zombies(
	create_manager: ZombieWaveCreateManager,
	wave_spawn: Array[CharacterRegistry.ZombieType],
	wave: int
) -> Array[Zombie000Base]:
	return create_manager.create_norm_wave_zombies(wave_spawn, wave)


## 本关流程 —— **顺序结构的程序**：上一个预制体结束才开下一个
## 默认实现等价于 ResourceLevelData.build_default_timeline() 生成的那条轴：
## 戴夫推销 → 戴夫对话 → 开场教程 → 保龄球红线 → 展示僵尸 → 选卡 → 初始化小推车 → 准备安放植物 → 开战
## 只生成本关**真实生效**的步骤（判据与 build_default_timeline 一致）
func run_flow(mg: MainGameManager) -> void:
	var is_first_round: bool = mg.curr_game_round == 1
	if is_dave_sell_possible() and is_first_round:
		await prefab.dave_sell()
	if has_dave_dialog():
		await prefab.dave_dialog()
	if is_opening_tutorial_level() and should_run_tutorial(mg) and is_first_round:
		await prefab.tutorial()
	if is_bowling_stripe and is_first_round:
		await prefab.bowling_stripe()
	if look_show_zombie:
		## 老 .tres 关卡的出怪表还在关卡数据上，这里把它带过去给预览僵尸用
		## （脚本关的出怪表写在自己的 show_zombie / start_battle 调用上，本字段是空的）
		await prefab.show_zombie(zombie_refresh_types)
		if can_choosed_card:
			await prefab.choose_card()
		else:
			## 不能选卡：相机在预览位停 3 秒再归位开战（等价旧的 no_choosed_card_start_game）
			await prefab.wait(3.0)
			await prefab.camera_back()
	## 初始化小推车：出生在屏幕外左侧，按从下到上的顺序开到位
	## （推车之前一直看不见 —— 这一步才登场，正好赶在「准备…安放…植物」之前）
	await prefab.init_lawn_mover()
	## 「准备…安放…植物」红字：砸罐子关不播（罐子摆好就能直接砸，见原版冒险 4-5）
	if is_show_ready_set_plant:
		await prefab.ready_set_plant()
	## 开战自己会等到本段打完，所以末尾不再挂别的预制体
	await prefab.start_battle()


## 本关这次要不要播新手教程 —— **关卡脚本可覆写**（想每次都播就 return true）
## 默认沿用原版规则：教程声明「只播一次」时，本关已经有通关记录就不再播。
## 执行器创建 TutorialManager 之前先问这里，所以「跳过」在脚本里一处说了算
## （非开场教程进 MAIN_GAME 后由 TutorialManager 自己跑，同样受这个开关管）
func should_run_tutorial(mg: MainGameManager) -> bool:
	if not has_tutorial():
		return false
	var data := get_tutorial_data()
	## 教程数据在 run_flow() 里现场构造时这里取不到（null）：按「只播一次」的默认规则判
	if data != null and not data.only_first_playthrough:
		return true
	return not mg.is_curr_level_success()
