extends RefCounted
## 探针 PROBE8b：新手教程（原版冒险模式 1-2）
## 覆盖：
##   1. 首次游玩 1-2 会创建 TutorialManager 并播教程（拥有豌豆射手 + 向日葵）
##   2. 教程严格按原版顺序推进：捡向日葵种子包 → 种下第一棵 → 种满三棵向日葵 → 干得漂亮
##   3. 教程期间第一波僵尸不自动开波，而是在种下第一株向日葵后由教程启动
##   4. 教程结束后提示条消失、教程运行标记复位
##   5. 已通关 1-2 后再进本关不再播教程（原版教程只在冒险模式第一轮出现）
## 机器可读汇总：最后一行 [TUTORIAL12] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_02.gd"
const SAVE_NAME_02 := "101_0_0002"
## 原版教程文本（data/strings/lawn_strings.txt 的 ADVICE_* 条目）
const ADVICE_SUNFLOWER_INTRO := "向日葵是非常重要的植物！"
const ADVICE_CLICK_GRASS := "点击草地种下你的种子！"
const ADVICE_PLANT_THREE := "至少要种下三棵向日葵！"
const ADVICE_NICELY_DONE := "干得漂亮！"
## 原版 1-2 教程的完整顺序（步骤下标 -> 提示文本）
const EXPECT_ADVICE := {
	0: ADVICE_SUNFLOWER_INTRO,
	1: ADVICE_CLICK_GRASS,
	2: ADVICE_PLANT_THREE,
	3: ADVICE_NICELY_DONE,
}
## 实际播过的提示（步骤下标 -> 提示文本），由 signal_step_changed 记录
var _advice_by_step: Dictionary = {}


