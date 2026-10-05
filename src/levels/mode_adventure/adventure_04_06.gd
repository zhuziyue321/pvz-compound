extends LevelScriptBase
## adventure_04_06 —— 由同目录的 adventure_04_06.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 prefab.dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "雾这么大，我差点撞到你的房子！"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "今晚有僵尸会从地底下挖过来！"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_2.text = "他们直接钻到你最后面那排！"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "别慌，我给你带了个东西！"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "手套！"
	crazy_dave_dialog_detail_resource_4.is_hand = true
	crazy_dave_dialog_detail_resource_4.hand_item_id = 0
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "把种下去的植物拎起来，换个地方放下！"
	crazy_dave_dialog_detail_resource_5.is_hand = true
	crazy_dave_dialog_detail_resource_5.hand_item_id = 0
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_6.text = "不用铲掉，不用重种，跟原来一模一样！"
	crazy_dave_dialog_detail_resource_6.is_hand = true
	crazy_dave_dialog_detail_resource_6.hand_item_id = 0
	var crazy_dave_dialog_detail_resource_7 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_7.text = "拿去用吧，别谢我——因为我疯了！！！"
	crazy_dave_dialog_detail_resource_7.is_crazy = true
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6, crazy_dave_dialog_detail_resource_7])
	crazy_dave_dialog_resource_0.all_hand_itmes_scene.assign([preload("res://src/dave/hand_item/hand_glove.tscn")])
	return crazy_dave_dialog_resource_0


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Fog
	game_BGM = ConstLevelData.GameBGM.Fog
	is_fog = true
	is_day = false
	is_day_sun = false
	dave_dialog_only_first_playthrough = true
	drop_unlock_wave = 5
	drop_unlock_tip = "解谜模式解锁！可以从主菜单中进入该模式！"


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z018Digger,
	]

	## 关卡戴夫对话：整段是「戴夫送手套」的赠礼演出，手套功能隐藏时不播
	## （见 ConstFeatureSwitch.GLOVE_ENABLED）
	if ConstFeatureSwitch.GLOVE_ENABLED:
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


## 本关的开场戴夫对话就是手套赠礼演出：对话在 run_flow() 里现场构造（见 _build_dave_dialog），
## 手套功能隐藏时整段不播，这里同步声明「没有对话」（见 ConstFeatureSwitch.GLOVE_ENABLED）。
## 有对话时：不再播戴夫推销卡槽扩充（见 is_dave_sell_possible）
func has_dave_dialog() -> bool:
	return ConstFeatureSwitch.GLOVE_ENABLED
