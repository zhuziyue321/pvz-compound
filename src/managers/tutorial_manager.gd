extends Node
class_name TutorialManager
## 新手教程管理器（原版：冒险模式 1-1 / 1-2 / 1-5 的教学流程）
##
## 教程关的卡槽形态不同：1-1 / 1-2 是普通出战卡槽，1-5 是传送带关（卡片由传送带送来），
## 取卡片一律走 _get_curr_card_list()，不要直接读 card_slot_battle（传送带关它是空的）。
##
## 步骤数据（ResourceTutorialData）有两个来路：
##   · 关卡资源字段 tutorial_data（老 .tres 关卡 / 没改过的关卡脚本）
##   · 关卡脚本在 run_flow() 里现场构造、由教程事件交进来（见 set_tutorial_data）
## 本类只做四件事：
##   1. 按顺序推进教程步骤，等玩家做出对应操作（种下植物 / 收阳光 / 捡卡片）
##   2. 显示提示条与指向箭头（TutorialAdviceUI）
##   3. 替关卡做两件原本由管理器自动完成的事：生成阳光、启动第一波僵尸
##      （原版：第一波僵尸在种下第一株植物之后才出现）
##   4. 教程结束 / 游戏结束时收尾（隐藏提示、断开订阅、保证僵尸已开波）
##
## 提示文本使用原版 advice 字符串，见 data/strings/lawn_strings.txt 的 ADVICE_* 条目。

## 教程全部步骤走完（供主游戏管理器 / 自动测试取用）
signal signal_tutorial_finished
## 当前步骤变化（参数为步骤下标，从 0 开始）
signal signal_step_changed(step_index: int)
## 提示文本变化：逐步模式下由 show_advice_text() 发出，参数是新的文本（空串 = 收起提示）
## 逐步模式没有 step 下标可看，调试通道 / 自动测试靠它跟踪教程说到哪一句
signal signal_advice_changed(text: String)
## 单步完成（内部使用：唤醒等待中的步骤协程）
signal _signal_step_finished

## 教程是否正在运行
var is_running := false
## 教程是否已经跑过（多轮游戏不重复播）
var is_finished := false
## 当前步骤下标，-1 表示还没进入任何步骤
var curr_step_index := -1

var main_game: MainGameManager
var tutorial_data: ResourceTutorialData

var _curr_step: ResourceTutorialStep
var _advice_ui: TutorialAdviceUI
## 当前步骤内已种下的植物数量（PlantCount 条件用）
var _plant_done_num := 0
## 当前步骤内已铲掉的植物数量（DigPlantCount 条件用）
var _plant_free_num := 0
## 是否已经启动过第一波僵尸
var _is_zombie_wave_started := false


func _ready() -> void:
	set_process(false)
	## 步骤数据在 _ready 就取好：主游戏要靠 is_opening_tutorial() 决定「教程是在开局前还是开局后跑」
	## 关卡脚本把教程放在 run_flow() 里现场构造时，这时还取不到 —— 由教程事件后补（见 set_tutorial_data）
	if Global.main_game != null:
		main_game = Global.main_game
		tutorial_data = main_game.game_para.get_tutorial_data()


## 教程数据后补：数据在 run_flow() 里才构造出来，由教程事件交进来
## （见 LevelTimelineEventTutorial.run → MainGameManager.setup_tutorial_manager）
func set_tutorial_data(data: ResourceTutorialData) -> void:
	tutorial_data = data


#region 对外接口
## 本教程是否为「开场教程」：整段教程在关卡正式开局（预览僵尸）之前跑完
## （原版 1-5：戴夫开场白 → 玩家铲光草坪 → 戴夫介绍保龄球 → 才预览僵尸并开局）
func is_opening_tutorial() -> bool:
	return tutorial_data != null and tutorial_data.is_opening_tutorial


