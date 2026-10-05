extends LevelScriptBase
## minigame_05_beghouled —— 原版迷你游戏**第 5 关**「僵尸迷阵」(Beghouled)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## **本关的三消玩法全部归本文件管**（硬约束 §1-8：一关专属机制不进游戏本体）：
##   · 玩法本体 `BeghouledManager`、界面 `BeghouledUI`、数值 `ConstBeghouled` 都在
##     `src/levels/script/mini_game/beghouled/` 下，只被本关引用
##   · 管理器由**本脚本自己 new() 并持有**（见 init_level_items / _init_beghouled），
##     本体（`MainGameManager`）不认识它，关卡数据上也没有「是不是三消关」这种开关字段
##   · 本体给的是通用口子 `MainGameManager.register_level_init_callback()`：
##     本脚本注册一条回调，主游戏跑完所有子管理器 init_manager() 之后回调它
##
## 玩法：草坪开局铺满植物（最右一列留空给僵尸入场）→ 交换相邻两株凑三个及以上同类连线
##   → 消除给阳光（3 连 25 / 4 连 50 / 5 连及以上 100）→ 累计 75 次配对通关。
##   植物被僵尸啃掉会留弹坑（花 200 阳光填），阳光还能买三档升级与手动重置。
##
## 数据来源: Plants vs Zombies Wiki(https://plantsvszombies.wiki.gg/wiki/Beghouled)（一代原版口径）

## 本关的三消玩法管理器（本脚本创建并持有，本体没有对应字段）
var beghouled: BeghouledManager = null


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0006"
	## 场景曲：本关是夜晚前院 → 夜晚曲 Moongrains
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 原版是黑夜前院；但本关蘑菇是醒着的（原版僵尸迷阵里蘑菇不睡觉），所以 is_day 保持 true
	game_BG = ConstLevelData.GameBg.FrontNight
	## 阳光只来自配对，不天降
	is_day_sun = false
	## 原版没有小推车也没有钉耙：任意一只僵尸走到屋里就算输
	is_lawn_mover = false
	## 植物是系统铺的，玩家没有卡片可选，也不能铲（原版植物不能铲掉）
	can_choosed_card = false
	is_shovel = false
	## 出战卡槽只留一个占位（本关没有卡片，留它是为了让阳光计数有地方显示）
	max_choosed_card_num = 1
	## 开局没有阳光，全靠配对攒
	start_sun = 0
	## 原版本关是无限波（wiki：unlimited number of flags），这里给一个足够大的波数；
	## 必须是 10 的倍数，否则波次进度条 init_flag_from_wave() 的断言会失败
	max_wave = 100


#region 三消的接入（本关专属，本体不认识）
## 进关时（格子已建好、玩家还动手不了）把三消接进主游戏：
## **只注册一条回调，不立刻创建** —— 棋盘要读 PlantCellManager 的格子，
## 掩掉波次进度条要等 ZombieManager 初始化；回调排在所有子管理器 init_manager() 之后，两样都齐了
## （时机说明见 MainGameManager.level_init_callbacks）
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	mg.register_level_init_callback(Callable(self, "_init_beghouled").bind(mg))


## 真正创建三消管理器：挂到主游戏的 Manager 节点下，与本体的其它子管理器同一套路
func _init_beghouled(mg: MainGameManager) -> void:
	if is_instance_valid(beghouled):
		return
	beghouled = BeghouledManager.new()
	beghouled.name = "BeghouledManager"
	mg.manager.add_child(beghouled)
	beghouled.init_manager()
#endregion


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
	]

	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 相机归位（本关不走选卡，预览后直接回来摆场）
	await prefab.camera_back()
	## 正常走 init_level_items 注册进来的回调时管理器已经有了；
	## 没走到的场合（比如关卡脚本被直接跑）这里兜底建一次，保证流程拿得到它
	if not is_instance_valid(beghouled):
		_init_beghouled(mg)
	if not is_instance_valid(beghouled):
		Log.error("僵尸迷阵：三消管理器没建起来，本关无法开局")
		return
	## 摆场：草坪铺满植物，并放出三消界面（配对进度 + 升级 / 重置 / 填坑按钮）
	## 必须 await：摆场内部要等两帧让格子槽位空出来，不等的话它会和 main_game_start() 抢着跑
	await beghouled.setup_board()
	## 开战并等到达标：结束条件是配对次数，不是「打完最后一波 + 僵尸清空」
	## （所以这里不走 prefab.start_battle()，见 BeghouledManager.start_beghouled）
	await beghouled.start_beghouled(zombie_list)
