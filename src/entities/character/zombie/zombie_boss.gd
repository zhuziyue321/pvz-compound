extends Node2D
class_name ZombossBoss
## 僵王博士（Dr. Zomboss）—— 冒险 5-10 最终关 & 小游戏「僵尸博士的复仇」的 Zombot。
##
## 机制忠实原版：休息计时 → 动作队列（投放 / 踩踏 / RV / 天降蹦极），
## 头部吐火球 / 冰球是**独立冷却循环**，只有低头期间才可能被植物打到。
## 血量 40000，阶段阈值 80% / 50% / 10%（提速），死亡后加速演出 + 爆炸闪烁 → 奖杯。
##
## 2026-10-05 **整套重做**：按用户要求推倒此前的一批「对齐原版」增强，
## **严格照参考项目重新写一遍**，出招节奏与范围回到参考口径
## （见 [工作记录](../../../docs/工作记录/2026-10-05_僵王本体重做为参考口径.md)）。
## 同日**按用户要求改回原版口径**（同一轮里逐次点名，最后四条全改）：
##   - **放僵尸**：开局走固定剧本（4 普僵 → 4~5 路障 → 低头 → 4~5 铁桶偶尔混 1 只路障 → 再低头），
##     剧本后随机且不再出普僵，投放行只挑「小推车还在」的行（_build_opening_script / _pick_spawn_row）
##   - **踩踏**：2 行 × 最右侧 4 列（STOMP_ROW_COUNT / STOMP_COL_COUNT），候选是「行对起始行」
##   - **蹦极 / 房车**：第 3 / 4 次低头后解锁，之后每轮 50% 追加一招（HEAD_COUNT_UNLOCK_*）
##   - **死亡**：清场（原版 boss 一死，它召唤的僵尸跟着 despawn）
## 数据来源口径统一见 [docs/参考存档/特殊关卡.md](../../../docs/参考存档/特殊关卡.md#僵王博士dr-zomboss本体)。
##
## 移植自参考项目 PVZ-Godot-main/scripts/character/zombie/zombie_boss.gd。
## 只有这几处不是照抄，属于「接进本仓库」所必需的适配，改了会断链或违反硬约束：
##   1. `Global.ZombieType` / `Global.AttackMode` → `CharacterRegistry` / `BulletRegistry`（硬约束 §1-4：类型映射走注册表）
##   2. `push_error` / `push_warning` → `Log.error` / `Log.warn`（硬约束 §1-6）
##   3. 冰火球走 `SceneRegistry.ZOMBOSS_BALL`（硬约束 §1-4：业务代码不散落场景路径）
##   4. 保留 `max_hp` / `set_max_hp()` / `HP_MAX_REPEAT`：重打时 60000 血，
##      由关卡流程的「生成僵王」事件写入（LevelTimelineEventSpawnZomboss），血条按 `max_hp` 算百分比
##   5. 保留 `is_range_detectable`：僵王站在场外，植物射线常常够不到，
##      索敌组件靠这条「按位置直接锁定」的兜底路径才打得到（DetectComponent._try_zomboss_by_range）
##   6. 保留 `ART_OFFSET`：关卡只给锚点，整机落位微调是僵王自己的事（所有僵王关共用这一个值）
##   7. `_exit_tree()` 退订 EventBus：本仓库会重复进关，不退订会留下悬垂回调
##
## 为什么是独立 Node2D 而不是僵尸角色：
##   僵王的躯干是 reanim 拆出来的 ~50 个 Sprite2D，由 23 段动画直接驱动，
##   没有「走 / 啃 / 死」这类可以喂给组件状态机的行为，也没有血量组件意义上的防具分层；
##   它对外只需要对齐两个鸭子类型属性（`hurt_box_component` / `is_death`）和一个受击签名
##   （`be_attacked_bullet`），就能无缝接进已有的植物检测 / 子弹 / 溅射链路。
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Dr._Zomboss_(PvZ))
##   - 血量 40000
##   - 掉到 32000 / 20000 时头、下巴、右手、脚换受损贴图
##   - 火球被寒冰菇扑灭，冰球被同行火爆辣椒化解

signal boss_died

