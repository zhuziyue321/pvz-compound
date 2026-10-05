extends MainGameSubManager
class_name BeghouledManager
## 僵尸迷阵（Beghouled）三消玩法管理器
##
## 原版迷你游戏第 5 关（夜间前院）：草坪开局已铺满植物，玩家**交换相邻两株**凑成
## 三个及以上同类连线即可消除，消除给阳光；累计 75 次配对通关。
## 规则来源见 ConstBeghouled 文件头（Plants vs Zombies Wiki）。
##
## 与常规玩法的关系：
##   · 棋盘 = 植物格子去掉最右一列（原版：僵尸入场那一列留空），见 ConstBeghouled.EMPTY_COL_NUM_ON_RIGHT
##   · 一株植物 = 一个格子上的普通植物实例，交换 / 下落复用 PlantCell 的手套搬运 API
##     （glove_take_plant / glove_put_plant：不销毁实例，血量等状态跟着走）
##   · 植物被僵尸啃掉 → 本管理器在格子上留一个**永久弹坑**（原版口径：不花阳光填就一直在）
##   · 通关不走「打完最后一波」：达标后自己推 create_trophy（见 _win）
##
## 谁在用它：**只有 minigame_05_beghouled 一关**（硬约束 §1-8：一关专属机制不进游戏本体）。
## 创建时机：关卡脚本 minigame_05_beghouled.gd 自己 ——
##   init_level_items() 里往 MainGameManager 注册一条初始化回调（通用口子，本体不认识玩法名），
##   MainGameManager 跑完所有子管理器 init_manager() 之后回调它，本管理器这才 new() 出来。
## 本体不再常驻本管理器，关卡数据上也没有「是不是三消关」这种开关字段。

## 本关三消已达标（关卡脚本 await 它即可把流程停在「等玩家凑够配对」上）
signal signal_beghouled_win

## 交换后到「判定是否成组」之间的停顿（秒）：让玩家看清植物换了个位置
const SWAP_WAIT := 0.18
## 消除到下落之间的停顿（秒）
const REMOVE_WAIT := 0.22
## 下落到下一次判定之间的停顿（秒）
const REFILL_WAIT := 0.18

## 玩法是否已接管本关
var is_running := false
## 正在跑「交换 → 消除 → 下落 → 再判定」这一段：期间不接受玩家点击
var is_resolving := false
## 正在替换植物（买了升级之后的换场）：同理，期间棋盘上一批格子是空的，必须一起挡住
var _is_replacing := false
## 已完成的配对次数（一次消除的一组连线记 1 次）
var match_num := 0
## 当前选中的格子（玩家第一次点的那株植物）
var selected_cell: PlantCell = null
## 三消棋盘的行数 / 列数
var board_row_num := 0
var board_col_num := 0

## 新植物的随机池（买了升级后池里的植物跟着换，见 try_buy_upgrade）
var plant_pool: RandomPicker
## 三档升级是否已购买
var purchased_upgrades: Array[bool] = []
## 本管理器自己正在移除植物：区分「被三消消除」与「被僵尸啃掉」（后者要留弹坑）
var _self_removing := false

var ui: BeghouledUI = null
## 选中格子的高亮框（挂在格子下，跟着格子走）
var _highlight: ColorRect = null


#region 生命周期与初始化

## 本管理器只在关卡脚本要它的时候才被创建（见文件头「创建时机」），
## 所以这里不再判任何玩法开关：能进来就说明本关就是三消关
func init_manager() -> void:
	var pcm := main_game.plant_cell_manager
	if pcm == null or pcm.row_col.x <= 0:
		Log.error("僵尸迷阵：植物格子还没生成，玩法无法启动")
		return
	board_row_num = pcm.row_col.x
	board_col_num = maxi(1, pcm.row_col.y - ConstBeghouled.EMPTY_COL_NUM_ON_RIGHT)
	_init_plant_pool()
	_connect_board_cells()
	_create_ui()
	## 原版本关没有波次（无限波，见 ConstBeghouled 来源注释），波次进度条不显示
	_hide_wave_progress_bar()
	## 阳光一变就要重算按钮的可用状态（钱够不够买升级 / 填坑）
	EventBus.subscribe("add_sun_value", func(_sun_value): _refresh_ui())
	is_running = true
	Log.debug("僵尸迷阵：棋盘 %d 行 × %d 列" % [board_row_num, board_col_num])


