extends RefCounted
## 探针：僵王博士（ZombossBoss，独立 Node2D 版）—— 冒险 5-10
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_zomboss
## 覆盖：
##   1. 静态：ZombossBoss / ZombossBall / ZombossHpBar 三个场景可实例化
##   2. 静态：5-10 关卡资源 is_zomboss_fight = true、monster_mode = Null
##   3. 实机：进 5-10 → 僵王登场（血量 40000 / 站在场外 / 默认不可被打）
##   4. 出怪池：前 2 轮用初级池（普通 / 路障 / 铁桶），之后用高级池
##   5. 踩踏范围：最右侧 4 列（单行的右侧 4 列，范围内有植物才触发）
##   6. 实机：出招循环在跑（round_count / action_num 会涨）
##   7. 实机：低头期间开受击窗口，此时才吃伤害；抬头后免疫
##   8. 实机：冰火球能生成（贴屋面），火球被寒冰菇驱散
##   9. 实机：打死僵王 → 出奖杯（create_trophy）→ 血条自毁
## 机器可读汇总：最后一行 [ZOMBOSS] result=PASS|FAIL failed=<n>

## 僵王关（5-10）在选关界面上的位置：第 5 页（0 起 = 4）的第 10 关
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const PAGE_05 := 4
const ID_05_10 := "0050"

const LEVEL_5_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
## 僵王血条：已搬到关卡侧（僵王关专属 UI），由 spawn_zomboss 事件实例化
const HP_BAR_SCENE := preload("res://src/levels/core/zomboss/zomboss_hp_bar.tscn")

var _failed := 0
var _hp_bar: ZombossHpBar


func run(a) -> void:
	a.log("")
	a.log("========== 探针 僵王博士（ZombossBoss） ==========")
	_check_scenes(a)
	_check_level_resource(a)
	await _check_runtime(a)
	_finish(a)


#region 静态

func _check_scenes(a) -> void:
	a.log("")
	a.log("STEP1 三个场景可实例化")
	var boss := SceneRegistry.ZOMBIE_BOSS.instantiate()
	_check(a, "ZOMBIE_BOSS 可实例化且是 ZombossBoss", boss is ZombossBoss, str(boss))
	if boss is ZombossBoss:
		var names: Array = []
		for child in boss.get_children():
			if child is AnimationPlayer:
				names.append_array((child as AnimationPlayer).get_animation_list())
		_check(a, "僵王动画库里有 23 段动画", names.size() == 23, str(names.size()))
		_check(a, "有登场 / 待机 / 死亡动画",
			names.has("Zombie_boss_enter") and names.has("Zombie_boss_idle")
			and names.has("Zombie_boss_death"),
			str(names))
		## reanim 帧动画靠「贴图序列 + 自身调色」两条轨道驱动，缺了它们僵王播动画时贴图不换
		## （早期本仓库的动画就只有 visible / 变换轨道，表现是「只动不换图」）
		var idle_props := _anim_track_props(boss, "Zombie_boss_idle")
		_check(a, "idle 动画带 texture / self_modulate 轨道（贴图序列）",
			idle_props.has("texture") and idle_props.has("self_modulate"),
			str(idle_props))
	boss.free()

	var ball := SceneRegistry.ZOMBOSS_BALL.instantiate()
	_check(a, "ZOMBOSS_BALL 可实例化且是 ZombossBall", ball is ZombossBall, str(ball))
	ball.free()

	var bar := HP_BAR_SCENE.instantiate()
	_check(a, "关卡侧僵王血条可实例化且是 ZombossHpBar", bar is ZombossHpBar, str(bar))
	bar.free()


