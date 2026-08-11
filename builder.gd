class_name Builder
extends Node3D

## 柱子 / 设备放置：全息预览跟随鼠标，0.5m 网格吸附 + 表面吸附，
## R 键旋转 90°，绿=可放，红=干涉。

var world: WorldStore
var camera_rig: CameraController
var hud: Hud

var tool := "none"          # "none" | "column" | "device"
var rot_steps := 0           # 0..3 → 旋转 0/90/180/270°
var valid := false

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _wire_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

func setup(w: WorldStore, cc: CameraController, h: Hud) -> void:
	world = w
	camera_rig = cc
	hud = h
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = Node3D.new()
	_preview_root.name = "PlacementPreview"
	_preview_root.visible = false
	add_child(_preview_root)
	_fill_mi = MeshInstance3D.new()
	_wire_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)
	_preview_root.add_child(_wire_mi)

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

func set_tool(t: String) -> void:
	tool = t
	rot_steps = 0
	_last_size = Vector3.ZERO
	if tool == "none":
		_preview_root.visible = false
	_update_hud()

func _current_size() -> Vector3:
	var s: Vector3
	if tool == "column":
		s = Vector3(Config.COLUMN_WIDTH, Config.COLUMN_HEIGHT, Config.COLUMN_DEPTH)
	else:
		s = Config.DEVICE_SIZE
	if rot_steps % 2 == 1:
		s = Vector3(s.z, s.y, s.x)
	return s

func _current_color() -> Color:
	if tool == "column":
		return Config.COLOR_COLUMN
	return Config.COLOR_DEVICE

func _physics_process(_delta: float) -> void:
	if tool == "none":
		return
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_preview_root.visible = false
		return
	var size := _current_size()
	var snapped := _snap_grid(aim["point"])
	var center := Vector3(snapped.x, aim["surface_y"] + size.y * 0.5, snapped.z)
	var aabb := AABB(center - size * 0.5, size).grow(Config.CLEARANCE)
	valid = world.aabb_clear(aabb, Config.CLEARANCE)
	_show_preview(center, size, valid)
	_update_hud()

func _snap_grid(p: Vector3) -> Vector3:
	var g := Config.GRID
	return Vector3(roundf(p.x / g) * g, 0.0, roundf(p.z / g) * g)

func _show_preview(center: Vector3, size: Vector3, ok: bool) -> void:
	if not size.is_equal_approx(_last_size):
		_last_size = size
		var bm := BoxMesh.new()
		bm.size = size
		_fill_mi.mesh = bm
		_wire_mi.mesh = _build_wire(size)
	_fill_mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
	var wire_mat := _wire_mi.mesh.surface_get_material(0) as StandardMaterial3D
	wire_mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0) if not ok else Color(0.2, 1.0, 0.35, 1.0)
	_preview_root.position = center
	_preview_root.visible = true

func _build_wire(box_size: Vector3) -> ImmediateMesh:
	var s := box_size * 0.5
	var corners := PackedVector3Array([
		Vector3(-s.x, -s.y, -s.z), Vector3(s.x, -s.y, -s.z), Vector3(s.x, -s.y, s.z), Vector3(-s.x, -s.y, s.z),
		Vector3(-s.x, s.y, -s.z), Vector3(s.x, s.y, -s.z), Vector3(s.x, s.y, s.z), Vector3(-s.x, s.y, s.z),
	])
	var edges := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 1.0, 0.35, 1.0)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for e in edges:
		im.surface_add_vertex(corners[e.x])
		im.surface_add_vertex(corners[e.y])
	im.surface_end()
	return im

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and tool != "none":
		if event.keycode == KEY_R:
			rot_steps = (rot_steps + 1) % 4
			_last_size = Vector3.ZERO
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and tool != "none" and valid:
			_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_tool("none")
			get_viewport().set_input_as_handled()

func _place() -> void:
	if not _preview_root.visible:
		return
	var size := _current_size()
	world.place_box(_preview_root.position, size, _current_color(), tool)

func _update_hud() -> void:
	var name_map := {"none": "无", "column": "柱子", "device": "设备"}
	if tool == "none":
		hud.set_tool_info("")
		return
	hud.set_tool_info("%s   旋转:%d°   尺寸:%.1f×%.1f×%.1f m" % [
		name_map[tool], rot_steps * 90, _current_size().x, _current_size().y, _current_size().z,
	])
	hud.set_status("放置：%s（绿色可放 / 红色干涉）" % name_map[tool])