## 摆场：清空棋盘后重新铺满植物
## 由关卡流程在开战前调用（晚于读档，所以无论有没有存档都是一局新局面）
func setup_board() -> void:
	if not is_running:
		return
	_clear_board()
	await _fill_new_board()
	if ui != null:
		ui.visible = true
	_refresh_ui()


## 开战并等到达标：关卡脚本 `await beghouled.start_beghouled(出怪表)`（beghouled 是脚本自己持有的实例）
## 不走时间轴的「开战」事件：本关的结束条件是配对次数，不是「最后一波刷完 + 僵尸清空」
func start_beghouled(zombie_refresh_types: Array[CharacterRegistry.ZombieType] = []) -> void:
	if not is_running:
		return
	if not zombie_refresh_types.is_empty():
		main_game.apply_level_zombie_refresh_types(zombie_refresh_types)
	main_game.main_game_start()
	await signal_beghouled_win


## 随机池：开局是六种基础植物，买了升级就把池里的旧植物换成升级后的
func _init_plant_pool() -> void:
	plant_pool = RandomPicker.new()
	for plant_type in ConstBeghouled.BASE_PLANT_TYPES:
		plant_pool.add_item(plant_type, 1.0)
	purchased_upgrades.clear()
	for _info in ConstBeghouled.UPGRADE_LIST:
		purchased_upgrades.append(false)


## 棋盘格子的点击与植物死亡都收到这里
func _connect_board_cells() -> void:
	for row in range(board_row_num):
		for col in range(board_col_num):
			var cell := get_cell(row, col)
			cell.click_cell.connect(_on_click_cell)
			cell.signal_plant_free.connect(_on_plant_free)


func _create_ui() -> void:
	ui = BeghouledUI.new()
	ui.name = "BeghouledUI"
	ui.bind_manager(self)
	main_game.canvas_layer_ui.add_child(ui)
	ui.visible = false


## 本关是无限波（原版僵尸迷阵没有旗帜，见 wiki「unlimited number of flags」），波次进度条不显示
func _hide_wave_progress_bar() -> void:
	if main_game.zombie_manager == null:
		return
	var wave_manager = main_game.zombie_manager.zombie_wave_manager
	if wave_manager == null or wave_manager.flag_progress_bar == null:
		return
	wave_manager.flag_progress_bar.visible = false
#endregion


#region 棋盘查询

## 取棋盘格子（row 从上往下、col 从左往右，与 PlantCell.row_col 同源）
func get_cell(row: int, col: int) -> PlantCell:
	return main_game.plant_cell_manager.all_plant_cells[row][col]


func is_board_cell(cell: PlantCell) -> bool:
	if cell == null:
		return false
	return cell.row_col.x < board_row_num and cell.row_col.y < board_col_num


## 格子上的植物（任意槽位上的第一株）
func get_cell_plant(cell: PlantCell) -> Plant000Base:
	if cell == null:
		return null
	for place in cell.plant_in_cell:
		var plant := cell.get_plant(place)
		if plant != null:
			return plant
	return null


## 格子当前的植物类型：弹坑 / 空格都算「没有」（不参与连线）
func get_cell_type(cell: PlantCell) -> CharacterRegistry.PlantType:
	if is_crater(cell):
		return CharacterRegistry.PlantType.Null
	var plant := get_cell_plant(cell)
	if plant == null:
		return CharacterRegistry.PlantType.Null
	return plant.plant_type


func is_crater(cell: PlantCell) -> bool:
	return cell != null and is_instance_valid(cell.crater)


## 把棋盘当前的植物类型抄成一份二维数组（模拟交换 / 找连线都在它上面做，不动场上实例）
func _build_type_grid() -> Array[Array]:
	var grid: Array[Array] = []
	for row in range(board_row_num):
		var line: Array[CharacterRegistry.PlantType] = []
		for col in range(board_col_num):
			line.append(get_cell_type(get_cell(row, col)))
		grid.append(line)
	return grid


