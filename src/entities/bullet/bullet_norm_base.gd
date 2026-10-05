extends Bullet000Base
class_name Bullet000NormBase

@onready var area_2d_attack: Area2D = $Area2DAttack

## 子弹击中特效
@onready var bullet_effect: BulletEffect000Base = $BulletEffect
## 子弹基类
@export_group("子弹基础属性")
## 子弹是否旋转
@export var is_rotate := false
## 最大攻击次数(-1表示可以无限攻击)
@export var max_attack_num:=1
## 当前攻击次数
var curr_attack_num:=0
## 子弹伤害
@export var attack_value := 20
## 子弹默认移动速度
@export var speed: float = 300.0
## 子弹默认移动方向
@export var direction: Vector2 = Vector2.RIGHT
## 子弹伤害模式：普通，穿透，真实
@export var bullet_mode : BulletRegistry.AttackMode
## 子弹移动离出生点最大距离，超过自动销毁
@export var max_distance := 2000.0
## 子弹初始位置
var start_pos: Vector2
## 默认是否激活行属性，激活后只能攻击本行的僵尸
@export var default_is_activate_lane:=true
var is_activate_lane:bool
## 子弹行属性
var lane :int = -1
@export_subgroup("子弹音效相关")
## 是否触发受击音效(火焰豌豆就不触发)
@export var trigger_be_attack_sfx := true
## 子弹本身音效
@export var type_bullet_SFX :SoundManagerClass.TypeBulletSFX =  SoundManagerClass.TypeBulletSFX.Pea


@export_group("子弹攻击相关")
## 可以攻击的敌人状态掩码组件（子弹场景中配置）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")

@export_group("子弹升级相关")
## 是否可以升级子弹
@export var is_can_up:=false


func _ready() -> void:
	_get_or_create_can_attack_status_component()
	body.rotation = direction.angle()

	if is_rotate:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(body, "rotation", TAU, 1.0).as_relative()

## 获取攻击框
## 子弹在加入场景树之前 init_bullet 就会调用，此时 @onready 还未赋值
func _get_area_2d_attack() -> Area2D:
	if not is_instance_valid(area_2d_attack):
		area_2d_attack = get_node_or_null(^"Area2DAttack")
	return area_2d_attack


## 应用阵营：把阵营对应的碰撞层写进攻击框
## 场景里配置的「非阵营」额外层（直线子弹的 World 斜坡层、保龄球的 Bowling 层）会被保留
func apply_bullet_camp() -> void:
	BulletCampConfig.apply_camp_collision(_get_area_2d_attack(), bullet_camp)


## 获取或创建可攻击状态掩码组件
## 子弹在加入场景树之前 init_bullet 就会调用，此时 @onready 还未赋值
func _get_or_create_can_attack_status_component() -> CanAttackStatusComponent:
	if not is_instance_valid(can_attack_status_component):
		can_attack_status_component = get_node_or_null(^"CanAttackStatusComponent")
	if not is_instance_valid(can_attack_status_component):
		can_attack_status_component = CanAttackStatusComponent.new()
		can_attack_status_component.name = "CanAttackStatusComponent"
		add_child(can_attack_status_component)
	return can_attack_status_component


## 子弹初始化参数种类
enum E_InitParasAttr{
	IsActivateLane,		## 是否激活行属性
	BulletLane, 		## 子弹所在行
	Position,			## 子弹起始位置
	Direction,			## 子弹起始方向
	CanAttackPlantState,	## 子弹可以攻击的敌人(植物)状态
	CanAttackZombieState,	## 子弹可以攻击的敌人(僵尸)状态

	## 抛物线子弹\追踪子弹额外属性
	Enemy,				## 子弹选中的敌人
	EnemyGloPos,		## 敌人位置(发射子弹时敌人若已经消失,抛物线依旧可以攻击)
	ZombossBoss,		## 僵王博士目标(投手抛物线；僵王不是 Character000Base，单独传)

	## 阵营相关
	BulletCamp,			## 子弹阵营（发射方决定；不传时沿用场景导出值 bullet_camp）

}

## 初始化子弹属性
func init_bullet(bullet_paras:Dictionary):
	## 子弹阵营：由发射方决定（植物 / 植物僵尸），缺省沿用场景导出值
	set_bullet_camp(bullet_paras.get(E_InitParasAttr.BulletCamp, bullet_camp), true)

	## 子弹行
	self.is_activate_lane = bullet_paras.get(E_InitParasAttr.IsActivateLane, default_is_activate_lane)
	self.lane = bullet_paras.get(E_InitParasAttr.BulletLane, -1)
	z_index = self.lane * 50 + 45

	self.start_pos = bullet_paras.get(E_InitParasAttr.Position, Vector2.ZERO)
	position = self.start_pos

	self.direction = bullet_paras.get(E_InitParasAttr.Direction, Vector2.RIGHT)
	var can_attack_status := _get_or_create_can_attack_status_component()
	can_attack_status.can_attack_plant_status = bullet_paras.get(E_InitParasAttr.CanAttackPlantState, can_attack_status.can_attack_plant_status)
	can_attack_status.can_attack_zombie_status = bullet_paras.get(E_InitParasAttr.CanAttackZombieState, can_attack_status.can_attack_zombie_status)


