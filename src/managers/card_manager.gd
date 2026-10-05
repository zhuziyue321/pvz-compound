extends MainGameSubManager
class_name CardManager

@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
@onready var card_slot_container: PanelContainer = %CardSlotContainer
@onready var canvas_layer_card_slot_front: CanvasLayer = %CanvasLayerCardSlotFront

## 普通卡槽
var card_slot_norm: CardSlotNorm
var card_slot_battle:CardSlotBattle
## 普通卡槽是否已出现
var is_norm_appeared:=false

## 传送带卡槽
var card_slot_conveyor_belt: CardSlotConveyorBelt
## 传送带是否已启动（教程关会晚一步启动，避免重复启动）
var is_conveyor_belt_started := false

var card_mode:ConstLevelData.E_CardMode

## 当前临时卡片
var curr_temp_cards:Array[Card]
## 当前手持的临时卡片
var curr_temp_card_in_hm:Card
## 手持物：卡片从手上放回卡槽（临时卡片等待该信号）
signal signal_hand_card_release(card:Card)

func _ready():
	EventBus.subscribe("hand_card_release", _on_hand_card_release)
	EventBus.subscribe("hand_card_take", _on_hand_card_take)

## 当手持物拿到新卡片时
func _on_hand_card_take(curr_card:Card):
	curr_temp_card_in_hm = curr_card
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_stop()

## 当手持物清除当前手持卡片数据时
func _on_hand_card_release(curr_card:Card):
	## 卡片已经离手，清掉记录：不清的话 clear_all_temp_cards() 会一直把它当「手上的卡」跳过
	if curr_temp_card_in_hm == curr_card:
		curr_temp_card_in_hm = null
	signal_hand_card_release.emit(curr_card)
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_start()

func init_manager() -> void:
	self.card_mode = game_para.card_mode
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			card_slot_norm = load("res://src/ui/card/card_slot/card_slot_norm.tscn").instantiate()
			card_slot_root.add_child(card_slot_norm)
			card_slot_norm.init_card_slot_norm(game_para)
			card_slot_battle = card_slot_norm.card_slot_battle
			card_slot_root.curr_cards = card_slot_battle.curr_cards

		ConstLevelData.E_CardMode.ConveyorBelt:
			card_slot_conveyor_belt = load("res://src/ui/card/card_slot/card_slot_conveyor_belt.tscn").instantiate()
			card_slot_root.add_child(card_slot_conveyor_belt)
			card_slot_conveyor_belt.init_card_slot_conveyor_belt(game_para)
			card_slot_root.curr_cards = card_slot_conveyor_belt.curr_cards

## 出战卡槽补一格:夜晚关卡开场戴夫卖出卡槽扩充后,本关的卡槽数要当场 +1
## (戴夫对话发生在 init_manager() 之后,出战卡槽占位已经按旧卡槽数建好了)
func add_one_battle_card_placeholder() -> void:
	match card_mode:
		ConstLevelData.E_CardMode.Norm:
			if card_slot_norm != null:
				card_slot_norm.card_slot_battle.add_one_card_placeholder()
		_:
			pass

## 开始下一轮游戏更新卡片管理器
func start_next_game_card_manager_update():
	## 铲子（手持物）界面由 HandManager 依据主游戏阶段统一刷新，这里不再直接改显隐
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			card_slot_battle.reparent(card_slot_norm)
			card_slot_battle.start_next_game_card_slot_battle_update()

		ConstLevelData.E_CardMode.ConveyorBelt:
			pass
	## 罐子模式没有出战卡槽，卡片全是罐子里开出来的临时卡片：
	## 切换批次时上一批没用完的卡片一起清掉（原版冒险 4-5 每批重新开始）
	if game_para.is_pot_mode:
		clear_all_temp_cards()


## 卡槽出现(选卡)
func card_slot_appear_choose():
	is_norm_appeared = true
	card_slot_norm.move_card_slot_battle(true)
	card_slot_norm.move_card_slot_candidate(true)

## 卡槽出现（主游戏阶段开始）
func card_slot_update_main_game():
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			if not is_norm_appeared:
				await card_slot_norm.move_card_slot_battle(true)
			#card_slot_norm.remove_child(card_slot_battle)
			#card_slot_container.add_child(card_slot_battle)
			card_slot_battle.reparent(card_slot_container)
			card_slot_battle.main_game_refresh_card()
			## 测试模式卡片没有冷却
			if Global.main_game.is_test:
				for card in card_slot_battle.curr_cards:
					card.card_change_cool_time(0)

		ConstLevelData.E_CardMode.ConveyorBelt:
			## 教程关（1-5 铲子教学）：传送带等玩家铲完预置植物后由 TutorialManager 启动
			if _is_conveyor_start_by_tutorial():
				Log.debug("本关有新手教程，传送带交给教程管理器启动")
			else:
				await start_conveyor_belt()
	## 铲子（手持物）界面由 HandManager 依据关卡参数与主游戏阶段统一刷新

## 待选卡槽卡槽消失
## 传送带这类关卡没有普通卡槽(card_slot_norm 为 null),
## 选卡阶段被跳过后(见 ResourceLevelData.is_no_choose_permission)这里要能空转,
## 否则「选卡」事件会在这里报错,关卡再也走不到开战
func card_slot_disappear_choose():
	if card_slot_norm == null:
		return
	await card_slot_norm.move_card_slot_candidate(false)