## 开始教程
## 普通教程（1-1 / 1-2）由 MainGameManager 在进入 MAIN_GAME 阶段后调用；
## 开场教程（1-5）由 MainGameManager 在开场戴夫对话之后、预览僵尸之前调用，等它跑完才继续开局
func start_tutorial() -> void:
	if is_running or is_finished:
		return
	main_game = Global.main_game
	if main_game == null:
		Log.error("TutorialManager: 主游戏不存在，无法开始教程")
		return
	if tutorial_data == null:
		tutorial_data = main_game.game_para.get_tutorial_data()
	if tutorial_data == null or tutorial_data.steps.is_empty():
		Log.warn("TutorialManager: 没有可执行的教程步骤，跳过教程")
		is_finished = true
		return

	is_running = true
	set_process(true)
	_create_advice_ui()
	_connect_signals()
	Log.debug("新手教程开始，共 " + str(tutorial_data.steps.size()) + " 步")
	## 开场教程在关卡开局之前跑，此时铲子界面默认不显示（只在 MAIN_GAME 阶段显示），
	## 这里主动刷新一次，否则 1-5 的「点击拾取铲子」一步拿不到铲子
	if is_opening_tutorial():
		main_game.hand_manager.refresh_all_hand_ui()
	## 铲子教学却拿不到铲子：直接收尾，别把教程和「等教程启动的传送带」一起卡死
	if _is_shovel_tutorial_blocked():
		Log.warn("新手教程需要铲子，但本关没有铲子 / 玩家还没拿到铲子，跳过教程")
		_stop_tutorial()
		return
	await _run_steps()
	_stop_tutorial()


## 教程里有没有「拿起铲子」的步骤、而本局又拿不到铲子
## （关卡禁了铲子 或 玩家还没通关 1-4，两种情况下这一步永远等不到）
func _is_shovel_tutorial_blocked() -> bool:
	for step: ResourceTutorialStep in tutorial_data.steps:
		if step == null or step.finish_type != ResourceTutorialStep.E_FinishType.TakeShovel:
			continue
		return not main_game.game_para.is_shovel \
			or not Global.global_game_state.is_shovel_unlocked()
	return false


## 当前提示文本（调试 / 自动测试取用），教程未运行时返回空字符串
func get_advice_text() -> String:
	if _advice_ui == null:
		return ""
	return _advice_ui.get_advice_text()


## 提示条当前是否可见（调试 / 自动测试取用）
func is_advice_visible() -> bool:
	return _advice_ui != null and _advice_ui.is_advice_visible()


## 箭头当前指向的画布坐标（调试 / 自动测试取用），无指向时返回 null
func get_pointer_target_position() -> Variant:
	if _curr_step == null:
		return null
	return _resolve_pointer_target(_curr_step)


## 当前提示条节点（调试 / 自动测试取用）
func get_advice_ui() -> TutorialAdviceUI:
	return _advice_ui
#endregion


#region 步骤推进
func _run_steps() -> void:
	for step_index in range(tutorial_data.steps.size()):
		if not is_running:
			return
		await _enter_step(step_index)
		await _wait_step_finish()
	Log.debug("新手教程步骤全部执行完毕")


func _enter_step(step_index: int) -> void:
	curr_step_index = step_index
	_curr_step = tutorial_data.steps[step_index]
	_plant_done_num = 0
	_plant_free_num = 0

	Log.debug("教程步骤 %d/%d：%s" % [step_index + 1, tutorial_data.steps.size(), _curr_step.advice_text])

	## 附加动作：原版教程固定掉落一颗阳光，第一波僵尸在种下第一株植物后出现，
	## 1-5 是铲完草坪上的植物之后才启动传送带（保龄球开局）
	## 本步带戴夫对话时先让戴夫说完（原版 1-5：铲光草坪后戴夫才介绍保龄球）
	## 说话期间先收起上一步的提示，别让旧提示压在戴夫气泡上
	if _curr_step.dave_dialog != null:
		if _advice_ui != null:
			_advice_ui.hide_advice()
		await main_game.play_crazy_dave_dialog(_curr_step.dave_dialog)
	if _curr_step.spawn_sun:
		main_game.day_suns_manager.spawn_sun()
	if _curr_step.start_zombie_wave:
		start_zombie_wave()
	if _curr_step.start_conveyor_belt:
		main_game.card_manager.start_conveyor_belt()

	if _advice_ui != null:
		## 纯戴夫对话步骤没有提示文本，别弹一个空气泡
		if _curr_step.advice_text.is_empty():
			_advice_ui.hide_advice()
		else:
			_advice_ui.show_advice(_curr_step.advice_text)
	signal_step_changed.emit(step_index)


