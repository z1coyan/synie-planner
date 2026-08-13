class_name ToolParamsPanel
extends CanvasLayer

## 工具参数对话框：按种类编辑基本尺寸（柱/墙/地板/楼梯/门洞/窗洞）。

signal confirmed
signal cancelled

var camera_rig: CameraController

var _mask: ColorRect
var _panel: PanelContainer
var _title: Label
var _form: GridContainer
var _open := false
var _kind := ""
var _values: Dictionary = {}

var _height_spin: SpinBox
var _thickness_spin: SpinBox
var _width_spin: SpinBox
var _length_spin: SpinBox
var _height_row_label: Label
var _thickness_row_label: Label
var _width_row_label: Label
var _length_row_label: Label
var _sill_spin: SpinBox
var _sill_row_label: Label

func setup(cc: CameraController) -> void:
	camera_rig = cc
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mask = ColorRect.new()
	_mask.name = "ParamsMask"
	_mask.color = Color(0, 0, 0, 0.55)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mask)

	_panel = PanelContainer.new()
	_panel.name = "ParamsDialog"
	_panel.theme = UiTheme.make_theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(300.0, 220.0)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -160.0
	_panel.offset_top = -140.0
	_panel.offset_right = 160.0
	_panel.offset_bottom = 140.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(vb)

	_title = Label.new()
	_title.text = "工具参数"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	vb.add_child(_title)

	_form = GridContainer.new()
	_form.columns = 2
	_form.add_theme_constant_override("h_separation", 10)
	_form.add_theme_constant_override("v_separation", 8)
	_form.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_form)

	_width_row_label = _mk_label("横向宽度")
	_width_spin = _mk_float_spin(0.4, 20.0, 0.05, 1.2)
	_length_row_label = _mk_label("前后长度")
	_length_spin = _mk_float_spin(0.5, 40.0, 0.1, 8.0)
	_height_row_label = _mk_label("高度")
	_height_spin = _mk_float_spin(0.5, 50.0, 0.1, 5.0)
	_thickness_row_label = _mk_label("厚度")
	_thickness_spin = _mk_float_spin(0.1, 10.0, 0.05, 0.4)
	_sill_row_label = _mk_label("窗台高度")
	_sill_spin = _mk_float_spin(0.0, 10.0, 0.05, 0.9)
	_form.add_child(_width_row_label)
	_form.add_child(_width_spin)
	_form.add_child(_length_row_label)
	_form.add_child(_length_spin)
	_form.add_child(_height_row_label)
	_form.add_child(_height_spin)
	_form.add_child(_thickness_row_label)
	_form.add_child(_thickness_spin)
	_form.add_child(_sill_row_label)
	_form.add_child(_sill_spin)

	var hint := Label.new()
	hint.text = "确认后立即生效"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	vb.add_child(hint)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(96.0, 0.0)
	cancel_btn.pressed.connect(func (): cancelled.emit())
	btns.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(96.0, 0.0)
	_style_primary(confirm_btn)
	confirm_btn.pressed.connect(_on_confirm)
	btns.add_child(confirm_btn)
	vb.add_child(btns)

	visible = false
	_open = false

func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", UiTheme.button_style(false, true))
	btn.add_theme_stylebox_override("hover", UiTheme.button_style(true, false))
	btn.add_theme_stylebox_override("pressed", UiTheme.button_style(false, true))
	btn.add_theme_color_override("font_color", UiTheme.WHITE)
	btn.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	btn.add_theme_color_override("font_pressed_color", UiTheme.WHITE)

