extends Control
class_name TutorialAdviceUI
## 新手教程提示条（屏幕下方的横幅文字 + 指向目标的箭头）
##
## 只负责「显示什么、指哪里」，步骤判定全部在 TutorialManager。
## 本节点由 TutorialManager 挂到主游戏 CanvasLayerUI 下，不受主游戏场景的鼠标拦截影响。
##
## 提示条**固定在屏幕底部**（tscn 里 Bottom Wide 锚点 + 底部外边距），高度按文本行数算：
## 教程台词、一次性提示一律走这一条屏幕下方的提示，不再有飘在草坪上的小框。
## 所以没有「指定位置」的接口 —— 位置由锚点决定，改样式请改 tscn。

@onready var advice_panel: Control = $AdvicePanel
@onready var advice_label: Label = $AdvicePanel/MarginContainer/AdviceLabel
@onready var pointer: TutorialPointer = $Pointer

## 一次性提示模式下箭头要跟随的节点（例如第一次掉出来的金币）
var _once_target: Node2D
## 当前显示的文本（Label 拿到布局宽度后要按它重算一次高度）
var _curr_text := ""

## 提示条最小高度（单行短提示够用）
const ADVICE_PANEL_MIN_HEIGHT := 64.0
## 面板上下 content_margin 之和（tscn 里各 10）
const ADVICE_PANEL_MARGIN_Y := 20.0
## 面板左右 content_margin 之和（tscn 里各 14）
const ADVICE_PANEL_MARGIN_X := 28.0
## 提示条左右各留的边距（与 tscn 的 offset_left / offset_right 一致）
const ADVICE_PANEL_SIDE_MARGIN := 24.0
## Label 还没拿到布局宽度时（节点刚 add_child、还没跑过一次布局）用它兜底：
## 800 设计分辨率下 屏幕宽 - 左右边距共 48 - content_margin 28
const ADVICE_LABEL_FALLBACK_WIDTH := 724.0


## 显示提示文本（箭头由 update_pointer / hide_pointer 单独控制）
func show_advice(text: String) -> void:
	_curr_text = text
	advice_label.text = text
	advice_panel.visible = true
	_ensure_label_width()
	_refresh_advice_height()


func _ready() -> void:
	## 布局还没跑过时 Label 的宽度是 1px，minimum_size 会按「一个字一行」把提示条撑到几千高。
	## 这里先把宽度钉上，容器随后会给出同样的值
	_ensure_label_width()
	## Label 拿到真实宽度后会 resized：再按实际行数定一次高度
	advice_label.resized.connect(_refresh_advice_height)


## Label 尺寸变化（= 拿到可用宽度）后按实际行数重定一次高度
func _refresh_advice_height() -> void:
	if _curr_text.is_empty() or not is_instance_valid(advice_panel):
		return
	var height := maxf(ADVICE_PANEL_MIN_HEIGHT, _measure_advice_height(_curr_text))
	## 锚点在底部：**改上端偏移**就等于「贴着底部往上长」。
	## 不要直接写 `advice_panel.size.y`：锚点布局下一布局就被 offsets 覆盖回去
	advice_panel.offset_top = advice_panel.offset_bottom - height


## Label 的可用宽度：提示条宽 - 左右 content_margin
##
## **不要**读 `advice_label.size.x`：容器还没给它分配宽度时它是 **1px**（不是 0），
## 拿 1px 去算折行 / 让 Godot 算 minimum_size，一句 12 字的提示会算出几千高的条。
func _advice_label_width() -> float:
	var width := advice_panel.size.x - ADVICE_PANEL_MARGIN_X
	if width <= 0.0:
		width = maxf(0.0, get_viewport_rect().size.x - ADVICE_PANEL_SIDE_MARGIN * 2.0) - ADVICE_PANEL_MARGIN_X
	if width <= 0.0:
		width = ADVICE_LABEL_FALLBACK_WIDTH
	return width


## Label 必须知道自己多宽：Godot 会把 Control 的 size 钳到不小于 minimum_size，
## 而 minimum_size 是按 Label 的可用宽度折行算出来的
func _ensure_label_width() -> void:
	var width := _advice_label_width()
	if advice_label.size.x < width:
		advice_label.size.x = width


