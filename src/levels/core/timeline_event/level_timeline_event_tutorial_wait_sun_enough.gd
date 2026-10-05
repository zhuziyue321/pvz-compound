extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialWaitSunEnough
## 等玩家的阳光攒到 sun_value
##
## 关卡开局就给了那么多阳光时立刻往下走（不该逼玩家白等一轮收阳光），
## 判据读的是出战卡槽当前的阳光数（见 TutorialManager._get_curr_sun_value）。

## 要攒到的阳光数（够买一株豌豆射手 = 100）
@export var sun_value: int = 100


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	await tutorial_manager.wait_sun_at_least(sun_value)