## 等待当前步骤完成
func _wait_step_finish() -> void:
	## 进入步骤时条件已经满足（例如阳光本来就够了）就不再等
	if _is_step_condition_satisfied():
		return
	if _curr_step.finish_type == ResourceTutorialStep.E_FinishType.None:
		await get_tree().create_timer(_curr_step.finish_time).timeout
		return
	await _signal_step_finished


## 进入步骤的那一刻，完成条件是否已经成立
func _is_step_condition_satisfied() -> bool:
	if _curr_step == null:
		return false
	match _curr_step.finish_type:
		ResourceTutorialStep.E_FinishType.TakeCard:
			return main_game.hand_manager.is_holding_hand()
		ResourceTutorialStep.E_FinishType.SunValueAtLeast:
			return _get_curr_sun_value() >= _curr_step.sun_value
		ResourceTutorialStep.E_FinishType.TakeShovel:
			return _is_holding_shovel()
		ResourceTutorialStep.E_FinishType.DigAllPlants:
			return _count_lawn_plants() <= 0
		_:
			return false


## 当前步骤是否在等某个完成条件（避免无关事件打断当前步骤）
func _is_waiting_finish(finish_type: ResourceTutorialStep.E_FinishType) -> bool:
	return is_running and _curr_step != null and _curr_step.finish_type == finish_type


func _finish_step() -> void:
	_signal_step_finished.emit()
#endregion


#region 完成条件：事件回调
func _on_hand_card_take(card: Card) -> void:
	if not _is_waiting_finish(ResourceTutorialStep.E_FinishType.TakeCard):
		return
	if _curr_step.plant_type != CharacterRegistry.PlantType.Null \
		and card.card_plant_type != _curr_step.plant_type:
		return
	_finish_step()


## 种下植物（植物格子 signal_plant_create）
func _on_plant_create(_plant_cell: PlantCell, plant_type: CharacterRegistry.PlantType) -> void:
	if not _is_waiting_finish(ResourceTutorialStep.E_FinishType.PlantCount):
		return
	if _curr_step.plant_type != CharacterRegistry.PlantType.Null and plant_type != _curr_step.plant_type:
		return
	_plant_done_num += 1
	if _plant_done_num >= maxi(1, _curr_step.plant_count):
		_finish_step()


## 铲掉植物（植物格子 signal_plant_free）：铲子铲除、被僵尸吃掉都会发
func _on_plant_free(_plant_cell: PlantCell, _plant_type: CharacterRegistry.PlantType) -> void:
	if not _is_waiting_finish(ResourceTutorialStep.E_FinishType.DigPlantCount):
		return
	_plant_free_num += 1
	if _plant_free_num >= maxi(1, _curr_step.plant_count):
		_finish_step()


## 收集阳光（阳光对象点击后推 add_sun_value）
## 注意：同一个事件里卡槽也在扣数值，所以"阳光够不够"只在 _process 里按帧判断，
## 不依赖事件回调顺序
func _on_add_sun_value(_sun_value: int) -> void:
	if _is_waiting_finish(ResourceTutorialStep.E_FinishType.CollectSun):
		_finish_step()


## 游戏结束（僵尸进家 / 胜利）时终止教程
func _on_main_game_progress_update(curr_progress: MainGameManager.E_MainGameProgress) -> void:
	if curr_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
		_stop_tutorial()
#endregion


