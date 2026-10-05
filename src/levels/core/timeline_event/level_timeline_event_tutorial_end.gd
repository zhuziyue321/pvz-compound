extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialEnd
## 教程收尾：收起提示条、停掉箭头、断开教程的事件订阅
##
## 用完教程最后一步之后要跑一次：
##   · 提示条节点还挂在 UI 层上不摘掉，后面的战斗会一直压在草坪上
##   · TutorialManager 还在跑 per-frame 判定，白白每帧解析箭头目标
## 不需要参数
## （配对的开启由教程系列事件自动完成，见 MainGameManager.ensure_tutorial_stepped_mode）


func run(main_game: MainGameManager) -> void:
	if main_game.tutorial_manager == null:
		return
	main_game.tutorial_manager.end_stepped_mode()
