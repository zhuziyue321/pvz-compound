extends LevelScriptBase
## adventure_05_10 —— 由同目录的 adventure_05_10.tres 迁移而来
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
	## 僵王关是夜屋顶：几何与 map_roof 逐格相同，换的是夜色底图与背景子场景
	## （见 docs/参考存档/特殊关卡.md），地图由本关显式指定，不再靠场景槽位区分
	map_data = preload("res://data/map/map_boss.tres") as ResourceMapData
	game_BG = ConstLevelData.GameBg.Boss
	game_BGM = ConstLevelData.GameBGM.Boss
	is_day = false
	is_day_sun = false
	all_pre_plant_data.assign([pre_plant_in_level_0, pre_plant_in_level_1, pre_plant_in_level_2, pre_plant_in_level_3])
	zombie_multy = 3
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	monster_mode = ConstLevelData.E_MonsterMode.Null
	is_zomboss_fight = true
	## 出怪预览为空：本关不自然出怪（僵尸全由僵王投放），出怪池在僵王脚本里，
	## 原版开局那段「看僵尸」也是一只不出 —— 连带着「镜头右移看僵尸」也不跑
	## （见 docs/参考存档/特殊关卡.md「僵王关」）
	look_show_zombie = false
	## 没有预览这段镜头，进关就停在归位位（否则整个登场过程都在拍左侧的房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	all_card_plant_type_probability.assign({
	33: 2,
	34: 2,
	35: 2,
	40: 2,
	21: 2,
	15: 2
	})


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关的僵尸全部由僵王投放，开战时要带上这一份
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z023Catapult,
		CharacterRegistry.ZombieType.Z024Gargantuar,
	]

	## 没有僵尸预览：本关不自然出怪，出怪预览为空（look_show_zombie = false），
	## 连「镜头右移看僵尸 / 移回相机」这两步一起不跑，直接进僵王登场
	## 生成僵尸博士：本关的僵尸全部由它投放（monster_mode = Null 不自然出怪）
	await prefab.spawn_zomboss()
	## 等僵王登场动画落位再往下走
	await prefab.wait(3.0)
	## 准备-安放-植物
	## 初始化小推车
	await prefab.init_lawn_mover()
	await prefab.ready_set_plant()
	## 开战
	await prefab.start_battle(-1, zombie_list)