#region 每帧：指向箭头 + 阳光数量条件
func _process(_delta: float) -> void:
	if not is_running or _curr_step == null:
		return
	## 阳光数量条件按帧判断，不依赖事件回调顺序
	if _curr_step.finish_type == ResourceTutorialStep.E_FinishType.SunValueAtLeast \
		and _get_curr_sun_value() >= _curr_step.sun_value:
		_finish_step()
		return
	## 铲子没有「拿到手上」的事件，按帧读手持物类型；铲光同理按帧数草坪上的植物
	if _curr_step.finish_type == ResourceTutorialStep.E_FinishType.TakeShovel and _is_holding_shovel():
		_finish_step()
		return
	if _curr_step.finish_type == ResourceTutorialStep.E_FinishType.DigAllPlants \
		and _count_lawn_plants() <= 0:
		_finish_step()
		return

	_update_pointer()


func _update_pointer() -> void:
	if _advice_ui == null:
		return
	var target_pos: Variant = _resolve_pointer_target(_curr_step)
	if target_pos == null:
		_advice_ui.hide_pointer()
		return
	_advice_ui.update_pointer(target_pos)
#endregion


#region 指向目标
## 解析当前步骤箭头要指的画布坐标；目标不存在时返回 null（例如场上还没有阳光）
func _resolve_pointer_target(step: ResourceTutorialStep) -> Variant:
	match step.pointer_target:
		ResourceTutorialStep.E_PointerTarget.Card:
			var card := _get_battle_card(step.plant_type)
			if card == null:
				return null
			return _get_card_pointer_position(card)
		ResourceTutorialStep.E_PointerTarget.Lawn:
			var plant_cell := _get_lawn_center_plant_cell()
			if plant_cell == null:
				return null
			return _get_canvas_center(plant_cell)
		ResourceTutorialStep.E_PointerTarget.Sun:
			var sun := _get_first_sun()
			if sun == null:
				return null
			return sun.get_global_transform_with_canvas().origin
		ResourceTutorialStep.E_PointerTarget.Shovel:
			var ui_shovel := _get_ui_shovel()
			if ui_shovel == null:
				return null
			return _get_canvas_center(ui_shovel)
		ResourceTutorialStep.E_PointerTarget.Plant:
			var plant_cell := _get_first_plant_cell_with_plant()
			if plant_cell == null:
				return null
			return _get_canvas_center(plant_cell)
		_:
			return null


## 当前可点的卡里指定植物的那张（plant_type 为 Null 时取第一张）
## 传送带关（1-5 / x-10）没有出战卡槽，卡片在传送带上，所以统一走 _get_curr_card_list()
func _get_battle_card(plant_type: CharacterRegistry.PlantType) -> Card:
	for card: Card in _get_curr_card_list():
		if plant_type == CharacterRegistry.PlantType.Null or card.card_plant_type == plant_type:
			return card
	return null


## 当前卡槽里的卡片：普通关取出战卡槽，传送带关取传送带上的卡片
func _get_curr_card_list() -> Array:
	var card_manager: CardManager = main_game.card_manager
	if card_manager == null:
		return []
	if card_manager.card_slot_battle != null:
		return card_manager.card_slot_battle.curr_cards
	if card_manager.card_slot_conveyor_belt != null:
		return card_manager.card_slot_conveyor_belt.curr_cards
	return []


## 草坪上「最适合种下当前卡片」的植物格子：从草坪中心向外找第一个能种下的格子
## 地图是数据驱动的（例如 1-1 只有一行铺了草皮），所以不能直接取几何中心；
## 1-5 保龄球关红线右边一律不可种植，靠 _can_plant_in_cell() 过滤掉红线外的格子
func _get_lawn_center_plant_cell() -> PlantCell:
	var cell_rows: Array[Array] = main_game.plant_cell_manager.all_plant_cells
	if cell_rows.is_empty():
		return null
	var plant_type := _get_pointer_plant_type()
	for row_index: int in _center_out_order(cell_rows.size()):
		var cells: Array = cell_rows[row_index]
		for col_index: int in _center_out_order(cells.size()):
			var plant_cell := cells[col_index] as PlantCell
			if plant_cell == null:
				continue
			if plant_type == CharacterRegistry.PlantType.Null:
				return plant_cell
			if _can_plant_in_cell(plant_cell, plant_type):
				return plant_cell
	return null