const HP_MAX := 40000.0
## 重打（本关已有通关记录）时的血量，由关卡流程的「生成僵王」事件写入
## （LevelTimelineEventSpawnZomboss.repeat_hp → set_max_hp）
const HP_MAX_REPEAT := 60000.0
const BALL_DAMAGE := 1800
## reanim 部件局部锚点（Boss_body2 / 腿等），场景原点与此错位 ~660px
const REANIM_ANCHOR_X := 660.0
const REANIM_ANCHOR := Vector2(REANIM_ANCHOR_X, -100.0)
## 投手抛物线瞄准点（相对 hurt_box；正值 = 更靠下）
const PULT_AIM_OFFSET := Vector2(0, 90)
## 手臂投放点 / 吐球 X（相对机体原点）
const SPAWN_MARKER := Vector2(REANIM_ANCHOR_X - 40.0, -60.0)
const BALL_MARKER := Vector2(REANIM_ANCHOR_X - 55.0, -90.0)
## 整机贴图偏移（相对关卡给的落位点）—— **所有僵王关都用这一个值**，调左右只改这里
##
## 关卡只负责给锚点（见 LevelTimelineEventSpawnZomboss：第 3 行生成点 − REANIM_ANCHOR_X），
## 落位后的微调写在僵王自己身上，`_ready()` 里一次性加上，任何生成路径拿到的都是同一套站位。
## X **越小 = 整机越靠左（越入画）**；受击框 / 手臂投放点 / 吐球点全挂在同一个原点上，会跟着一起走。
## 动画是绝对关键帧 —— **不要**去改 `zombie_boss.tscn` 里 reanim 部件的局部坐标，改了不生效。
const ART_OFFSET := Vector2(-260.0, -350.0)
const TEX_EYEGLOW := preload("res://assets/reanim/Zombie_boss_eyeglow.png")
const TEX_MOUTHGLOW := preload("res://assets/reanim/Zombie_boss_mouthglow.png")
const TEX_EYEGLOW_RED := preload("res://assets/reanim/Zombie_boss_eyeglow_red.png")
const TEX_EYEGLOW_BLUE := preload("res://assets/reanim/Zombie_boss_eyeglow_blue.png")
const TEX_MOUTHGLOW_RED := preload("res://assets/reanim/Zombie_boss_mouthglow_red.png")
const TEX_MOUTHGLOW_BLUE := preload("res://assets/reanim/Zombie_boss_mouthglow_blue.png")
## 源图是 jpg + 黑白蒙版（neck_.png / upperbody_.png），
## 已用 tools/merge_alpha.ps1 把蒙版烘进 alpha，加载的是烘焙后的 RGBA png
const TEX_NECK := preload("res://assets/reanim/Zombie_boss_neck.png")
const TEX_UPPERBODY := preload("res://assets/reanim/Zombie_boss_upperbody.png")
const COCKPIT_BODY1_POS := Vector2(528.5, 154.032)
const COCKPIT_BODY1_ROT := -0.286234
const COCKPIT_NECK_POS := Vector2(553.6, 170.46399)
const COCKPIT_NECK_ROT := -0.033161
const COCKPIT_SCALE := Vector2(0.796, 0.796)
const COCKPIT_IDLE_ANIM := "Zombie_boss_idle"
const HEAD_ANIM_PREFIX := "Zombie_boss_head"
const HEAD_PARTS: Array[String] = [
	"Boss_head",
	"Boss_jaw",
	"Boss_innerjaw",
	"Boss_mouthglow",
	"Boss_mouthglow_red",
	"Boss_eyeglow",
	"Boss_eyeglow_red",
	"Boss_head2",
	"Boss_antenna",
]
## 破损阶段贴图（原版：8000 / 20000 伤害后切换）
const DAMAGE_PARTS: Dictionary = {
	"Boss_head": [
		preload("res://assets/reanim/Zombie_boss_head.png"),
		preload("res://assets/reanim/Zombie_boss_head_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_head_damage2.png"),
	],
	"Boss_jaw": [
		preload("res://assets/reanim/Zombie_boss_jaw.png"),
		preload("res://assets/reanim/Zombie_boss_jaw_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_jaw_damage2.png"),
	],
	"Boss_outerleg_foot": [
		preload("res://assets/reanim/Zombie_boss_foot.png"),
		preload("res://assets/reanim/Zombie_boss_foot_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_foot_damage2.png"),
	],
	"Boss_outerarm_hand": [
		preload("res://assets/reanim/Zombie_boss_outerarm_hand.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_hand_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_hand_damage2.png"),
	],
	"Boss_outerarm_thumb1": [
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb1.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb_damage2.png"),
	],
	"Boss_outerarm_thumb2": [
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb2.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb_damage1.png"),
		preload("res://assets/reanim/Zombie_boss_outerarm_thumb_damage2.png"),
	],
}
## 各动画时长（与 tres 一致）
const T_ENTER := 3.25
const T_IDLE := 1.166667
const T_DEATH := 8.833333
const T_RV := 3.083333
const T_BUNGEE_IN := 2.0
const T_BUNGEE_OUT := 1.416667
const T_HEAD_ENTER := 4.666667
const T_HEAD_LEAVE := 3.666667
## 低头吐球后 idle 停留（给植物输出窗口）
const HEAD_IDLE_DWELL := 4.0
## 吐球冷却
const HEAD_COOLDOWN := 20.0
## 第 3 次低头后解锁天降蹦极，第 4 次后解锁 RV，之后两招进随机池
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Dr._Zomboss_(PvZ)) §Strategies
const HEAD_COUNT_UNLOCK_BUNGEE := 3
const HEAD_COUNT_UNLOCK_RV := 4
## 两次解锁都完成后，每轮额外追加一招（蹦极 / RV 各半）的概率
const SPECIAL_ACTION_CHANCE := 0.5
## 踩踏范围（原版：最右侧 4 列 × 2 行）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Dr._Zomboss_(PvZ)) §Attacks
const STOMP_COL_COUNT := 4
const STOMP_ROW_COUNT := 2
## 阶段休息时间（Stage1/2/3）—— 给植物更多输出窗口
const REST_BY_STAGE: Array[float] = [8.0, 7.0, 6.0]
## 投放间隔（Stage1/2/3）—— 同一批「连着放」时每只之间的最小间隔
## （参考项目定义了这张表但 `_do_spawn()` 里没用到（它是一轮一只），
##  本仓库按原版「一批连着放」的口径把它用在批内间隔上）
const SPAWN_GAP_BY_STAGE: Array[float] = [3.5, 3.0, 2.6]
## 投放动画播到 0.85s 时松手（手臂落到最低点）
const SPAWN_DROP_DELAY := 0.85
## 开局固定剧本（原版 5-10 的 set pattern，逐条见 _build_opening_script）
const OPENING_NORM_COUNT := 4
const OPENING_CONE_COUNT := Vector2i(4, 5)			## x = 最少，y = 最多
const OPENING_BUCKET_COUNT := Vector2i(4, 5)
## 铁桶批里混 1 只路障的概率（原版「sometimes he places one Conehead Zombie」）
const OPENING_BUCKET_MIX_CONE_CHANCE := 0.35
## action_queue 里的动作类型
const ACT_SPAWN := "Spawn"
const ACT_HEAD := "Head"
## 剧本走完后的随机池：对齐原版 5-10 的 Summoned 列表
## **不再出普通僵尸**；蹦极走天降不进池，小鬼由伽刚特尔自己扔
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_5-10)
const POOL_LATE: Array[int] = [
	CharacterRegistry.ZombieType.Z006Paper,
	CharacterRegistry.ZombieType.Z007ScreenDoor,
	CharacterRegistry.ZombieType.Z004PoleVaulter,
	CharacterRegistry.ZombieType.Z008Football,
	CharacterRegistry.ZombieType.Z016Jackbox,
	CharacterRegistry.ZombieType.Z022Ladder,
	CharacterRegistry.ZombieType.Z024Gargantuar,
	CharacterRegistry.ZombieType.Z013Zamboni,
	CharacterRegistry.ZombieType.Z023Catapult,
	CharacterRegistry.ZombieType.Z019Pogo,
]

