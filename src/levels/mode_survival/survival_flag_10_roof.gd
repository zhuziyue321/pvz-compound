extends LevelScriptBase
## survival_flag_10_roof —— 由同目录的 survival_flag_10_roof.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	var pre_plant_in_level_0 := PrePlantResource.new()
	pre_plant_in_level_0.plant_type = CharacterRegistry.PlantType.P034FlowerPot
	pre_plant_in_level_0.plant_cell_pos = Vector2i(0, 1)
	var pre_plant_in_level_1 := PrePlantResource.new()
	pre_plant_in_level_1.plant_type = CharacterRegistry.PlantType.P034FlowerPot
	pre_plant_in_level_1.plant_cell_pos = Vector2i(0, 2)
	var pre_plant_in_level_2 := PrePlantResource.new()
	pre_plant_in_level_2.plant_type = CharacterRegistry.PlantType.P034FlowerPot
	pre_plant_in_level_2.plant_cell_pos = Vector2i(0, 3)
	var pre_plant_in_level_3 := PrePlantResource.new()
	pre_plant_in_level_3.plant_type = CharacterRegistry.PlantType.P034FlowerPot
	pre_plant_in_level_3.plant_cell_pos = Vector2i(0, 4)

	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_round = 10
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	all_pre_plant_data.assign([pre_plant_in_level_0, pre_plant_in_level_1, pre_plant_in_level_2, pre_plant_in_level_3])
	is_bungi = true


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z019Pogo,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z023Catapult,
		CharacterRegistry.ZombieType.Z024Gargantuar,
	]

	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 选卡
	await prefab.choose_card()
	## 准备安放植物
	## 初始化小推车
	await prefab.init_lawn_mover()
	await prefab.ready_set_plant()
	## 开战
	await prefab.start_battle(20, zombie_list)
