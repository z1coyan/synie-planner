class_name CameraController
extends Node3D

## 第一人称漫游 ⇄ 俯视正交 双视角，Tab 切换，F 开关飞行。
## 位移由 Player 负责；本节点只管朝向、投影与飞行标志。

var camera: Camera3D
var host: Node

var mode := "fp"        # "fp" | "top"
var flying := false

var yaw := 0.0
var pitch := 0.0
var top_height := Config.TOP_DOWN_START

const HEAD_LAYER := 2

func setup() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 75.0
	add_child(camera)
	position = Vector3(0.0, Config.EYE_HEIGHT, 0.0)
	_apply_mode()

func is_top_down() -> bool:
	return mode == "top"

func is_input_blocked() -> bool:
	if host != null and host.has_method("is_any_dialog_open") and host.is_any_dialog_open():
		return true
	var vp := get_viewport()
	if vp == null:
		return false
	var fo := vp.gui_get_focus_owner()
	if fo == null:
		return false
	return fo is LineEdit or fo is TextEdit or fo is SpinBox or fo is CodeEdit

static func fp_velocity(mv: Vector3, look_yaw: float) -> Vector3:
	var fwd := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var rgt := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	return fwd * mv.z + rgt * mv.x

func apply_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "fp" else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_input_blocked():
			return
		if event.keycode == KEY_TAB:
			_toggle_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			flying = not flying
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and mode == "top" and event.pressed:
		if is_input_blocked():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			top_height = clampf(top_height * 0.8, Config.TOP_DOWN_MIN, Config.TOP_DOWN_MAX)
			_apply_projection()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			top_height = clampf(top_height / 0.8, Config.TOP_DOWN_MIN, Config.TOP_DOWN_MAX)
			_apply_projection()
	elif event is InputEventMouseMotion and mode == "fp":
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			yaw -= event.relative.x * Config.MOUSE_SENS
			pitch = clampf(pitch - event.relative.y * Config.MOUSE_SENS, -1.5, 1.5)

func _toggle_mode() -> void:
	if mode == "fp":
		mode = "top"
		flying = false
	else:
		mode = "fp"
		pitch = 0.0
	_apply_mode()

func _apply_mode() -> void:
	if mode == "fp":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_projection()
	apply_mouse_mode()
	_apply_cull()

func _apply_cull() -> void:
	if camera == null:
		return
	var all_layers := (1 << 20) - 1
	if mode == "fp":
		camera.cull_mask = all_layers & ~HEAD_LAYER
	else:
		camera.cull_mask = all_layers

func _apply_projection() -> void:
	if mode == "fp":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = top_height * 0.8
	_sync_taa()

func _sync_taa() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	# 正交俯视平移时 TAA 容易拖影；第一人称与 4x MSAA 组合良好
	vp.use_taa = mode == "fp"

func _physics_process(_delta: float) -> void:
	rotation.y = yaw
	if mode == "fp":
		position = Vector3(0.0, Config.EYE_HEIGHT, 0.0)
		camera.rotation.x = pitch
		camera.rotation.y = 0.0
		camera.rotation.z = 0.0
	else:
		camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		position = Vector3.ZERO
		var gp := global_position
		gp.y = top_height
		global_position = gp
