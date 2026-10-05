extends ResourceLevelTimelineEvent
class_name LevelTimelineEventTutorialWaitPlant
## 等玩家把植物种到草坪上
##
## plant_type 留 Null = 种什么都算过了；写上就是「非这种植物不算」
## （原版 1-1：点击草地种下豌豆射手 / 再种一棵豌豆射手）。
##
## timeout > 0 时是**限时等待**：时限内种下了才往下走，到点还没动手也往下走 ——
## 结果在 is_planted 里（关卡流程据此决定要不要补一句教学，见 LevelPrefabs.wait_plant_timeout）。

## 指定要种的植物；留 Null 表示任意植物
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
## 要种几株才算过（同一种植物可以连种几株）
@export var count: int = 1
## 最多等几秒；0 = 一直等到玩家种下为止
@export var timeout: float = 0.0

## 等待结果：true = 玩家种下了；false = 超时或教程已停（给了 timeout 才看这一项）
var is_planted := false


func run(main_game: MainGameManager) -> void:
	var tutorial_manager := main_game.ensure_tutorial_stepped_mode()
	if tutorial_manager == null:
		return
	if timeout > 0.0:
		is_planted = await tutorial_manager.wait_plant_timeout(count, plant_type, timeout)
		return
	await tutorial_manager.wait_plant(count, plant_type)
	is_planted = true