## 当前棋盘上有弹坑的格子（填坑按钮用）
func get_crater_cells() -> Array[PlantCell]:
	var cells: Array[PlantCell] = []
	for row in range(board_row_num):
		for col in range(board_col_num):
			var cell := get_cell(row, col)
			if is_crater(cell):
				cells.append(cell)
	return cells
#endregion


#region 玩家操作：选中与交换

func _on_click_cell(cell: PlantCell) -> void:
	if not _can_operate():
		return
	if not is_board_cell(cell):
		return
	if get_cell_plant(cell) == null:
		return
	if selected_cell == null:
		_select_cell(cell)
		return
	if selected_cell == cell:
		_clear_select()
		return
	if _is_adjacent(selected_cell, cell):
		await _try_swap(selected_cell, cell)
		return
	## 不相邻：改成选中新点的那一株（原版同口径：拖到哪儿就选哪儿）
	_select_cell(cell)


## 两个格子是否上下左右相邻
func _is_adjacent(cell_a: PlantCell, cell_b: PlantCell) -> bool:
	var d := cell_a.row_col - cell_b.row_col
	return absi(d.x) + absi(d.y) == 1


## 交换两格里的植物；凑不成连线就换回去（原版：会听到一声「不行」的音效）
func _try_swap(cell_a: PlantCell, cell_b: PlantCell) -> void:
	is_resolving = true
	_clear_select()
	_swap_plants(cell_a, cell_b)
	await _wait(SWAP_WAIT)
	if _find_match_groups(_build_type_grid()).is_empty():
		_swap_plants(cell_a, cell_b)
		await _wait(SWAP_WAIT)
		is_resolving = false
		Log.debug("僵尸迷阵：交换没有凑成连线，已换回")
		return
	await _resolve_board()


## 两株植物互换格子：用搬运 API，植物实例与状态（血量 / 冷却）都跟着走
func _swap_plants(cell_a: PlantCell, cell_b: PlantCell) -> void:
	var plant_a := get_cell_plant(cell_a)
	var plant_b := get_cell_plant(cell_b)
	if plant_a == null or plant_b == null:
		return
	var place_a_in_b := cell_b.glove_get_put_place(plant_a)
	var place_b_in_a := cell_a.glove_get_put_place(plant_b)
	cell_a.glove_take_plant(plant_a)
	cell_b.glove_take_plant(plant_b)
	cell_b.glove_put_plant(plant_a, place_a_in_b)
	cell_a.glove_put_plant(plant_b, place_b_in_a)


func _select_cell(cell: PlantCell) -> void:
	selected_cell = cell
	_show_highlight(cell)


func _clear_select() -> void:
	selected_cell = null
	_hide_highlight()


func _show_highlight(cell: PlantCell) -> void:
	if _highlight == null:
		_highlight = ColorRect.new()
		_highlight.color = Color(1.0, 1.0, 0.4, 0.35)
		_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _highlight.get_parent() != cell:
		if _highlight.get_parent() != null:
			_highlight.get_parent().remove_child(_highlight)
		cell.add_child(_highlight)
		_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight.visible = true


func _hide_highlight() -> void:
	if _highlight != null:
		_highlight.visible = false
#endregion


#region 连线判定、消除、下落

## 找出棋盘上所有「三个及以上同类连成一线」的组；每组是一串格子坐标
func _find_match_groups(grid: Array[Array]) -> Array[Array]:
	var groups: Array[Array] = []
	if grid.is_empty():
		return groups
	var col_num: int = grid[0].size()
	## 横向
	for row in range(grid.size()):
		var col := 0
		while col < col_num:
			var plant_type: CharacterRegistry.PlantType = grid[row][col]
			if plant_type == CharacterRegistry.PlantType.Null:
				col += 1
				continue
			var end_col := col + 1
			while end_col < col_num and grid[row][end_col] == plant_type:
				end_col += 1
			if end_col - col >= 3:
				## (起点行, 起点列, 长度, 步长)：横向步长 0 —— 行不动、列往后数
				groups.append(_make_coord_list(row, col, end_col - col, 0))
			col = end_col
	## 纵向
	for col in range(col_num):
		var row := 0
		while row < grid.size():
			var type_v: CharacterRegistry.PlantType = grid[row][col]
			if type_v == CharacterRegistry.PlantType.Null:
				row += 1
				continue
			var end_row := row + 1
			while end_row < grid.size() and grid[end_row][col] == type_v:
				end_row += 1
			if end_row - row >= 3:
				groups.append(_make_coord_list(row, col, end_row - row, 1))
			row = end_row
	return groups