func run(a) -> void:
	a.log("")
	a.log("========== 探针：新手教程（1-2）==========")

	var state = Global.global_game_state
	## 已通关 1-1：拥有豌豆射手 + 向日葵；没有任何通关记录
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P002SunFlower,
	])
	state.curr_all_level_state_data = {}

	if not await _enter_level(a, true):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(1.0)

	var mg = Global.main_game
	var tut = mg.tutorial_manager
	var para = mg.game_para

	# ------------------------------------------------ STEP1 教程启动
	a.log("STEP1 教程启动与开局参数")
	## 教程在 run_flow() 里现场构造（见 _build_tutorial），静态读不到数据本体
	_check(a, "1-2 配置了教程数据", para.is_tutorial(), str(para.has_tutorial()))
	_check(a, "创建了教程管理器", tut != null, "null" if tut == null else str(tut.get_path()))
	if tut == null:
		_finish(a)
		return
	_check(a, "教程正在运行", tut.is_running, str(tut.is_running))
	## 第 1 步的信号在教程启动时就发过了，这里补记
	tut.signal_step_changed.connect(_on_step_changed.bind(tut))
	_advice_by_step[tut.curr_step_index] = tut.get_advice_text()
	_check(a, "第 1 步提示=向日葵是非常重要的植物", tut.get_advice_text() == ADVICE_SUNFLOWER_INTRO,
		tut.get_advice_text())
	_check(a, "提示条可见", tut.is_advice_visible(), str(tut.is_advice_visible()))
	_check(a, "第 1 步箭头指向向日葵卡", tut.get_pointer_target_position() != null,
		str(tut.get_pointer_target_position()))
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	_check(a, "教程期间第一波未开始", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))

	# ------------------------------------------------ STEP2 点击向日葵种子包
	a.log("STEP2 点击向日葵种子包，卡片拿在手上")
	var battle = mg.card_manager.card_slot_battle
	var card: Card = _get_sunflower_card(battle)
	_check(a, "战斗卡槽有向日葵卡", card != null,
		"null" if card == null else str(card.card_plant_type))
	if card == null:
		_finish(a)
		return
	var card_center: Vector2 = a.screen_center(card)
	await a.click(card_center.x, card_center.y)
	if not await _wait_step(a, 1, 8.0):
		_check(a, "点卡后进入第 2 步", false, "curr_step_index=" + str(tut.curr_step_index))
		_finish(a)
		return
	_check(a, "点卡后进入第 2 步", tut.curr_step_index == 1, str(tut.curr_step_index))
	_check(a, "第 2 步提示=点击草地", tut.get_advice_text() == ADVICE_CLICK_GRASS, tut.get_advice_text())
	_check(a, "卡片已拿在手上", mg.hand_manager.is_holding_hand(), str(mg.hand_manager.is_holding_hand()))

	# ------------------------------------------------ STEP3 种下第一株向日葵
	a.log("STEP3 种下第一株向日葵（第一波僵尸由此启动）")
	var plant_row := _find_plant_row(mg)
	a.log("  可种植的行 = %d" % plant_row)
	_check(a, "1-2 有可种植的草坪行", plant_row >= 0, str(plant_row))
	if plant_row < 0:
		_finish(a)
		return
	await a.click_plant_cell(plant_row, 1)
	if not await _wait_step(a, 2, 12.0):
		_check(a, "种下第一株后走到第 3 步", false, "curr_step_index=" + str(tut.curr_step_index))
		_finish(a)
		return
	_check(a, "种下第一株后第一波僵尸已启动", wave_manager.curr_wave >= 0, str(wave_manager.curr_wave))
	_check(a, "第 3 步提示=至少要种下三棵向日葵", tut.get_advice_text() == ADVICE_PLANT_THREE,
		tut.get_advice_text())

	# ------------------------------------------------ STEP4 集齐三棵向日葵
	a.log("STEP4 收集阳光，种满三棵向日葵（教程结束）")
	if not await _grow_sunflowers_to_end(a, 90.0):
		_check(a, "种满三棵向日葵后教程结束", false,
			"curr_step_index=" + str(tut.curr_step_index) + " 向日葵=" + str(_count_plant(mg, CharacterRegistry.PlantType.P002SunFlower)))
		_finish(a)
		return
	_check(a, "教程已结束", tut.is_finished and not tut.is_running,
		"finished=" + str(tut.is_finished) + " running=" + str(tut.is_running))
	_check(a, "教程结束后提示条已移除", mg.tutorial_manager.get_advice_ui() == null,
		str(mg.tutorial_manager.get_advice_ui()))
	_check(a, "教程结束后僵尸波次仍在进行", wave_manager.curr_wave >= 0, str(wave_manager.curr_wave))
	_check(a, "场上已种下 3 株向日葵", _count_plant(mg, CharacterRegistry.PlantType.P002SunFlower) >= 3,
		str(_count_plant(mg, CharacterRegistry.PlantType.P002SunFlower)))
	_check(a, "教程提示顺序与原版一致", _advice_by_step == EXPECT_ADVICE, str(_advice_by_step))

	# ------------------------------------------------ STEP5 已通关后不再播教程
	a.log("STEP5 已通关 1-2 后再进本关（不播教程）")
	state.curr_all_level_state_data[SAVE_NAME_02] = {"IsSuccess": true}
	_check(a, "1-2 已有通关记录", state.curr_all_level_state_data.has(SAVE_NAME_02))
	if not await _enter_level(a, false):
		_check(a, "重进 1-2 到 MAIN_GAME", false, "超时")
		_finish(a)
		return
	await a.wait(1.0)
	_check(a, "已通关时不再创建教程管理器", Global.main_game.tutorial_manager == null,
		str(Global.main_game.tutorial_manager))

	_finish(a)


#region 断言与工具
## 教程步骤变化：记下这一步实际播出的提示文本
func _on_step_changed(step_index: int, tut) -> void:
	if tut != null:
		_advice_by_step[step_index] = tut.get_advice_text()


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[TUTORIAL12] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 直接用关卡数据进 1-2 主游戏（1-2 不是选关界面里第一个按钮，走菜单到不了）
func _enter_level(a, first: bool) -> bool:
	if first:
		## 先等引擎把真实主场景（开始菜单）稳定下来
		await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 10.0)
	var para = (load(LEVEL_PATH) as GDScript).new()
	para.set_choose_level(ADV, 0, "0002")
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences])
	return await _wait_main_game(a, 40.0)


