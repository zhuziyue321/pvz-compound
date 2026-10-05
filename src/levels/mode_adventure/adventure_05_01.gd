extends LevelScriptBase
## adventure_05_01 —— 由同目录的 adventure_05_01.tres 迁移而来
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
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	all_pre_plant_data.assign([pre_plant_in_level_0, pre_plant_in_level_1, pre_plant_in_level_2, pre_plant_in_level_3])
	dave_dialog_only_first_playthrough = true
	is_bungi = true


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 prefab.dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	crazy_dave_dialog_detail_resource_0.text = "哇——！他们甚至在你的屋顶上找到条路！"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	crazy_dave_dialog_detail_resource_1.text = "真是些有恒心的僵尸。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	crazy_dave_dialog_detail_resource_2.text = "考虑到你屋顶的角度，你会需要用到卷心菜投手的。"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	## 原版冒险模式 5-1 开场（进入屋顶场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1201~1204
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-1 段
	crazy_dave_dialog_detail_resource_3.text = "记住这点，你会平安无事的！"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3])
	return crazy_dave_dialog_resource_0


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
	]

	## 关卡戴夫对话
	await prefab.dave_dialog(_build_dave_dialog())
	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 选卡
	await prefab.choose_card()
	## 准备安放植物
	## 初始化小推车
	await prefab.init_lawn_mover()
	await prefab.ready_set_plant()
	## 开战
	await prefab.start_battle(10, zombie_list)


## 本关有开场戴夫对话：对话在 run_flow() 里现场构造（见 _build_dave_dialog），
## 这里只做声明 —— 有对话就不再播戴夫推销卡槽扩充（见 is_dave_sell_possible）
func has_dave_dialog() -> bool:
	return true
