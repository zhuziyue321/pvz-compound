extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialAdvice
## 教程提示文本：把这段台词显示在屏幕下方的提示条上
##
## 传空串 = 收起提示条与箭头（原版这一步是 hid()），教程说完最后一句就用它。
## 提示条由 TutorialManager 的逐步模式托管，第一次调用会自动拉开提示条。

## 提示文本；留空表示隐藏提示条与箭头
@export_multiline var text: String = ""


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	tutorial_manager.show_advice_text(text)
