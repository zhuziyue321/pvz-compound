extends ResourceLevelTimelineEvent
class_name LevelTimelineEventSpawnZomboss
## 生成僵王博士 —— 原版 5-10：僵尸全部由僵王自己投放（本关 `monster_mode = Null` 不自然出怪）
##
## 僵王**不是**僵尸角色，是独立的 Node2D（见 `ZombossBoss`），由本事件在开战前放进场。
## 搬到关卡流程里之后，「哪一关有僵王 / 什么时候登场 / 站在第几行 / 重打多少血 / 血条长什么样」
## 全是关卡自己的事，MainGameManager 不再为僵王关留任何分支
## （原先是开战时自动 spawn 的那段 `_spawn_zomboss_if_needed`）。
##
## 前提：本关 `is_zomboss_fight = true`。这是关卡数据层的声明（不自然出怪、胜利 = 打死僵王），
## 与本事件的配对由本事件自己校验；能不能打到僵王是僵王自己的事（见 `ZombossBoss.is_range_detectable`）。

## 僵王血条：僵王关的 UI 归关卡侧，由本事件创建、僵王死亡时它自己销毁（`ZombossHpBar.bind_boss`）
const HP_BAR_SCENE: PackedScene = preload("res://src/levels/core/zomboss/zomboss_hp_bar.tscn")

## 锚定第几行的僵尸生成点（原版僵王压在第 3 行；行数不够时自动取最后一行）
##
## 只给「锚点」（生成点 − REANIM_ANCHOR_X）；整机还要往哪挪由僵王自己加 `ZombossBoss.ART_OFFSET`，
## **所有僵王关共用那一个值**，本事件不再提供逐关覆盖 —— 想调左右改 `ART_OFFSET.x` 即可
@export var anchor_row_index := 2
## 重打（本关已有通关记录）时的血量；<= 0 表示一律用僵王自己的默认血量
@export var repeat_hp := ZombossBoss.HP_MAX_REPEAT
## 放进去之后等几秒再走下一个事件（等登场动画落位；0 = 不等）
@export var settle_time := 0.0


func run(main_game: MainGameManager) -> void:
	if main_game.game_para == null:
		return
	if not main_game.game_para.is_zomboss_fight:
		Log.error("生成僵王事件：本关 is_zomboss_fight 为 false，僵王关要在关卡脚本 _init() 里开这个开关")
		return
	## 已经生成过就不再生成（多轮关卡 / 事件被重复排进流程时挡一道）
	if is_instance_valid(main_game.zomboss_boss):
		return
	var boss: ZombossBoss = SceneRegistry.ZOMBIE_BOSS.instantiate() as ZombossBoss
	var rows := main_game.zombie_manager.all_zombie_rows
	if rows.is_empty():
		Log.error("僵王战：僵尸行未初始化")
		boss.queue_free()
		return
	var anchor_row = rows[mini(anchor_row_index, rows.size() - 1)]
	var anchor_pos: Vector2 = anchor_row.zombie_create_position.global_position
	## 落位后的整机偏移（左移 / 右移）由僵王自己在 `_ready()` 里加 ART_OFFSET，这里只给锚点
	boss.global_position = anchor_pos + Vector2(-ZombossBoss.REANIM_ANCHOR_X, 0.0)
	main_game.add_child(boss)
	main_game.zomboss_boss = boss
	if repeat_hp > 0.0 and main_game.is_curr_level_success():
		boss.set_max_hp(repeat_hp)
	_spawn_hp_bar(main_game, boss)
	Log.debug("僵王博士登场，血量：" + str(boss.max_hp))
	await wait_seconds(main_game, settle_time)


## 血条挂在关卡信息 UI 上（原版位置：波次进度条那一条）
## 僵王关的 UI 归关卡侧：本事件只管创建，销毁由血条自己在僵王死亡时做（`ZombossHpBar.bind_boss`）
func _spawn_hp_bar(main_game: MainGameManager, boss: ZombossBoss) -> void:
	if main_game.level_info == null:
		return
	var bar := HP_BAR_SCENE.instantiate() as ZombossHpBar
	main_game.level_info.add_child(bar)
	bar.bind_boss(boss)
