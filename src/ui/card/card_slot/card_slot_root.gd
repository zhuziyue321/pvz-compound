extends Control
class_name CardSlotRoot

## 卡片
var curr_cards:Array[Card]
## 铲子
@onready var ui_shovel: UIShovel = %UIShovel
## 手套
@onready var ui_glove: UIGlove = %UIGlove

## 快捷键
@warning_ignore("unused_parameter")
func _unhandled_key_input(event: InputEvent) -> void:
	## 铲子快捷键
	if Input.is_action_just_pressed("ShortcutKeys_Shovel"):
		if ui_shovel.visible:
			ui_shovel._on_button_pressed()
		return
	## 手套快捷键（手套功能总开关关闭时整条不响应，见 ConstFeatureSwitch.GLOVE_ENABLED）
	if Input.is_action_just_pressed("ShortcutKeys_Glove"):
		if ConstFeatureSwitch.GLOVE_ENABLED and ui_glove.visible:
			ui_glove._on_button_pressed()
		return
	## 卡片快捷键
	for i in range(1,11):
		## 卡片快捷键
		if Input.is_action_just_pressed("ShortcutKeys_Card" + str(int(i))):
			## 0-9
			var card_i = i - 1
			if card_i < curr_cards.size():
				curr_cards[card_i]._on_button_pressed()
			else:
				return

