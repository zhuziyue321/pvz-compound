extends LevelScriptBase
## minigame_09_beghouled_twist —— 原版迷你游戏**第 9 关**「僵尸迷阵 旋风」(Beghouled Twist)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ **未实现**：本关的三消玩法（旋转 2x2 凑三消）一行都没写，下面的 run_flow() 只是一段
## 「普通打僵尸」的骨架（预览僵尸 → 选卡 → 小推车 → 开战），**不是本关的原版玩法**。
## 为了避免玩家把它当成「已做好的第 9 关」点进去，选关场景里本关的按钮已经摘掉
## （`mini_game_choose_level.tscn` 的 ChooseLevelButton10 只留空槽位，没有 level_script）。
##
## 真正实现本关时要做的：
##   TODO(僵尸迷阵 旋风) 玩法与「僵尸迷阵」(minigame_05_beghouled) 同源，复用 BeghouledManager，
##                     区别只是**消除方式**：顺时针旋转一个 2x2 的四格来凑三消，不是交换相邻两格
##   TODO(僵尸迷阵 旋风) 通关条件同样是累计消除次数，不是打完最后一波
##   TODO(僵尸迷阵 旋风) 照 minigame_05 把 can_choosed_card / is_shovel / max_wave 这些属性补齐，
##                     玩法管理器也照它自己 new() 并持有（`BeghouledManager` 在 src/levels/script/mini_game/beghouled/ 下）：
##                     run_flow() 换成 await beghouled.setup_board() + start_beghouled()
##   TODO(僵尸迷阵 旋风) 做完后回选关场景把 ChooseLevelButton10 的 level_script / preview_icon 两行加回来


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0010"
	## 场景曲：本关是夜晚前院 → 夜晚曲 Moongrains
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 原版是黑夜前院。空实现先不开「夜间睡觉」（is_day 保持默认 true），
	## 免得玩家没带咖啡豆就全程看着蘑菇睡觉 —— 等三消玩法做完再一起接
	game_BG = ConstLevelData.GameBg.FrontNight
	is_day_sun = false
	zombie_multy = 2


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
	]

	## 展示僵尸
	await prefab.show_zombie(zombie_list)
	## 选卡
	await prefab.choose_card()
	## 准备安放植物
	## 初始化小推车
	await prefab.init_lawn_mover()
	await prefab.ready_set_plant()
	## 开战
	await prefab.start_battle(20, zombie_list)
