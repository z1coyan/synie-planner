class_name ArrayPanel
extends CanvasLayer

## 阵列参数居中对话框：遮罩 + 数量/间距表单，确认后进入准星放置。

signal confirmed
signal cancelled

const COUNT_MAX := 40
const SPACING_MAX := 50.0

var camera_rig: CameraController

var _mask: ColorRect
var _panel: PanelContainer
var _count_u: SpinBox
var _count_v: SpinBox
var _spacing_u: SpinBox
var _spacing_v: SpinBox
var _open := false

func setup(cc: CameraController) -> void:
	camera_rig = cc
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mask = ColorRect.new()
	_mask.name = "ArrayMask"
	_mask.color = Color(0, 0, 0, 0.55)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mask)

	_panel = PanelContainer.new()
	_panel.name = "ArrayDialog"
	_panel.theme = UiTheme.make_theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(280.0, 300.0)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -140.0
	_panel.offset_top = -150.0
	_panel.offset_right = 140.0
	_panel.offset_bottom = 150.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(vb)

	var title := Label.new()
	title.text = "阵列参数"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 10)
	form.add_theme_constant_override("v_separation", 6)
	form.mouse_filter = Control.MOUSE_FILTER_STOP
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(_mk_label("横向数量"))
	_count_u = _mk_int_spin(1, COUNT_MAX, 1)
	form.add_child(_count_u)
	form.add_child(_mk_label("纵向数量"))
	_count_v = _mk_int_spin(1, COUNT_MAX, 1)
	form.add_child(_count_v)
	form.add_child(_mk_label("横向间距"))
	_spacing_u = _mk_float_spin(0.0, SPACING_MAX, 0.01, 0.0)
	form.add_child(_spacing_u)
	form.add_child(_mk_label("纵向间距"))
	_spacing_v = _mk_float_spin(0.0, SPACING_MAX, 0.01, 0.0)
	form.add_child(_spacing_v)
	vb.add_child(form)

	var hint := Label.new()
	hint.text = "确认后准星定方向，左键放置"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.mouse_filter = Control.MOUSE_FILTER_STOP
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(96.0, 0.0)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btns.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(96.0, 0.0)
	_style_primary(confirm_btn)
	confirm_btn.pressed.connect(_on_confirm_pressed)
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

func _mk_int_spin(min_v: int, max_v: int, def_v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1
	s.rounded = true
	s.value = def_v
	s.custom_minimum_size = Vector2(110.0, 0.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	return s

func _mk_float_spin(min_v: float, max_v: float, step_v: float, def_v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.value = def_v
	s.suffix = " m"
	s.custom_minimum_size = Vector2(110.0, 0.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	return s

func reset_defaults() -> void:
	_count_u.value = 1
	_count_v.value = 1
	_spacing_u.value = 0.0
	_spacing_v.value = 0.0

func show_dialog() -> void:
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

func show_panel() -> void:
	show_dialog()

func hide_panel() -> void:
	hide_dialog()

func is_open() -> bool:
	return _open

func get_count_u() -> int:
	return int(_count_u.value)

func get_count_v() -> int:
	return int(_count_v.value)

func get_spacing_u() -> float:
	return float(_spacing_u.value)

func get_spacing_v() -> float:
	return float(_spacing_v.value)

func _on_confirm_pressed() -> void:
	confirmed.emit()

func _on_cancel_pressed() -> void:
	cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _open or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancelled.emit()
			get_viewport().set_input_as_handled()
