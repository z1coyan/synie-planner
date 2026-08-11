class_name CameraController
extends Node3D

## 第一人称漫游 ⇄ 俯视正交 双视角，Tab 切换，F 开关飞行。

var camera: Camera3D

var mode := "fp"        # "fp" | "top"
var flying := false

var yaw := 0.0
var pitch := 0.0
var top_height := Config.TOP_DOWN_START

func setup() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 75.0
	add_child(camera)
	global_position = Vector3(0.0, Config.EYE_HEIGHT, 10.0)
	_apply_mode()

func is_top_down() -> bool:
	return mode == "top"

static func fp_velocity(mv: Vector3, yaw: float) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var rgt := Vector3(cos(yaw), 0.0, -sin(yaw))
	return fwd * mv.z + rgt * mv.x

func apply_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "fp" else Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			_toggle_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			flying = not flying
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and mode == "top" and event.pressed:
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

func _apply_projection() -> void:
	if mode == "fp":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = top_height * 0.8

func _physics_process(delta: float) -> void:
	rotation.y = yaw
	if mode == "fp":
		camera.rotation.x = pitch
		camera.rotation.y = 0.0
		camera.rotation.z = 0.0
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			mv.z += 1.0
		if Input.is_key_pressed(KEY_S):
			mv.z -= 1.0
		if Input.is_key_pressed(KEY_A):
			mv.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			mv.x += 1.0
		var vel := fp_velocity(mv, yaw)
		if flying:
			if Input.is_key_pressed(KEY_SPACE):
				vel.y += 1.0
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
				vel.y -= 1.0
		var speed := Config.FLY_SPEED if flying else Config.WALK_SPEED
		if vel.length_squared() > 0.001:
			global_position += vel.normalized() * speed * delta
		if not flying:
			global_position.y = Config.EYE_HEIGHT
		global_position.y = clampf(global_position.y, 0.1, Config.TOP_DOWN_MAX)
	else:
		camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			mv.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			mv.z += 1.0
		if Input.is_key_pressed(KEY_A):
			mv.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			mv.x += 1.0
		if mv.length_squared() > 0.001:
			global_position += mv.normalized() * Config.TOP_DOWN_SPEED * delta
		global_position.y = top_height
