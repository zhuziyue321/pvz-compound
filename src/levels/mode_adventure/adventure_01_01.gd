extends LevelScriptBase
## adventure_01_01 —— 教程关（原版冒险模式 1-1）
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
##
## 本关的教程**不是**一串 ResourceTutorialStep，而是写在 run_flow() 里的一句话一个 await：
## 「箭头指哪 → 说什么台词 → 等玩家做什么」全在流程里排着，翻这一个函数就知道本关教了什么。
## 提示条 / 箭头 / 完成条件的判定仍由 TutorialManager 托管（逐步模式，
## 见 MainGameManager.ensure_tutorial_stepped_mode），这里只负责编排顺序。
##
## 教程能不能跑到底，依赖一条前提：**首次打 1-1 的玩家手里只有豌豆射手一张卡**
## （植物按关解锁，选卡阶段「卡槽数 >= 拥有植物卡数」时系统锁卡、按序固定把豌豆射手选满）。
## 所以下面 wait_take_card / wait_plant 都敢指定豌豆射手 —— 别的卡这时候还没解锁。
## 玩家已经通关过 1-1 时那条分支（看 run_flow）不播教程，不受这条约束影响。


func _init() -> void:
	save_key = "101_0_0001"
	## 本关专用地图：5 行草坪里按原版只有最中间 1 行铺了草皮（第一天只开一条道）
	## 地图由关卡自己指定，不再靠「为 1-1 单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_1row.tres") as ResourceMapData
	start_sun = 150


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

	## 预览：镜头拉到草坪右侧，让玩家先看一眼马上要面对的是什么
	await prefab.show_zombie(zombie_list)
	## 选卡
	await prefab.choose_card()
	## 移回视角
	await prefab.camera_back()
	## 初始化小推车：本关新手教程不走「准备安放植物aaaa」，在这里让推车从屏幕外左侧开到位
	await prefab.init_lawn_mover()
	## 允许操作：从这一刻起玩家能点卡片 / 种植 / 收阳光了，但还没出怪
	await prefab.allow_operation()
	if not _mg.is_curr_level_success():
		## 新手教程只在还没通关过 1-1 时播
		await _tutorial_flow()
	else:
		## 已经通关过：教程跳过，红字照常播（ PREPARE YOUR DEFENSES 那一段）
		await prefab.ready_set_plant()
	## 战斗：10 波，出怪表里只有普通僵尸（1-1 只放最基础的那一只）
	await prefab.start_battle(10, zombie_list)


## 新手教程：一句话一个 await，顺序照搬原版 1-1 的教学节奏
## （台词取自原版 ADVICE_* 条目，见 data/strings/lawn_strings.txt）
func _tutorial_flow() -> void:
	## 箭头指到豌豆射手的种子包上
	await prefab.point_card(CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 教玩家把种子包捡起来
	await prefab.advice("点击种子包，把它捡起来！")
	await prefab.wait_take_card(CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 手上拿着东西了，撤回箭头，别挡着草地
	await prefab.hide_pointer()
	## 教玩家把植物种下去
	await prefab.advice("点击草地种下你的种子！")
	await prefab.wait_plant(1, CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 夸一句，停一停让玩家看清发生了什么
	await prefab.advice("干得漂亮！")
	await prefab.wait(4.0)
	## 掉一颗阳光下来，教玩家收阳光
	await prefab.spawn_sun()
	await prefab.point_sun()
	await prefab.advice("点击收集掉落的阳光！")
	await prefab.wait_collect_sun()
	## 再掉一颗，让玩家攒够种第二株豌豆射手的阳光
	await prefab.spawn_sun()
	await prefab.advice("继续收集阳光！\n你需要他们来种下更多植物！")
	await prefab.wait_sun_enough(100)
	## 阳光够了，先让玩家自己动手：4 秒内种下了就往下走
	await prefab.advice("太好了！你已经收集到了足够\n进行下一次种植的阳光！")
	if not await prefab.wait_plant_timeout(1, CharacterRegistry.PlantType.P001PeaShooterSingle, 4.0):
		## 等了 4 秒还没动手，才补这一句教学（卡片要玩家自己捡，不给箭头）
		await prefab.advice("点击豌豆射手，再种一棵！")
		await prefab.wait_plant(1, CharacterRegistry.PlantType.P001PeaShooterSingle)
	await prefab.advice("别让僵尸靠近你的房子！")
	await prefab.wait(4.0)
	## 教程收尾：收起提示条与箭头，把教程的事件订阅摘掉
	await prefab.advice("")
	await prefab.end_tutorial()


## 本关有新手教程：教程写在 run_flow() 里（见 _tutorial_flow），这里只做声明 ——
## 供「要不要建 TutorialManager」判定用（见 should_run_tutorial）
func has_tutorial() -> bool:
	return true


## 教程播不播由 run_flow() 自己按通关记录判断（见那里的 if），这里一律返回 true：
## 本关教程走的是逐步模式，TutorialManager 必须建起来（提示条与判定都在它身上），
## 否则已通关过的存档再进 1-1 时管理器不存在，教程事件会全部空转
func should_run_tutorial(_mg: MainGameManager) -> bool:
	return true