var _anim_players: Dictionary = {}
var _active_anim_player: AnimationPlayer

var max_hp := HP_MAX
var curr_hp := HP_MAX
var stage := 1						## 当前阶段 1..3
var is_resting := true
var rest_timer := 0.0
var rest_time := REST_BY_STAGE[0]
var round_count := 0					## 已完成动作轮数
var action_queue: Array[Dictionary] = []		## 本轮待执行动作 {"act": ACT_*, "types": [...]}
var _opening_script: Array[Dictionary] = []		## 开局固定剧本（原版 set pattern），一轮消费一条
var head_attack_count := 0				## 已完成低头次数（原版用它解锁蹦极 / RV）
var _is_bungee_unlocked := false
var _is_rv_unlocked := false
var _forced_next_action := ""				## 解锁当轮强制排出去的那一招
var head_cooldown := HEAD_COOLDOWN			## 吐球冷却计时
var is_busy := false					## 正在播放攻击动画
var is_dead := false
var _head_attack_lane := 2
var damage_level := 0
var _head_glow_fire := true
var _head_glow_active := false
var is_head_vulnerable := false
## 是否接受「按位置直接锁定」这种索敌（僵王站在场外，植物的射线常常够不到它，
## 平时就靠这条路径才打得到 —— 见 DetectComponent._try_zomboss_by_range）。
## 检测组件只认这个声明，不认识任何关卡开关：某关想让僵王不被自动锁定（例如它只是背景演出），
## 由关卡脚本 / 生成事件把它压成 false
var is_range_detectable := true
var _is_frozen := false
var _freeze_timer: Timer
var _ice_effect: Node2D
var _anim_speed_backup: Dictionary = {}
var _hurt_area: Area2D
var _detect_area: Area2D

## 抛物线子弹追踪用（对齐 Character000Base.hurt_box_component）
var hurt_box_component: Area2D:
	get:
		return _hurt_area

## 对齐 Character000Base.is_death
var is_death: bool:
	get:
		return is_dead


func _enter_tree() -> void:
	## 场景默认是 idle 驾驶舱姿态；进场前先全隐藏，避免 add_child 到 _ready 之间闪一帧
	_hide_all_sprite_parts()


func _hide_all_sprite_parts() -> void:
	for child in get_children():
		if child is Sprite2D:
			(child as Sprite2D).visible = false


func _ready() -> void:
	## 整机按 ART_OFFSET 落位：关卡只给锚点，贴图微调是僵王自己的事（所有僵王关同一个值）
	global_position += ART_OFFSET
	## 绘制层级高于背景与普通单位
	z_index = 260
	_setup_hurt_box()
	_setup_detect_box()
	_cache_anim_players()
	_opening_script = _build_opening_script()
	_apply_cockpit_textures()
	EventBus.subscribe("ice_all_zombie", _on_ice_all_zombie)
	EventBus.subscribe("jalapeno_bomb_lane_zombie", _on_jalapeno_lane)
	_play_enter()


func _exit_tree() -> void:
	EventBus.unsubscribe("ice_all_zombie", _on_ice_all_zombie)
	EventBus.unsubscribe("jalapeno_bomb_lane_zombie", _on_jalapeno_lane)


## 设置血量上限（首次 40000 / 重打 60000；由「生成僵王」事件调用）
func set_max_hp(value: float) -> void:
	max_hp = value
	curr_hp = value


func _setup_hurt_box() -> void:
	var area := Area2D.new()
	area.name = "HurtBoxReal"
	area.collision_layer = 512
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	## Area 中心对齐头部，子弹瞄准 / 碰撞用 global_position
	area.position = REANIM_ANCHOR + Vector2(-80.0, -120.0)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200.0, 280.0)
	shape_node.shape = rect
	area.add_child(shape_node)
	add_child(area)
	## 运行时节点必须手动设 owner，子弹 / 射线用 area.owner 识别僵王
	area.owner = self
	_hurt_area = area


func _setup_detect_box() -> void:
	var area := Area2D.new()
	area.name = "HurtBoxDetection"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitorable = false
	area.monitoring = false
	## 覆盖全行高度，方便植物水平射线重叠检测
	area.position = REANIM_ANCHOR + Vector2(-40.0, 40.0)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(180.0, 520.0)
	shape_node.shape = rect
	area.add_child(shape_node)
	add_child(area)
	area.owner = self
	_detect_area = area


func _set_head_vulnerable(v: bool) -> void:
	is_head_vulnerable = v
	if _hurt_area != null:
		_hurt_area.monitorable = v
		var mon := _hurt_area.monitoring
		_hurt_area.monitoring = not mon
		_hurt_area.monitoring = mon
	if _detect_area != null:
		_detect_area.monitorable = v
	## 通知植物重新判定攻击目标
	EventBus.push_event("zomboss_head_vulnerable", [v])


