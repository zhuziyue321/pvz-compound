extends RefCounted
class_name ConstBeghouled
## 僵尸迷阵（Beghouled）玩法常量
##
## 数据来源: Plants vs Zombies Wiki(https://plantsvszombies.wiki.gg/wiki/Beghouled) —— 一代原版口径：
##   夜间前院、开局草坪已铺满植物（僵尸入场那一列留空）、植物不能铲、
##   完成 **75 次配对** 通关、3 连 25 阳光 / 4 连 50 / 5 连及以上 100、
##   升级 豌豆射手→双重射手 1000、小喷菇→大喷菇 500、坚果→高坚果 250、
##   植物被啃掉留弹坑、花 200 阳光填坑、没有小推车（一只僵尸进屋即输）
##
## 待核实: 手动「重置植物」的价格 —— wiki 只写「有 100 阳光就能立刻手动重置」，这里按 100 落地

## 通关所需配对次数
const TARGET_MATCH_NUM := 75

## 一条连线长度 → 阳光奖励；超过表内长度（5 连及以上）一律按 SUN_CHAIN_MAX 给
const SUN_BY_CHAIN_LEN := {
	3: 25,
	4: 50,
}
## 长连线的阳光奖励上限
const SUN_CHAIN_MAX := 100

## 三消棋盘上的基础植物（原版六种，见 wiki「The six plants are all different colors」；
## 策略段提到的植物即这六种：豌豆射手 / 坚果 / 寒冰射手 / 小喷菇 / 星星果 / 磁力菇）
const BASE_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
	CharacterRegistry.PlantType.P004WallNut,
	CharacterRegistry.PlantType.P006SnowPea,
	CharacterRegistry.PlantType.P009PuffShroom,
	CharacterRegistry.PlantType.P030StarFruit,
	CharacterRegistry.PlantType.P032MagnetShroom,
]

## 升级项：把场上所有 from 换成 to（原版三档，价格见文件头来源注释）
## sun —— 购买价格；name —— 按钮上显示的升级目标名
const UPGRADE_LIST: Array[Dictionary] = [
	{
		"from": CharacterRegistry.PlantType.P001PeaShooterSingle,
		"to": CharacterRegistry.PlantType.P008PeaShooterDouble,
		"sun": 1000,
		"name": "双重射手",
	},
	{
		"from": CharacterRegistry.PlantType.P009PuffShroom,
		"to": CharacterRegistry.PlantType.P011FumeShroom,
		"sun": 500,
		"name": "大喷菇",
	},
	{
		"from": CharacterRegistry.PlantType.P004WallNut,
		"to": CharacterRegistry.PlantType.P024TallNut,
		"sun": 250,
		"name": "高坚果",
	},
]

## 手动重置植物（洗牌）所需阳光
const SHUFFLE_SUN := 100
## 填补一个弹坑所需阳光
const CRATER_FILL_SUN := 200

## 棋盘最右侧留空的列数（原版：僵尸入场那一列是空的，见 wiki「a lone empty column」）
const EMPTY_COL_NUM_ON_RIGHT := 1

## 按连线长度取阳光奖励（一次交换造成多组连线时各组奖励累加，见 wiki「Multiple matches ... more sun」）
static func get_sun_by_chain_len(chain_len: int) -> int:
	if chain_len >= 5:
		return SUN_CHAIN_MAX
	return int(SUN_BY_CHAIN_LEN.get(chain_len, 0))