## 按「显式 \n + 可用宽度内的自动折行」估文本高度
##
## **不要**直接问 `advice_panel.get_minimum_size()`：Label 还没拿到布局宽度时会按
## 「一个字一行」算 —— 一句 12 字的提示能算出 300 多高（第一次显示必踩）。
func _measure_advice_height(text: String) -> float:
	var font := advice_label.get_theme_font("font")
	var font_size := advice_label.get_theme_font_size("font_size")
	if font == null:
		return ADVICE_PANEL_MIN_HEIGHT
	var width := _advice_label_width()
	var line_height := font.get_height(font_size)
	var lines := 0
	for line in text.split("\n"):
		lines += maxi(1, ceili(font.get_string_size(line, font_size).x / width))
	return lines * line_height + ADVICE_PANEL_MARGIN_Y


## 一次性提示：显示 text，箭头跟着 target 节点走，show_time 秒后自动隐藏并释放自身
## 用于「全局只提示一次」的场合（第一次掉落金币），步骤教程仍由 TutorialManager 推进
func show_advice_once(text: String, target: Node2D, show_time: float) -> void:
	show_advice(text)
	_once_target = target
	set_process(true)
	_update_once_pointer()
	await get_tree().create_timer(show_time, false).timeout
	## 等待期间节点可能已经被场景切换带走
	if not is_instance_valid(self):
		return
	_once_target = null
	set_process(false)
	hide_advice()
	queue_free()


## 一次性提示期间每帧刷新箭头：目标还在就跟着走，被拾取 / 消失就收起箭头
func _process(_delta: float) -> void:
	## **只在一次性提示期间**干活：目标没了就收一次箭头并停掉按帧处理。
	## 逐步教程那条路每帧由 TutorialManager 喂 update_pointer，这里要是也去碰 hide_pointer，
	## 就会每帧把刚点亮的箭头按回去 —— 症状是「第一句提示没有箭头」。
	if not is_instance_valid(_once_target):
		hide_pointer()
		set_process(false)
		return
	_update_once_pointer()


func _update_once_pointer() -> void:
	if not is_instance_valid(_once_target):
		hide_pointer()
		return
	update_pointer(_once_target.get_global_transform_with_canvas().origin)


## 隐藏提示条与箭头（步骤结束 / 教程结束 / 纯戴夫对话步骤没有提示文本）
## 一并清空文本：get_advice_text() 是「当前有没有在提示」的判定依据，藏着旧文本会误判
func hide_advice() -> void:
	advice_label.text = ""
	advice_panel.visible = false
	pointer.visible = false


## 更新箭头：指向画布坐标 target_canvas_pos；箭尾朝向底部的提示条
func update_pointer(target_canvas_pos: Vector2) -> void:
	pointer.point_to(target_canvas_pos, get_advice_box_center())


## 隐藏箭头（该步骤没有指向目标，或目标暂时不存在：例如场上还没有阳光）
func hide_pointer() -> void:
	pointer.visible = false


## 提示条在画布上的中心点（箭头从这里出发）
##
## 走画布变换而不是 `position + size * 0.5`：提示条是锚点布局，
## position 落在锚点上（`Vector2.ZERO` 那一侧），跟屏幕上的真实位置不是一回事
func get_advice_box_center() -> Vector2:
	return advice_panel.get_global_transform_with_canvas() * (advice_panel.size * 0.5)


## 当前提示文本（调试 / 自动测试取用）
func get_advice_text() -> String:
	return advice_label.text


## 提示条当前是否可见（调试 / 自动测试取用）
func is_advice_visible() -> bool:
	return advice_panel.visible


## 箭头当前是否可见（调试 / 自动测试取用）
func is_pointer_visible() -> bool:
	return pointer.visible


## 提示面板当前尺寸（调试 / 自动测试取用：多行长提示会不会把提示条撑爆）
func get_advice_panel_size() -> Vector2:
	return advice_panel.size
