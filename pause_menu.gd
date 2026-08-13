class_name PauseMenu
extends CanvasLayer

## Esc 唤出/关闭暂停菜单：暂停游戏、释放鼠标；本地存档 / 读取 / 新建。

var camera_rig: CameraController
var save_system: SaveSystem
var _open := false
var _confirming := false
var _confirm_action := ""

var _name_edit: LineEdit
var _save_list: ItemList
var _status: Label
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _panel: PanelContainer

func setup(cc: CameraController, saves: SaveSystem = null) -> void:
	camera_rig = cc
	save_system = saves
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -170.0
	_panel.offset_top = -250.0
	_panel.offset_right = 170.0
	_panel.offset_bottom = 250.0
	_panel.theme = UiTheme.make_theme()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "菜单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "WASD 移动 · Shift 跑 · 空格 跳 · F 飞行 · Tab 视角"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

	var resume := Button.new()
	resume.text = "继续"
	resume.pressed.connect(toggle)
	vb.add_child(resume)

	vb.add_child(HSeparator.new())

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var name_lab := Label.new()
	name_lab.text = "存档名"
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_lab)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "自动时间戳"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	vb.add_child(name_row)

	var save_btn := Button.new()
	save_btn.text = "本地存档"
	save_btn.pressed.connect(_on_save)
	vb.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "读取存档"
	load_btn.pressed.connect(_on_load)
	vb.add_child(load_btn)

	_save_list = ItemList.new()
	_save_list.custom_minimum_size = Vector2(0.0, 110.0)
	_save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_list.item_activated.connect(func(_i: int) -> void: _on_load())
	vb.add_child(_save_list)

	var new_btn := Button.new()
	new_btn.text = "新建存档"
	new_btn.pressed.connect(_on_new)
	vb.add_child(new_btn)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	vb.add_child(HSeparator.new())

	var quit := Button.new()
	quit.text = "退出"
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

	add_child(_panel)

	_confirm_panel = PanelContainer.new()
	_confirm_panel.theme = UiTheme.make_theme()
	_confirm_panel.anchor_left = 0.5
	_confirm_panel.anchor_top = 0.5
	_confirm_panel.anchor_right = 0.5
	_confirm_panel.anchor_bottom = 0.5
	_confirm_panel.offset_left = -160.0
	_confirm_panel.offset_top = -70.0
	_confirm_panel.offset_right = 160.0
	_confirm_panel.offset_bottom = 70.0
	_confirm_panel.visible = false
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 10)
	_confirm_panel.add_child(cvb)
	_confirm_label = Label.new()
	_confirm_label.text = "有未保存更改，确定新建？"
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cvb.add_child(_confirm_label)
	var cbtns := HBoxContainer.new()
	cbtns.alignment = BoxContainer.ALIGNMENT_CENTER
	cbtns.add_theme_constant_override("separation", 10)
	var cancel_c := Button.new()
	cancel_c.text = "取消"
	cancel_c.custom_minimum_size = Vector2(96.0, 0.0)
	cancel_c.pressed.connect(_hide_confirm)
	cbtns.add_child(cancel_c)
	var ok_c := Button.new()
	ok_c.text = "确定"
	ok_c.custom_minimum_size = Vector2(96.0, 0.0)
	ok_c.pressed.connect(_confirm_ok)
	cbtns.add_child(ok_c)
	cvb.add_child(cbtns)
	add_child(_confirm_panel)

	visible = false

func toggle() -> void:
	if _confirming:
		_hide_confirm()
		return
	_open = not _open
	if _open:
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		_refresh_list()
		if save_system != null:
			_name_edit.placeholder_text = save_system.default_save_name()
		_status.text = ""
	else:
		_hide_confirm()
		visible = false
		get_tree().paused = false
		if camera_rig != null:
			camera_rig.apply_mouse_mode()

func _refresh_list() -> void:
	_save_list.clear()
	if save_system == null:
		return
	for rec in save_system.list_saves():
		var stamp := Time.get_datetime_string_from_unix_time(int(rec["mtime"]))
		_save_list.add_item("%s    %s" % [rec["name"], stamp])
		_save_list.set_item_metadata(_save_list.item_count - 1, rec["path"])

func _on_save() -> void:
	if save_system == null:
		return
	var err := save_system.save_game(_name_edit.text)
	if err == "":
		_status.text = "已保存到本地"
		_name_edit.text = ""
		_refresh_list()
	else:
		_status.text = err

func _on_load() -> void:
	if save_system == null:
		return
	var sel := _save_list.get_selected_items()
	if sel.is_empty():
		_status.text = "请先在列表中选择存档"
		return
	if save_system.is_dirty():
		_ask_confirm("有未保存更改，确定读取？", "load")
		return
	_do_load()

func _on_new() -> void:
	if save_system == null:
		return
	if save_system.is_dirty():
		_ask_confirm("有未保存更改，确定新建？", "new")
		return
	_do_new()

func _ask_confirm(msg: String, action: String) -> void:
	_confirming = true
	_confirm_action = action
	_confirm_label.text = msg
	_confirm_panel.visible = true

func _hide_confirm() -> void:
	_confirming = false
	_confirm_action = ""
	_confirm_panel.visible = false

func _confirm_ok() -> void:
	var act := _confirm_action
	_hide_confirm()
	if act == "new":
		_do_new()
	elif act == "load":
		_do_load()

func _do_new() -> void:
	save_system.new_world()
	_status.text = "已新建空场景"

func _do_load() -> void:
	var sel := _save_list.get_selected_items()
	if sel.is_empty():
		_status.text = "请先在列表中选择存档"
		return
	var path := String(_save_list.get_item_metadata(sel[0]))
	var err := save_system.load_game(path)
	if err == "":
		_status.text = "已读取存档"
	else:
		_status.text = err

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _confirming:
				_hide_confirm()
			else:
				toggle()
			get_viewport().set_input_as_handled()