## 传送带是否由教程接管启动：本关创建了教程管理器（1-5 铲子教学）
## 判定用「有没有教程管理器、教程跑完没有」而不是「教程是否在跑」——
## 卡槽刷新发生在 start_tutorial() 之前；开场教程（1-5）在关卡开局之前就跑完了，
## 此时传送带该由关卡通流程启动，不能再等教程
func _is_conveyor_start_by_tutorial() -> bool:
	## main_game 由基类 MainGameSubManager 在 _enter_tree 中解析，此处直接使用，不要重复声明同名局部变量
	if not is_instance_valid(main_game) or main_game.tutorial_manager == null:
		return false
	return not main_game.tutorial_manager.is_finished


## 传送带出现并开始运转（教程关由 TutorialManager 在铲完预置植物后调用，可重复调用）
func start_conveyor_belt() -> void:
	if card_slot_conveyor_belt == null or is_conveyor_belt_started:
		return
	is_conveyor_belt_started = true
	await card_slot_conveyor_belt.move_card_slot_conveyor_belt(true)
	card_slot_conveyor_belt.reparent(card_slot_container)
	card_slot_conveyor_belt.start_conveyor_belt()

#region 临时卡片
enum E_TempCardParaAttr{
	PlantType,
	ZombieType,
	GlobalPos,
	ExistTime,	## 存在时间，若没有，则永久存在
}

## 通用接口：往卡片前景层挂一个节点（临时卡片就挂在这一层）
## **只做挂载，不含任何玩法判断** —— 挂什么、什么时候挂、什么时候起停由关卡脚本自己决定
## （一关专属的发卡器不该进通用管理器，见 docs/项目规范.md §1-8）
func add_card_front_node(node:Node) -> void:
	canvas_layer_card_slot_front.add_child(node)

## 创建临时卡片
func create_temp_card(temp_card_para:Dictionary) -> Card:
	var new_card_prefabs:Card
	if temp_card_para.has(E_TempCardParaAttr.PlantType) and temp_card_para[E_TempCardParaAttr.PlantType] != CharacterRegistry.PlantType.Null:
		new_card_prefabs = AllCards.all_plant_card_prefabs[temp_card_para[E_TempCardParaAttr.PlantType]]
	elif temp_card_para.has(E_TempCardParaAttr.ZombieType) and temp_card_para[E_TempCardParaAttr.ZombieType] !=  CharacterRegistry.ZombieType.Null:
		new_card_prefabs = AllCards.all_zombie_card_prefabs[temp_card_para[E_TempCardParaAttr.ZombieType]]
	else:
		Log.warn("error: 没有卡片类型")
		return
	var temp_card = new_card_prefabs.duplicate()
	curr_temp_cards.append(temp_card)
	canvas_layer_card_slot_front.add_child(temp_card)
	temp_card.global_position = temp_card_para.get(E_TempCardParaAttr.GlobalPos, Vector2(100, 100))
	temp_card.signal_card_use_end.connect(card_use_end.bind(temp_card))

	if temp_card_para.has(E_TempCardParaAttr.ExistTime):
		temp_card_add_exist_timer(temp_card, temp_card_para[E_TempCardParaAttr.ExistTime])

	return temp_card

func temp_card_add_exist_timer(temp_card:Card, temp_card_exist_time:float):
	var temp_card_timer:Timer = Timer.new()
	temp_card_timer.autostart = false
	temp_card_timer.one_shot = true
	temp_card_timer.timeout.connect(_on_temp_card_timer_timeout.bind(temp_card))
	temp_card.add_child(temp_card_timer)
	temp_card_timer.start(temp_card_exist_time)

func _on_temp_card_timer_timeout(temp_card:Card):
	temp_card.card_blink_start()
	## 五秒闪烁后消失
	await get_tree().create_timer(5.0, false).timeout
	if curr_temp_card_in_hm == temp_card:
		await signal_hand_card_release
	## 如果还未被使用
	if is_instance_valid(temp_card):
		card_use_end(temp_card)

func card_use_end(card:Card):
	if not card.is_queued_for_deletion():
		curr_temp_cards.erase(card)
		card.queue_free()

## 清除所有临时卡片（砸罐子关切换批次时用：上一批开出来的卡片不带到下一批）
## 切换批次前主游戏进度已经离开 MAIN_GAME，手持物会先 drop_hand() 把手上的卡放掉，
## （hand_card_release 事件里 curr_temp_card_in_hm 会清空），这里才能整批清掉
func clear_all_temp_cards():
	for temp_card in curr_temp_cards.duplicate():
		card_use_end(temp_card)

#endregion

#region 存档
func get_save_game_data_card_manager()->Dictionary:
	var save_game_data_card_manager:Dictionary = {}
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			save_game_data_card_manager["curr_sun_value"] = card_slot_battle.sun_value
	return save_game_data_card_manager

func load_game_data_card_manager(save_game_data_card_manager:Dictionary):
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			card_slot_battle.sun_value = int(save_game_data_card_manager.get("curr_sun_value", game_para.start_sun))

#endregion