func _cache_anim_players() -> void:
	for child in get_children():
		if child is AnimationPlayer:
			var player := child as AnimationPlayer
			for anim_name in player.get_animation_list():
				_anim_players[anim_name] = player
				## 头部动画保留 cockpit 轨道（neck / upperbody 跟随头部运动）
				if not anim_name.begins_with(HEAD_ANIM_PREFIX):
					_strip_cockpit_texture_tracks(player.get_animation(anim_name))
	if _anim_players.is_empty():
		Log.error("僵王：未找到 AnimationPlayer")


## 驾驶舱 body1 / neck 全部由脚本控制；剥离所有相关动画轨道（含空 key 轨道，避免 Godot 报错）
func _strip_cockpit_texture_tracks(anim: Animation) -> void:
	if anim == null:
		return
	for i in range(anim.get_track_count() - 1, -1, -1):
		var track_path := str(anim.track_get_path(i))
		if track_path.begins_with("Boss_body1:") or track_path.begins_with("Boss_neck:"):
			anim.remove_track(i)


func _get_anim_player(anim_name: String) -> AnimationPlayer:
	if _anim_players.has(anim_name):
		return _anim_players[anim_name]
	var node_name := "Anim_" + anim_name
	var player := get_node_or_null(node_name) as AnimationPlayer
	if player != null:
		_anim_players[anim_name] = player
		return player
	Log.warn("僵王：缺少动画 %s" % str(anim_name))
	return _active_anim_player if _active_anim_player != null else get_child(0) as AnimationPlayer


func _play_anim(anim_name: String, loop := false) -> void:
	var player := _get_anim_player(anim_name)
	if player == null or not player.has_animation(anim_name):
		return
	var anim := player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	## 先让新动画第 0 帧立即生效，再停其它播放器，避免部件停在上一姿态闪一帧
	player.play(anim_name)
	player.seek(0.0, true)
	for child in get_children():
		if child is AnimationPlayer and child != player:
			(child as AnimationPlayer).stop()
	_active_anim_player = player
	_apply_cockpit_textures()
	_apply_damage_look()
	_post_anim_switch_fixup(anim_name)


func _snap_cockpit_pose() -> void:
	var body1 := get_node_or_null("Boss_body1") as Sprite2D
	if body1 != null:
		body1.visible = true
		body1.position = COCKPIT_BODY1_POS
		body1.rotation = COCKPIT_BODY1_ROT
		body1.scale = COCKPIT_SCALE
	var neck := get_node_or_null("Boss_neck") as Sprite2D
	if neck != null:
		neck.visible = true
		neck.position = COCKPIT_NECK_POS
		neck.rotation = COCKPIT_NECK_ROT
		neck.scale = COCKPIT_SCALE


func _hide_head_parts() -> void:
	for part_name in HEAD_PARTS:
		var spr := get_node_or_null(part_name) as Sprite2D
		if spr != null:
			spr.visible = false


func _hide_cockpit_parts() -> void:
	var body1 := get_node_or_null("Boss_body1") as Sprite2D
	if body1 != null:
		body1.visible = false
	var neck := get_node_or_null("Boss_neck") as Sprite2D
	if neck != null:
		neck.visible = false


func _post_anim_switch_fixup(anim_name: String) -> void:
	if anim_name == COCKPIT_IDLE_ANIM:
		_hide_cockpit_parts()
		_hide_head_parts()
	elif anim_name == "Zombie_boss_enter":
		## enter 第 0 帧应是整机入画（body2 可见、驾驶舱隐藏），不能套用 idle 驾驶舱 snap
		_hide_cockpit_parts()
		_hide_head_parts()
		if is_instance_valid(_active_anim_player):
			_active_anim_player.seek(0.0, true)
	elif anim_name.begins_with(HEAD_ANIM_PREFIX):
		## 头部动画保留 cockpit 轨道，neck / upperbody 跟随头部运动
		var body1 := get_node_or_null("Boss_body1") as Sprite2D
		if body1 != null:
			body1.visible = true
		var neck := get_node_or_null("Boss_neck") as Sprite2D
		if neck != null:
			neck.visible = true
	else:
		_hide_cockpit_parts()
		_hide_head_parts()


func _apply_damage_look() -> void:
	_apply_cockpit_textures()
	for node_name in DAMAGE_PARTS:
		var spr := get_node_or_null(node_name) as Sprite2D
		if spr == null:
			continue
		var texs: Array = DAMAGE_PARTS[node_name]
		spr.texture = texs[mini(damage_level, texs.size() - 1)]


## 按「已损失血量占比」决定破损外观（原版 20% / 50%）。
## 参考项目写死 32000 / 20000，那是 40000 血下的同一组阈值（32000 = 掉 20%、20000 = 掉 50%）；
## 这里按比例算，是为了重打时 60000 血也能在同一节奏上换贴图。
func _damage_level_from_hp() -> int:
	var loss_ratio := 1.0 - curr_hp / max_hp
	if loss_ratio >= 0.5:
		return 2
	if loss_ratio >= 0.2:
		return 1
	return 0


func _apply_cockpit_textures() -> void:
	var neck := get_node_or_null("Boss_neck") as Sprite2D
	if neck != null:
		neck.texture = TEX_NECK
	var body1 := get_node_or_null("Boss_body1") as Sprite2D
	if body1 != null:
		body1.texture = TEX_UPPERBODY


func _play_enter() -> void:
	is_busy = true
	_play_anim("Zombie_boss_enter")
	await _active_anim_player.animation_finished
	is_busy = false
	_apply_damage_look()
	_play_anim("Zombie_boss_idle", true)


