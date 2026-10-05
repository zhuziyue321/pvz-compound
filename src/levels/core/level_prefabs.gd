extends RefCounted
class_name LevelPrefabs
## 关卡流程「预制体」门面
##
## 关卡流程改由脚本（LevelScriptBase.run_flow）控制之后，原先时间轴上的事件
## 不再是「被数据轴编排的条目」，而是脚本里随手取用的一段现成流程 —— 预制体。
##
## 本门面把 `timeline_event/` 下的事件脚本包成一行式调用，关卡脚本里写
## `await prefab.show_zombie()` 即可；事件自带的 @export 参数（wait_time / timeout / plants）
## 作为方法参数传，其余通用参数（note / is_enabled / is_first_round_only）在门面里填。
##
## **加一种预制体 = 加一个方法，事件脚本本身一行都不用改。**
##
## 谁在用它：LevelScriptBase.run_flow()（关卡脚本的 prefab 字段由执行器注入，见
## LevelTimelineManager.run_timeline）

var mg: MainGameManager


func _init(main_game: MainGameManager) -> void:
	mg = main_game


## 跑一个预制体事件：填通用参数后 await 它的 run()
##
## **主游戏没了就直接放弃这段流程**：关卡协程挂在教程的等待上时玩家可能退回主菜单，
## MainGameManager 一被释放，教程那边的 signal/timer 会把协程唤醒 —— 这时候再 `event.run(mg)`
## 传的就是个已释放的对象（GDScript 会报 "previously freed ... is not a subclass of"）。
## 这里挡一道，后面每个 await 都会立刻返回，协程自己跑完退出。
func _run(event: ResourceLevelTimelineEvent, note: String) -> void:
	event.note = note
	if not is_instance_valid(mg):
		return
	await event.run(mg)


#region 预制体（与 timeline_event/ 下的事件脚本一一对应）

## 戴夫推销卡槽扩充（默认流程里只在第 1 轮跑）
func dave_sell() -> void:
	await _run(LevelTimelineEventDaveSell.new(), "戴夫推销卡槽扩充")


## 关卡戴夫对话：**说哪一段由流程现场给**（`await prefab.dave_dialog(对话)`）
## 多轮关卡按 mg.curr_game_round 自己挑（见 adventure_04_05 的三批罐子）
## 不传时才回落到关卡资源上的 crazy_dave_dialog / crazy_dave_dialog_next_round（老写法）
func dave_dialog(dialog_resource: CrazyDaveDialogResource = null) -> void:
	var event := LevelTimelineEventDaveDialog.new()
	event.dialog_resource = dialog_resource
	await _run(event, "关卡戴夫对话")


## 开场新手教程（在预览僵尸之前跑完的那种，见 TutorialManager.is_opening_tutorial）
## **教程数据由流程现场给**（`await prefab.tutorial(教程数据)`）；
## 不传时才回落到关卡资源上的 tutorial_data（老写法）。
## 普通教程（1-1 / 1-2）写在这里只做登记，真正开跑在开战之后，事件自己判断
func tutorial(tutorial_data: ResourceTutorialData = null) -> void:
	var event := LevelTimelineEventTutorial.new()
	event.tutorial_data = tutorial_data
	await _run(event, "开场新手教程")


## 保龄球红线
func bowling_stripe() -> void:
	await _run(LevelTimelineEventBowlingStripe.new(), "保龄球红线")


## 展示僵尸（相机拉到预览位，僵尸走两步）
## zombie_refresh_types —— 本关出怪表，预览僵尸按它生成；留空 = 沿用关卡数据
## （预览跑在开战之前，本关出怪表要在这里一起给，见 LevelTimelineEventShowZombie）
func show_zombie(zombie_refresh_types: Array[CharacterRegistry.ZombieType] = []) -> void:
	var event := LevelTimelineEventShowZombie.new()
	event.zombie_refresh_types = zombie_refresh_types
	await _run(event, "展示僵尸")


## 选卡：等玩家选完卡
func choose_card() -> void:
	await _run(LevelTimelineEventChooseCard.new(), "选卡")


