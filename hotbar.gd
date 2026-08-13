class_name Hotbar
extends CanvasLayer

## 双层快捷栏——底层工具 1-8/X 常驻；设备选中时上层浮出 F2 阵列。
## 柱/墙/地板/楼梯/门洞/窗洞的 F1/F3 由 ParamBar 负责。

signal action_chosen(action_id: String)

const SLOT_DEFS := [
	{"key": "1", "name": "无", "icon": "cancel"},
	{"key": "2", "name": "柱子", "icon": "column"},
	{"key": "3", "name": "墙体", "icon": "wall"},
	{"key": "4", "name": "地板", "icon": "floor_tile"},
	{"key": "5", "name": "楼梯", "icon": "stair"},
	{"key": "6", "name": "门洞", "icon": "door"},
	{"key": "7", "name": "窗洞", "icon": "window"},
	{"key": "8", "name": "地洞", "icon": "floor_hole"},
	{"key": "X", "name": "删除", "icon": "delete"},
]

const ACTION_DEFS := [
	{"key": "F2", "id": "array", "name": "阵列", "icon": "array"},
]

var _tools_root: HBoxContainer
var _actions_root: HBoxContainer
var _action_title: Label
var _slots: Array = []
var _icons: Array = []
var _action_slots: Array = []
var _action_icons: Array = []
var _tool_state := "none"
var _bar_mode := "tools"  # tools | actions

func setup() -> void:
	layer = 60
	var wrap := Control.new()
	wrap.name = "HotbarWrap"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)

	_tools_root = HBoxContainer.new()
	_tools_root.name = "HotbarRoot"
	_tools_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tools_root.add_theme_constant_override("separation", 4)
	_tools_root.theme = UiTheme.make_theme()
	_tools_root.anchor_left = 0.5
	_tools_root.anchor_right = 0.5
	_tools_root.anchor_top = 1.0
	_tools_root.anchor_bottom = 1.0
	_tools_root.offset_top = -84.0
	_tools_root.offset_bottom = -16.0
	_tools_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tools_root.alignment = BoxContainer.ALIGNMENT_CENTER
	for def in SLOT_DEFS:
		var slot := _build_slot(def, false)
		_slots.append(slot)
		_tools_root.add_child(slot)
	wrap.add_child(_tools_root)

	_actions_root = HBoxContainer.new()
	_actions_root.name = "ActionRoot"
	_actions_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions_root.add_theme_constant_override("separation", 4)
	_actions_root.theme = UiTheme.make_theme()
	_actions_root.anchor_left = 0.5
	_actions_root.anchor_right = 0.5
	_actions_root.anchor_top = 1.0
	_actions_root.anchor_bottom = 1.0
	_actions_root.offset_top = -160.0
	_actions_root.offset_bottom = -92.0
	_actions_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_actions_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_root.visible = false

	_action_title = Label.new()
	_action_title.text = "物体"
	_action_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_title.add_theme_font_size_override("font_size", 12)
	_action_title.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_action_title.custom_minimum_size = Vector2(72.0, 64.0)
	_actions_root.add_child(_action_title)

	for def in ACTION_DEFS:
		var slot2 := _build_slot(def, true)
		_action_slots.append(slot2)
		_actions_root.add_child(slot2)
	wrap.add_child(_actions_root)

	set_state("none")

func _build_slot(def: Dictionary, clickable: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(58.0, 64.0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.slot_style())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	var key_label := Label.new()
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.text = str(def.get("key", "·"))
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	var icon := IconView.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.icon = def["icon"]
	icon.icon_param = def.get("param", 0)
	if clickable:
		_action_icons.append(icon)
	else:
		_icons.append(icon)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = def["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	vb.add_child(key_label)
	vb.add_child(icon)
	vb.add_child(name_label)
	p.add_child(vb)
	if clickable:
		var action_id: String = def["id"]
		p.gui_input.connect(_on_action_slot_input.bind(action_id))
	return p

func _on_action_slot_input(event: InputEvent, action_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		action_chosen.emit(action_id)
		get_viewport().set_input_as_handled()

## tool: "none" | "wall" | "column" | "device" | "floor_tile" | "stair" | "door" | "window" | "floor_hole" | "delete"
func set_state(tool: String) -> void:
	_tool_state = tool
	for i in _slots.size():
		var active := false
		match i:
			0:
				active = tool == "none"
			1:
				active = tool == "column"
			2:
				active = tool == "wall"
			3:
				active = tool == "floor_tile"
			4:
				active = tool == "stair"
			5:
				active = tool == "door"
			6:
				active = tool == "window"
			7:
				active = tool == "floor_hole"
			8:
				active = tool == "delete"
		(_slots[i] as PanelContainer).add_theme_stylebox_override(
			"panel", UiTheme.slot_style(active, false))
		(_icons[i] as IconView).icon_color = UiTheme.ACCENT if active else UiTheme.TEXT
		(_icons[i] as IconView).queue_redraw()

func show_tools() -> void:
	_bar_mode = "tools"
	_tools_root.visible = true
	_actions_root.visible = false
	set_state(_tool_state)

func show_actions(kind_name: String, active_action: String = "") -> void:
	_bar_mode = "actions"
	_actions_root.visible = true
	_tools_root.visible = true
	_action_title.text = kind_name
	_highlight_actions(active_action)

func _highlight_actions(active_action: String) -> void:
	for i in _action_slots.size():
		var id: String = ACTION_DEFS[i]["id"]
		var on := active_action != "" and id == active_action
		(_action_slots[i] as PanelContainer).add_theme_stylebox_override(
			"panel", UiTheme.slot_style(on, false))
		(_action_icons[i] as IconView).icon_color = UiTheme.ACCENT if on else UiTheme.TEXT
		(_action_icons[i] as IconView).queue_redraw()

func is_action_mode() -> bool:
	return _bar_mode == "actions"

class IconView:
	extends Control

	var icon := ""
	var icon_param := 0
	var icon_color := UiTheme.TEXT

	func _draw() -> void:
		UiIcons.draw(self, icon, icon_color, size.x, icon_param)
