class_name MaterialPanel
extends CanvasLayer

## 通用材质居中对话框：遮罩 + 泥土/混凝土选择，确认后应用并关闭。
## 供参数栏 F3 打开，柱/墙/地板放置与选中共用。

signal confirmed
signal cancelled

var camera_rig: CameraController

var _mask: ColorRect
var _panel: PanelContainer
var _option: OptionButton
var _open := false
var _material := "concrete"

func setup(cc: CameraController) -> void:
	camera_rig = cc
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mask = ColorRect.new()
	_mask.name = "MaterialMask"
	_mask.color = Color(0, 0, 0, 0.55)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mask)

	_panel = PanelContainer.new()
	_panel.name = "MaterialDialog"
	_panel.theme = UiTheme.make_theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(280.0, 200.0)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -140.0
	_panel.offset_top = -100.0
	_panel.offset_right = 140.0
	_panel.offset_bottom = 100.0
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

	var title := Label.new()
	title.text = "选择材质"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var lab := Label.new()
	lab.text = "材质"
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	_option = OptionButton.new()
	_option.name = "MaterialOption"
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.mouse_filter = Control.MOUSE_FILTER_STOP
	_option.add_item("泥土", 0)
	_option.add_item("混凝土", 1)
	_option.set_item_metadata(0, "dirt")
	_option.set_item_metadata(1, "concrete")
	_option.select(1)
	row.add_child(_option)
	vb.add_child(row)

	var hint := Label.new()
	hint.text = "确认后立即生效"
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

func show_dialog(current_material: String) -> void:
	_material = Config.normalize_material(current_material)
	_sync_option_from_material()
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

func get_material() -> String:
	return _material

func _sync_option_from_material() -> void:
	if _option == null:
		return
	for i in _option.item_count:
		if str(_option.get_item_metadata(i)) == _material:
			_option.select(i)
			return
	_option.select(1)

func _read_option_material() -> String:
	if _option == null:
		return _material
	var idx := _option.selected
	if idx < 0:
		return _material
	var meta: Variant = _option.get_item_metadata(idx)
	return Config.normalize_material(str(meta))

func _on_confirm_pressed() -> void:
	_material = _read_option_material()
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