## 当前指向的植物类型：优先取步骤里写的，其次取手上 / 卡槽第一张卡
func _get_pointer_plant_type() -> CharacterRegistry.PlantType:
	if _curr_step != null and _curr_step.plant_type != CharacterRegistry.PlantType.Null:
		return _curr_step.plant_type
	var card := _get_battle_card(CharacterRegistry.PlantType.Null)
	if card != null:
		return card.card_plant_type
	return CharacterRegistry.PlantType.Null


func _can_plant_in_cell(plant_cell: PlantCell, plant_type: CharacterRegistry.PlantType) -> bool:
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if plant_condition == null:
		return false
	return plant_condition.judge_is_can_plant(plant_cell, plant_type)


## 从中间向两端扩散的下标顺序：8 -> [4, 5, 3, 6, 2, ...]
func _center_out_order(size: int) -> Array[int]:
	var order: Array[int] = []
	if size <= 0:
		return order
	@warning_ignore("integer_division")
	var mid := size / 2
	order.append(mid)
	for step in range(1, size):
		if mid + step < size:
			order.append(mid + step)
		if mid - step >= 0:
			order.append(mid - step)
	return order


## 场上第一颗还没被收集的阳光
func _get_first_sun() -> Sun:
	for child in main_game.suns.get_children():
		var sun := child as Sun
		if sun != null and not sun.collected:
			return sun
	return null


## 卡槽里的铲子（铲子教学要指它）
func _get_ui_shovel() -> UIShovel:
	var card_slot_root: CardSlotRoot = main_game.card_slot_root
	if card_slot_root == null:
		return null
	return card_slot_root.ui_shovel


## 草坪上第一株还活着的植物所在格子（铲子教学要指它）
func _get_first_plant_cell_with_plant() -> PlantCell:
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null and plant_cell.get_curr_plant_num() > 0:
				return plant_cell
	return null


## 控件在屏幕（画布）上的中心点
func _get_canvas_center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


## 指向卡片的落点：从卡片中心朝提示条方向挪出卡片外沿
## （箭尖落在卡面中心会压住卡图，原版的提示箭头也是指着卡片外侧）
func _get_card_pointer_position(card: Control) -> Vector2:
	var card_center := _get_canvas_center(card)
	if _advice_ui == null:
		return card_center
	var to_box := _advice_ui.get_advice_box_center() - card_center
	if to_box == Vector2.ZERO:
		return card_center
	return card_center + to_box.normalized() * (maxf(card.size.x, card.size.y) * 0.5 + 8.0)
#endregion


#region 阳光与僵尸
func _get_curr_sun_value() -> int:
	var card_slot_battle: CardSlotBattle = main_game.card_manager.card_slot_battle
	if card_slot_battle == null:
		return 0
	return card_slot_battle.sun_value


## 启动第一波僵尸：教程关里 ZombieManager.start_game() 不会自己开波，
## 由教程在原版时机（种下第一株植物后）调用
func start_zombie_wave() -> void:
	if _is_zombie_wave_started:
		return
	_is_zombie_wave_started = true
	if main_game.game_para.monster_mode != ConstLevelData.E_MonsterMode.Norm:
		return
	Log.debug("教程启动第一波僵尸")
	## 标记第一波已开：时间轴的 Wave 事件 / 开战流程就不会再开一次
	main_game.zombie_manager.is_first_wave_started = true
	main_game.zombie_manager.zombie_wave_manager.start_first_wave()


## 手上是不是拿着铲子（铲子没有「拿起」事件，按帧读手持物类型）
func _is_holding_shovel() -> bool:
	return main_game.hand_manager.get_curr_hand_type() \
		== HandComponentBase.E_HandComponentType.Shovel


## 草坪上还活着的植物数量（1-5「铲光」判定）
func _count_lawn_plants() -> int:
	var num := 0
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null:
				num += plant_cell.get_curr_plant_num()
	return num