## 取某段动画里出现过的属性名（去重），用来判断动画轨道齐不齐
func _anim_track_props(boss: Node2D, anim_name: String) -> Array[String]:
	var props: Array[String] = []
	for child in boss.get_children():
		if not child is AnimationPlayer:
			continue
		var player := child as AnimationPlayer
		if not player.has_animation(anim_name):
			continue
		var anim := player.get_animation(anim_name)
		for i in anim.get_track_count():
			var parts := str(anim.track_get_path(i)).split(":")
			if parts.size() > 1 and not props.has(parts[1]):
				props.append(parts[1])
		break
	props.sort()
	return props


func _check_level_resource(a) -> void:
	a.log("")
	a.log("STEP2 5-10 关卡资源")
	var para: ResourceLevelData = (load(LEVEL_5_10) as GDScript).new()
	if para == null:
		_check(a, "5-10 关卡资源可加载", false, LEVEL_5_10)
		return
	_check(a, "5-10 关卡资源可加载", true)
	_check(a, "5-10 is_zomboss_fight = true", para.is_zomboss_fight, str(para.is_zomboss_fight))
	_check(a, "5-10 monster_mode = Null（不自然出怪）",
		para.monster_mode == ConstLevelData.E_MonsterMode.Null, str(para.monster_mode))
#endregion


#region 实机

func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP3 进 5-10，僵王登场")
	var para: ResourceLevelData = (load(LEVEL_5_10) as GDScript).new()
	if para == null:
		_check(a, "5-10 关卡资源可加载", false)
		return
	para.set_choose_level(ADV, PAGE_05, ID_05_10)
	## 屋顶清洁车要在商店买过才配发（僵王关是夜屋顶，本局按「已买」跑）
	Global.global_game_state.buy_lawn_mover(GIM_LawnMover.E_LawnMoverType.RoofCleaner)
	Global.game_para = para
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences]
	)
	if not await _wait_main_game(a, 90.0):
		_check(a, "5-10 进入 MAIN_GAME", false, "超时")
		return
	_check(a, "5-10 进入 MAIN_GAME", true)

	## 登场动画 3.25s，等它站稳
	var boss: ZombossBoss = await _wait_boss(a, 20.0)
	if boss == null:
		_check(a, "僵王已生成", false, "超时")
		return
	_check(a, "僵王已生成", true)
	_check(a, "僵王血量 = 40000（首次通关）", boss.max_hp == 40000.0, str(boss.max_hp))
	_check(a, "僵王默认不可被打（没低头）", not boss.is_head_vulnerable, str(boss.is_head_vulnerable))
	_check(a, "僵王受击框在碰撞层 512（植物子弹能命中）",
		boss.hurt_box_component.collision_layer == 512,
		str(boss.hurt_box_component.collision_layer))
	## 站位：事件只给锚点，整机左右微调是僵王自己的 ART_OFFSET（所有僵王关同一个值）
	var rows = Global.main_game.zombie_manager.all_zombie_rows
	var anchor_x: float = rows[mini(2, rows.size() - 1)].zombie_create_position.global_position.x
	var expect_x: float = anchor_x - ZombossBoss.REANIM_ANCHOR_X + ZombossBoss.ART_OFFSET.x
	_check(a, "僵王落位 = 锚点 + ART_OFFSET（左右微调只认这一个值）",
		absf(boss.global_position.x - expect_x) < 1.0,
		"boss_x=%.0f expect=%.0f" % [boss.global_position.x, expect_x])
	## 血条由关卡侧（spawn_zomboss 事件）创建并挂到关卡信息 UI 上，本体不再管
	_hp_bar = _find_hp_bar()
	_check(a, "僵王血条挂在关卡信息 UI 上", is_instance_valid(_hp_bar), str(_hp_bar))

	await _check_spawn_script(a, boss)
	await _check_stomp_range(a, boss)
	await _check_action_loop(a, boss)
	await _check_head_window(a, boss)
	await _check_ball(a, boss)
	await _check_death(a, boss)


