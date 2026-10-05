extends RefCounted
## 探针：迷你游戏第 5 关「僵尸迷阵」(Beghouled)
## 覆盖：
##   ① 关卡数据：无限波（100 波）/ 没有小推车 / 没有选卡权；三消管理器由**关卡脚本**持有（本体不再创建）
##   ② 摆场：棋盘（去掉最右一列）铺满植物、最右一列留空、开局没有现成的连线、有步可走
##   ③ 交换三消：点两下相邻格子 → 凑成连线 → 植物被消掉 + 阳光到账 + 空位补满
##   ④ 棋盘上的植物被啃掉留弹坑 + 花阳光填坑
##   ⑤ 花阳光买升级：场上旧植物全换成升级版 + 随机池跟着换 + 换完盘面仍「无现成连线 + 有步可走」
##   ⑥ 通关判定：配对次数达标 → 出奖杯进 GAME_OVER（不是靠打完波次）
## 机器可读汇总：最后一行 [BEGHOULED] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_05_beghouled.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸迷阵（Beghouled） ==========")

	## 不标类型：下面要取子类才有的字段 beghouled（标成 Resource 会取不到）
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP1 关卡数据
	a.log("STEP1 关卡数据")
	_check(a, "波数配成 100（无限波）", mg.game_para.max_wave == 100, str(mg.game_para.max_wave))
	_check(a, "没有小推车", not mg.game_para.is_lawn_mover, str(mg.game_para.is_lawn_mover))
	_check(a, "没有选卡权", mg.game_para.is_no_choose_permission())
	## 本体上取不到 beghouled_manager（字段已删；Object.get 取不存在的属性返回 null）
	_check(a, "本体不再持有三消管理器", mg.get("beghouled_manager") == null,
		"MainGameManager 上不该再有 beghouled_manager 字段")

	## 三消管理器由**关卡脚本**自己创建并持有（硬约束 §1-8：一关专属机制不进本体）
	var mgr = para.beghouled
	if mgr == null:
		_check(a, "关卡脚本创建了三消管理器", false, "para.beghouled 为空")
		_finish(a)
		return
	_check(a, "关卡脚本创建了三消管理器", true)

	## 关卡流程：展示僵尸 → 相机归位 → 摆场 → 开战
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.MAIN_GAME, 60.0):
		_finish(a)
		return

	# ------------------------------------------------ STEP2 摆场
	a.log("STEP2 摆场")
	_check(a, "玩法已接管本关", mgr.is_running, str(mgr.is_running))
	var col_num: int = mg.plant_cell_manager.row_col.y
	_check(a, "棋盘列数 = 总列数 - 1（最右列留给僵尸入场）",
		mgr.board_col_num == col_num - 1, str(mgr.board_col_num))

	var empty_num := 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			if mgr.get_cell_plant(mgr.get_cell(row, col)) == null:
				empty_num += 1
	_check(a, "棋盘上没有空格子", empty_num == 0, "空格数=" + str(empty_num))

	var right_col_plants := 0
	for row in range(mgr.board_row_num):
		if mgr.get_cell_plant(mgr.get_cell(row, col_num - 1)) != null:
			right_col_plants += 1
	_check(a, "最右一列是空的", right_col_plants == 0, "有植物行数=" + str(right_col_plants))
	_check(a, "开局没有现成的连线", mgr._find_match_groups(mgr._build_type_grid()).is_empty())
	_check(a, "开局有步可走", mgr._has_possible_move())
	_check(a, "三消界面已挂上并显示", mgr.ui != null and mgr.ui.visible, "ui=" + str(mgr.ui))

	# ------------------------------------------------ STEP3 交换三消
	a.log("STEP3 交换相邻两株做三消")
	var swap_pair := _find_valid_swap(mgr)
	if swap_pair.is_empty():
		_check(a, "找到一步有效交换", false, "null")
		_finish(a)
		return
	var cell_a: PlantCell = swap_pair[0]
	var cell_b: PlantCell = swap_pair[1]
	var sun_before: int = mgr.get_sun()
	var match_before: int = mgr.match_num
	mgr._on_click_cell(cell_a)
	mgr._on_click_cell(cell_b)
	await a.wait(3.0)
	_check(a, "配对次数增加了", mgr.match_num > match_before,
		str(match_before) + " -> " + str(mgr.match_num))
	_check(a, "消除给了阳光", mgr.get_sun() > sun_before,
		str(sun_before) + " -> " + str(mgr.get_sun()))

	empty_num = 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			if mgr.get_cell_plant(mgr.get_cell(row, col)) == null:
				empty_num += 1
	_check(a, "消除后空位被补满", empty_num == 0, "空格数=" + str(empty_num))

	# ------------------------------------------------ STEP4 被啃掉留弹坑
	a.log("STEP4 植物没了会留弹坑")
	## 填一个坑要 200 阳光，先把阳光补给够（STEP3 只消了一组，攒不到 200）
	EventBus.push_event("add_sun_value", [300])
	var victim: PlantCell = mgr.get_cell(0, 0)
	var victim_plant = mgr.get_cell_plant(victim)
	victim_plant.character_death()
	await a.wait(0.5)
	_check(a, "棋盘上的植物没了会留弹坑", mgr.is_crater(victim), str(mgr.is_crater(victim)))
	_check(a, "填坑按钮此时可用（有坑 + 阳光够）", mgr.try_fill_crater())
	_check(a, "填完坑那格长出新植物", mgr.get_cell_plant(victim) != null)

	# ------------------------------------------------ STEP5 买升级
	a.log("STEP5 花阳光买升级（豌豆射手 → 双重射手）")
	EventBus.push_event("add_sun_value", [2000])
	var upgrade_ok: bool = mgr.try_buy_upgrade(0)
	_check(a, "阳光够时买升级成功", upgrade_ok, str(upgrade_ok))
	await a.wait(1.5)
	_check(a, "升级被记成已购买", mgr.purchased_upgrades[0], str(mgr.purchased_upgrades[0]))
	_check(a, "阳光被扣掉 1000", mgr.get_sun() <= 2000, "阳光=" + str(mgr.get_sun()))
	var old_num := 0
	var new_num := 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			var t = mgr.get_cell_type(mgr.get_cell(row, col))
			if t == CharacterRegistry.PlantType.P001PeaShooterSingle:
				old_num += 1
			elif t == CharacterRegistry.PlantType.P008PeaShooterDouble:
				new_num += 1
	_check(a, "场上不再有豌豆射手", old_num == 0, "剩余=" + str(old_num))
	_check(a, "场上出现了双重射手", new_num > 0, "数量=" + str(new_num))
	## 换场那两帧里棋盘是半空的（不许玩家插手），换完必须还能玩：没有现成的连线 + 有步可走
	_check(a, "换场后没有现成的连线", mgr._find_match_groups(mgr._build_type_grid()).is_empty())
	_check(a, "换场后还有步可走", mgr._has_possible_move())
	_check(a, "同一档升级不能买第二次", not mgr.try_buy_upgrade(0), "第二次购买该返回 false")
	## 换 plants 期间 / 结算期间锁操作：is_resolving 为真时不该受理点击
	_check(a, "换场已完成（锁已解开）", not mgr._is_replacing, "_is_replacing=" + str(mgr._is_replacing))

	# ------------------------------------------------ STEP6 达标通关
	a.log("STEP6 配对达标 → 出奖杯（不看波次）")
	mgr.match_num = ConstBeghouled.TARGET_MATCH_NUM - 1
	var swap_pair2 := _find_valid_swap(mgr)
	if swap_pair2.is_empty():
		_check(a, "再找到一步有效交换", false, "null")
		_finish(a)
		return
	mgr._on_click_cell(swap_pair2[0])
	mgr._on_click_cell(swap_pair2[1])
	await a.wait(3.0)
	_check(a, "达标后进入 GAME_OVER（掉奖杯结算）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		str(mg.main_game_progress))

	_finish(a)


#region 工具
## 找一对「交换后能凑成连线」的相邻格子（与玩家手动点两下等价）
func _find_valid_swap(mgr) -> Array:
	var grid: Array[Array] = mgr._build_type_grid()
	## 只试右邻与下邻（左 / 上邻会被反过来试到，试两次就够了）
	var neighbor_offsets: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			for offset in neighbor_offsets:
				var row2: int = row + offset.x
				var col2: int = col + offset.y
				if row2 >= mgr.board_row_num or col2 >= mgr.board_col_num:
					continue
				var t1 = grid[row][col]
				var t2 = grid[row2][col2]
				if t1 == CharacterRegistry.PlantType.Null or t2 == CharacterRegistry.PlantType.Null:
					continue
				grid[row][col] = t2
				grid[row2][col2] = t1
				var matched: bool = mgr._has_match_at(grid, row, col) or mgr._has_match_at(grid, row2, col2)
				grid[row][col] = t1
				grid[row2][col2] = t2
				if matched:
					return [mgr.get_cell(row, col), mgr.get_cell(row2, col2)]
	return []


## 等主游戏推进到某个阶段
func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到阶段 " + str(progress), false, "当前阶段=" + str(mg.main_game_progress))
	return false


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[BEGHOULED] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
