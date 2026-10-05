extends RefCounted
## 探针：迷你游戏第 19 关「蹦蹦舞会」(Pogo Party)
##
## 覆盖：
##   ① 关卡数据：屋顶场景 + 屋顶曲 Graze the Roof、**只有蹦蹦僵尸**的出怪表、
##      30 波（原版 3 面旗帜）、没有蹦极、约 55 秒的超长开场、开局预置的花盆
##   ② 预览僵尸：清一色蹦蹦僵尸（开场那一眼就是本关的关键）
##   ③ 波次构成（直接问波次生成管理器，不依赖随机结果）：
##      · 非旗帜波 0~28：**全是**蹦蹦僵尸，一只别的都没有
##      · 旗帜波 9 / 19 / 29：1 只旗帜 + 4/8 只普僵（原版大波本来就掺普僵）
##        + 战力凑不满一只时补的那几只普僵，**其余全是蹦蹦，且蹦蹦仍是本波主体**
##   ④ 实机：真刷一波出来，场上僵尸全是蹦蹦
## 机器可读汇总：最后一行 [POGOPARTY] result=PASS|FAIL failed=<n>
##
## 跑：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_pogo_party -Windowed

const LEVEL := "res://src/levels/mode_minigame/minigame_19_pogo_party.gd"
## 原版：Roof + Three flags（本仓库每 10 波 1 面旗帜）
const EXPECT_MAX_WAVE := 30
## 原版 Trivia：从可以种植物到第一波约有 55 秒
const EXPECT_FIRST_WAVE_DELAY := 55.0
const POGO := CharacterRegistry.ZombieType.Z019Pogo
const FLAG := CharacterRegistry.ZombieType.Z002Flag
const NORM := CharacterRegistry.ZombieType.Z001Norm

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 蹦蹦舞会（Pogo Party） ==========")

	# ---------------------------------------------- STEP1 关卡数据
	a.log("STEP1 关卡数据（还没进场景，先读关卡脚本里那份）")
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	_check(a, "存档键 = 102_0_0017", para.save_key == "102_0_0017", para.save_key)
	_check(a, "场景是屋顶 MainGameRoof",
		para.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, str(para.game_sences))
	_check(a, "背景是 Roof", para.game_BG == ConstLevelData.GameBg.Roof, str(para.game_BG))
	_check(a, "BGM 是屋顶曲 Roof（原版本关播 Graze the Roof，不放通用小游戏曲）",
		para.game_BGM == ConstLevelData.GameBGM.Roof, str(para.game_BGM))
	_check(a, "出怪倍率 = 4", para.zombie_multy == 4, str(para.zombie_multy))
	_check(a, "第一波延迟 = " + str(EXPECT_FIRST_WAVE_DELAY) + " 秒",
		para.first_wave_delay == EXPECT_FIRST_WAVE_DELAY, str(para.first_wave_delay))
	_check(a, "没有蹦极僵尸偷植物", para.is_bungi == false, str(para.is_bungi))

	var pot_num := 0
	var pot_all_flower := true
	for i in range(para.all_pre_plant_data.size()):
		var pre: PrePlantResource = para.all_pre_plant_data[i]
		pot_num += 1
		if pre.plant_type != CharacterRegistry.PlantType.P034FlowerPot:
			pot_all_flower = false
	_check(a, "开局预置了 4 列花盆（屋顶得先有花盆才能种）", pot_num == 4, str(pot_num))
	_check(a, "预置的全是花盆", pot_all_flower)

	# ---------------------------------------------- STEP2 进关卡
	a.log("STEP2 进关卡（手里要有卡，免得被「种子包过少」自动跳过选卡）")
	var state = Global.global_game_state
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantType.P004WallNut,
		CharacterRegistry.PlantType.P009PuffShroom,
	])
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return
	var zm = mg.zombie_manager

	# ---------------------------------------------- STEP3 预览僵尸
	a.log("STEP3 预览僵尸应全是蹦蹦僵尸")
	var show_zombies: Array = []
	for i in range(40):
		show_zombies = zm.zombie_show_in_start.show_zombies_array
		if not show_zombies.is_empty():
			break
		await a.wait(0.5)
	if show_zombies.is_empty():
		_check(a, "预览僵尸已生成", false, "20 秒内没等到预览僵尸")
		_finish(a)
		return
	var types: Dictionary = {}
	for j in range(show_zombies.size()):
		var z0: Zombie000Base = show_zombies[j]
		types[z0.zombie_type] = types.get(z0.zombie_type, 0) + 1
	a.log("  预览僵尸构成: " + str(types))
	_check(a, "预览僵尸全是蹦蹦僵尸（" + str(show_zombies.size()) + " 只）",
		types.size() == 1 and types.has(POGO), str(types))
	_check(a, "本关出怪表只有蹦蹦僵尸",
		zm.zombie_refresh_types == [POGO], str(zm.zombie_refresh_types))

	# ---------------------------------------------- STEP4 选卡 → 开战
	a.log("STEP4 选卡并开局")
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.CHOOSE_CARD, 40.0):
		_finish(a)
		return
	mg.choosed_card_start_game()
	## 「开战」事件会把波数写回关卡数据（LevelTimelineEventStartBattle._apply_battle_para）
	if not await _wait_max_wave(a, mg, EXPECT_MAX_WAVE, 40.0):
		_finish(a)
		return
	_check(a, "总波数 = " + str(EXPECT_MAX_WAVE) + "（原版 3 面旗帜）",
		mg.game_para.max_wave == EXPECT_MAX_WAVE, str(mg.game_para.max_wave))
	_check(a, "波次管理器的每轮波数同步成 " + str(EXPECT_MAX_WAVE),
		zm.zombie_wave_manager.max_wave_one_round == EXPECT_MAX_WAVE,
		str(zm.zombie_wave_manager.max_wave_one_round))

	# ---------------------------------------------- STEP5 逐波核对构成
	a.log("STEP5 逐波核对僵尸构成")
	var wcm = zm.zombie_wave_manager.zombie_wave_create_manager
	var bad_wave := -1
	var bad_detail := ""
	var counts: Array[String] = []
	for wave in range(EXPECT_MAX_WAVE):
		var is_big: bool = wave % 10 == 9
		var list = wcm.create_curr_wave_zombie_list(wave, is_big)
		var got: Dictionary = {}
		for t in list:
			got[t] = got.get(t, 0) + 1
		counts.append("W" + str(wave) + "=" + str(list.size()))
		if not is_big:
			## 非旗帜波：一只别的都不能有
			if not (got.size() == 1 and got.has(POGO)):
				bad_wave = wave
				bad_detail = str(got)
				break
		else:
			## 旗帜波：1 只旗帜 + 4/8 只普僵（原版大波本来就掺普僵）
			## + 战力预算不足一只蹦蹦时的余额补齐（每只 1 点，最多补 min_power-1 = 3 只）
			var expect_norm: int = 4 if wave == 9 else 8
			var ok: bool = got.get(FLAG, 0) == 1 and got.get(NORM, 0) >= expect_norm
			## 旗帜波除旗帜 + 普僵外，剩下的也只能是蹦蹦僵尸
			for t2 in got:
				if t2 != FLAG and t2 != NORM and t2 != POGO:
					ok = false
			## 即便算上补齐的那几只普僵，旗帜波的主体仍然是蹦蹦僵尸
			if got.get(POGO, 0) < got.get(NORM, 0):
				ok = false
			if not ok:
				bad_wave = wave
				bad_detail = str(got)
				break
	_check(a, "第 0~29 波：非旗帜波全是蹦蹦、旗帜波只有旗帜 + 普僵 + 蹦蹦",
		bad_wave < 0, "第 " + str(bad_wave) + " 波不符: " + bad_detail)
	a.log("  每波只数: " + " ".join(counts))

	# ---------------------------------------------- STEP6 实机刷一波
	a.log("STEP6 真刷一波出来，场上应全是蹦蹦僵尸")
	zm.zombie_wave_manager.start_first_wave()
	await a.wait(3.0)
	var on_field: Dictionary = {}
	for row in zm.all_zombies_2d:
		for k in range(row.size()):
			var z1: Zombie000Base = row[k]
			if not is_instance_valid(z1):
				continue
			on_field[z1.zombie_type] = on_field.get(z1.zombie_type, 0) + 1
	a.log("  场上僵尸构成: " + str(on_field))
	_check(a, "第一波有僵尸进场", not on_field.is_empty(), "一只都没有")
	_check(a, "第一波全是蹦蹦僵尸",
		on_field.size() == 1 and on_field.has(POGO), str(on_field))

	_finish(a)


#region 工具
## 等主游戏推进到某个阶段
func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到选卡阶段", false, "当前阶段=" + str(mg.main_game_progress))
	return false


## 等「开战」把波数写成 expect（不选卡时关卡可能自动跳过选卡，这里与时间轴解耦）
func _wait_max_wave(a, mg, expect: int, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.game_para.max_wave == expect:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到总波数变成 " + str(expect), false, str(mg.game_para.max_wave))
	return false


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[POGOPARTY] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
