extends Node
## 僵尸波次管理器
class_name ZombieWaveManager

#region 波次管理器参数
## 是否有墓碑,即墓碑是否生成僵尸
var is_have_tombston := false
## 墓碑是否会在大波前继续生长(生存夜晚 / 锤僵尸类关卡为 true,普通冒险夜晚关卡为 false)
var is_tombstone_respawn := false
## 一轮游戏最大波次
var max_wave_one_round :int
## 本关携带解锁道具的波次,-1 表示本关不掉(见 ResourceLevelData.drop_unlock_wave)
var drop_unlock_wave :int = -1
#endregion

## 波次刷新管理器
@onready var zombie_wave_refresh_manager: ZombieWaveRefreshManager = $ZombieWaveRefreshManager
## 波次创建管理器
@onready var zombie_wave_create_manager: ZombieWaveCreateManager = $ZombieWaveCreateManager
## 每秒进度条更新计时器
@onready var every_wave_progress_timer: Timer = $EveryWaveProgressTimer

## 关卡进度条
@onready var flag_progress_bar: FlagProgressBar = %FlagProgressBar
## 大波时文字提醒
@onready var ui_remind_word: UIRemindWord = %UIRemindWord

## 大波僵尸时墓碑生产的僵尸类型
@export var zombie_type_candidate_tombstone :Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

## 当前波次类型
enum E_WaveType{
	Norm,		## 普通波
	FlagFront,	## 旗前波
	Flag,		## 旗帜波
	Final,		## 最后一波
}
var curr_wave_type:E_WaveType
## 最大波次(多轮游戏时更新最大波次)
var max_wave :int
## 当前波次
var curr_wave := -1
## 每波进度条所占大小
var progress_bar_segment_every_wave:float
## 每段根据当前波次时间，每秒多长
var progress_bar_segment_mini_every_sec:float

## 波次刷新信号,给zombie_manager,删除魅惑僵尸，更新是否为最后一波
signal signal_wave_refresh(is_end_wave:bool)


func _ready() -> void:
	## 刷新波次信号
	zombie_wave_refresh_manager.signal_refresh.connect(start_next_wave)
	## 新波次自然刷新时间
	zombie_wave_refresh_manager.signal_norm_time.connect(update_progress_bar_segment_mini_every_sec)

## 初始化波次管理器
func init_zombie_wave_manager(game_para:ResourceLevelData):
	is_have_tombston = game_para.is_have_tombston
	is_tombstone_respawn = game_para.is_tombstone_respawn
	max_wave_one_round = game_para.max_wave
	## 关卡结束时才掉的解锁道具(原版冒险 3-4 的车钥匙)不由僵尸携带,波次路径整关关闭
	drop_unlock_wave = -1 if game_para.drop_unlock_on_level_complete else game_para.drop_unlock_wave
	## 如果存在存档
	if game_para.save_game_data_main_game:
		curr_wave = game_para.save_game_data_main_game.curr_wave
		max_wave = game_para.save_game_data_main_game.curr_max_wave
	else:
		curr_wave = -1
		max_wave = game_para.max_wave

	flag_progress_bar.init_flag_from_wave(max_wave_one_round)
	## 关卡 max_wave 配成 1 时 (max_wave_one_round - 1) 为 0，会得到 INF/NaN
	progress_bar_segment_every_wave = 100.0 / max(1, max_wave_one_round - 1)

	zombie_wave_create_manager.init_zombie_wave_create_manager(game_para)

## 开战前改写本关波数：**关卡流程的「开战」事件带 max_wave 时走这里**
## （见 LevelTimelineEventStartBattle._apply_battle_para）
## 本管理器在 init_manager() 阶段就按关卡数据读过一遍，这里要把那一次的结果一起改掉：
## 波数、进度条每波占比、进度条上的旗帜数量
func apply_max_wave(wave_num: int) -> void:
	if wave_num <= 0 or wave_num == max_wave_one_round:
		return
	## 总波数按「改了多少」跟着挪：没跨过轮时它等于每轮波数，直接跟到新值；
	## 多轮关卡读存档时它是按轮累加出来的（见 init_zombie_wave_manager），累加关系不能丢
	max_wave += wave_num - max_wave_one_round
	max_wave_one_round = wave_num
	## 关卡 max_wave 配成 1 时 (max_wave_one_round - 1) 为 0，会得到 INF/NaN
	progress_bar_segment_every_wave = 100.0 / max(1, wave_num - 1)
	flag_progress_bar.init_flag_from_wave(wave_num)


## 多轮游戏开始下一轮僵尸波次管理器更新数据
func start_next_game_zombie_wave_mananger_update():
	max_wave += max_wave_one_round
	flag_progress_bar.start_next_game_flag_progress_bar_update()
	flag_progress_bar.visible = false
	zombie_wave_create_manager.update_zombie_refresh_types()