#endregion


#region 提示条与订阅
func _create_advice_ui() -> void:
	_advice_ui = SceneRegistry.TUTORIAL_ADVICE.instantiate()
	## 提示条属于界面层，挂在 CanvasLayerUI 下（层号 50，压住草坪与卡槽）
	## 位置由提示条自己的 Bottom Wide 锚点决定（贴屏幕底部），不用外部再给坐标
	main_game.canvas_layer_ui.add_child(_advice_ui)


func _connect_signals() -> void:
	EventBus.subscribe("hand_card_take", _on_hand_card_take)
	EventBus.subscribe("add_sun_value", _on_add_sun_value)
	EventBus.subscribe("main_game_progress_update", _on_main_game_progress_update)
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			plant_cell.signal_plant_create.connect(_on_plant_create)
			plant_cell.signal_plant_free.connect(_on_plant_free)


func _disconnect_signals() -> void:
	EventBus.unsubscribe("hand_card_take", _on_hand_card_take)
	EventBus.unsubscribe("add_sun_value", _on_add_sun_value)
	EventBus.unsubscribe("main_game_progress_update", _on_main_game_progress_update)
	## 主游戏可能已经先一步被释放了（教程还在等东西时玩家退回主菜单），
	## 这时候再去摸 plant_cell_manager / 格子上的 signal 就是访问已释放对象
	if not is_instance_valid(main_game):
		return
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			var create_callback := Callable(self, "_on_plant_create")
			if plant_cell.signal_plant_create.is_connected(create_callback):
				plant_cell.signal_plant_create.disconnect(create_callback)
			var free_callback := Callable(self, "_on_plant_free")
			if plant_cell.signal_plant_free.is_connected(free_callback):
				plant_cell.signal_plant_free.disconnect(free_callback)


## 收尾：教程结束 / 游戏结束都走这里
func _stop_tutorial() -> void:
	if not is_running:
		return
	is_running = false
	is_finished = true
	set_process(false)
	_disconnect_signals()
	if is_instance_valid(_advice_ui):
		_advice_ui.queue_free()
	_advice_ui = null
	_curr_step = null
	## 开场教程跑完就把铲子界面收回去（关卡还没进入主游戏阶段，铲子不该留在卡槽上）
	## 注意用 is_instance_valid：`main_game != null` 对已释放对象是 true，照样会崩
	if is_opening_tutorial() and is_instance_valid(main_game):
		main_game.hand_manager.refresh_all_hand_ui()

	## 教程中途结束（游戏结束等）时不补开波；正常跑完则保证僵尸已经出动、传送带已经启动
	## （1-5 的传送带原本由最后一步启动，教程异常中断时这里兜底，否则永远没有卡）
	if is_instance_valid(main_game) \
		and main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		start_zombie_wave()
		main_game.card_manager.start_conveyor_belt()
	## 唤醒可能还在等步骤完成的协程，让它自己退出
	_signal_step_finished.emit()
	signal_tutorial_finished.emit()
	Log.debug("新手教程结束")
#endregion


#region 逐步模式（关卡流程用事件一步步驱动教程）
## 两种模式互斥：
##   · **自驱模式**（老写法）：教程数据 tutorial_data 里有一串 steps，start_tutorial() 自己跑完
##   · **逐步模式**（新写法）：没有 steps，由关卡流程里的 prefab.advice(文本) / prefab.point_card(植物)
##     / prefab.wait_plant(...) 这些事件一次做一件事地推进（见 LevelPrefabs 的教程系列）
## 好处是「教程长什么样」直接写进 run_flow()，一眼能看出这一关在教什么，不用回头翻数据。
##
## 逐步模式复用自驱模式的全部判定能力（事件订阅 / 每帧判定 / 箭头解析）：
## 每次等待都临时造一个 step 塞给 _is_step_condition_satisfied() 用。

