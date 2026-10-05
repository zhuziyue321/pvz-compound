extends Node2D
class_name ZombossBall
## 僵王博士低头吐出的火球 / 冰球：沿一行向左滚过草坪，滚到的植物被碾平。
##
## 移植自参考项目 PVZ-Godot-main/scripts/main_game_item/zomboss_ball.gd。
## 克制关系（原版）：
##   · 火球被【寒冰菇】全场冰冻扑灭（ice_all_zombie）
##   · 冰球被【火爆辣椒】同行爆炸化解（jalapeno_bomb_lane_zombie）
## 球贴着屋面滚：每帧按当前 x 取斜面高度（MainGameSlope），顺着屋顶斜坡往左下走。

var lane := 2
var is_fire := true
var damage := 1800
var boss_ref: ZombossBoss
## 参考项目是 20 px/s（实测近 50s 才滚出屏幕，明显偏慢），原版手感约 120 px/s，
## 这里按需求调慢到 60 px/s（约原先一半，跨场约 16s），留给玩家更充裕的应对时间。
## 想再微调：直接在场景 `zombie_boss_ball.tscn` 的 Inspector 里改「Speed」，或用 `ball.speed = x`
@export var speed := 60.0
var _dead := false
var _layers: Array[Sprite2D] = []
var _row_base_y := 0.0
const BALL_Y_OFFSET := 52.0

const BALL_SCALE := 1.05
const SHADOW_SCALE := 0.95
const TEX_SHADOW := preload("res://assets/reanim/Zombie_boss_icefire_shadow.png")

## 图层来自 Zombie_boss_fireball.reanim（6 层：superglow / multiply / chunks / fireball /
## additive / icefire_shadow）。
## **不要**加 Zombie_boss_fireball_black.png —— 它在仓库任何一个 .reanim 里都没被引用过，
## 叠在底层只会把主体 1.7% 的羽化边缘填实（它的轮廓只比主体小 3px），边缘看上去发硬发脏。
## 各层的内容在自己的图里就是居中的（reanim 里 superglow 与 fireball 的图层中心只差 0.3），
## 所以 offset 一律用 ZERO、centered=true；scale 用 reanim 的 sx 比值（0.100/0.109=0.92 等）。
const FIRE_LAYERS: Array[Dictionary] = [
	{"tex": "res://assets/reanim/Zombie_boss_fireball.png", "scale": 1.0, "offset": Vector2.ZERO},
	{"tex": "res://assets/reanim/Zombie_boss_fireball_chunks.png", "scale": 1.0, "offset": Vector2.ZERO},
	{"tex": "res://assets/reanim/Zombie_boss_fireball_multiply.png", "scale": 1.0, "blend": CanvasItemMaterial.BLEND_MODE_MUL},
	{"tex": "res://assets/reanim/Zombie_boss_fireball_additive.png", "scale": 0.96, "blend": CanvasItemMaterial.BLEND_MODE_ADD},
	{"tex": "res://assets/reanim/Zombie_boss_fireball_superglow.png", "scale": 0.92, "blend": CanvasItemMaterial.BLEND_MODE_ADD},
]

## 图层来自 Zombie_boss_iceball.reanim（8 层 + shadow，crystal1 有两份）。
## crystal 的 offset 由 reanim 的图层坐标换算：先把每层的图层中心
## （x + 宽*sx/2, y + 高*sy/2）减掉 iceball 的中心，再乘换算系数 BALL_SCALE/0.128 = 8.203。
## 之前用的是拍脑袋的 (3,-4) / (-5,3) / (4,5)，三块冰晶全糊在球心，看着像抠图残留。
const ICE_LAYERS: Array[Dictionary] = [
	{"tex": "res://assets/reanim/Zombie_boss_iceball.png", "scale": 1.0, "offset": Vector2.ZERO},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_crystal1.png", "scale": 1.0, "offset": Vector2(-63.4, -30.7)},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_crystal1.png", "scale": 1.0, "offset": Vector2(58.8, 26.7)},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_crystal2.png", "scale": 1.0, "offset": Vector2(0.5, 44.4)},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_crystal3.png", "scale": 1.0, "offset": Vector2(35.8, -29.1)},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_overlay.png", "scale": 1.0, "offset": Vector2.ZERO},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_multiply.png", "scale": 1.0, "blend": CanvasItemMaterial.BLEND_MODE_MUL},
	{"tex": "res://assets/reanim/Zombie_boss_iceball_highlight.png", "scale": 1.0, "blend": CanvasItemMaterial.BLEND_MODE_ADD},
]


