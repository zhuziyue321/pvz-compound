extends LevelScriptBase
## adventure_01_02 —— 由同目录的 adventure_01_02.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关新手教程：在 run_flow() 里现场构造并传给 prefab.tutorial
## （普通教程：写在这里只做登记，真正开跑在开战之后，见 TutorialManager）
func _build_tutorial() -> ResourceTutorialData:
	var tutorial_step_0 := ResourceTutorialStep.new()
	tutorial_step_0.advice_text = "向日葵是非常重要的植物！"
	tutorial_step_0.pointer_target = ResourceTutorialStep.E_PointerTarget.Card
	tutorial_step_0.finish_type = ResourceTutorialStep.E_FinishType.TakeCard
	tutorial_step_0.plant_type = CharacterRegistry.PlantType.P002SunFlower
	var tutorial_step_1 := ResourceTutorialStep.new()
	tutorial_step_1.advice_text = "点击草地种下你的种子！"
	tutorial_step_1.pointer_target = ResourceTutorialStep.E_PointerTarget.Lawn
	tutorial_step_1.finish_type = ResourceTutorialStep.E_FinishType.PlantCount
	tutorial_step_1.plant_type = CharacterRegistry.PlantType.P002SunFlower
	var tutorial_step_2 := ResourceTutorialStep.new()
	tutorial_step_2.advice_text = "至少要种下三棵向日葵！"
	tutorial_step_2.pointer_target = ResourceTutorialStep.E_PointerTarget.Card
	tutorial_step_2.finish_type = ResourceTutorialStep.E_FinishType.PlantCount
	tutorial_step_2.plant_type = CharacterRegistry.PlantType.P002SunFlower
	tutorial_step_2.plant_count = 2
	tutorial_step_2.start_zombie_wave = true
	var tutorial_step_3 := ResourceTutorialStep.new()
	tutorial_step_3.advice_text = "干得漂亮！"
	var tutorial_data_0 := ResourceTutorialData.new()
	tutorial_data_0.steps.assign([tutorial_step_0, tutorial_step_1, tutorial_step_2, tutorial_step_3])
	return tutorial_data_0


func _init() -> void:
	save_key = "101_0_0002"
	## 本关专用地图：5 行草坪里只有中间 3 行铺了草皮（1-2 / 1-3 共用这一张）
	## 地图由关卡自己指定，不再靠「为本关单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_5row.tres") as ResourceMapData


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

	## 本关教程（登记：普通教程真正开跑在开战之后，见 TutorialManager）
	await prefab.tutorial(_build_tutorial())
	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 选卡
	await prefab.choose_card()
	## 准备安放植物
	## 初始化小推车
	await prefab.init_lawn_mover()
	await prefab.ready_set_plant()
	## 开战：10 波，出怪表里只有普通僵尸
	await prefab.start_battle(10, zombie_list)


## 本关有新手教程：教程在 run_flow() 里现场构造（见 _build_tutorial），
## 这里只做声明 —— 供「要不要建 TutorialManager」判定用（见 should_run_tutorial）
func has_tutorial() -> bool:
	return true