## 放僵尸（原版口径）：开局固定剧本 4 普僵 → 4~5 路障 → 低头 → 4~5 铁桶（偶尔混 1 只路障）
## → 再低头；剧本走完后随机，且不再出普僵。投放行只挑「小推车还在」的行
func _check_spawn_script(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP4 开局放僵尸剧本（原版 set pattern）")
	var norm := CharacterRegistry.ZombieType.Z001Norm
	var cone := CharacterRegistry.ZombieType.Z003Cone
	var bucket := CharacterRegistry.ZombieType.Z005Bucket
	## 直接问剧本构造函数：不赌随机、也不怕剧本已经被消费掉
	var script: Array = boss._build_opening_script()
	_check(a, "剧本 5 条（放 / 放 / 低头 / 放 / 低头）", script.size() == 5, str(script.size()))
	if script.size() == 5:
		var norm_types: Array = script[0].get("types", [])
		_check(a, "第 1 条 = 4 只普通僵尸",
			str(script[0].get("act")) == "Spawn"
			and norm_types.size() == ZombossBoss.OPENING_NORM_COUNT
			and norm_types.all(func(t): return t == norm),
			str(script[0]))
		var cone_types: Array = script[1].get("types", [])
		_check(a, "第 2 条 = 4~5 只路障",
			str(script[1].get("act")) == "Spawn" and cone_types.size() >= 4
			and cone_types.size() <= 5 and cone_types.all(func(t): return t == cone),
			str(script[1]))
		_check(a, "第 3 条 = 低头吐球", str(script[2].get("act")) == "Head", str(script[2]))
		var bucket_types: Array = script[3].get("types", [])
		_check(a, "第 4 条 = 4~5 只铁桶（最多混 1 只路障）",
			str(script[3].get("act")) == "Spawn" and bucket_types.size() >= 4
			and bucket_types.size() <= 5
			and bucket_types.all(func(t): return t == bucket or t == cone)
			and bucket_types.count(cone) <= 1,
			str(script[3]))
		_check(a, "第 5 条 = 再低头吐球", str(script[4].get("act")) == "Head", str(script[4]))
	_check(a, "剧本后随机池不再出普通僵尸",
		not ZombossBoss.POOL_LATE.has(norm), str(ZombossBoss.POOL_LATE))
	## 直接问抽签函数，不赌随机：抽出来的类型必须落在池子里
	var in_pool := true
	for _i in range(20):
		if not ZombossBoss.POOL_LATE.has(boss._pick_spawn_type(ZombossBoss.POOL_LATE)):
			in_pool = false
			break
	_check(a, "随机池抽签只出池内类型", in_pool, "")
	await _check_spawn_row(a, boss)


## 投放行（原版）：避开「清洁车已被僵尸触发」的行；全没了才回到任意行
func _check_spawn_row(a, boss: ZombossBoss) -> void:
	var gim = Global.main_game.game_item_manager.gim_lawn_mover
	if gim == null or gim.all_lawn_movers.is_empty():
		_check(a, "本局配了小推车（否则投放行断言跳过）", false, "SKIP")
		return
	var movers: Array = gim.all_lawn_movers
	var alive: Array[int] = []
	for i in range(movers.size()):
		if is_instance_valid(movers[i]) and not movers[i].is_moving:
			alive.append(i)
	if alive.size() < 2:
		_check(a, "至少 2 行有推车（否则投放行断言跳过）", false, "alive=%s" % str(alive))
		return
	var hit := _picked_rows(boss, 30)
	_check(a, "投放只落在推车还在的行", hit.all(func(r): return alive.has(r)),
		"hit=%s alive=%s" % [str(hit), str(alive)])
	## 触发掉一行的车：那一行不应再被投放
	var victim: int = alive[0]
	movers[victim].is_moving = true
	var hit2 := _picked_rows(boss, 30)
	_check(a, "清洁车被触发的行不再投放", not hit2.has(victim), "victim=%d hit=%s" % [victim, str(hit2)])
	## 全部触发 → 原版回到任意行
	for m in movers:
		if is_instance_valid(m):
			m.is_moving = true
	var hit3 := _picked_rows(boss, 30)
	_check(a, "所有推车都没了 → 任意行都能投放", hit3.size() >= 2, "hit=%s" % str(hit3))
	## 还原：别把本局的推车测没了
	for m in movers:
		if is_instance_valid(m):
			m.is_moving = false


## 问 _pick_spawn_row() n 次，返回去重写过的行号（不赌单次随机）
func _picked_rows(boss: ZombossBoss, times: int) -> Array[int]:
	var out: Array[int] = []
	for _i in range(times):
		var r: int = boss._pick_spawn_row()
		if not out.has(r):
			out.append(r)
	return out

## 踩踏范围（参考口径）：最右侧 4 列，单行结算（范围内有植物才触发）
func _check_stomp_range(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP5 踩踏 = 2 行 × 最右侧 4 列")
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	if cells.is_empty():
		_check(a, "有植物格子", false, "all_plant_cells 为空")
		return
	var last_col: int = cells[0].size() - 1
	var plants := []
	for row in cells:
		plants.append(row[last_col].create_plant(CharacterRegistry.PlantType.P001PeaShooterSingle))
	await a.wait(0.5)
	var planted := 0
	for p in plants:
		if is_instance_valid(p):
			planted += 1
	_check(a, "最右列每行都种上了植物", planted == plants.size(),
		str(planted) + "/" + str(plants.size()))
	## 候选是「行对起始行」：5 行地图 = 4 个行对（0/1、1/2、2/3、3/4）
	var stomp_rows: Array = boss._rows_with_plants_in_stomp_range()
	_check(a, "每行都有植物 → 4 个行对起点全候选", stomp_rows == [0, 1, 2, 3], str(stomp_rows))
	## 直接调结算函数，不赌随机行数与动画时机：从起始行起压 2 行的右侧 4 列
	boss._smash_stomp_rows(3)
	await a.wait(0.5)
	_check(a, "踩踏压 2 行（第 3 / 4 行的植物没了，前 3 行还在）",
		not is_instance_valid(plants[3]) and not is_instance_valid(plants[4])
		and is_instance_valid(plants[0]) and is_instance_valid(plants[1])
		and is_instance_valid(plants[2]),
		str(["存活:", is_instance_valid(plants[0]), is_instance_valid(plants[1]),
			is_instance_valid(plants[2]), is_instance_valid(plants[3]),
			is_instance_valid(plants[4])]))
	## 第 3 / 4 行都没植物了 → 行对起点 3 出候选；起点 2 仍因第 2 行有植物留在候选里
	var rows_after: Array = boss._rows_with_plants_in_stomp_range()
	_check(a, "整个行对都没植物 → 不再进候选", not rows_after.has(3) and rows_after.has(2),
		str(rows_after))


## 出招循环：等一会儿看 round_count 有没有涨（不赌随机到哪一招）
func _check_action_loop(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP6 出招循环在跑")
	var before := boss.round_count
	var waited := 0.0
	while boss.round_count == before and waited < 20.0:
		await a.wait(0.5)
		waited += 0.5
	_check(a, "僵王会自己出招（round_count 增长）", boss.round_count > before,
		"%d -> %d" % [before, boss.round_count])


## 低头窗口：只有低头时才能打到，抬头后免疫
func _check_head_window(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP7 低头才开受击窗口")
	## 僵王正在放别的招时 _do_head_attack() 会直接 return，先等它空闲
	var idle_wait := 0.0
	while boss.is_busy and idle_wait < 30.0:
		await a.wait(0.5)
		idle_wait += 0.5
	_check(a, "等到僵王空闲", not boss.is_busy, "waited=%.1fs" % idle_wait)
	## 不等它自己随机到这一招，直接驱动一次低头攻击（协程在第一个 await 处让出）
	boss._do_head_attack()
	var waited := 0.0
	while not boss.is_head_vulnerable and waited < 15.0:
		await a.wait(0.3)
		waited += 0.3
	_check(a, "低头后受击窗口打开", boss.is_head_vulnerable,
		"waited=%.1fs is_busy=%s" % [waited, boss.is_busy])

	var hp_before := boss.curr_hp
	boss.be_attacked_bullet(1000, BulletRegistry.AttackMode.Norm)
	_check(a, "低头期间能被打掉血", boss.curr_hp == hp_before - 1000,
		"%.0f -> %.0f" % [hp_before, boss.curr_hp])

	## 抬头后免疫
	boss._finish_head_attack(false)
	hp_before = boss.curr_hp
	boss.be_attacked_bullet(1000, BulletRegistry.AttackMode.Norm)
	_check(a, "抬头后免疫（不再掉血）", boss.curr_hp == hp_before,
		"%.0f -> %.0f" % [hp_before, boss.curr_hp])
	await _check_head_unlock(a, boss)


## 解锁时机（原版）：第 3 次低头后解锁天降蹦极，第 4 次后解锁 RV
func _check_head_unlock(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP7b 蹦极 / 房车解锁（第 3 / 4 次低头后）")
	_check(a, "默认没解锁蹦极 / 房车", boss.head_attack_count < ZombossBoss.HEAD_COUNT_UNLOCK_BUNGEE
		or boss._is_bungee_unlocked, "%d 次低头" % boss.head_attack_count)
	## 不真的等它随机低头（一次 ~15s）：把计数推到位，再驱动一次
	var cases := [
		{"nth": ZombossBoss.HEAD_COUNT_UNLOCK_BUNGEE, "act": "BungeeDrop", "flag": "_is_bungee_unlocked"},
		{"nth": ZombossBoss.HEAD_COUNT_UNLOCK_RV, "act": "RV", "flag": "_is_rv_unlocked"},
	]
	for c in cases:
		await _trigger_nth_head_attack(a, boss, c["nth"])
		_check(a, "第 %d 次低头后解锁 %s" % [c["nth"], c["act"]],
			boss.get(c["flag"]) and boss._forced_next_action == c["act"],
			"forced=%s" % boss._forced_next_action)
	## 解锁的那一招要在下一轮排出去（清掉剧本，直接问建队函数）
	boss._opening_script.clear()
	boss._build_round_queue()
	var acts: Array = []
	for act in boss.action_queue:
		acts.append(str((act as Dictionary).get("act")))
	_check(a, "解锁招排进下一轮", acts.has("RV") or acts.has("BungeeDrop"), str(acts))


## 把 head_attack_count 推到第 nth 次低头（_do_head_attack 里会 +1）再收尾，不等动画跑完
func _trigger_nth_head_attack(a, boss: ZombossBoss, nth: int) -> void:
	var idle_wait := 0.0
	while boss.is_busy and idle_wait < 30.0:
		await a.wait(0.5)
		idle_wait += 0.5
	boss.head_attack_count = nth - 1
	boss._do_head_attack()
	await a.wait(0.3)
	boss._finish_head_attack(false)
	await a.wait(0.3)


## 冰火球：能生成、贴屋面、火球被寒冰菇扑灭
func _check_ball(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP8 冰火球")
	## 先把场上已有的球清掉：STEP7 / 7b 手工驱动的低头被 _finish_head_attack 截断后，
	## 「出球帧」的 timer 仍会照常开火，不清会让下面的查找抓到别人的行、y 对不上
	for child in Global.main_game.get_children():
		if child is ZombossBall:
			child.queue_free()
	await a.wait(0.3)
	var lane := 0
	boss._fire_ball(lane, true)
	await a.wait(0.5)
	var ball: ZombossBall = null
	for child in Global.main_game.get_children():
		if child is ZombossBall:
			ball = child
			break
	if ball == null:
		_check(a, "火球已生成", false)
		return
	_check(a, "火球已生成", true)
	var row_y: float = Global.main_game.get_row_base_global_y(lane)
	var slope_y := 0.0
	if is_instance_valid(Global.main_game.main_game_slope):
		slope_y = Global.main_game.main_game_slope.get_all_slope_y(ball.global_position.x)
	_check(a, "火球贴屋面（与屋面误差 < 4px）",
		abs(ball.global_position.y - (row_y + slope_y - 52.0)) < 4.0,
		"y=%.1f expect=%.1f" % [ball.global_position.y, row_y + slope_y - 52.0])
	var x_before := ball.global_position.x
	await a.wait(1.0)
	_check(a, "火球在向左滚", ball.global_position.x < x_before,
		"%.0f -> %.0f" % [x_before, ball.global_position.x])

	EventBus.push_event("ice_all_zombie", [4.0, 0.0])
	await a.wait(0.5)
	_check(a, "寒冰菇扑灭火球", not is_instance_valid(ball) or ball.is_queued_for_deletion(), "")


## 死亡：加速演出 + 爆炸闪烁后发 create_trophy，血条随僵王一起销毁，场上僵尸一并消失
func _check_death(a, boss: ZombossBoss) -> void:
	a.log("")
	a.log("STEP9 打死僵王")
	## 用字典存标记：GDScript 的 lambda 对局部变量是值捕获，直接改 bool 拿不到结果
	var flags := {"trophy": false}
	var on_trophy := func(_glo_pos): flags["trophy"] = true
	EventBus.subscribe("create_trophy", on_trophy)
	## 先放几只僵尸：原版僵王一死，它召唤的僵尸会跟着 despawn
	var zm = Global.main_game.zombie_manager
	boss._spawn_zombie(CharacterRegistry.ZombieType.Z001Norm, 0)
	boss._spawn_zombie(CharacterRegistry.ZombieType.Z003Cone, 1)
	await a.wait(0.5)
	var before := _field_zombie_num(zm)
	_check(a, "打死前场上有僵尸", before >= 2, str(before))
	boss.curr_hp = 1.0
	boss.is_head_vulnerable = true
	boss.be_attacked_bullet(1000, BulletRegistry.AttackMode.Real)
	_check(a, "僵王已死亡", boss.is_death, str(boss.is_death))

	var waited := 0.0
	while not flags["trophy"] and waited < 25.0:
		await a.wait(0.5)
		waited += 0.5
	EventBus.unsubscribe("create_trophy", on_trophy)
	_check(a, "僵王死亡后出奖杯（create_trophy）", flags["trophy"], "waited=%.1fs" % waited)
	## 血条跟僵王一起销毁，不留挂在主 UI 上的孤儿节点
	_check(a, "僵王死亡后血条已销毁", not is_instance_valid(_hp_bar), str(_hp_bar))
	## 清场：多等几秒（僵尸走的是正常死亡流程）
	var clear_wait := 0.0
	while _field_zombie_num(zm) > 0 and clear_wait < 10.0:
		await a.wait(0.5)
		clear_wait += 0.5
	_check(a, "僵王死亡后场上僵尸清干净（原版 despawn）",
		_field_zombie_num(zm) == 0, "before=%d after=%d waited=%.1fs" % [before, _field_zombie_num(zm), clear_wait])


## 场上还活着的僵尸数
func _field_zombie_num(zm) -> int:
	var n := 0
	for row in zm.all_zombies_2d:
		n += (row as Array).size()
	return n


## 在主 UI 的关卡信息节点下找僵王血条
func _find_hp_bar() -> ZombossHpBar:
	if Global.main_game == null or Global.main_game.level_info == null:
		return null
	for child in Global.main_game.level_info.get_children():
		if child is ZombossHpBar:
			return child
	return null


func _wait_boss(a, timeout: float) -> ZombossBoss:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and is_instance_valid(Global.main_game.zomboss_boss):
			return Global.main_game.zomboss_boss
		await a.wait(0.5)
		waited += 0.5
	return null


func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null \
			and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false
#endregion


#region 断言

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSS] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
