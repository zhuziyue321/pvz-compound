extends LevelScriptBase
## adventure_04_09 —— 由同目录的 adventure_04_09.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Fog
	game_BGM = ConstLevelData.GameBGM.Fog
	is_fog = true
	is_day = false
	is_day_sun = false


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z017Balloon,
		CharacterRegistry.ZombieType.Z019Pogo,
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
