extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialWaitTakeCard
## 等玩家把卡片捡到手上（玩家点了卡槽里的某张卡）
##
## plant_type 留 Null = 捡哪张卡都算过了；写上就是「非这张不可」
## （原版 1-1 第一步：捡起豌豆射手的种子包）。
## 玩家手上已经有东西时立刻往下走，不会卡住（见 TutorialManager._is_step_condition_satisfied）。

## 指定要捡的植物；留 Null 表示任意卡
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	await tutorial_manager.wait_take_card(plant_type)