## 相机归位（不能选卡时：预览位停一会儿再回来）
func camera_back() -> void:
	await _run(LevelTimelineEventCameraBack.new(), "相机归位")


## 纯等待 seconds 秒
func wait(seconds: float = 1.0) -> void:
	var event := LevelTimelineEventWait.new()
	event.wait_time = seconds
	await _run(event, str("等待", seconds, "秒"))


## 初始化小推车：出生在屏幕外左侧，串行地按从下到上开到位
func init_lawn_mover() -> void:
	await _run(LevelTimelineEventLawnMover.new(), "初始化小推车")


## 「准备…安放…植物」红字
func ready_set_plant() -> void:
	await _run(LevelTimelineEventReadySetPlant.new(), "准备安放植物")


## 生成僵王博士（僵王关专用：原版 5-10 的僵尸全由它投放，本关不自然出怪）
## 参数见 LevelTimelineEventSpawnZomboss；默认就是原版的站位与「重打血量 60000」
##
## 僵王的站位（含「整机往左挪多少」）只有 `ZombossBoss.ART_OFFSET` 一个值，所有僵王关共用，
## 不在这里开逐关覆盖 —— 要调左右直接改那个常量
func spawn_zomboss(anchor_row_index: int = 2, settle_time: float = 0.0) -> void:
	var event := LevelTimelineEventSpawnZomboss.new()
	event.anchor_row_index = anchor_row_index
	event.settle_time = settle_time
	await _run(event, "生成僵王博士")


## 布阵阶段：放开玩家的手（能种植）并放一个「开始战斗！」按钮，等玩家点它
## （原版迷你游戏「坚不可摧」：开局那笔阳光先拿去种防线，种好了自己点按钮开打）
## 本预制体自己会先允许操作，点完按钮再往下走，下一个事件通常是「开战」
func wait_battle_start() -> void:
	await _run(LevelTimelineEventWaitBattleStart.new(), "等待开始战斗")


## 开战：跑到本段打完为止（出怪关 = 最后一波刷完 + 僵尸清空；砸罐子 = 罐子全开 + 僵尸清空）
## 本段的出怪参数可以在这里给（关卡脚本里一眼看出「这一仗怎么打」），留默认 = 沿用关卡数据上的值：
##   max_wave —— 本段波数（> 0 生效）
##   zombie_refresh_types —— 本段出怪表（非空生效）
## timeout > 0 时最多等这么多秒
func start_battle(max_wave: int = -1,
		zombie_refresh_types: Array[CharacterRegistry.ZombieType] = [],
		timeout: float = 0.0) -> void:
	var event := LevelTimelineEventStartBattle.new()
	event.max_wave = max_wave
	event.zombie_refresh_types = zombie_refresh_types
	event.timeout = timeout
	await _run(event, "开战")


## 系统代种植物（1-1 教程的向日葵等）
func system_plant(plants: Array[PrePlantResource]) -> void:
	var event := LevelTimelineEventSystemPlant.new()
	event.plants = plants
	await _run(event, "系统种植")


## 清场：清空场上僵尸 / 罐子等，为下一批摆场做准备
func clear_field() -> void:
	await _run(LevelTimelineEventClearField.new(), "清场")


## 切换背景音乐：**跑到这一句当场换曲，不等**
## 曲目见 ConstLevelData.GameBGM（GameBGM.NoBGM = 停掉音乐）
## keep_as_main_game_bgm 留 true（默认）：开战一秒后 / 下一轮开局时主游戏会重播 BGM，不同步会被本关原曲盖回去
func change_bgm(bgm: ConstLevelData.GameBGM, keep_as_main_game_bgm: bool = true) -> void:
	var event := LevelTimelineEventChangeBgm.new()
	event.bgm = bgm
	event.keep_as_main_game_bgm = keep_as_main_game_bgm
	await _run(event, "切换BGM")
#endregion


