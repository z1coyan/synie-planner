class_name ParamBar
extends CanvasLayer

## 统一参数栏（柱/墙/地板/楼梯/门洞/窗洞）：放置或选中时浮于快捷栏上方。
## F1 工具参数 · F2 阵列（仅选中） · F3 材质（开洞隐藏）

signal action_requested(action_id: String)

const KIND_NAMES := {
	"column": "柱子", "wall": "墙体", "floor_tile": "地板", "stair": "楼梯",
	"door": "门洞", "window": "窗洞", "floor_hole": "地洞",
}
const MATERIAL_KINDS := ["column", "wall", "floor_tile", "stair"]
const PARAM_KINDS := ["column", "wall", "floor_tile", "stair", "door", "window", "floor_hole"]

var _root: HBoxContainer
var _kind_label: Label
var _mat_label: Label
var _f1_slot: PanelContainer
var _f2_slot: PanelContainer
var _f3_slot: PanelContainer
var _f1_icon: Control
var _f2_icon: Control
var _f3_icon: Control

var _context := ""  # "" | "placement" | "selection"
var _kind := ""
var _material_id := "concrete"
var _show_array := false

func setup() -> void:
	layer = 61
	var wrap := Control.new()
	wrap.name = "ParamBarWrap"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)

	_root = HBoxContainer.new()
	_root.name = "ParamBarRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 4)
	_root.theme = UiTheme.make_theme()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_top = -160.0
	_root.offset_bottom = -92.0
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_root)

	var info := PanelContainer.new()
	info.custom_minimum_size = Vector2(140.0, 64.0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_stylebox_override("panel", UiTheme.slot_style())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	_kind_label = Label.new()
	_kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kind_label.text = "参数"
	_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kind_label.add_theme_font_size_override("font_size", 11)
	_kind_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_mat_label = Label.new()
	_mat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat_label.text = "材质：混凝土"
	_mat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mat_label.add_theme_font_size_override("font_size", 12)
	_mat_label.add_theme_color_override("font_color", UiTheme.TEXT)
	vb.add_child(_kind_label)
	vb.add_child(_mat_label)
	info.add_child(vb)
	_root.add_child(info)

	_f1_slot = _build_action_slot("F1", "工具参数", "params", "params")
	_f1_icon = _f1_slot.get_meta("icon_view")
	_root.add_child(_f1_slot)
	_f2_slot = _build_action_slot("F2", "阵列", "array", "array")
	_f2_icon = _f2_slot.get_meta("icon_view")
	_root.add_child(_f2_slot)
	_f3_slot = _build_action_slot("F3", "材质", "material", "material")
	_f3_icon = _f3_slot.get_meta("icon_view")
	_root.add_child(_f3_slot)

	visible = false

func _build_action_slot(key: String, name: String, icon_id: String, action_id: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(64.0, 64.0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", UiTheme.slot_style())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	var key_label := Label.new()
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.text = key
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	var icon := IconView.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.icon = icon_id
	icon.icon_color = UiTheme.TEXT
	p.set_meta("icon_view", icon)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	vb.add_child(key_label)
	vb.add_child(icon)
	vb.add_child(name_label)
	p.add_child(vb)
	p.gui_input.connect(_on_slot_input.bind(action_id))
	return p

func _on_slot_input(event: InputEvent, action_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if action_id == "array" and not _show_array:
			return
		action_requested.emit(action_id)
		get_viewport().set_input_as_handled()

## context: "placement" | "selection"；placement 隐藏 F2，selection 显示 F2
func show_context(context: String, kind: String, material_id: String, show_array: bool = false) -> void:
	if not PARAM_KINDS.has(kind):
		hide_bar()
		return
	_context = context
	_kind = kind
	_show_array = show_array and context == "selection"
	_kind_label.text = KIND_NAMES.get(kind, "参数")
	if context == "selection":
		_kind_label.text = "已选 · %s" % KIND_NAMES.get(kind, "物体")
	elif context == "placement":
		_kind_label.text = "放置 · %s" % KIND_NAMES.get(kind, "物体")
	var show_mat := MATERIAL_KINDS.has(kind)
	_f3_slot.visible = show_mat
	if show_mat:
		_material_id = Config.normalize_material(material_id)
		_refresh_material_label()
	else:
		_material_id = ""
		_mat_label.text = "开洞 · 无材质"
	_f2_slot.visible = _show_array
	_root.offset_top = -160.0
	_root.offset_bottom = -92.0
	visible = true

func hide_bar() -> void:
	_context = ""
	_kind = ""
	_show_array = false
	visible = false

func is_visible_bar() -> bool:
	return visible and _context != ""

func get_context() -> String:
	return _context

func get_kind() -> String:
	return _kind

func get_material() -> String:
	return _material_id

func set_material(material_id: String) -> void:
	_material_id = Config.normalize_material(material_id)
	_refresh_material_label()

func _refresh_material_label() -> void:
	_mat_label.text = "材质：%s" % Config.material_label(_material_id)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_bar():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				action_requested.emit("params")
				get_viewport().set_input_as_handled()
			KEY_F2:
				if _show_array:
					action_requested.emit("array")
					get_viewport().set_input_as_handled()
			KEY_F3:
				if _f3_slot.visible:
					action_requested.emit("material")
					get_viewport().set_input_as_handled()

class IconView:
	extends Control

	var icon := ""
	var icon_param := 0
	var icon_color := UiTheme.TEXT

	func _draw() -> void:
		UiIcons.draw(self, icon, icon_color, size.x, icon_param)

