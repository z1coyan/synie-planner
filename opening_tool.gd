class_name OpeningTool
extends Node3D

## 楼板开洞：在当前楼层楼板上放置矩形洞口（吊装孔 / 输送井）。
## R 旋转 90°，[ ] 调长，Q/E 调宽，Y 循环类型，L 贯通全部楼层。

var world: WorldStore
var camera_rig: CameraController
var hud: Hud
var floors: FloorManager

var active := false
var type_index := 0
var rot_steps := 0
var size := Vector2(3.0, 3.0)
var link_all := false
var valid := false

var _preview_root: Node3D
var _fill: MeshInstance3D
var _wire: MeshInstance3D
var _fill_ok: StandardMaterial3D
var _fill_bad: StandardMaterial3D

func setup(w: WorldStore, cc: CameraController, h: Hud, fm: FloorManager) -> void:
	world = w
	camera_rig = cc
	hud = h
	floors = fm
	_fill_ok = _holo_mat(Config.COLOR_OK)
	_fill_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = Node3D.new()
	_preview_root.name = "OpeningPreview"
	_preview_root.visible = false
	add_child(_preview_root)
	_fill = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_fill.mesh = quad
	_fill.rotation_degrees.x = -90.0
	_preview_root.add_child(_fill)
	_wire = MeshInstance3D.new()
	_wire.mesh = _build_wire_unit()
	_preview_root.add_child(_wire)

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

func _build_wire_unit() -> ImmediateMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Config.COLOR_ACCENT
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	var h := 0.5
	im.surface_add_vertex(Vector3(-h, 0.0, -h))
	im.surface_add_vertex(Vector3(h, 0.0, -h))
	im.surface_add_vertex(Vector3(h, 0.0, -h))
	im.surface_add_vertex(Vector3(h, 0.0, h))
	im.surface_add_vertex(Vector3(h, 0.0, h))
	im.surface_add_vertex(Vector3(-h, 0.0, h))
	im.surface_add_vertex(Vector3(-h, 0.0, h))
	im.surface_add_vertex(Vector3(-h, 0.0, -h))
	im.surface_end()
	return im

func set_active(a: bool) -> void:
	active = a
	if not a:
		_preview_root.visible = false
	else:
		hud.set_status("楼板开洞：左键放置，R 旋转，[ ]/Q/E 调尺寸，Y 换类型，L 贯通全层")
		_update_hud()

func _current_size() -> Vector2:
	var s := size
	if rot_steps % 2 == 1:
		s = Vector2(s.y, s.x)
	return s

func _current_type_name() -> String:
	return String(Config.OPENING_TYPES[type_index]["name"])

func _physics_process(_delta: float) -> void:
	if not active:
		return
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_preview_root.visible = false
		return
	var snapped := _snap_grid(aim["point"])
	var s := _current_size()
	var yaw := rot_steps * PI * 0.5
	valid = floors.rect_fits(Vector2(snapped.x, snapped.z), s, yaw)
	_show_preview(Vector3(snapped.x, floors.current_top() + 0.06, snapped.z), s, yaw, valid)

func _snap_grid(p: Vector3) -> Vector3:
	var g := Config.GRID
	return Vector3(roundf(p.x / g) * g, 0.0, roundf(p.z / g) * g)

func _show_preview(pos: Vector3, s: Vector2, yaw: float, ok: bool) -> void:
	_fill.material_override = _fill_ok if ok else _fill_bad
	var wire_mat := _wire.mesh.surface_get_material(0) as StandardMaterial3D
	wire_mat.albedo_color = Color(0.96, 0.60, 0.15, 1.0) if ok else Color(0.55, 0.56, 0.58, 1.0)
	_preview_root.position = pos
	_preview_root.rotation.y = yaw
	_preview_root.scale = Vector3(s.x, 1.0, s.y)
	_preview_root.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				rot_steps = (rot_steps + 1) % 4
				get_viewport().set_input_as_handled()
			KEY_BRACKETRIGHT:
				size.x = clampf(size.x + Config.OPENING_SIZE_STEP, Config.OPENING_SIZE_MIN, Config.OPENING_SIZE_MAX)
				get_viewport().set_input_as_handled()
			KEY_BRACKETLEFT:
				size.x = clampf(size.x - Config.OPENING_SIZE_STEP, Config.OPENING_SIZE_MIN, Config.OPENING_SIZE_MAX)
				get_viewport().set_input_as_handled()
			KEY_Q:
				size.y = clampf(size.y + Config.OPENING_SIZE_STEP, Config.OPENING_SIZE_MIN, Config.OPENING_SIZE_MAX)
				get_viewport().set_input_as_handled()
			KEY_E:
				size.y = clampf(size.y - Config.OPENING_SIZE_STEP, Config.OPENING_SIZE_MIN, Config.OPENING_SIZE_MAX)
				get_viewport().set_input_as_handled()
			KEY_Y:
				type_index = (type_index + 1) % Config.OPENING_TYPES.size()
				size = Vector2(Config.OPENING_TYPES[type_index]["size"])
				get_viewport().set_input_as_handled()
			KEY_L:
				link_all = not link_all
				get_viewport().set_input_as_handled()
		_update_hud()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and valid:
			_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_active(false)
			get_viewport().set_input_as_handled()

func _place() -> void:
	var s := _current_size()
	var center := Vector2(_preview_root.position.x, _preview_root.position.z)
	var yaw := rot_steps * PI * 0.5
	if floors.add_opening(floors.current_floor, center, s, yaw, link_all):
		hud.set_status("已开洞：%s %d×%d m%s" % [
			_current_type_name(), int(s.x), int(s.y),
			"（贯通全部楼层）" if link_all else "",
		])

func _update_hud() -> void:
	var s := _current_size()
	hud.set_tool_info("开洞:%s %d×%d m  旋转:%d°  贯通:%s" % [
		_current_type_name(), int(s.x), int(s.y), rot_steps * 90, "开" if link_all else "关",
	])