func _physics_process(delta: float) -> void:
	if is_dead or _is_frozen:
		return
	if _head_glow_active:
		_apply_head_glow(_head_glow_fire)
	if is_resting and not is_busy:
		rest_timer += delta
		## 剧本期间低头只认剧本里的节点：随机冷却冻结（不冻结会抢在剧本前面，
		## 「先放 9 只再低头」永远走不出来）
		if _opening_script.is_empty():
			head_cooldown -= delta
			if head_cooldown <= 0.0:
				head_cooldown = HEAD_COOLDOWN
				_do_head_attack()
				return
		else:
			head_cooldown = HEAD_COOLDOWN
		if rest_timer >= rest_time:
			rest_timer = 0.0
			_build_round_queue()
			is_resting = false
			_run_next_action()
	elif not is_resting and not is_busy:
		if _opening_script.is_empty():
			head_cooldown -= delta
			if head_cooldown <= 0.0:
				head_cooldown = HEAD_COOLDOWN
				_do_head_attack()
		else:
			head_cooldown = HEAD_COOLDOWN
		if not is_busy and not action_queue.is_empty():
			_run_next_action()
		elif not is_busy:
			is_resting = true

## ===== 动作队列（参考 HE SetStateList 规则） =====
func _build_round_queue() -> void:
	action_queue.clear()
	round_count += 1
	## 开局剧本还没走完：一轮消费一条，期间不追加踩踏 / 天降 / RV
	## （原版开局只有「放僵尸」和「低头」两件事）
	if not _opening_script.is_empty():
		action_queue.append(_opening_script.pop_front())
		rest_time = REST_BY_STAGE[stage - 1]
		return
	action_queue.append({"act": ACT_SPAWN, "types": [_pick_spawn_type(POOL_LATE)]})
	## 解锁当轮：原版是「第 3 次低头后先来一波蹦极，第 4 次后扔 RV」
	if not _forced_next_action.is_empty():
		action_queue.append({"act": _forced_next_action})
		_forced_next_action = ""
	## stage >= 2 且偶数轮才考虑踩踏，降低压迫频率
	elif stage >= 2 and round_count % 2 == 0 and not _rows_with_plants_in_stomp_range().is_empty():
		action_queue.append({"act": "Stomp"})
	## 两次解锁都完成后，每轮 50% 追加一招
	elif _is_rv_unlocked and randf() < SPECIAL_ACTION_CHANCE:
		action_queue.append({"act": "BungeeDrop" if randf() < 0.5 else "RV"})
	rest_time = REST_BY_STAGE[stage - 1]


func _run_next_action() -> void:
	if action_queue.is_empty():
		is_resting = true
		return
	var act: Dictionary = action_queue.pop_front()
	match str(act.get("act", "")):
		ACT_SPAWN:
			_do_spawn(_int_array(act.get("types", [])))
		ACT_HEAD:
			_do_head_attack()
		"Stomp":
			_do_stomp()
		"BungeeDrop":
			_do_bungee_drop()
		"RV":
			_do_rv_attack()


## 开局固定剧本（原版 5-10 的 set pattern，一轮消费一条）：
## 4 只普通 → 4~5 只路障 → 低头吐球 → 4~5 只铁桶（偶尔混 1 只路障）→ 再低头吐球。
## 剧本走完后类型完全随机，且**不再出普通僵尸**。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Dr._Zomboss_(PvZ)) §Strategies
## （与 https://plantsvszombies.wiki.gg/wiki/Level_5-10 §Difficulty 互相印证）
func _build_opening_script() -> Array[Dictionary]:
	var norm := CharacterRegistry.ZombieType.Z001Norm
	var cone := CharacterRegistry.ZombieType.Z003Cone
	var bucket := CharacterRegistry.ZombieType.Z005Bucket
	var script: Array[Dictionary] = []
	script.append(_batch(norm, OPENING_NORM_COUNT))
	script.append(_batch(cone, randi_range(OPENING_CONE_COUNT.x, OPENING_CONE_COUNT.y)))
	script.append({"act": ACT_HEAD})
	var bucket_types := _batch(bucket, randi_range(OPENING_BUCKET_COUNT.x, OPENING_BUCKET_COUNT.y))
	if randf() < OPENING_BUCKET_MIX_CONE_CHANCE:
		bucket_types["types"][randi() % bucket_types["types"].size()] = cone
	script.append(bucket_types)
	script.append({"act": ACT_HEAD})
	return script


## 一批同类型僵尸（原版是「连着放」一批，不是一只一停）
func _batch(ztype: int, count: int) -> Dictionary:
	var types: Array[int] = []
	for _i in range(count):
		types.append(ztype)
	return {"act": ACT_SPAWN, "types": types}


## 把从 Dictionary 里取出的 `types` 统一转成 Array[int]。
## 注意：`as Array[int]` 不会给无类型 Array 打上元素类型（只做引用转换），
## 直接传给 `_do_spawn(types: Array[int])` 会在运行时报
## 「The array of argument 1 (Array) does not have the same element type ...」。
func _int_array(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for e in v as Array:
			out.append(int(e))
	return out


## ===== 投放僵尸（手臂掉落，一批连着放） =====
func _do_spawn(types: Array[int]) -> void:
	is_busy = true
	var gap: float = SPAWN_GAP_BY_STAGE[clampi(stage - 1, 0, SPAWN_GAP_BY_STAGE.size() - 1)]
	for i in range(types.size()):
		if is_dead:
			break
		var row := _pick_spawn_row()
		_play_anim("Zombie_boss_spawn_%d" % (row + 1))
		var anim_len := _curr_anim_length()
		## 投放帧：手臂落到最低点时松手
		await get_tree().create_timer(SPAWN_DROP_DELAY).timeout
		if is_dead:
			break
		_spawn_zombie(types[i], row)
		await _active_anim_player.animation_finished
		## 批内间隔（动画本身已经占掉 anim_len，不足 gap 的部分才补等）
		if i < types.size() - 1:
			await get_tree().create_timer(maxf(gap - anim_len, 0.0)).timeout
	is_busy = false
	_apply_damage_look()
	_play_anim("Zombie_boss_idle", true)


## 投放行：原版会避开「清洁车已被僵尸触发」的行；
## 被冰火球压掉的车不算（那种行照样放），所有行的车都没了则回到任意行
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_5-10) §Difficulty
func _pick_spawn_row() -> int:
	var row_num := _row_num()
	if row_num <= 0:
		return 0
	var rows := _rows_with_mower_alive()
	if rows.is_empty():
		return randi() % row_num
	return rows.pick_random()