func setup(boss: ZombossBoss, p_lane: int, p_is_fire: bool, p_damage: int) -> void:
	boss_ref = boss
	lane = clampi(p_lane, 0, 4)
	is_fire = p_is_fire
	damage = p_damage
	_row_base_y = _get_row_base_y(lane)


func _ready() -> void:
	z_index = lane * 50 + 45
	modulate = Color.WHITE
	_build_layers()
	_update_y_on_slope()
	## 寒冰菇：全场消火球
	EventBus.subscribe("ice_all_zombie", _on_ice_all)
	## 火爆辣椒：本行消冰球
	EventBus.subscribe("jalapeno_bomb_lane_zombie", _on_jalapeno_lane)


func _build_layers() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = TEX_SHADOW
	shadow.centered = true
	shadow.position = Vector2(0, 36)
	shadow.scale = Vector2(SHADOW_SCALE, SHADOW_SCALE)
	shadow.modulate = Color(1, 1, 1, 0.32)
	add_child(shadow)
	_layers.append(shadow)

	var specs := FIRE_LAYERS if is_fire else ICE_LAYERS
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var s := Sprite2D.new()
		s.name = "Layer%d" % i
		s.texture = load(spec["tex"]) as Texture2D
		s.centered = true
		var sc: float = spec.get("scale", 1.0) * BALL_SCALE
		s.scale = Vector2(sc, sc)
		s.position = spec.get("offset", Vector2.ZERO) * BALL_SCALE
		if spec.has("blend"):
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = spec["blend"]
			s.material = mat
		add_child(s)
		_layers.append(s)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position.x -= speed * delta
	_update_y_on_slope()
	for s in _layers:
		if s.name != "Shadow":
			s.rotation -= delta * 2.4
	_flatten_cells_at_x(global_position.x)
	if global_position.x < -150.0:
		_destroy()


func _get_row_base_y(row: int) -> float:
	var main_game = Global.main_game
	if main_game == null:
		return 282.0
	if row < main_game.zombie_manager.all_zombie_rows.size():
		return main_game.get_row_base_global_y(row)
	return 282.0


## 贴屋面：行基准 y + 当前 x 的斜面高度 - 球半径
func _update_y_on_slope() -> void:
	var slope_y := 0.0
	if is_instance_valid(Global.main_game.main_game_slope):
		slope_y = Global.main_game.main_game_slope.get_all_slope_y(global_position.x)
	global_position.y = _row_base_y + slope_y - BALL_Y_OFFSET


var _last_smashed_col := -999


func _flatten_cells_at_x(x: float) -> void:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	if lane >= cells.size():
		return
	var col := int(floor((x - 45.0) / 80.0))
	if col == _last_smashed_col:
		return
	if col < 0 or col >= cells[lane].size():
		return
	_last_smashed_col = col
	var cell = cells[lane][col]
	if cell.get_curr_plant_num() > 0:
		cell.plant_be_flattened()


## 寒冰菇冰冻全场 → 火球熄灭（EventBus 传 time_ice, time_decelerate）
func _on_ice_all(_time_ice = null, _time_decelerate = null) -> void:
	if is_fire:
		_destroy()


## 火爆辣椒本行火焰 → 冰球融化
func _on_jalapeno_lane(bomb_lane: int = -1) -> void:
	if is_fire:
		return
	if bomb_lane == lane:
		_destroy()


func _destroy() -> void:
	if _dead:
		return
	_dead = true
	EventBus.unsubscribe("ice_all_zombie", _on_ice_all)
	EventBus.unsubscribe("jalapeno_bomb_lane_zombie", _on_jalapeno_lane)
	queue_free()
