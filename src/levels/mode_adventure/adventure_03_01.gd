extends LevelScriptBase
## adventure_03_01 —— 由同目录的 adventure_03_01.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 prefab.dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	crazy_dave_dialog_detail_resource_0.text = "看来僵尸们要放弃进攻你的前院了。"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	crazy_dave_dialog_detail_resource_1.text = "现在他们想试试你的后院。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	crazy_dave_dialog_detail_resource_2.text = "但最重要的是，你不能使用你的蘑菇了！"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	crazy_dave_dialog_detail_resource_3.text = "因为他们白天要睡觉！"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	## 原版冒险模式 3-1 开场（进入泳池场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_501~505
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 3-1 段
	crazy_dave_dialog_detail_resource_4.text = "这难道不是公子哥的作风吗？"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4])
	return crazy_dave_dialog_resource_0


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.Pool
	dave_dialog_only_first_playthrough = true


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