## 小推车还在（没被触发 / 没驶出）的行
func _rows_with_mower_alive() -> Array[int]:
	var out: Array[int] = []
	var main_game = Global.main_game
	if main_game == null:
		return out
	var gim = main_game.game_item_manager
	if gim == null:
		return out
	var mover_gim = gim.gim_lawn_mover
	if mover_gim == null:
		return out
	var row_num := _row_num()
	for r in range(mini(mover_gim.all_lawn_movers.size(), row_num)):
		var mover: LawnMover = mover_gim.all_lawn_movers[r]
		if is_instance_valid(mover) and not mover.is_moving:
			out.append(r)
	return out


func _row_num() -> int:
	var main_game = Global.main_game
	if main_game == null:
		return 0
	var zm = main_game.zombie_manager
	if zm == null:
		return 0
	return zm.all_zombie_rows.size()


func _pick_spawn_type(pool: Array[int]) -> int:
	## 高级池中巨人 / 冰车 / 投石车为稀有项
	for _i in range(pool.size(), 0, -1):
		var t: int = pool[randi() % pool.size()]
		if t in [
			CharacterRegistry.ZombieType.Z024Gargantuar,
			CharacterRegistry.ZombieType.Z013Zamboni,
			CharacterRegistry.ZombieType.Z023Catapult,
		]:
			if randf() < 0.75:
				continue
		return t
	return pool[0] if not pool.is_empty() else CharacterRegistry.ZombieType.Z001Norm


func _spawn_zombie(ztype: int, row: int, at_pos := Vector2.ZERO) -> void:
	var zm = Global.main_game.zombie_manager
	if zm == null or zm.all_zombie_rows.size() <= row:
		return
	var row_node = zm.all_zombie_rows[row]
	var pos := at_pos
	if pos == Vector2.ZERO:
		pos = Vector2(global_position.x + SPAWN_MARKER.x, _row_y(row))
	var init_para: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: row,
	}
	zm.create_norm_zombie(ztype, row_node, init_para, pos)

## ===== 踩踏：最右侧 4 列 × 2 行碾压（有植物才触发） =====
func _do_stomp() -> void:
	var rows := _rows_with_plants_in_stomp_range()
	if rows.is_empty():
		return
	is_busy = true
	var row: int = rows.pick_random()
	## 5 行地图只有 4 个「行对」起点，正好对上动画库里的 Zombie_boss_stomp_1~4（不用 clamp）
	_play_anim("Zombie_boss_stomp_%d" % (row + 1))
	## 踩踏落地帧（约 55%）碾压右侧 4 列 × 2 行
	get_tree().create_timer(_curr_anim_length() * 0.55).timeout.connect(func():
		if not is_dead:
			_smash_stomp_rows(row))
	await _active_anim_player.animation_finished
	is_busy = false
	_apply_damage_look()
	_play_anim("Zombie_boss_idle", true)


func _stomp_col_start(col_count: int) -> int:
	return maxi(0, col_count - STOMP_COL_COUNT)


## 踩踏结算：从起始行起压 STOMP_ROW_COUNT 行的最右侧 STOMP_COL_COUNT 列。
## 音效放在这里（不是逐行），否则压两行会响两声
func _smash_stomp_rows(row_start: int) -> void:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	SoundManager.play_character_SFX("gargantuar_thump")
	for r in range(row_start, mini(row_start + STOMP_ROW_COUNT, cells.size())):
		var start_col := _stomp_col_start(cells[r].size())
		for c in range(start_col, cells[r].size()):
			cells[r][c].plant_be_flattened()

## ===== 天降蹦极僵尸（enter → 投放蹦极 → leave） =====
func _do_bungee_drop() -> void:
	is_busy = true
	_play_anim("Zombie_boss_bungee_1_enter")
	var targets := _plant_cells_for_bungee(3)
	get_tree().create_timer(T_BUNGEE_IN * 0.55).timeout.connect(func():
		if is_dead:
			return
		for cell in targets:
			if is_instance_valid(cell):
				_spawn_bungee_at_cell(cell)
	)
	await _active_anim_player.animation_finished
	_play_anim("Zombie_boss_bungee_1_leave")
	await _active_anim_player.animation_finished
	is_busy = false
	_apply_damage_look()
	_play_anim("Zombie_boss_idle", true)


func _plant_cells_for_bungee(max_n: int) -> Array[PlantCell]:
	var cells: Array[PlantCell] = Global.main_game.plant_cell_manager.get_cell_have_plant()
	cells.shuffle()
	var out: Array[PlantCell] = []
	for cell in cells:
		## 只偷前半场，与原版蹦极落点接近
		if cell.row_col.y <= 4:
			out.append(cell)
		if out.size() >= max_n:
			break
	return out


func _spawn_bungee_at_cell(plant_cell: PlantCell) -> void:
	var zm = Global.main_game.zombie_manager
	if zm == null:
		return
	var lane: int = plant_cell.row_col.x
	if lane < 0 or lane >= zm.all_zombie_rows.size():
		return
	var row_node = zm.all_zombie_rows[lane]
	var init_para: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
	}
	var pos := Vector2(
		plant_cell.global_position.x + plant_cell.size.x * 0.5,
		row_node.zombie_create_position.global_position.y
	)
	zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z021Bungi,
		row_node,
		init_para,
		pos,
		GlobalUtils.create_bungi.bind(plant_cell)
	)
	SoundManager.play_character_SFX("bungee_scream")

