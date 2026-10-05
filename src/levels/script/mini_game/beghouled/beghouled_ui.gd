extends Control
class_name BeghouledUI
## 僵尸迷阵（Beghouled）的玩法界面
##
## 两块内容：
##   1. 顶部：已完成配对数 / 通关需要的总数（原版 ADSCORE 口径「完成 N 次配对以完成关卡」）
##   2. 底部一排按钮：N 档植物升级（档数跟着 `ConstBeghouled.UPGRADE_LIST` 走）+ 重置植物 + 填补弹坑
##
## **节点在脚本里建，不做 .tscn**：这一块没有美术资源（就是一行文字 + 五个按钮），
## 做成场景文件反而要跟着维护一份没有内容的 .tscn。主题沿用主界面主题 pvz_theme。
##
## 谁在用它：BeghouledManager._create_ui()（挂在 MainGameManager 的 CanvasLayerUI 下）

const UI_THEME_PATH := "res://data/ui/themes/pvz_theme.tres"
## 按钮条左下角起点 x（让开左下角的阳光计数器与出战卡槽）
const BAR_OFFSET_LEFT := 150.0
## 按钮条底边距（卡槽上方）
const BAR_OFFSET_BOTTOM := 120.0
const BAR_HEIGHT := 50.0
const BUTTON_WIDTH := 120.0
## 升级按钮之后的固定按钮数：重置植物、填补弹坑
const EXTRA_BUTTON_NUM := 2

var manager: BeghouledManager = null
var progress_label: Label = null
var all_buttons: Array[Button] = []


func bind_manager(beghouled_manager: BeghouledManager) -> void:
	manager = beghouled_manager


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := load(UI_THEME_PATH) as Theme
	if ui_theme != null:
		theme = ui_theme
	_build_progress_label()
	_build_button_bar()


func _build_progress_label() -> void:
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progress_label.offset_left = -120.0
	progress_label.offset_top = 6.0
	progress_label.offset_right = 120.0
	progress_label.offset_bottom = 36.0
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 18)
	add_child(progress_label)


func _build_button_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "ButtonBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = BAR_OFFSET_LEFT
	bar.offset_top = -BAR_OFFSET_BOTTOM - BAR_HEIGHT
	bar.offset_right = 800.0
	bar.offset_bottom = -BAR_OFFSET_BOTTOM
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	## 按钮数跟常量表走：升级有几档就先排几个，末尾固定跟上「重置 / 填坑」
	for i in range(ConstBeghouled.UPGRADE_LIST.size() + EXTRA_BUTTON_NUM):
		var new_button := Button.new()
		new_button.name = "BeghouledButton%d" % i
		new_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BAR_HEIGHT)
		new_button.add_theme_font_size_override("font_size", 15)
		new_button.pressed.connect(_on_button_pressed.bind(i))
		bar.add_child(new_button)
		all_buttons.append(new_button)


## 刷新进度与按钮（阳光变化 / 消除 / 购买后由 BeghouledManager 调用）
func refresh_view(match_num: int, button_infos: Array[Dictionary]) -> void:
	if progress_label != null:
		progress_label.text = "配对 %d / %d" % [match_num, ConstBeghouled.TARGET_MATCH_NUM]
	for i in range(all_buttons.size()):
		if i >= button_infos.size():
			break
		var info: Dictionary = button_infos[i]
		all_buttons[i].text = str(info.get("text", ""))
		all_buttons[i].disabled = bool(info.get("disabled", true))


func _on_button_pressed(index: int) -> void:
	if manager == null:
		return
	var upgrade_num: int = ConstBeghouled.UPGRADE_LIST.size()
	if index < upgrade_num:
		manager.try_buy_upgrade(index)
	elif index == upgrade_num:
		manager.try_shuffle()
	else:
		manager.try_fill_crater()
