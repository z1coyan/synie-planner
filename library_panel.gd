class_name LibraryPanel
extends CanvasLayer

## 元素库面板：列出设备类型、选择当前放置设备、新增/删除设备类型（纯代码 UI）。

signal device_selected

var library: ElementLibrary
var builder: Builder
var camera_rig: CameraController
var hud: Hud

var _open := false
var _panel: PanelContainer
var _list: ItemList
var _info: Label
var _name_edit: LineEdit
var _cat_edit: LineEdit
var _w_box: SpinBox
var _h_box: SpinBox
var _d_box: SpinBox
var _color_btn: ColorPickerButton

func setup(lib: ElementLibrary, b: Builder, cc: CameraController, h: Hud) -> void:
	library = lib
	builder = b
	camera_rig = cc
	hud = h
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -200.0
	_panel.offset_top = -235.0
	_panel.offset_right = 200.0
	_panel.offset_bottom = 235.0
	_panel.theme = UiTheme.make_theme()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "设备元素库"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	vb.add_child(title)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0.0, 125.0)
	_list.item_selected.connect(_on_selected)
	vb.add_child(_list)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_info)

	var sep := HSeparator.new()
	vb.add_child(sep)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 6)
	form.add_theme_constant_override("v_separation", 3)
	form.add_child(_mk_label("名称"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "如：CNC 加工中心"
	form.add_child(_name_edit)
	form.add_child(_mk_label("分类"))
	_cat_edit = LineEdit.new()
	_cat_edit.placeholder_text = "如：机加工"
	form.add_child(_cat_edit)
	form.add_child(_mk_label("长 L (m)"))
	_w_box = _mk_spin()
	form.add_child(_w_box)
	form.add_child(_mk_label("宽 D (m)"))
	_d_box = _mk_spin()
	form.add_child(_d_box)
	form.add_child(_mk_label("高 H (m)"))
	_h_box = _mk_spin()
	form.add_child(_h_box)
	form.add_child(_mk_label("颜色"))
	_color_btn = ColorPickerButton.new()
	_color_btn.color = Color(0.78, 0.79, 0.81)
	form.add_child(_color_btn)
	vb.add_child(form)

	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "添加设备类型"
	add_btn.pressed.connect(_on_add)
	btns.add_child(add_btn)
	var del_btn := Button.new()
	del_btn.text = "删除选中"
	del_btn.pressed.connect(_on_delete)
	btns.add_child(del_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭 (B)"
	close_btn.pressed.connect(toggle)
	btns.add_child(close_btn)
	vb.add_child(btns)

	add_child(_panel)
	visible = false

func is_open() -> bool:
	return _open

func _mk_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _mk_spin() -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 0.5
	s.max_value = 50.0
	s.step = 0.5
	s.value = 2.0
	s.suffix = " m"
	return s

func toggle() -> void:
	_open = not _open
	if _open:
		_refresh()
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		visible = false
		camera_rig.apply_mouse_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		toggle()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	_list.clear()
	for i in library.count():
		var dev := library.get_device(i)
		_list.add_item("%s   %d×%d×%d m  [%s]" % [
			dev.name, int(dev.size.x), int(dev.size.y), int(dev.size.z), dev.category,
		])
	_list.select(library.current)
	_update_info()

func _update_info() -> void:
	var dev := library.current_device()
	_info.text = "当前放置：%s\n尺寸：%d×%d×%d m   分类：%s" % [
		dev.name, int(dev.size.x), int(dev.size.y), int(dev.size.z), dev.category,
	]

func _on_selected(index: int) -> void:
	library.set_current(index)
	_update_info()
	builder.refresh_device()
	hud.set_status("选择设备：%s" % library.current_device().name)
	device_selected.emit()

func _on_add() -> void:
	var ok := library.add_device(
		_name_edit.text,
		Vector3(_w_box.value, _h_box.value, _d_box.value),
		_color_btn.color,
		_cat_edit.text,
	)
	if ok:
		_refresh()
		builder.refresh_device()
		hud.set_status("已添加设备类型：%s" % library.current_device().name)
	else:
		hud.set_status("添加失败：名称不能为空，尺寸需 ≥ 0.5m")

func _on_delete() -> void:
	if library.count() <= 1:
		hud.set_status("至少保留一个设备类型")
		return
	var i := _list.get_selected_items()
	if i.is_empty():
		return
	var dev_name: String = library.get_device(i[0]).name
	library.remove_device(i[0])
	_refresh()
	builder.refresh_device()
	hud.set_status("已删除设备类型：%s" % dev_name)
