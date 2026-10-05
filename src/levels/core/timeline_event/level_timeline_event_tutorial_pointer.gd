extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialPointer
## 教程箭头：指到某个目标上，跟着目标走（阳光会飘、卡片会位移，箭头每帧更新）
##
## 目标与植物类型的配合：
##   · Card（种子包）—— plant_type 必填，指到那张卡的外侧
##   · Lawn（草地）—— plant_type 给了才知道「哪一格能种它」（地图是数据驱动的，不能取几何中心）
##   · Sun / Shovel / Plant 不需要 plant_type
## 传 None = 收起箭头（玩家该用到的是"手上已有的东西"时就别再指了）。

## 箭头指向的目标
@export var target: ResourceTutorialStep.E_PointerTarget = ResourceTutorialStep.E_PointerTarget.None
## 目标对应的植物类型（Card / Lawn 两个目标用得上）
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	tutorial_manager.point_to(target, plant_type)
