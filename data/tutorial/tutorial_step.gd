extends Resource
class_name ResourceTutorialStep
## 新手教程的单步配置（原版：冒险模式 1-1 / 1-2 / 1-5 的教学流程）
##
## 一步 = 一句提示文本 + 一个「玩家做到什么才算完成」的条件 + 可选的指向目标与附加动作。
## 推进逻辑在 TutorialManager 里，本资源只描述数据；文本取自原版 advice 字符串
## （见 data/strings/lawn_strings.txt 的 ADVICE_* 条目）。

## 完成条件：玩家做了什么才算这一步结束
enum E_FinishType {
	None,				## 不需要玩家操作，等 finish_time 秒后自动进入下一步
	TakeCard,			## 玩家把卡片捡起来（拿在手上）
	PlantCount,			## 玩家种下 plant_count 株 plant_type（plant_type 为 Null 表示任意植物）
	CollectSun,			## 玩家收集一次阳光
	SunValueAtLeast,	## 当前阳光数达到 sun_value
	TakeShovel,			## 玩家把铲子拿在手上（1-5 铲子教学）
	DigPlantCount,		## 玩家铲掉 plant_count 株植物（铲除会把手上的铲子用掉，铲下一株要重新拿）
	DigAllPlants,		## 玩家把草坪上的植物全部铲光（1-5：铲完才开始传送带）
}

## 提示条箭头指向的目标
enum E_PointerTarget {
	None,	## 不显示箭头
	Card,	## 指向出战卡槽里 plant_type 对应的卡（plant_type 为 Null 时指向第一张卡）
	Lawn,	## 指向草坪中央的植物格子
	Sun,	## 指向场上的一颗阳光
	Shovel,	## 指向卡槽里的铲子
	Plant,	## 指向草坪上一株还活着的植物
}

@export_group("提示内容")
## 提示文本（建议直接使用 data/strings/lawn_strings.txt 里的原版 ADVICE_* 文本）
@export_multiline var advice_text: String = ""
## 箭头指向的目标
@export var pointer_target: E_PointerTarget = E_PointerTarget.None

@export_group("完成条件")
## 完成条件类型
@export var finish_type: E_FinishType = E_FinishType.None
## 完成条件为 None 时，等待多少秒后自动进入下一步
@export var finish_time: float = 2.0
## 完成条件为 PlantCount 时：要种的植物（Null = 任意植物）
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
## 完成条件为 PlantCount 时：要种几株
@export var plant_count: int = 1
## 完成条件为 SunValueAtLeast 时：目标阳光数
@export var sun_value: int = 0

@export_group("附加动作")
## 进入本步时先播一段戴夫对话，说完才显示本步提示（原版 1-5：铲光草坪后戴夫介绍保龄球）
@export var dave_dialog: CrazyDaveDialogResource
## 进入本步时立刻生成一颗阳光（原版：教程固定掉落一颗阳光，保证玩家有太阳可点）
@export var spawn_sun: bool = false
## 进入本步时启动第一波僵尸（原版：第一波僵尸在种下第一株植物之后才出现）
@export var start_zombie_wave: bool = false
## 进入本步时启动传送带（原版 1-5：铲完草坪上的植物之后传送带才送来保龄球坚果）
@export var start_conveyor_belt: bool = false
