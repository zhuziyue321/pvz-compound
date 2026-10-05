extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialWaitCollectSun
## 等玩家点掉一颗阳光
##
## 注意：同一个事件里卡槽也在加阳光值，「阳光够不够」是另一件事，
## 本事件只管「有没有被点」这一下（点在别的道具上不算，见 EventBus "add_sun_value"）。
## 没有参数


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	await tutorial_manager.wait_collect_sun()
