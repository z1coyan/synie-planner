class_name Hotbar
extends CanvasLayer

## Satisfactory 风格底部快捷栏：0-9 槽位，高亮当前工具 / 楼层 / 全层状态。

const SLOT_DEFS := [
	{"key": "0", "name": "取消", "icon": "cancel"},
	{"key": "1", "name": "墙体", "icon": "wall"},
	{"key": "2", "name": "立柱", "icon": "column"},
	{"key": "3", "name": "设备", "icon": "device"},
	{"key": "4", "name": "开洞", "icon": "opening"},
	{"key": "5", "name": "1F", "icon": "floors", "param": 1},
	{"key": "6", "name": "2F", "icon": "floors", "param": 2},
	{"key": "7", "name": "3F", "icon": "floors", "param": 3},
	{"key": "8", "name": "4F", "icon": "floors", "param": 4},
	{"key": "9", "name": "全层", "icon": "showall"},
	{"key": "X", "name": "拆除", "icon": "delete"},
]

var _slots: Array = []
var _icons: Array = []

func setup() -> void:
	layer = 60
	var root := HBoxContainer.new()
	root.name = "HotbarRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 4)
	root.theme = UiTheme.make_theme()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_top = -84.0
	root.offset_bottom = -16.0
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	for def in SLOT_DEFS:
		var slot := _build_slot(def)
		_slots.append(slot)
		root.add_child(slot)
	add_child(root)
	set_state("column", 0, false)

func _build_slot(def: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(58.0, 64.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.slot_style())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	var key_label := Label.new()
	key_label.text = def["key"]
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	var icon := IconView.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.icon = def["icon"]
	icon.icon_param = def.get("param", 0)
	_icons.append(icon)
	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	vb.add_child(key_label)
	vb.add_child(icon)
	vb.add_child(name_label)
	p.add_child(vb)
	return p

## tool: "none" | "wall" | "column" | "device" | "opening" | "delete"
func set_state(tool: String, floor: int, show_all: bool) -> void:
	for i in _slots.size():
		var active := false
		var secondary := false
		match i:
			0:
				active = tool == "none"
			1:
				active = tool == "wall"
			2:
				active = tool == "column"
			3:
				active = tool == "device"
			4:
				active = tool == "opening"
			5, 6, 7, 8:
				secondary = not show_all and floor == i - 5
			9:
				secondary = show_all
			10:
				active = tool == "delete"
		(_slots[i] as PanelContainer).add_theme_stylebox_override(
			"panel", UiTheme.slot_style(active, secondary))
		(_icons[i] as IconView).icon_color = UiTheme.ACCENT if (active or secondary) else UiTheme.TEXT
		(_icons[i] as IconView).queue_redraw()

class IconView:
	extends Control

	var icon := ""
	var icon_param := 0
	var icon_color := UiTheme.TEXT

	func _draw() -> void:
		UiIcons.draw(self, icon, icon_color, size.x, icon_param)
