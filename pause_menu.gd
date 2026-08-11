class_name PauseMenu
extends CanvasLayer

## Esc 唤出/关闭暂停菜单：暂停游戏、释放鼠标，便于操作窗口与 UI。

var camera_rig: CameraController
var _open := false

func setup(cc: CameraController) -> void:
	camera_rig = cc
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -170.0
	panel.offset_top = -130.0
	panel.offset_right = 170.0
	panel.offset_bottom = 130.0

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "菜单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "Tab 视角切换 · 1/2/3 工具 · R 旋转 · F 飞行"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var resume := Button.new()
	resume.text = "继续"
	resume.pressed.connect(toggle)
	vb.add_child(resume)

	var quit := Button.new()
	quit.text = "退出"
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

	add_child(panel)
	visible = false

func toggle() -> void:
	_open = not _open
	if _open:
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		visible = false
		get_tree().paused = false
		camera_rig.apply_mouse_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()
