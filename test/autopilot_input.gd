extends RefCounted
class_name AutopilotInput
## 输入模拟：合成真实鼠标 / 键盘事件，或直接触发 pressed 信号。
##
## 「坐标怎么算」在 AutopilotProbe，「等多久」在 AutopilotClock，本文件都不重复实现。
##
## 为什么有时用合成事件、有时直接 emit pressed：
##   合成事件过 GUI 命中测试，能覆盖「卡片音效 / 格子 Button」这类真实链路，
##   但无头环境下命中测试依赖视口尺寸；press_first 绕过命中测试，是最可靠的兜底。

var _tree: SceneTree = null
var _clock: AutopilotClock = null
var _report: AutopilotReport = null
var _probe: AutopilotProbe = null


func setup(scene_tree: SceneTree, clock: AutopilotClock, report: AutopilotReport, probe: AutopilotProbe) -> void:
	_tree = scene_tree
	_clock = clock
	_report = report
	_probe = probe


#region 鼠标

## 在屏幕坐标点一次。
##
## 种植走格子的 Button（GUI 命中测试），但手持物的跟随 / 虚影 / 能否种 / 点空白取消
## 读的是**真实鼠标位置**，所以合成事件之前必须真的把光标挪过去（warp + motion），
## 否则 hand_manager.curr_plant_cell 不更新。
func click(x: float, y: float) -> void:
	var pos := Vector2(x, y)
	Input.warp_mouse(pos)
	await _clock.frames(1)
	_send_motion(pos)
	await _clock.frames(2)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await _clock.frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await _clock.frames(2)
	_report.line("[操作] 点击 (%d, %d)" % [int(x), int(y)])


## 点击第一个【完整路径】含 pattern 的可见可点控件
func click_first(pattern: String, index: int = 0) -> bool:
	var found := _probe.find_clickable(pattern, true)
	_report.line("[查找] " + pattern + " 命中 " + str(found.size()) + " 个可点控件")
	for i in range(mini(found.size(), 6)):
		_report.line("    [" + str(i) + "] " + str(found[i].get_path()) + " screen=" + str(AutopilotProbe.screen_center_of(found[i])))
	if found.size() <= index:
		_report.line("!! 没有可点的目标: " + pattern)
		return false
	var c := found[index] as Control
	var center := AutopilotProbe.screen_center_of(c)
	_report.line("[操作] 点击 " + str(c.get_path()))
	await click(center.x, center.y)
	return true


## 点击某个 Control 的屏幕中心
func click_node(path: String) -> void:
	var n := _node(path)
	if n == null:
		return
	if not (n is Control):
		_report.line("!! 节点不是 Control，无法取中心点: " + path)
		return
	var c := n as Control
	var center := AutopilotProbe.screen_center_of(c)
	_report.line("[操作] 点击节点 " + path + " 屏幕中心 " + str(center))
	await click(center.x, center.y)


## 点击草坪格子。[row] 0 = 最上面一行，[col] 0 = 最左一列（= row_col.y）
func click_plant_cell(row: int, col: int) -> bool:
	var cell := _probe.plant_cell_node(row, col)
	if cell == null:
		_report.line("!! 没有格子 row=%d col=%d（不在关卡内？）" % [row, col])
		return false
	var btn: Control = cell.get_node_or_null("Button")
	if btn == null:
		_report.line("!! 格子没有 Button: " + str(cell.get_path()))
		return false
	var c := AutopilotProbe.screen_center_of(btn)
	_report.line("[种植] 点击 row=%d col=%d -> %s 屏幕中心 %s (rect 中心 %s)" % [
		row, col, str(cell.get_path()), str(c), str(btn.get_global_rect().get_center())])
	await click(c.x, c.y)
	return true

#endregion


#region 键盘与直接触发

## 按一下输入动作（如 "ShortcutKeys_Card1"）
func key(action: String) -> void:
	if not InputMap.has_action(action):
		_report.line("!! 输入动作不存在: " + action)
		return
	Input.action_press(action)
	await _clock.frames(2)
	Input.action_release(action)
	await _clock.frames(2)
	_report.line("[操作] 按键动作 " + action)


## 按一下物理键
func keycode(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await _clock.frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await _clock.frames(2)
	_report.line("[操作] 按键 " + str(code))


## 直接触发第一个匹配控件的 pressed 信号 —— 绕过命中测试，最可靠
func press_first(pattern: String, index: int = 0) -> bool:
	var found := _probe.find_clickable(pattern, true)
	_report.line("[查找] " + pattern + " 命中 " + str(found.size()) + " 个可点控件")
	for i in range(mini(found.size(), 6)):
		_report.line("    [" + str(i) + "] " + str(found[i].get_path()))
	if found.size() <= index:
		_report.line("!! 没有可触发目标: " + pattern)
		return false
	var b: Node = found[index]
	if not b.has_signal("pressed"):
		_report.line("!! 目标没有 pressed 信号: " + str(b.get_path()))
		return false
	_report.line("[操作] 触发 pressed: " + str(b.get_path()))
	b.emit_signal("pressed")
	await _clock.frames(3)
	return true


## 对节点调用方法（绕过 UI，直接驱动游戏逻辑）
func call_on(path: String, method: String, args: Array = []) -> void:
	var n := _node(path)
	if n == null:
		return
	if not n.has_method(method):
		_report.line("!! 节点没有方法 " + method + ": " + path)
		return
	n.callv(method, args)
	_report.line("[操作] 调用 " + path + "." + method + str(args))
	await _clock.frames(2)

#endregion


func _send_motion(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)


## 按路径取节点；找不到只记一行事实，不抛异常（驾驶脚本不该因为找不到节点就崩）
func _node(path: String) -> Node:
	var n := _tree.root.get_node_or_null(path)
	if n == null:
		_report.line("!! 找不到节点: " + path)
	return n