## 获取子弹属性
func get_bullet_paras()->Dictionary[E_InitParasAttr,Variant]:
	return {
		E_InitParasAttr.IsActivateLane : self.is_activate_lane,
		E_InitParasAttr.BulletLane : self.lane,
		E_InitParasAttr.Position : position,
		E_InitParasAttr.Direction : self.direction,
		E_InitParasAttr.CanAttackPlantState : can_attack_status_component.can_attack_plant_status,
		E_InitParasAttr.CanAttackZombieState : can_attack_status_component.can_attack_zombie_status,
		E_InitParasAttr.BulletCamp : bullet_camp,
	}

## 子弹与敌人碰撞
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	var enemy = area.owner
	## 僵王博士不是 Character000Base（独立 Node2D），且只在低头窗口里可被命中
	if enemy is ZombossBoss:
		var boss: ZombossBoss = enemy
		if boss.is_dead or not boss.is_head_vulnerable:
			return
		if max_attack_num != -1 and curr_attack_num >= max_attack_num:
			return
		attack_once_boss(boss)
		return
	## 只攻击敌对阵营：植物方子弹打僵尸，僵尸方子弹（植物僵尸 / 投石车僵尸）打植物
	## 同阵营（含魅惑僵尸对植物方子弹）由碰撞层先过滤掉，这里再判一次保证语义明确
	if not BulletCampConfig.is_enemy(bullet_camp, enemy):
		if not (enemy is Plant000Base or enemy is Zombie000Base):
			## 非角色（斜坡、道具等）由子类先行处理，走到这里说明检测层配错了
			Log.error("子弹检测到的对象既不是植物也不是僵尸：" + str(enemy))
		return
	## 如果不是可攻击状态敌人
	if not can_attack_status_component.can_attack(enemy):
		return
	## 子弹没有攻击次数
	if max_attack_num != -1 and curr_attack_num >= max_attack_num:
		return

	## 如果子弹有行属性
	if is_activate_lane:
		if lane == enemy.lane:
			attack_once(enemy)
	else:
		attack_once(enemy)


## 对敌人造成伤害
func _attack_enemy(enemy:Character000Base):
	if not is_instance_valid(enemy):
		## 攻击 null（抛物线落空、直线撞斜坡）时没有实际目标，只消耗次数与播特效
		return
	if enemy is Zombie000Base:
		_attack_zombie(enemy)
	elif enemy is Plant000Base:
		_attack_plant(enemy)

## 对僵尸敌人造成伤害,直线类子弹重写
func _attack_zombie(zombie:Zombie000Base):
	## 攻击敌人
	zombie.be_attacked_bullet(attack_value, bullet_mode, true, trigger_be_attack_sfx)


## 对植物敌人造成伤害（僵尸方子弹 / 植物僵尸使用）
func _attack_plant(plant:Plant000Base):
	plant = get_first_be_hit_plant_in_cell(plant)
	if not is_instance_valid(plant):
		## 格子里没有可攻击的植物（例如只剩花盆 / 睡莲且掩码不含悬浮）
		return
	## 攻击敌人
	plant.be_attacked_bullet(attack_value, bullet_mode, true, trigger_be_attack_sfx)


## 直线子弹先对壳类进行攻击
## 抛物线子弹先对Norm进行攻击
func get_first_be_hit_plant_in_cell(plant:Plant000Base)->Plant000Base:
	return plant

## 攻击一次僵王博士（僵王不是 Character000Base，不能走 attack_once 的角色分支）
## 特效 X 用僵王机体原点 + reanim 锚点修正：僵王的节点原点在机体左侧 ~660px 处
func attack_once_boss(boss: ZombossBoss) -> void:
	curr_attack_num += 1
	if max_attack_num != -1 and curr_attack_num > max_attack_num:
		return
	boss.be_attacked_bullet(attack_value, bullet_mode, true, trigger_be_attack_sfx)
	if type_bullet_SFX != SoundManagerClass.TypeBulletSFX.Null:
		SoundManager.play_bullet_attack_SFX(type_bullet_SFX)
	if bullet_effect.is_bullet_effect:
		bullet_effect.global_position.x = boss.global_position.x + ZombossBoss.REANIM_ANCHOR_X - 40.0
		bullet_effect.activate_bullet_effect()
	if max_attack_num != -1 and curr_attack_num >= max_attack_num:
		queue_free()

## 攻击一次
func attack_once(enemy:Character000Base):
	curr_attack_num += 1
	if max_attack_num != -1 and curr_attack_num > max_attack_num:
		return
	## 对敌人造成伤害
	_attack_enemy(enemy)
	## 是否有音效
	if type_bullet_SFX != SoundManagerClass.TypeBulletSFX.Null:
		SoundManager.play_bullet_attack_SFX(type_bullet_SFX)
	## 如果有子弹特效
	if bullet_effect.is_bullet_effect:
		if enemy is Character000Base:
			bullet_effect.global_position.x = enemy.hurt_box_component.global_position.x
		bullet_effect.activate_bullet_effect()

	## 判断是否进入删除队列
	if max_attack_num != -1 and curr_attack_num >= max_attack_num:
		queue_free()
