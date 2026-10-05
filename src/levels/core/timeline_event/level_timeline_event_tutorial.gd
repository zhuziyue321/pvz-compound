extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorial
## 开场新手教程：只有「整段教学在开局前跑完」的教程关才在这里等
## （普通教程在 main_game_start() 进入 MAIN_GAME 之后才跑，见 TutorialManager）
##
## **教程数据是流程的事** —— run_flow() 里 `await prefab.tutorial(教程数据)` 现场给
## （关卡脚本把教程放在流程里构造，不再往 tutorial_data 字段上赋值）。
## 数据在流程里才构造出来，所以本事件顺带把它交给 TutorialManager
## （管理器还没建就现建，见 MainGameManager.setup_tutorial_manager）；
## 没传时才回落到关卡资源上的 tutorial_data。

## 流程现场给的教程数据（prefab.tutorial(教程数据)）；留空时取关卡资源上的 tutorial_data
var tutorial_data: ResourceTutorialData


func run(main_game: MainGameManager) -> void:
	var data := tutorial_data
	if data == null:
		data = main_game.game_para.get_tutorial_data()
	if data == null:
		return
	## 数据在流程里才构造出来：这里补交给教程管理器（管理器还没建就现建）
	main_game.setup_tutorial_manager(data)
	if main_game.tutorial_manager == null:
		return
	## 普通教程（1-1 / 1-2）不在这里等：进 MAIN_GAME 后由 MainGameManager 自己触发
	if not main_game.tutorial_manager.is_opening_tutorial():
		return
	await main_game.tutorial_manager.start_tutorial()