## 当前箭头指向（每次等待造新 step 时要带过去，否则箭头会跳回 None）
var _stepped_pointer_target: ResourceTutorialStep.E_PointerTarget = ResourceTutorialStep.E_PointerTarget.None
## 当前箭头对应的植物类型（找那张卡 / 找能种它的格子）
var _stepped_pointer_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
## 占位步骤：没有等待任务时挂在 _curr_step 上（_process 的箭头刷新要有 _curr_step 才能干活）
var _idle_step: ResourceTutorialStep
## 限时等待的轮询间隔（秒）
const WAIT_POLL_STEP := 0.25


## 本关有没有自驱的教程步骤（有 = 自驱模式，无 = 逐步模式）
## MainGameManager.main_game_start() 据此决定要不要自己开跑教程
func has_steps() -> bool:
	return tutorial_data != null and not tutorial_data.steps.is_empty()


## 进入逐步模式：建提示条、订阅事件信号，但不跑任何步骤
func begin_stepped_mode() -> void:
	if is_running:
		return
	main_game = Global.main_game
	if main_game == null:
		Log.error("TutorialManager: 主游戏不存在，无法开始教程")
		return
	is_running = true
	is_finished = false
	curr_step_index = -1
	_stepped_pointer_target = ResourceTutorialStep.E_PointerTarget.None
	_stepped_pointer_plant_type = CharacterRegistry.PlantType.Null
	## 占位步骤：逐步模式没有 tutorial_data.steps，但 _process 的箭头刷新要有 _curr_step
	_curr_step = ResourceTutorialStep.new()
	_curr_step.finish_type = ResourceTutorialStep.E_FinishType.None
	_curr_step.finish_time = 0.0
	_idle_step = _curr_step
	set_process(true)
	_create_advice_ui()
	_connect_signals()
	Log.debug("新手教程开始（逐步模式）")


## 结束逐步模式：收回提示条、断开订阅、停掉按帧判定
func end_stepped_mode() -> void:
	if not is_running:
		return
	is_running = false
	is_finished = true
	set_process(false)
	_disconnect_signals()
	if is_instance_valid(_advice_ui):
		_advice_ui.queue_free()
	_advice_ui = null
	_curr_step = null
	_idle_step = null
	## 唤醒可能还卡在「等一个条件」上的协程，让它自己退出
	_signal_step_finished.emit()
	signal_tutorial_finished.emit()
	Log.debug("新手教程结束（逐步模式）")


## 显示提示文本；传空串表示收起提示条与箭头（原版这一步是 hid()）
func show_advice_text(text: String) -> void:
	if not _ensure_stepped_ui():
		return
	signal_advice_changed.emit(text)
	if text.is_empty():
		_advice_ui.hide_advice()
		return
	_advice_ui.show_advice(text)