## 计算当前进度并更新进度条
func set_progress_bar(curr_flag:int=-1):
	var curr_progress = curr_wave % max_wave_one_round * progress_bar_segment_every_wave
	flag_progress_bar.set_progress(curr_progress, curr_flag)

## 开始第一波
func start_first_wave():
	start_next_wave()
	every_wave_progress_timer.start()
	flag_progress_bar.visible = true

## 开始刷新下一波,发射刷新下一波信号
func start_next_wave() -> void:
	curr_wave += 1
	var curr_wave_all_zombies:Array[Zombie000Base]
	## 旗前波
	if curr_wave % 10 == 8:
		curr_wave_type = E_WaveType.FlagFront
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
	## 旗帜波
	elif curr_wave % 10 == 9 :
		## 最后一波
		if curr_wave == max_wave - 1:
			curr_wave_type = E_WaveType.Final
			await ui_remind_word.zombie_approach(true)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			zombie_wave_create_manager.spawn_special_zombie_in_big_wave(true)

			## 最终波:全部墓碑各放一只伏击僵尸(原版:墓碑只在最后一大波冒僵尸,普通大波不冒)
			if is_have_tombston:
				call_tombstone_create_zombie()

		else:
			curr_wave_type = E_WaveType.Flag
			await ui_remind_word.zombie_approach(false)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			zombie_wave_create_manager.spawn_special_zombie_in_big_wave(false)

			## 会补墓碑的关卡(生存夜晚)每一个大波都是本轮的最终波,同样补墓碑 + 放伏击僵尸
			## 普通冒险夜晚关卡(2-x)只有开局那一批墓碑,这里不触发
			if is_have_tombston and is_tombstone_respawn:
				call_tombstone_create_zombie()

	## 普通波
	else:
		curr_wave_type = E_WaveType.Norm
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
		set_progress_bar()

	var wave_all_hp := 0
	for zombie:Zombie000Base in curr_wave_all_zombies:
		## 波次生成的僵尸额外连接掉血信号,旗前波死亡触发信号
		zombie.signal_zombie_hp_loss.connect(zombie_wave_refresh_manager.judge_half_refresh)
		wave_all_hp += zombie.hp_component.get_all_hp()

	zombie_wave_refresh_manager.update_wave_health_data(wave_all_hp, curr_wave_type, curr_wave)

	## 本波有僵尸携带解锁道具，它死亡时在原地把道具掉出来
	if curr_wave == drop_unlock_wave and not curr_wave_all_zombies.is_empty():
		var unlock_zombie: Zombie000Base = curr_wave_all_zombies.pick_random()
		unlock_zombie.signal_character_death.connect(
			_on_unlock_zombie_death.bind(unlock_zombie), CONNECT_ONE_SHOT
		)
		Log.debug(str("第") + str(curr_wave) + str("波僵尸携带解锁道具"))

	signal_wave_refresh.emit(curr_wave == max_wave - 1)


## 携带解锁道具的僵尸死亡，推送掉落事件（由 DropItemManager 实例化道具）
func _on_unlock_zombie_death(unlock_zombie: Zombie000Base) -> void:
	EventBus.push_event("create_unlock_drop", [unlock_zombie.global_position])

## 墓碑伏击:先补一批新墓碑(仅会生长的关卡),再由场上每个墓碑各放出一只僵尸
## 僵尸种类固定为普通 / 路障 / 铁桶三选一(见 zombie_type_candidate_tombstone)
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ))
func call_tombstone_create_zombie():
	if is_tombstone_respawn:
		EventBus.push_event("create_tombstone", [randi()%3+1])
		await get_tree().create_timer(1.0, false).timeout
	for i in range(Global.main_game.plant_cell_manager.tombstone_list.size()):
		var new_zombie_type = zombie_type_candidate_tombstone.pick_random()
		Global.main_game.plant_cell_manager.tombstone_list[i].create_new_zombie(new_zombie_type)

## 更新每秒旗帜进度(僵尸波次更新管理器信号触发)
func update_progress_bar_segment_mini_every_sec(time:float):
	## 如果是旗帜波，时间加上红字「一大波僵尸正在接近」的时长（原版约 7.45 秒）
	## 最后一波置为 0（进度条直接走到头）
	if curr_wave % 10 == 9:
		time += ui_remind_word.TIME_ZOMBIE_APPROACH
		if curr_wave == max_wave - 1:
			time = 0

	progress_bar_segment_mini_every_sec = progress_bar_segment_every_wave / time

## 随时间每秒更新进度条
func _on_every_wave_progress_timer_timeout() -> void:
	# 每秒进度条增加对应的进度值
	flag_progress_bar.set_progress_add_every_sec(progress_bar_segment_mini_every_sec)