## ===== RV 房车冲撞：3x2 区域碾压 =====
func _do_rv_attack() -> void:
	is_busy = true
	_play_anim("Zombie_boss_RV_1")
	var target := _rv_target_cell()
	## 冲撞判定帧
	get_tree().create_timer(_curr_anim_length() * 0.5).timeout.connect(func():
		if not is_dead:
			_smash_area(target.x, target.y))
	await _active_anim_player.animation_finished
	is_busy = false
	_apply_damage_look()
	_play_anim("Zombie_boss_idle", true)


func _rv_target_cell() -> Vector2i:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	var candidates: Array[Vector2i] = []
	for r in range(cells.size()):
		for c in range(mini(5, cells[r].size())):
			var cell = cells[r][c]
			if cell.get_curr_plant_num() > 0 and r < cells.size() - 1:
				candidates.append(Vector2i(c, r))
	if candidates.is_empty():
		return Vector2i(2, 2)
	return candidates.pick_random()


func _smash_area(col: int, row: int) -> void:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	SoundManager.play_character_SFX("gargantuar_thump")
	for r in range(row, mini(row + 2, cells.size())):
		for c in range(maxi(col - 1, 0), mini(col + 2, cells[r].size())):
			cells[r][c].plant_be_flattened()

## ===== 头部吐球（火 / 冰各 50%） =====
func _do_head_attack() -> void:
	if is_busy or is_dead:
		return
	is_busy = true
	## 低头次数到点 → 解锁天降蹦极 / RV（解锁的那一招排在下一轮）
	head_attack_count += 1
	if head_attack_count >= HEAD_COUNT_UNLOCK_RV and not _is_rv_unlocked:
		_is_rv_unlocked = true
		_forced_next_action = "RV"
	elif head_attack_count >= HEAD_COUNT_UNLOCK_BUNGEE and not _is_bungee_unlocked:
		_is_bungee_unlocked = true
		_forced_next_action = "BungeeDrop"
	_head_attack_lane = randi_range(0, 4)
	var is_fire := randf() > 0.5
	_head_glow_fire = is_fire
	_head_glow_active = true
	_apply_head_glow(is_fire)
	_play_anim("Zombie_boss_head_enter")
	await _active_anim_player.animation_finished
	if is_dead:
		_finish_head_attack(false)
		return
	_set_head_vulnerable(true)
	_apply_head_glow(is_fire)
	_play_anim("Zombie_boss_head_attack_%d" % (_head_attack_lane + 1))
	## 出球帧（约 40%）
	get_tree().create_timer(_curr_anim_length() * 0.4).timeout.connect(func():
		if not is_dead:
			_apply_head_glow(is_fire)
			_fire_ball(_head_attack_lane, is_fire))
	await _active_anim_player.animation_finished
	if is_dead:
		_finish_head_attack(false)
		return
	## 吐球后低头 idle 停留，给植物输出时间
	_play_anim("Zombie_boss_head_idle", true)
	await get_tree().create_timer(HEAD_IDLE_DWELL).timeout
	if is_dead:
		_finish_head_attack(false)
		return
	_play_anim("Zombie_boss_head_leave")
	await _active_anim_player.animation_finished
	_finish_head_attack(true)


func _finish_head_attack(play_body_idle: bool) -> void:
	_head_glow_active = false
	_clear_head_glow()
	_set_head_vulnerable(false)
	is_busy = false
	if not is_dead and play_body_idle:
		_apply_damage_look()
		_play_anim("Zombie_boss_idle", true)


func _apply_head_glow(is_fire: bool) -> void:
	var mouth := get_node_or_null("Boss_mouthglow_red") as Sprite2D
	var eye := get_node_or_null("Boss_eyeglow_red") as Sprite2D
	if mouth != null:
		mouth.texture = TEX_MOUTHGLOW_RED if is_fire else TEX_MOUTHGLOW_BLUE
	if eye != null:
		eye.texture = TEX_EYEGLOW_RED if is_fire else TEX_EYEGLOW_BLUE


func _clear_head_glow() -> void:
	var mouth := get_node_or_null("Boss_mouthglow_red") as Sprite2D
	var eye := get_node_or_null("Boss_eyeglow_red") as Sprite2D
	if mouth != null:
		mouth.texture = TEX_MOUTHGLOW
	if eye != null:
		eye.texture = TEX_EYEGLOW


func _fire_ball(lane: int, is_fire: bool) -> void:
	var ball_scene: PackedScene = SceneRegistry.ZOMBOSS_BALL
	if ball_scene == null:
		return
	var ball = ball_scene.instantiate()
	ball.setup(self, lane, is_fire, BALL_DAMAGE)
	Global.main_game.add_child(ball)
	ball.global_position = Vector2(
		global_position.x + BALL_MARKER.x,
		_row_y(lane) - 52.0
	)

## ===== 受击（供植物子弹调用，签名对齐 Character000Base） =====
func be_attacked_bullet(
	attack_value: int,
	_bullet_mode: BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm,
	_is_drop := true,
	_sfx := true
) -> void:
	if is_dead or not is_head_vulnerable:
		return
	curr_hp -= attack_value
	body_flash()
	_update_stage()
	if curr_hp <= 0.0:
		_die()


## 寒冰菇：冻结僵王行动
func _on_ice_all_zombie(time_ice = null, _time_decelerate = null) -> void:
	if is_dead:
		return
	var t := 4.0
	if time_ice is float or time_ice is int:
		t = float(time_ice)
	_apply_ice_freeze(t)


