extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialSpawnSun
## 生成一颗阳光：从天上掉下来，落地的那一刻起才能被点
##
## 教程要靠它给玩家东西收（原版 1-1 第三步：先掉一颗阳光，教玩家点阳光）。
## 关卡自己的天降阳光是「开战」事件里启动的，教程掉的是单独一颗，不是那个定时器。
## 没有参数


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	tutorial_manager.spawn_sun()
	## 阳光从天上掉下来要点时间，先看它落地再往下走（否则箭头会指空）
	await wait_seconds(main_game, 0.5)
