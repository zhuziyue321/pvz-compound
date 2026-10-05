extends LevelScriptBase
## adventure_01_05 —— 由同目录的 adventure_01_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	var pre_plant_in_level_0 := PrePlantResource.new()
	pre_plant_in_level_0.plant_type = CharacterRegistry.PlantType.P001PeaShooterSingle
	pre_plant_in_level_0.plant_cell_pos = Vector2i(2, 6)
	var pre_plant_in_level_1 := PrePlantResource.new()
	pre_plant_in_level_1.plant_type = CharacterRegistry.PlantType.P001PeaShooterSingle
	pre_plant_in_level_1.plant_cell_pos = Vector2i(3, 8)
	var pre_plant_in_level_2 := PrePlantResource.new()
	pre_plant_in_level_2.plant_type = CharacterRegistry.PlantType.P001PeaShooterSingle
	pre_plant_in_level_2.plant_cell_pos = Vector2i(4, 7)
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	## 进关就停在相机归位位（保龄球关没有选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	all_pre_plant_data.assign([pre_plant_in_level_0, pre_plant_in_level_1, pre_plant_in_level_2])
	can_choosed_card = false
	first_wave_delay = 6.0
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	all_card_plant_type_probability.assign({
	1001: 2,
	1002: 1,
	1003: 1
	})
	card_order_plant.assign({
	0: 1001,
	1: 1002,
	2: 1003
	})
	is_bowling_stripe = true
	plant_cell_can_use.assign({
	"left_can_plant": true,
	"left_can_zombie": true,
	"right_can_plant": false,
	"right_can_zombie": true
	})


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 prefab.dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "你好，我的邻居！"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "我的名字叫疯狂的戴夫。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_2.text = "但你叫我疯狂的戴夫就行了。"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "听好，我有个惊喜要给你。"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "但是首先，你必须清理下你的草坪。"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "用你的铲子挖出那些植物！"
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_6.text = "开始挖吧！"
	crazy_dave_dialog_detail_resource_6.is_crazy = true
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6])
	return crazy_dave_dialog_resource_0


## 本关新手教程：在 run_flow() 里现场构造并传给 prefab.tutorial
## （开场教程：整段教学在预览僵尸之前跑完，见 TutorialManager.is_opening_tutorial）
func _build_tutorial() -> ResourceTutorialData:
	var tutorial_step_0 := ResourceTutorialStep.new()
	tutorial_step_0.advice_text = "点击拾取铲子！"
	tutorial_step_0.pointer_target = ResourceTutorialStep.E_PointerTarget.Shovel
	tutorial_step_0.finish_type = ResourceTutorialStep.E_FinishType.TakeShovel
	var tutorial_step_1 := ResourceTutorialStep.new()
	tutorial_step_1.advice_text = "点击移除一颗植物！"
	tutorial_step_1.pointer_target = ResourceTutorialStep.E_PointerTarget.Plant
	tutorial_step_1.finish_type = ResourceTutorialStep.E_FinishType.DigPlantCount
	var tutorial_step_2 := ResourceTutorialStep.new()
	tutorial_step_2.advice_text = "一直挖吧，直到你的草坪上没有植物！"
	tutorial_step_2.pointer_target = ResourceTutorialStep.E_PointerTarget.Plant
	tutorial_step_2.finish_type = ResourceTutorialStep.E_FinishType.DigAllPlants
	var crazy_dave_dialog_detail_resource_7 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_7.text = "好的，干得不错，现在给你个惊喜……"
	var crazy_dave_dialog_detail_resource_8 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_8.text = "我们去玩保龄球！"
	crazy_dave_dialog_detail_resource_8.on_talk_event = &"show_bowling_stripe"
	var crazy_dave_dialog_detail_resource_9 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_9.text = "嘿，拿好这个坚果！"
	var crazy_dave_dialog_detail_resource_10 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_10.text = "为什么我要给你坚果？"
	var crazy_dave_dialog_detail_resource_11 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_11.text = "因为我疯了！！！！！"
	var crazy_dave_dialog_detail_resource_12 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_12.text = "现在出发！快给我赢个冠军回来！！！"
	crazy_dave_dialog_detail_resource_12.is_crazy = true
	var crazy_dave_dialog_resource_1 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_1.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_7, crazy_dave_dialog_detail_resource_8, crazy_dave_dialog_detail_resource_9, crazy_dave_dialog_detail_resource_10, crazy_dave_dialog_detail_resource_11, crazy_dave_dialog_detail_resource_12])
	var tutorial_step_3 := ResourceTutorialStep.new()
	tutorial_step_3.finish_time = 0.1
	tutorial_step_3.dave_dialog = crazy_dave_dialog_resource_1
	var tutorial_data_0 := ResourceTutorialData.new()
	tutorial_data_0.steps.assign([tutorial_step_0, tutorial_step_1, tutorial_step_2, tutorial_step_3])
	tutorial_data_0.is_opening_tutorial = true
	return tutorial_data_0


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
	]

	## 关卡戴夫对话
	await prefab.dave_dialog(_build_dave_dialog())
	if mg.curr_game_round == 1 and should_run_tutorial(mg):
		## 开场新手教程（仅第 1 轮；本关已通关过则跳过，见 should_run_tutorial）
		await prefab.tutorial(_build_tutorial())
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await prefab.bowling_stripe()
	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 不选卡时相机停留
	await prefab.wait(3.0)
	## 相机归位
	await prefab.camera_back()
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


## 本关有新手教程：教程在 run_flow() 里现场构造（见 _build_tutorial），
## 这里只做声明 —— 供「要不要建 TutorialManager」判定用（见 should_run_tutorial）
func has_tutorial() -> bool:
	return true
