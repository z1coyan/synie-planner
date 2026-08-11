class_name WallTool
extends Node3D

## 墙体：连续点击绘制，起点/终点有可视化标记，实时显示长度，[ ] 调整墙厚。
## 墙面基准高度取起点所在表面，自动归属楼层。

var world: WorldStore
var camera_rig: CameraController
var hud: Hud
var floors: FloorManager

var active := false
var drawing := false
var start_point: Vector3
var thickness := Config.WALL_THICKNESS_DEFAULT
var base_y := 0.0

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_between := Vector3.ZERO
var _last_size := Vector3.ZERO

var _start_marker: MeshInstance3D
var _end_marker: MeshInstance3D

var _preview_center := Vector3.ZERO
var _preview_size := Vector3.ZERO
var _preview_yaw := 0.0
var _preview_ok := false
var _preview_end := Vector3.ZERO

func setup(w: WorldStore, cc: CameraController, h: Hud, fm: FloorManager) -> void:
	world = w
	camera_rig = cc
	hud = h
	floors = fm
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = Node3D.new()
	_preview_root.name = "WallPreview"
	_preview_root.visible = false
	add_child(_preview_root)
	_fill_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)
	_start_marker = _make_marker(Config.COLOR_ACCENT)
	_end_marker = _make_marker(Config.COLOR_PATH)

func _make_marker(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	bm.material = m
	mi.mesh = bm
	mi.visible = false
	add_child(mi)
	return mi

func _holo_mat(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = base
	m.emission_enabled = true
	var e := base
	e.a = 1.0
	m.emission = e
	return m

func set_active(a: bool) -> void:
	active = a
	if not a:
		_cancel()
	else:
		hud.set_status("画墙：连续点击端点，实时显示长度")
		_update_hud()

func cancel() -> void:
	_cancel()

func _cancel() -> void:
	drawing = false
	start_point = Vector3.ZERO
	_preview_root.visible = false
	_start_marker.visible = false
	_end_marker.visible = false
	_last_between = Vector3.ZERO
	_preview_ok = false
	hud.set_length("")

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if drawing:
		_start_marker.position = Vector3(start_point.x, base_y + 0.11, start_point.z)
		_start_marker.visible = true
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_preview_root.visible = false
		_end_marker.visible = false
		return
	var snapped := _snap_grid(aim["point"])
	var mark_y: float = (base_y if drawing else aim["surface_y"]) + 0.11
	_end_marker.position = Vector3(snapped.x, mark_y, snapped.z)
	_end_marker.visible = true
	if drawing:
		_update_preview(snapped)

func _snap_grid(p: Vector3) -> Vector3:
	var g := Config.GRID
	return Vector3(roundf(p.x / g) * g, 0.0, roundf(p.z / g) * g)

func _update_preview(end_point: Vector3) -> void:
	var between := end_point - start_point
	between.y = 0.0
	if between.length_squared() < 0.001:
		_preview_root.visible = false
		_preview_ok = false
		hud.set_length("")
		return
	var length := between.length()
	var yaw := -atan2(between.z, between.x)
	var size := Vector3(length, Config.WALL_HEIGHT, thickness)
	var center := Vector3(
		(start_point.x + end_point.x) * 0.5,
		base_y + Config.WALL_HEIGHT * 0.5,
		(start_point.z + end_point.z) * 0.5,
	)
	var bs := BoxShape3D.new()
	bs.size = size
	var ok := world.shape_clear(bs, Transform3D(Basis(Vector3.UP, yaw), center), 0.0, [], "wall")
	_preview_center = center
	_preview_size = size
	_preview_yaw = yaw
	_preview_ok = ok
	_preview_end = end_point
	_show_preview(center, size, yaw, ok)
	hud.set_length("墙长: %.2f m" % length)

func _show_preview(center: Vector3, size: Vector3, yaw: float, ok: bool) -> void:
	if not size.is_equal_approx(_last_size) or center != _last_between:
		_last_size = size
		_last_between = center
		var bm := BoxMesh.new()
		bm.size = size
		_fill_mi.mesh = bm
	_fill_mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
	_preview_root.position = center
	_preview_root.rotation.y = yaw
	_preview_root.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETRIGHT:
			thickness = clampf(thickness + Config.WALL_THICKNESS_STEP, Config.WALL_THICKNESS_MIN, Config.WALL_THICKNESS_MAX)
			_update_hud()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BRACKETLEFT:
			thickness = clampf(thickness - Config.WALL_THICKNESS_STEP, Config.WALL_THICKNESS_MIN, Config.WALL_THICKNESS_MAX)
			_update_hud()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
			get_viewport().set_input_as_handled()

func _on_left_click() -> void:
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		return
	var snapped := _snap_grid(aim["point"])
	if not drawing:
		start_point = snapped
		base_y = aim["surface_y"]
		drawing = true
		_last_size = Vector3.ZERO
		_preview_ok = false
		hud.set_length("")
		return
	if not _preview_ok or not _preview_root.visible:
		return
	world.place_box(_preview_center, _preview_size, Config.COLOR_WALL, "wall", _preview_yaw, floors.floor_from_y(base_y))
	start_point = _preview_end
	_last_size = Vector3.ZERO
	_preview_ok = false

func _update_hud() -> void:
	hud.set_tool_info("墙厚: %.2f m   [ / ] 调整" % thickness)