## 把一条连线摊成坐标数组（横着 / 竖着）
func _make_coord_list(start_row: int, start_col: int, length: int, step: int) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for i in range(length):
		list.append(Vector2i(start_row + i * step, start_col + i * (1 - step)))
	return list


## 消除 → 给阳光 → 下落补充 → 再判定，直到棋盘上没有连线（连锁一路消到底）
func _resolve_board() -> void:
	is_resolving = true
	while true:
		var groups := _find_match_groups(_build_type_grid())
		if groups.is_empty():
			break
		var sun_sum := 0
		var to_remove: Array[Vector2i] = []
		for group in groups:
			sun_sum += ConstBeghouled.get_sun_by_chain_len(group.size())
			for coord in group:
				if not to_remove.has(coord):
					to_remove.append(coord)
		match_num += groups.size()
		_remove_cells(to_remove)
		_give_sun(sun_sum)
		_refresh_ui()
		Log.debug("僵尸迷阵：消除 %d 组（阳光 +%d），累计 %d/%d 次配对" % [
			groups.size(), sun_sum, match_num, ConstBeghouled.TARGET_MATCH_NUM
		])
		if match_num >= ConstBeghouled.TARGET_MATCH_NUM:
			break
		await _wait(REMOVE_WAIT)
		_collapse_all()
		await _wait(REFILL_WAIT)
	is_resolving = false
	if match_num >= ConstBeghouled.TARGET_MATCH_NUM:
		_win()
		return
	## 没有可走的步了：原版会免费把整盘植物刷新一遍（见 ConstBeghouled 来源注释）
	_ensure_board_playable()
	_refresh_ui()


## 消掉一批格子上的植物
func _remove_cells(coords: Array[Vector2i]) -> void:
	_self_removing = true
	for coord in coords:
		var plant := get_cell_plant(get_cell(coord.x, coord.y))
		if plant != null:
			plant.character_death_disappear()
	_self_removing = false


## 下落：同一列里上方的植物往下补空位，顶部空出来的格子长出新植物
## 弹坑留在原地不动，且会挡住上方植物的下落（坑就是地面上的洞，跨不过去）
func _collapse_all() -> void:
	for col in range(board_col_num):
		var write_row := board_row_num - 1
		for row in range(board_row_num - 1, -1, -1):
			var cell := get_cell(row, col)
			if is_crater(cell):
				write_row = row - 1
				continue
			if get_cell_plant(cell) == null:
				continue
			if write_row != row:
				_move_plant(cell, get_cell(write_row, col))
			write_row -= 1
		## 顶部补新植物
		for row in range(write_row, -1, -1):
			var top_cell := get_cell(row, col)
			if is_crater(top_cell):
				continue
			top_cell.create_plant(_random_plant_type(), false, false, false, false)


## 把一株植物从一个格子挪到另一个空格子
func _move_plant(from_cell: PlantCell, to_cell: PlantCell) -> void:
	var plant := get_cell_plant(from_cell)
	if plant == null:
		return
	var place := to_cell.glove_get_put_place(plant)
	from_cell.glove_take_plant(plant)
	to_cell.glove_put_plant(plant, place)
#endregion


#region 摆场与重置

func _clear_board() -> void:
	_clear_select()
	_self_removing = true
	for row in range(board_row_num):
		for col in range(board_col_num):
			var cell := get_cell(row, col)
			cell.clear_data_plant_cell()
			if is_crater(cell):
				cell.remove_crater()
	_self_removing = false


## 铺一盘新植物：逐格挑「不会立刻凑成连线」的种类，铺完还要保证有步可走
## （原版开局盘面上就没有现成的连线，也不该一上来就死局）
func _fill_new_board() -> void:
	var guard := 0
	while guard < 30:
		guard += 1
		_clear_board_only_plants()
		## 等槽位真正空出来：queue_free 与死亡回调都在这两帧里跑完
		## （同一套写法见 PlantCellManager.start_next_game_plant_cell_manager_update）
		await get_tree().process_frame
		await get_tree().process_frame
		for row in range(board_row_num):
			for col in range(board_col_num):
				var cell := get_cell(row, col)
				cell.create_plant(_pick_type_without_match(row, col), false, false, false, false)
		if _has_possible_move():
			return
	Log.warn("僵尸迷阵：连续 30 次没能摆出「有解」的开局，沿用最后一盘")


