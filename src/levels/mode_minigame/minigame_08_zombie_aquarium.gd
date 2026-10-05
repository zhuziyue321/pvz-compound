extends LevelScriptBase
## minigame_08_zombie_aquarium —— 原版迷你游戏**第 8 关**「僵尸水族馆」(Zombie Aquarium)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 本关没有草坪玩法：不出怪、不种植物、不天降阳光，整关就是一口鱼缸，
## 玩法本体在 `src/zombiquarium/`（数值见 `src/core/consts/const_zombiquarium.gd`）：
##   点鱼缸花 5 阳光造脑子喂潜水僵尸 -> 僵尸定时产阳光 -> 100 阳光买僵尸、1000 阳光买奖杯通关；
##   僵尸 20 秒没吃到脑子会饿死，全死光判负。
## 因此这里**不走** prefab.show_zombie / choose_card / start_battle 那套流程，只负责把
## 主游戏推进到 MAIN_GAME 阶段，然后把流程挂在水族馆的结束信号上。


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0009"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 原版水族馆播夜晚曲「Moongrains」，**不是**通用小游戏曲
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Music_(PvZ))
	## ——「The Night music is called 'Moongrains.' … This music also plays in Zombiquarium.」
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 开局 50 阳光（原版数值，见 ConstZombiquarium.SUN_START）
	start_sun = ConstZombiquarium.SUN_START
	## 本关不出怪：僵尸是养在缸里的宠物，不是敌人
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 没有植物，也就不需要选卡、小推车、天降阳光、准备安放植物
	can_choosed_card = false
	is_lawn_mover = false
	is_day_sun = false
	is_show_ready_set_plant = false
	look_show_zombie = false
	## 相机直接停在归位位（水族馆按相机左上角对齐整屏，见 ZombiquariumManager）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x


func run_flow(_mg: MainGameManager) -> void:
	## 推进到 MAIN_GAME 阶段：本关不出怪（monster_mode = Null），波次管理器不会刷僵尸，
	## 这一步只是把阶段切过去、相机归位、BGM 起来
	await _mg.main_game_start()

	## 挂上水族馆：它自己管投食、产阳光、买僵尸 / 买奖杯与胜负
	var aquarium: ZombiquariumManager = SceneRegistry.ZOMBIQUARIUM.instantiate()
	_mg.add_child(aquarium)
	aquarium.init_zombiquarium(_mg)

	var is_win: bool = await aquarium.signal_finished
	Log.debug("僵尸水族馆：关卡流程结束，is_win = %s" % str(is_win))