#region 教程预制体（把新手教程拆成一句话一件事，逐个 await）
## 这一组是给「教程写在 run_flow() 里」用的：每一步都单独一个 await，
## 流程长什么样一眼就看得出来，不用回头翻 ResourceTutorialData 的 steps。
## 提示条 / 箭头 / 完成条件的判定全部复用 TutorialManager（逐步模式），本门面只做转发。
## 教程期间要先让玩家能动手 —— 在第一个教程预制体之前 await allow_operation()。

## 允许操作：放开玩家的手（能点卡 / 种植 / 收阳光），但还不出怪、不天降阳光
func allow_operation() -> void:
	await _run(LevelTimelineEventTutorialAllowOperation.new(), "允许操作")


## 教程提示文本；传空串收起提示条与箭头
func advice(text: String = "") -> void:
	var event := LevelTimelineEventTutorialAdvice.new()
	event.text = text
	await _run(event, "教程提示：" + text)


## 箭头指到卡片上（参数即要指的那张种子包）
func point_card(plant_type: CharacterRegistry.PlantType) -> void:
	var event := LevelTimelineEventTutorialPointer.new()
	event.target = ResourceTutorialStep.E_PointerTarget.Card
	event.plant_type = plant_type
	await _run(event, "箭头指向种子包")


## 箭头指到一块能种下 plant_type 的草地上
func point_lawn(plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventTutorialPointer.new()
	event.target = ResourceTutorialStep.E_PointerTarget.Lawn
	event.plant_type = plant_type
	await _run(event, "箭头指向草地")


## 箭头指到场上一颗还没收的阳光上
func point_sun() -> void:
	var event := LevelTimelineEventTutorialPointer.new()
	event.target = ResourceTutorialStep.E_PointerTarget.Sun
	await _run(event, "箭头指向阳光")


## 收起箭头（玩家该用的东西已经在手上时不该再指）
func hide_pointer() -> void:
	var event := LevelTimelineEventTutorialPointer.new()
	event.target = ResourceTutorialStep.E_PointerTarget.None
	await _run(event, "收起箭头")


## 掉一颗阳光下来（给玩家收）
func spawn_sun() -> void:
	await _run(LevelTimelineEventTutorialSpawnSun.new(), "生成一颗阳光")


## 等玩家把这张卡捡到手上；plant_type 留 Null = 任意卡
func wait_take_card(plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventTutorialWaitTakeCard.new()
	event.plant_type = plant_type
	await _run(event, "等待玩家捡起卡片")


## 等玩家种下 count 株植物；plant_type 留 Null = 任意植物
func wait_plant(count: int = 1, plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventTutorialWaitPlant.new()
	event.count = count
	event.plant_type = plant_type
	await _run(event, "等待玩家种下植物")


## 限时等玩家种下 count 株植物：**时限内种下返回 true，到点还没动手返回 false**
##
## 给「说完一句提示先让玩家自己试」用的 —— 原版 1-1 说完「阳光够了」之后是直接等的，
## 只有玩家自己不动手的那 4 秒过去了，才补那句「点击豌豆射手，再种一棵！」。
func wait_plant_timeout(count: int = 1,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null,
		timeout: float = 4.0) -> bool:
	var event := LevelTimelineEventTutorialWaitPlant.new()
	event.count = count
	event.plant_type = plant_type
	event.timeout = timeout
	await _run(event, "限时等待玩家种下植物")
	return event.is_planted


## 等玩家点掉一颗阳光
func wait_collect_sun() -> void:
	await _run(LevelTimelineEventTutorialWaitCollectSun.new(), "等待玩家收集阳光")


## 等玩家的阳光攒到 sun_value
func wait_sun_enough(sun_value: int = 100) -> void:
	var event := LevelTimelineEventTutorialWaitSunEnough.new()
	event.sun_value = sun_value
	await _run(event, "等待阳光足够")


## 教程收尾：收起提示条、停掉箭头更新、断开教程的事件订阅
func end_tutorial() -> void:
	await _run(LevelTimelineEventTutorialEnd.new(), "教程收尾")
#endregion