## 只清植物（不动弹坑）：铺新盘重试时用
func _clear_board_only_plants() -> void:
	_self_removing = true
	for row in range(board_row_num):
		for col in range(board_col_num):
			get_cell(row, col).clear_data_plant_cell()
	_self_removing = false


## 挑一个不会与左边两个 / 上方两个凑成连线的种类（保证铺完就没有现成的连线）
func _pick_type_without_match(row: int, col: int) -> CharacterRegistry.PlantType:
	var candidates: Array[CharacterRegistry.PlantType] = []
	for plant_type in ConstBeghouled.BASE_PLANT_TYPES:
		if _is_type_in_pool(plant_type):
			candidates.append(plant_type)
	candidates.shuffle()
	for candidate in candidates:
		if col >= 2 \
				and get_cell_type(get_cell(row, col - 1)) == candidate \
				and get_cell_type(get_cell(row, col - 2)) == candidate:
			continue
		if row >= 2 \
				and get_cell_type(get_cell(row - 1, col)) == candidate \
				and get_cell_type(get_cell(row - 2, col)) == candidate:
			continue
		return candidate
	return candidates[0] if not candidates.is_empty() else (ConstBeghouled.BASE_PLANT_TYPES[0] as CharacterRegistry.PlantType)


func _is_type_in_pool(plant_type: CharacterRegistry.PlantType) -> bool:
	return plant_pool != null and plant_pool.get_item_weight(plant_type) > 0


func _random_plant_type() -> CharacterRegistry.PlantType:
	if plant_pool == null:
		return ConstBeghouled.BASE_PLANT_TYPES[0] as CharacterRegistry.PlantType
	var picked = plant_pool.get_random_item()
	if picked == null:
		return ConstBeghouled.BASE_PLANT_TYPES[0] as CharacterRegistry.PlantType
	return picked as CharacterRegistry.PlantType


## 保证棋盘「没有现成的连线 + 至少还有一步可走」：不满足就免费把整盘重排一遍
## 三处同一个口径：开局摆场后、每次结算收尾、买完升级换场后（原版：没步可走会免费重排）
func _ensure_board_playable() -> void:
	var grid := _build_type_grid()
	if _find_match_groups(grid).is_empty() and _has_possible_move():
		return
	Log.debug("僵尸迷阵：盘面没有可以走的步了，自动重置")
	_shuffle_plants()


## 整盘重排：把场上的植物实例打乱后重新放回格子（不销毁，血量等状态跟着走）
func _shuffle_plants() -> void:
	var cells: Array[PlantCell] = []
	var plants: Array[Plant000Base] = []
	for row in range(board_row_num):
		for col in range(board_col_num):
			var cell := get_cell(row, col)
			if is_crater(cell):
				continue
			cells.append(cell)
			var plant := get_cell_plant(cell)
			if plant != null:
				plants.append(plant)
	if plants.size() < 2:
		return
	var guard := 0
	while guard < 40:
		guard += 1
		plants.shuffle()
		for plant in plants:
			var from_cell: PlantCell = plant.plant_cell
			if from_cell != null:
				from_cell.glove_take_plant(plant)
		for i in range(plants.size()):
			var target: PlantCell = cells[i]
			target.glove_put_plant(plants[i], target.glove_get_put_place(plants[i]))
		if _find_match_groups(_build_type_grid()).is_empty() and _has_possible_move():
			return
#endregion


#region 还有没有可走的步

