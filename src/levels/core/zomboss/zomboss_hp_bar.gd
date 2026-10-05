extends Control
class_name ZombossHpBar
## 僵王战右下角血量条（原版位置：波次进度条那一条）
##
## 移植自参考项目 PVZ-Godot-main/src/ui/main_game_ui/ui_zomboss_hp_bar.gd。
## 只做显示：血量本体在 ZombossBoss，本脚本每帧读一次。
##
## 2026-10-04 从 `src/ui/` 挪到关卡侧：**僵王关的东西归关卡** ——
## 由时间轴事件 `LevelTimelineEventSpawnZomboss` 创建它、僵王死亡时它自己销毁，
## 游戏本体（`MainGameManager` / `SceneRegistry`）不再认识这个 UI。

var _boss: ZombossBoss

@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar
@onready var hp_label: Label = $HpLabel


## 绑定僵王；同时接管销毁（与创建方对称：谁都不用再记着这个节点）
func bind_boss(boss: ZombossBoss) -> void:
	_boss = boss
	if not boss.boss_died.is_connected(queue_free):
		boss.boss_died.connect(queue_free)
	visible = true
	_update()


func _process(_delta: float) -> void:
	## 僵王已经不在场上（关卡退出 / 重开）时血条跟着走，别留在主 UI 上变成孤儿
	if not is_instance_valid(_boss):
		queue_free()
		return
	_update()


func _update() -> void:
	if _boss.is_dead:
		visible = false
		return
	var pct := _boss.curr_hp / _boss.max_hp * 100.0
	texture_progress_bar.value = pct
	hp_label.text = str(int(_boss.curr_hp))