## 箭头指向 target；plant_type 用来找那张卡 / 找能种它的格子
## （Card 目标必须给 plant_type，Lawn 目标给了才知道「能种这个的格子」在哪）
## target 传 None 就收起箭头
func point_to(target: ResourceTutorialStep.E_PointerTarget,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	_stepped_pointer_target = target
	_stepped_pointer_plant_type = plant_type
	## 箭头目标由 _curr_step 驱动，改了即时生效
	if _curr_step != null:
		_curr_step.pointer_target = target
		_curr_step.plant_type = plant_type
	if not _ensure_stepped_ui():
		return
	if target == ResourceTutorialStep.E_PointerTarget.None:
		_advice_ui.hide_pointer()
		return
	_update_pointer()


## 掉一颗阳光下来（原版教程的第三步要它有东西可捡）
func spawn_sun() -> void:
	if main_game == null:
		return
	main_game.day_suns_manager.spawn_sun()


## 等玩家捡起一张卡（plant_type 留 Null = 任意卡）
func wait_take_card(plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	await _await_condition(ResourceTutorialStep.E_FinishType.TakeCard, plant_type, 1, 0)


## 等玩家种下 count 株植物（plant_type 留 Null = 任意植物）
func wait_plant(count: int = 1,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	await _await_condition(ResourceTutorialStep.E_FinishType.PlantCount, plant_type, count, 0)


## 等玩家收集任意一颗阳光
func wait_collect_sun() -> void:
	await _await_condition(ResourceTutorialStep.E_FinishType.CollectSun,
		CharacterRegistry.PlantType.Null, 1, 0)


## 限时等玩家种下 count 株植物：时限内种下返回 true，**等到点还没动手返回 false**
##
## 关卡流程拿这个返回值决定要不要补一句教学 —— 原版 1-1 说完「阳光够了」是直接等的，
## 只有玩家自己不动手的那 4 秒过去了，才补那句「点击豌豆射手，再种一棵！」。
func wait_plant_timeout(count: int = 1,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null,
		timeout: float = 4.0) -> bool:
	if not is_running:
		return false
	var step := _begin_condition_step(ResourceTutorialStep.E_FinishType.PlantCount,
		plant_type, count, 0)
	## 种植次数只在 _on_plant_create 里累加（PlantCount 不在 _is_step_condition_satisfied
	## 的查询表里），所以这里轮询这个计数判「有没有种下」
	var waited := 0.0
	## SceneTree 不会随主游戏一起没了，先取出来：等待期间主游戏被释放时
	## 再访问 `main_game.get_tree()` 就是访问已释放对象
	var tree := main_game.get_tree()
	while waited < timeout:
		await tree.create_timer(WAIT_POLL_STEP).timeout
		## 等待期间关卡可能已经结束 / 教程被叫停
		if not is_running or not is_instance_valid(main_game):
			_end_condition_step(step)
			return false
		waited += WAIT_POLL_STEP
		if _plant_done_num >= maxi(1, count):
			_end_condition_step(step)
			return true
	_end_condition_step(step)
	return false


## 开始一次等待：造一个只用于完成条件判定的步骤挂到 _curr_step 上
func _begin_condition_step(finish_type: ResourceTutorialStep.E_FinishType,
		plant_type: CharacterRegistry.PlantType, count: int, sun_value: int) -> ResourceTutorialStep:
	var step := ResourceTutorialStep.new()
	step.finish_type = finish_type
	step.plant_type = plant_type
	step.plant_count = count
	step.sun_value = sun_value
	## 箭头在这次等待期间照旧跟着上一次 point_to() 给的目标
	step.pointer_target = _stepped_pointer_target
	_curr_step = step
	_plant_done_num = 0
	_plant_free_num = 0
	return step


## 收掉一次等待：换回占位步骤，别让 _process 的按帧判定继续对着它反复发射「完成」
func _end_condition_step(step: ResourceTutorialStep) -> void:
	if step != null:
		step.finish_type = ResourceTutorialStep.E_FinishType.None
	if _curr_step == step:
		_curr_step = _idle_step


## 等阳光数攒到 sun_value（进入时已经够了就立刻往下走，见 _is_step_condition_satisfied）
func wait_sun_at_least(sun_value: int) -> void:
	await _await_condition(ResourceTutorialStep.E_FinishType.SunValueAtLeast,
		CharacterRegistry.PlantType.Null, 1, sun_value)


## 等一个完成条件：临时造一个 step 交给自驱模式那套判定
## （完成条件的推导表见 ResourceTutorialStep.E_FinishType）
func _await_condition(finish_type: ResourceTutorialStep.E_FinishType,
		plant_type: CharacterRegistry.PlantType, count: int, sun_value: int) -> void:
	if not is_running:
		return
	var step := _begin_condition_step(finish_type, plant_type, count, sun_value)
	if _is_step_condition_satisfied():
		_end_condition_step(step)
		return
	await _signal_step_finished
	_end_condition_step(step)


## 提示条还在不在（游戏结束这类情况会把它连带清掉），不在就重建一个
func _ensure_stepped_ui() -> bool:
	if not is_running or main_game == null:
		return false
	if is_instance_valid(_advice_ui):
		return true
	_create_advice_ui()
	return is_instance_valid(_advice_ui)
#endregion