## 等主游戏进入 MAIN_GAME 阶段
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.main_game_progress == 3:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等教程走到指定步骤
func _wait_step(a, step_index: int, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var tut = Global.main_game.tutorial_manager
		if tut != null and tut.curr_step_index >= step_index:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 反复收阳光 + 补种向日葵，直到教程结束
func _grow_sunflowers_to_end(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		var tut = mg.tutorial_manager
		if tut == null or tut.is_finished:
			return true
		await _click_all_suns(a, mg)
		await _try_plant_sunflower(a, mg)
		await a.wait(0.5)
		waited += 0.5
	return false


## 点掉场上所有可点的阳光（阳光掉下来不点不会进账）
func _click_all_suns(a, mg) -> void:
	var suns: Node = mg.suns
	if suns == null:
		return
	for child in suns.get_children():
		var sun := child as Sun
		if sun == null or sun.collected:
			continue
		## 阳光从屏幕上方掉下来，出屏之前点不到
		if sun.get_global_transform_with_canvas().origin.y < 120.0:
			continue
		var btn: Control = sun.get_node_or_null("Button") as Control
		if btn == null or not btn.is_visible_in_tree():
			continue
		var p: Vector2 = a.screen_center(btn)
		await a.click(p.x, p.y)


## 阳光足够且卡片冷却结束时，补种一棵向日葵
func _try_plant_sunflower(a, mg) -> void:
	if mg.hand_manager.is_holding_hand():
		return
	var battle = mg.card_manager.card_slot_battle
	var card: Card = _get_sunflower_card(battle)
	if card == null or not card.is_can_click:
		return
	if battle.sun_value < card.sun_cost:
		return
	var cell: PlantCell = _find_free_cell_in_row(mg, _find_plant_row(mg))
	if cell == null:
		return
	var card_center: Vector2 = a.screen_center(card)
	await a.click(card_center.x, card_center.y)
	await a.wait(0.3)
	var rc: Vector2i = cell.row_col
	await a.click_plant_cell(rc.x, rc.y)
	await a.wait(0.3)


## 出战卡槽里的向日葵卡
func _get_sunflower_card(battle) -> Card:
	if battle == null:
		return null
	for card: Card in battle.curr_cards:
		if card.card_plant_type == CharacterRegistry.PlantType.P002SunFlower:
			return card
	return null


## 找一行真的能种下向日葵的草坪（1-2 只有中间 3 行铺了草皮）
func _find_plant_row(mg) -> int:
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var cell_rows: Array[Array] = mg.plant_cell_manager.all_plant_cells
	for row_index in range(cell_rows.size()):
		var cells: Array = cell_rows[row_index]
		if cells.is_empty():
			continue
		if cond.judge_is_can_plant(cells[1], CharacterRegistry.PlantType.P002SunFlower):
			return row_index
	return -1


## 指定行里第一个「能种且空着」的格子
func _find_free_cell_in_row(mg, row_index: int) -> PlantCell:
	if row_index < 0:
		return null
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var cells: Array = mg.plant_cell_manager.all_plant_cells[row_index]
	for cell in cells:
		var plant_cell := cell as PlantCell
		if plant_cell == null:
			continue
		if not cond.judge_is_can_plant(plant_cell, CharacterRegistry.PlantType.P002SunFlower):
			continue
		if plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm) == null:
			return plant_cell
	return null


## 场上某种植物的数量
func _count_plant(mg, plant_type: CharacterRegistry.PlantType) -> int:
	var num := 0
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for place in plant_cell.plant_in_cell:
				var plant = plant_cell.get_plant(place)
				if is_instance_valid(plant) and plant.plant_type == plant_type:
					num += 1
	return num
#endregion
