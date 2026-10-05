extends Camera2D
class_name MainGameCamera


## 当前正在播放的位移 Tween，用于互斥
var curr_move_tween: Tween


# 返回 Tween 对象，供外部 await
func move_to(target_pos: Vector2, duration: float) -> Signal:
	## 已经在目标位置：不再播一次空位移，直接给一个立刻完成的信号。
	## 关卡流程自己排的 CameraBack 事件常会叠在「选卡」内部的相机归位之后
	## （choose_card_finish 已经 await 过 move_back_ori），重复跑会让玩家白等一轮 duration
	if duration <= 0.0 or global_position.is_equal_approx(target_pos):
		return get_tree().create_timer(0.0).timeout
	## 不 kill 上一个 Tween 会让两个 Tween 同时写 global_position（相机抖动/停在中途）
	if curr_move_tween != null and curr_move_tween.is_valid():
		curr_move_tween.kill()
	var tween = create_tween()
	curr_move_tween = tween

	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	return tween.finished


## 相机三个停靠点全部按「背景图」算，不写死魔数：
## 背景贴图 1400x600（res://assets/image/background/*.jpg），背景 Sprite2D 是
## centered = false、position = (-210, 0)（见 src/world/background/*.tscn），
## 所以背景占的世界区间是 x ∈ [-210, 1190]、y ∈ [0, 600]。
## 视口 800x600（project.godot），anchor_mode = FixedTopLeft →
## camera.position.x 就是「可见区左上角」的世界 x（screen_x = world_x - position.x）。
##
## 改分辨率 / 换背景尺寸时只动这三个常量，别去改各调用点。
const BG_LEFT_X := -210.0      ## 背景左上角（= 背景 Sprite2D 的 position.x）
const BG_WIDTH := 1400.0       ## 背景贴图宽
const VIEW_WIDTH := 800.0      ## 视口宽（与 project.godot 的 viewport 宽一致）

## 进关时：可见区左上角 == 背景左上角 → 拍到最左侧的房子（world -181..-32）
const CAM_POS_INIT := Vector2(BG_LEFT_X, 0)
## 开战前看僵尸：可见区右上角 == 背景右上角 → 拍到最右侧的僵尸入场马路
const CAM_POS_LOOK_ZOMBIE := Vector2(BG_LEFT_X + BG_WIDTH - VIEW_WIDTH, 0)
## 相机归位点（选卡结束 / 看僵尸结束回到这里）：背景左上角往右 220px
## → 可见区 = world 10..810，草坪（col_x 45..764）+ 左侧小推车（x = 20 + 小推车宽）正好装下，
## 房子留在屏幕外，由失败流程（mgm_lose_manager）平移去拍 CAM_POS_INIT
const CAM_POS_BACK_OFFSET := 220.0
const CAM_POS_ORI := Vector2(BG_LEFT_X + CAM_POS_BACK_OFFSET, 0)


func _ready() -> void:
	## 场景里摆的 Camera2D.position 与常量不同步时以常量为准
	## （两处不同步的坑见 docs/工作记录/2026-10-03_分辨率改成800x600.md）
	global_position = get_init_position()


## 进关停靠点：关卡数据上配了 camera_init_x 就以关卡为准（见 ResourceLevelData.camera_init_x），
## 没配就是背景最左侧（拍到房子）。
## 能在这里读到关卡数据：MainGameManager._enter_tree() 先设好 Global.main_game / game_para，
## 子节点（本相机）的 _ready 才跑。
func get_init_position() -> Vector2:
	var x := CAM_POS_INIT.x
	if Global.main_game != null and Global.main_game.game_para != null \
			and Global.main_game.game_para.has_camera_init_x():
		x = Global.main_game.game_para.camera_init_x
	return Vector2(x, CAM_POS_INIT.y)


## 瞬移（不播位移）：给「不走选卡就开战」的入口兜底用，见 MainGameManager.main_game_start
func snap_to(target_pos: Vector2) -> void:
	if curr_move_tween != null and curr_move_tween.is_valid():
		curr_move_tween.kill()
	global_position = target_pos


## 开始游戏查看僵尸
func move_look_zombie():
	return move_to(CAM_POS_LOOK_ZOMBIE, 2)

## 返回原点
func move_back_ori():
	return move_to(CAM_POS_ORI, 2)