func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _mk_float_spin(min_v: float, max_v: float, step_v: float, def_v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.value = def_v
	s.suffix = " m"
	s.custom_minimum_size = Vector2(120.0, 0.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	return s

## values: { "height": float?, "thickness": float? } 逻辑尺寸（不含 EMBED）
func show_dialog(kind: String, values: Dictionary) -> void:
	_kind = kind
	_values = values.duplicate()
	match kind:
		"column":
			_title.text = "柱子参数"
			_width_row_label.visible = false
			_width_spin.visible = false
			_length_row_label.visible = false
			_length_spin.visible = false
			_height_row_label.text = "高度"
			_thickness_row_label.text = "粗细"
			_height_row_label.visible = true
			_height_spin.visible = true
			_thickness_row_label.visible = true
			_thickness_spin.visible = true
			_height_spin.min_value = 1.0
			_height_spin.max_value = 50.0
			_height_spin.step = 0.1
			_thickness_spin.min_value = 0.2
			_thickness_spin.max_value = 5.0
			_thickness_spin.step = 0.05
			_height_spin.value = float(values.get("height", Config.COLUMN_HEIGHT))
			_thickness_spin.value = float(values.get("thickness", Config.COLUMN_SIZES[0]))
			_sill_row_label.visible = false
			_sill_spin.visible = false
		"wall":
			_title.text = "墙体参数"
			_width_row_label.visible = false
			_width_spin.visible = false
			_length_row_label.visible = false
			_length_spin.visible = false
			_height_row_label.text = "高度"
			_thickness_row_label.text = "厚度"
			_height_row_label.visible = true
			_height_spin.visible = true
			_thickness_row_label.visible = true
			_thickness_spin.visible = true
			_height_spin.min_value = 1.0
			_height_spin.max_value = 50.0
			_height_spin.step = 0.1
			_thickness_spin.min_value = Config.WALL_THICKNESS_MIN
			_thickness_spin.max_value = Config.WALL_THICKNESS_MAX
			_thickness_spin.step = Config.WALL_THICKNESS_STEP
			_height_spin.value = float(values.get("height", Config.WALL_HEIGHT))
			_thickness_spin.value = float(values.get("thickness", Config.WALL_THICKNESS_DEFAULT))
			_sill_row_label.visible = false
			_sill_spin.visible = false
		"floor_tile":
			_title.text = "地板参数"
			_width_row_label.visible = false
			_width_spin.visible = false
			_length_row_label.visible = false
			_length_spin.visible = false
			_height_row_label.visible = false
			_height_spin.visible = false
			_thickness_row_label.text = "厚度"
			_thickness_row_label.visible = true
			_thickness_spin.visible = true
			_thickness_spin.min_value = 0.1
			_thickness_spin.max_value = 2.0
			_thickness_spin.step = 0.05
			_thickness_spin.value = float(values.get("thickness", Config.FLOOR_THICKNESS))
			_sill_row_label.visible = false
			_sill_spin.visible = false
		"stair":
			_title.text = "楼梯参数"
			_width_row_label.text = "横向宽度"
			_width_row_label.visible = true
			_width_spin.visible = true
			_length_row_label.visible = true
			_length_spin.visible = true
			_height_row_label.visible = true
			_height_spin.visible = true
			_thickness_row_label.visible = false
			_thickness_spin.visible = false
			_sill_row_label.visible = false
			_sill_spin.visible = false
			_width_spin.min_value = 0.4
			_width_spin.max_value = 20.0
			_width_spin.step = 0.05
			_length_spin.min_value = 0.5
			_length_spin.max_value = 40.0
			_length_spin.step = 0.1
			_height_spin.min_value = 0.3
			_height_spin.max_value = 50.0
			_height_spin.step = 0.1
			_width_spin.value = float(values.get("width", Config.STAIR_WIDTH))
			_length_spin.value = float(values.get("length", Config.STAIR_LENGTH))
			_height_spin.value = float(values.get("height", Config.STAIR_HEIGHT))
		"door":
			_title.text = "门洞参数"
			_width_row_label.text = "宽度"
			_width_row_label.visible = true
			_width_spin.visible = true
			_length_row_label.visible = false
			_length_spin.visible = false
			_height_row_label.text = "高度"
			_height_row_label.visible = true
			_height_spin.visible = true
			_thickness_row_label.visible = false
			_thickness_spin.visible = false
			_sill_row_label.visible = false
			_sill_spin.visible = false
			_width_spin.min_value = Config.OPENING_MIN
			_width_spin.max_value = 20.0
			_width_spin.step = 0.05
			_height_spin.min_value = Config.OPENING_MIN
			_height_spin.max_value = 20.0
			_height_spin.step = 0.05
			_width_spin.value = float(values.get("width", Config.DOOR_WIDTH))
			_height_spin.value = float(values.get("height", Config.DOOR_HEIGHT))
		"floor_hole":
			_title.text = "地洞参数"
			_width_row_label.text = "横向宽度"
			_width_row_label.visible = true
			_width_spin.visible = true
			_length_row_label.text = "纵向长度"
			_length_row_label.visible = true
			_length_spin.visible = true
			_height_row_label.visible = false
			_height_spin.visible = false
			_thickness_row_label.visible = false
			_thickness_spin.visible = false
			_sill_row_label.visible = false
			_sill_spin.visible = false
			_width_spin.min_value = Config.OPENING_MIN
			_width_spin.max_value = 40.0
			_width_spin.step = 0.05
			_length_spin.min_value = Config.OPENING_MIN
			_length_spin.max_value = 40.0
			_length_spin.step = 0.05
			_width_spin.value = float(values.get("width", Config.FLOOR_HOLE_WIDTH))
			_length_spin.value = float(values.get("length", Config.FLOOR_HOLE_LENGTH))
		"window":
			_title.text = "窗洞参数"
			_width_row_label.text = "宽度"
			_width_row_label.visible = true
			_width_spin.visible = true
			_length_row_label.visible = false
			_length_spin.visible = false
			_height_row_label.text = "高度"
			_height_row_label.visible = true
			_height_spin.visible = true
			_thickness_row_label.visible = false
			_thickness_spin.visible = false
			_sill_row_label.text = "窗台高度"
			_sill_row_label.visible = true
			_sill_spin.visible = true
			_width_spin.min_value = Config.OPENING_MIN
			_width_spin.max_value = 20.0
			_width_spin.step = 0.05
			_height_spin.min_value = Config.OPENING_MIN
			_height_spin.max_value = 20.0
			_height_spin.step = 0.05
			_sill_spin.min_value = 0.0
			_sill_spin.max_value = 10.0
			_sill_spin.step = 0.05
			_width_spin.value = float(values.get("width", Config.WINDOW_WIDTH))
			_height_spin.value = float(values.get("height", Config.WINDOW_HEIGHT))
			_sill_spin.value = float(values.get("sill", Config.WINDOW_SILL))
		_:
			cancelled.emit()
			return
	_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_dialog() -> void:
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and _panel != null and (_panel == fo or _panel.is_ancestor_of(fo)):
		fo.release_focus()
	_open = false
	visible = false
	if camera_rig != null:
		camera_rig.apply_mouse_mode()

func is_open() -> bool:
	return _open

func get_kind() -> String:
	return _kind

func get_values() -> Dictionary:
	return _values.duplicate()

func _on_confirm() -> void:
	match _kind:
		"column", "wall":
			_values = {
				"height": float(_height_spin.value),
				"thickness": float(_thickness_spin.value),
			}
		"floor_tile":
			_values = {"thickness": float(_thickness_spin.value)}
		"stair":
			_values = {
				"width": float(_width_spin.value),
				"length": float(_length_spin.value),
				"height": float(_height_spin.value),
			}
		"door":
			_values = {
				"width": float(_width_spin.value),
				"height": float(_height_spin.value),
				"sill": 0.0,
			}
		"floor_hole":
			_values = {
				"width": float(_width_spin.value),
				"length": float(_length_spin.value),
			}
		"window":
			_values = {
				"width": float(_width_spin.value),
				"height": float(_height_spin.value),
				"sill": float(_sill_spin.value),
			}
	confirmed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _open or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()

