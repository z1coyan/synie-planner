class_name Hotbar
extends CanvasLayer

## Satisfactory 风格底部快捷栏：0-9 槽位，高亮当前工具 / 楼层 / 全层状态。

const SLOT_DEFS := [
	{"key": "0", "name": "取消"},
	{"key": "1", "name": "墙体"},
	{"key": "2", "name": "立柱"},
	{"key": "3", "name": "设备"},
	{"key": "4", "name": "开洞"},
	{"key": "5", "name": "1F"},
	{"key": "6", "name": "2F"},
	{"key": "7", "name": "3F"},
	{"key": "8", "name": "4F"},
	{"key": "9", "name": "全层"},
]

var _slots: Array = []

func setup() -> void:
	layer = 60
	var root := HBoxContainer.new()
	root.name = "HotbarRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	root.theme = UiTheme.make_theme()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_top = -100.0
	root.offset_bottom = -22.0
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
	p.custom_minimum_size = Vector2(72.0, 76.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.slot_style())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	var key_label := Label.new()
	key_label.text = def["key"]
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 16)
	key_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	vb.add_child(key_label)
	vb.add_child(name_label)
	p.add_child(vb)
	return p

## tool: "none" | "wall" | "column" | "device" | "opening"
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
		(_slots[i] as PanelContainer).add_theme_stylebox_override(
			"panel", UiTheme.slot_style(active, secondary))