## 是否存在「交换一次就能凑成连线」的走法（在类型副本上模拟，不动场上实例）
func _has_possible_move() -> bool:
	var grid := _build_type_grid()
	## 只试右邻与下邻（左 / 上邻会被反过来试到，试两次就够了）
	var neighbor_offsets: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	for row in range(board_row_num):
		for col in range(board_col_num):
			var plant_type: CharacterRegistry.PlantType = grid[row][col]
			if plant_type == CharacterRegistry.PlantType.Null:
				continue
			for offset in neighbor_offsets:
				var row2 := row + offset.x
				var col2 := col + offset.y
				if row2 >= board_row_num or col2 >= board_col_num:
					continue
				var other: CharacterRegistry.PlantType = grid[row2][col2]
				if other == CharacterRegistry.PlantType.Null or other == plant_type:
					continue
				grid[row][col] = other
				grid[row2][col2] = plant_type
				var matched := _has_match_at(grid, row, col) or _has_match_at(grid, row2, col2)
				grid[row][col] = plant_type
				grid[row2][col2] = other
				if matched:
					return true
	return false


## grid 里 (row,col) 这个位置是否处在一条「三个及以上」的连线上
func _has_match_at(grid: Array[Array], row: int, col: int) -> bool:
	var plant_type: CharacterRegistry.PlantType = grid[row][col]
	if plant_type == CharacterRegistry.PlantType.Null:
		return false
	var length := 1
	var c := col - 1
	while c >= 0 and grid[row][c] == plant_type:
		length += 1
		c -= 1
	c = col + 1
	while c < grid[row].size() and grid[row][c] == plant_type:
		length += 1
		c += 1
	if length >= 3:
		return true
	length = 1
	var r := row - 1
	while r >= 0 and grid[r][col] == plant_type:
		length += 1
		r -= 1
	r = row + 1
	while r < grid.size() and grid[r][col] == plant_type:
		length += 1
		r += 1
	return length >= 3
#endregion


#region 阳光与商店

func get_sun() -> int:
	if main_game.card_manager == null or main_game.card_manager.card_slot_battle == null:
		return 0
	return main_game.card_manager.card_slot_battle.sun_value


## 三消的阳光直接进账（不走「掉一颗阳光让玩家点」）：原版也是配对完立刻进计数器
func _give_sun(sun_value: int) -> void:
	if sun_value <= 0:
		return
	EventBus.push_event("add_sun_value", [sun_value])


func _cost_sun(sun_value: int) -> void:
	if main_game.card_manager == null or main_game.card_manager.card_slot_battle == null:
		return
	main_game.card_manager.card_slot_battle.sun_value -= sun_value


## 买一档升级：把场上所有 from 换成 to，后续长出来的新植物也换成 to
##
## 换场这一下会把棋盘上的格子腾空两帧（见 _replace_all_plants），期间一律不让玩家动手
## （_can_operate 会挡住点击 / 洗牌 / 填坑 / 再买），换完还要保证盘面还能玩
func try_buy_upgrade(index: int) -> bool:
	if not _can_operate():
		return false
	if index < 0 or index >= ConstBeghouled.UPGRADE_LIST.size():
		return false
	if purchased_upgrades[index]:
		return false
	var info: Dictionary = ConstBeghouled.UPGRADE_LIST[index]
	var price: int = info["sun"]
	if get_sun() < price:
		return false
	_cost_sun(price)
	purchased_upgrades[index] = true
	## 换植物在它自己的协程里跑完（要等两帧），按钮这里立刻拿到「买成了」的结果
	_replace_all_plants(info["from"], info["to"])
	## 随机池同步换掉：之后补位长出来的也是升级后的植物
	plant_pool.remove_item(info["from"])
	if not plant_pool.has_item(info["to"]):
		plant_pool.add_item(info["to"], 1.0)
	_refresh_ui()
	Log.debug("僵尸迷阵：已购买升级 %s" % str(info["name"]))
	return true


## 把场上所有 from 植物换成 to（换的是实例：先移除旧的，等槽位空出来再种新的）
func _replace_all_plants(from_type: CharacterRegistry.PlantType, to_type: CharacterRegistry.PlantType) -> void:
	var targets: Array[PlantCell] = []
	for row in range(board_row_num):
		for col in range(board_col_num):
			var cell := get_cell(row, col)
			if get_cell_type(cell) == from_type:
				targets.append(cell)
	if targets.is_empty():
		return
	_is_replacing = true
	_clear_select()
	_self_removing = true
	for cell in targets:
		var plant := get_cell_plant(cell)
		if plant != null:
			plant.character_death_disappear()
	## 等槽位真正空出来（queue_free 与死亡回调都在这两帧里跑完，见 PlantCellManager 的清场写法）
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		_self_removing = false
		_is_replacing = false
		return
	for cell in targets:
		cell.create_plant(to_type, false, false, false, false)
	## 「这是自己拿走的」要等换场彻底结束再解开：死亡回调万一延后一帧落到中间，
	## 会被当成「被僵尸啃掉」，原地留下一个不该有的弹坑
	_self_removing = false
	_is_replacing = false
	## 换完有可能摆出「没步可走」的死局（原先那些可用的步里可能有一半是靠 from 撑着的）：
	## 照 _resolve_board 收尾的口径免费重排一遍，不该让玩家为这一下再掏 100 阳光洗牌
	_ensure_board_playable()
	_refresh_ui()
	Log.debug("僵尸迷阵：%d 株植物已换成升级版" % targets.size())