func _apply_ice_freeze(time: float) -> void:
	_is_frozen = true
	modulate = Color(0.55, 0.82, 1.05)
	_pause_all_animations()
	if is_instance_valid(_ice_effect):
		_ice_effect.queue_free()
	_ice_effect = SceneRegistry.ICE_EFFECT.instantiate()
	add_child(_ice_effect)
	if _ice_effect.has_method("start_ice_effect"):
		_ice_effect.start_ice_effect(time)
	if _freeze_timer == null:
		_freeze_timer = Timer.new()
		_freeze_timer.one_shot = true
		_freeze_timer.timeout.connect(_on_ice_freeze_end)
		add_child(_freeze_timer)
	_freeze_timer.start(maxf(time, 0.1))


func _pause_all_animations() -> void:
	_anim_speed_backup.clear()
	for child in get_children():
		if child is AnimationPlayer:
			var player := child as AnimationPlayer
			_anim_speed_backup[player] = player.speed_scale
			player.speed_scale = 0.0


func _resume_all_animations() -> void:
	for child in get_children():
		if child is AnimationPlayer:
			var player := child as AnimationPlayer
			player.speed_scale = _anim_speed_backup.get(player, 1.0)
	_anim_speed_backup.clear()


func _on_ice_freeze_end() -> void:
	_is_frozen = false
	_resume_all_animations()
	if is_instance_valid(_ice_effect):
		_ice_effect.queue_free()
		_ice_effect = null
	if not is_dead:
		modulate = Color.WHITE


## 火爆辣椒：头部可攻击时造成伤害
func _on_jalapeno_lane(_lane = null) -> void:
	if is_dead or not is_head_vulnerable:
		return
	be_attacked_bullet(1800, BulletRegistry.AttackMode.Penetration, false, true)


func body_flash() -> void:
	modulate = Color(1.6, 1.2, 1.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)


func _update_stage() -> void:
	var new_dmg := _damage_level_from_hp()
	if new_dmg != damage_level:
		damage_level = new_dmg
		_apply_damage_look()
	var pct := curr_hp / max_hp
	if pct <= 0.10 and stage < 3:
		stage = 3
		rest_time = REST_BY_STAGE[2]
	elif pct <= 0.50 and stage < 2:
		stage = 2
		rest_time = REST_BY_STAGE[1]
	elif pct <= 0.80 and stage < 2:
		stage = 2
		rest_time = REST_BY_STAGE[1]

## 僵王一死，场上由它放出来的僵尸一并消失
## （原版：boss 与它召唤的僵尸算同一波，boss 没了屏幕上的僵尸全部 despawn，含被魅惑的）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Dr._Zomboss_(PvZ)) §Trivia
func _clear_field_zombies() -> void:
	var main_game = Global.main_game
	if main_game == null:
		return
	var zm = main_game.zombie_manager
	if zm != null:
		zm.death_all_zombie()


## ===== 死亡：加速演出 + 爆炸闪烁 → 奖杯 =====
func _die() -> void:
	is_dead = true
	_set_head_vulnerable(false)
	is_busy = true
	var death_player := _get_anim_player("Zombie_boss_death")
	if death_player != null:
		death_player.speed_scale = 1.5
	_play_anim("Zombie_boss_death")
	_explosion_sequence()
	await _active_anim_player.animation_finished
	if death_player != null:
		death_player.speed_scale = 1.0
	_clear_field_zombies()
	EventBus.push_event("boss_defeated", [global_position])
	boss_died.emit()
	EventBus.push_event("create_trophy", [global_position])


func _explosion_sequence() -> void:
	for _i in range(6):
		create_tween().tween_interval(0.9).finished.connect(func():
			if not is_instance_valid(self):
				return
			modulate = Color(2.0, 2.0, 2.0)
			SoundManager.play_character_SFX("gargantuar_thump")
			create_tween().tween_property(self, "modulate", Color.WHITE, 0.25))

## ===== 工具 =====
## 踩踏候选 = **行对起始行**（不是单个行）：这个行对里任意一行右侧 4 列有植物，它就进候选。
## 5 行地图只有 4 个行对，正好对上动画库里的 Zombie_boss_stomp_1~4。
## wiki 没写行对怎么挑，本仓库按「在有植物的行对里随机」实现，与原版观测一致
func _rows_with_plants_in_stomp_range() -> Array[int]:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	var out: Array[int] = []
	for r in range(maxi(0, cells.size() - STOMP_ROW_COUNT + 1)):
		if _row_pair_has_plants_in_stomp_cols(r):
			out.append(r)
	return out


func _row_pair_has_plants_in_stomp_cols(row_start: int) -> bool:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	for r in range(row_start, mini(row_start + STOMP_ROW_COUNT, cells.size())):
		if _row_has_plants_in_stomp_cols(r):
			return true
	return false


func _row_has_plants_in_stomp_cols(row: int) -> bool:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	if row >= cells.size():
		return false
	var start_col := _stomp_col_start(cells[row].size())
	for c in range(start_col, cells[row].size()):
		if cells[row][c].get_curr_plant_num() > 0:
			return true
	return false


func _planted_cells_for_drop(max_n: int) -> Array[Vector2i]:
	var cells = Global.main_game.plant_cell_manager.all_plant_cells
	var out: Array[Vector2i] = []
	for r in range(cells.size()):
		for c in range(cells[r].size()):
			if cells[r][c].get_curr_plant_num() > 0 and c <= 4:
				out.append(Vector2i(c, r))
	out.shuffle()
	return out.slice(0, max_n)


func _row_y(row: int) -> float:
	## Global.main_game 是弱类型字段，用 `=` 接（写 `:=` 会 Parse Error）
	var main_game = Global.main_game
	if main_game == null:
		return 282.0
	var zm = main_game.zombie_manager
	if zm != null and row < zm.all_zombie_rows.size():
		return zm.all_zombie_rows[row].zombie_create_position.global_position.y
	return 282.0


func _curr_anim_length() -> float:
	if _active_anim_player == null or _active_anim_player.current_animation == "":
		return 1.0
	return _active_anim_player.current_animation_length