## 手动重置植物（洗牌）
func try_shuffle() -> bool:
	if not _can_operate():
		return false
	if get_sun() < ConstBeghouled.SHUFFLE_SUN:
		return false
	_cost_sun(ConstBeghouled.SHUFFLE_SUN)
	_clear_select()
	_shuffle_plants()
	_refresh_ui()
	return true


## 填补一个弹坑（原版：花 200 阳光填一个，填完那格立刻长出新植物）
func try_fill_crater() -> bool:
	if not _can_operate():
		return false
	var craters := get_crater_cells()
	if craters.is_empty():
		return false
	if get_sun() < ConstBeghouled.CRATER_FILL_SUN:
		return false
	_cost_sun(ConstBeghouled.CRATER_FILL_SUN)
	var cell: PlantCell = craters[0]
	cell.remove_crater()
	cell.create_plant(_random_plant_type(), false, false, false, false)
	_refresh_ui()
	return true
#endregion


#region 弹坑：植物被僵尸啃掉

## 棋盘上的植物没了：不是本管理器消除的，就当作被僵尸啃掉，原地留一个弹坑
func _on_plant_free(cell: PlantCell, _plant_type: CharacterRegistry.PlantType) -> void:
	if not is_running or _self_removing or _is_replacing:
		return
	if not is_board_cell(cell):
		return
	if not _is_playable():
		return
	if is_crater(cell):
		return
	cell.create_crater_permanent()
	Log.debug("僵尸迷阵：%s 的植物被啃掉了，留下弹坑" % str(cell.row_col))
#endregion


#region 通关与界面刷新

func _win() -> void:
	if not is_running:
		return
	is_running = false
	_clear_select()
	if ui != null:
		ui.visible = false
	@warning_ignore("integer_division")
	var center := get_cell(board_row_num / 2, board_col_num / 2)
	EventBus.push_event("create_trophy", center.global_position)
	signal_beghouled_win.emit()


## 刷新界面（显隐由 setup_board / _win 管，这里只刷内容）
func _refresh_ui() -> void:
	if ui == null or not is_running:
		return
	ui.refresh_view(match_num, _build_button_infos())


## 底部按钮的显示状态：钱不够 / 已购买就置灰
func _build_button_infos() -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	var sun := get_sun()
	for i in range(ConstBeghouled.UPGRADE_LIST.size()):
		var info: Dictionary = ConstBeghouled.UPGRADE_LIST[i]
		var price: int = info["sun"]
		if purchased_upgrades[i]:
			infos.append({"text": "%s 已购买" % str(info["name"]), "disabled": true})
		else:
			infos.append({
				"text": "%s %d" % [str(info["name"]), price],
				"disabled": sun < price
			})
	infos.append({
		"text": "重置 %d" % ConstBeghouled.SHUFFLE_SUN,
		"disabled": sun < ConstBeghouled.SHUFFLE_SUN
	})
	infos.append({
		"text": "填坑 %d" % ConstBeghouled.CRATER_FILL_SUN,
		"disabled": sun < ConstBeghouled.CRATER_FILL_SUN or get_crater_cells().is_empty()
	})
	return infos


func _is_playable() -> bool:
	if not is_running:
		return false
	if not is_instance_valid(main_game):
		return false
	return main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


## 玩家能不能动手：连锁结算中 / 升级换场中棋盘正在变，这时插手会把格子搞乱
func _can_operate() -> bool:
	return _is_playable() and not is_resolving and not _is_replacing


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
#endregion
