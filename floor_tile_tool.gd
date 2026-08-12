class_name FloorTileTool
extends Node3D

## 地板工具：两段式点击。点击起点（点1）、移动鼠标预览、点击终点（点2），
## 铺设两点间的矩形地板（单块，任意尺寸，与画墙一致）。
## 端点 0.5m 网格吸附，并磁吸柱子 / 墙体 / 其他地板的角点，便于对齐拼接。
## 起点必须在地面、已有地板或墙柱表面；墙体/柱子不阻挡（地板从其下方铺过），
## 地板与其他地板、设备互斥。绿=可放 / 红=与地板或设备重叠，右键取消或退出。

var world: WorldStore
var camera_rig: CameraController
var hud: Hud

var active := false
var valid := false

var _drawing := false
var _start := Vector3.ZERO      # 起点（XZ，Y=0）
var _end := Vector3.ZERO        # 终点（XZ，Y=0）

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _wire_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

var _start_marker: MeshInstance3D
var _hover_marker: MeshInstance3D

func setup(w: WorldStore, cc: CameraController, h: Hud) -> void:
	world = w
	camera_rig = cc
	hud = h
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = Node3D.new()
	_preview_root.name = "FloorTilePreview"
	_preview_root.visible = false
	add_child(_preview_root)
	_fill_mi = MeshInstance3D.new()
	_wire_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)
	_preview_root.add_child(_wire_mi)
	_start_marker = _make_marker(Config.COLOR_ACCENT)
	_hover_marker = _make_marker(Config.COLOR_PATH)

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
	_cancel_drawing()
	_hover_marker.visible = false
	if a:
		hud.set_status("地板：点击起点、再点击终点铺设矩形（端点磁吸墙/柱/地板角点），右键取消")
		_update_hud()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	# 点1 前的悬停标记：显示端点落点（含角点磁吸后的位置）
	var p: Variant = _aim_point()
	if p == null:
		_hover_marker.visible = false
		if not _drawing:
			_preview_root.visible = false
			valid = false
			hud.set_length("仅可放在地面或地板边缘")
			return
	else:
		_hover_marker.position = Vector3(p.x, _mark_y(), p.z)
		_hover_marker.visible = true
	if not _drawing:
		_preview_root.visible = false
		valid = p != null
		if p != null:
			hud.set_length("点击确定起点")
		return
	# 已确定起点：更新终点与矩形预览
	_start_marker.position = Vector3(_start.x, _mark_y(), _start.z)
	_start_marker.visible = true
	if p != null:
		_end = p
	_update_rect_preview()

## 标记悬浮高度：略高于地面标高，避免与地板面穿插。
func _mark_y() -> float:
	return Config.FLOOR_TOP_OFFSET + 0.11

## 由当前瞄准点计算端点：地面 / 地板 / 墙 / 柱表面 → 网格 + 角点吸附；其它 → null。
func _aim_point() -> Variant:
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		return null
	var body: Object = aim.get("body")
	if body == world.ground_body:
		return _snap_point(aim["point"])
	if body != null and body.has_meta("kind") \
			and ["floor_tile", "wall", "column"].has(body.get_meta("kind")):
		return _snap_point(aim["point"])
	return null

## 先在原始点附近磁吸柱子 / 墙体 / 地板的角点；找不到再退回 0.5m 网格吸附。
## （顺序不能反：先网格吸附会偏移最多 0.35m，导致不在网格上的角点超出阈值。）
func _snap_point(p: Vector3) -> Vector3:
	var s := world.snap_to_corners(p, ["column", "wall", "floor_tile"], Config.SNAP_TO_CORNER)
	if s != p:
		return s
	var g := Config.GRID
	return Vector3(roundf(p.x / g) * g, 0.0, roundf(p.z / g) * g)

func _rect() -> Dictionary:
	var min_x: float = minf(_start.x, _end.x)
	var max_x: float = maxf(_start.x, _end.x)
	var min_z: float = minf(_start.z, _end.z)
	var max_z: float = maxf(_start.z, _end.z)
	return {
		"size": Vector3(max_x - min_x, Config.FLOOR_THICKNESS, max_z - min_z),
		"center": Vector3((min_x + max_x) * 0.5,
			Config.FLOOR_TOP_OFFSET + Config.FLOOR_THICKNESS * 0.5,
			(min_z + max_z) * 0.5),
	}

func _update_rect_preview() -> void:
	var r := _rect()
	var size: Vector3 = r["size"]
	if size.x < Config.GRID or size.z < Config.GRID:
		# 退化矩形（长或宽不足一格）
		_preview_root.visible = false
		valid = false
		hud.set_length("矩形过小")
		return
	valid = _rect_free(r["center"], size)
	_show_preview(r["center"], size, valid)
	hud.set_length("地板 %.1f×%.1f m：%s" % [size.x, size.z, "可铺设" if valid else "与地板/设备重叠"])

## 候选矩形是否无干涉。水平方向内缩 2cm，避免与边缘贴合的相邻地板误判重叠；
## 墙体 / 柱子不参与干涉（地板可从其下方铺过，消除接缝），仅与地板、设备互斥。
func _rect_free(center: Vector3, size: Vector3) -> bool:
	var test := Vector3(size.x - 0.02, size.y, size.z - 0.02)
	return world.aabb_clear(AABB(center - test * 0.5, test), 0.0, [], ["wall", "column"])

func _show_preview(center: Vector3, size: Vector3, ok: bool) -> void:
	if not size.is_equal_approx(_last_size):
		_last_size = size
		var bm := BoxMesh.new()
		bm.size = size
		_fill_mi.mesh = bm
		_wire_mi.mesh = _build_wire(size)
	_fill_mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
	var wire_mat := _wire_mi.mesh.surface_get_material(0) as StandardMaterial3D
	wire_mat.albedo_color = Color(0.96, 0.60, 0.15, 1.0) if ok else Color(0.55, 0.56, 0.58, 1.0)
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
	m.albedo_color = Color(0.96, 0.60, 0.15, 1.0)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for e in edges:
		im.surface_add_vertex(corners[e.x])
		im.surface_add_vertex(corners[e.y])
	im.surface_end()
	return im

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _drawing:
			# 点1：起点必须在地面 / 地板 / 墙柱表面
			var p: Variant = _aim_point()
			if p != null:
				_drawing = true
				_start = p
				_end = p
				_last_size = Vector3.ZERO
				_update_rect_preview()
			else:
				hud.set_status("起点无效：仅可从地面或已有地板边缘起铺")
		else:
			# 点2：确认铺设
			_place()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _drawing:
			_cancel_drawing()
			hud.set_status("已取消铺设")
		else:
			set_active(false)
		get_viewport().set_input_as_handled()

func _cancel_drawing() -> void:
	_drawing = false
	valid = false
	_preview_root.visible = false
	_start_marker.visible = false
	hud.set_length("")

## 点2 确认：铺设起点到终点的矩形地板（单块）。
func _place() -> void:
	if not valid or not _preview_root.visible:
		_cancel_drawing()
		hud.set_status("区域无效（过小或与地板/设备重叠），未铺设")
		return
	var r := _rect()
	world.place_box(r["center"], r["size"], Config.COLOR_FLOOR, "floor_tile")
	var size: Vector3 = r["size"]
	_cancel_drawing()
	hud.set_status("已铺设地板 %.1f×%.1f m" % [size.x, size.z])

func _update_hud() -> void:
	hud.set_tool_info("地板：两点矩形铺设，端点磁吸墙/柱/地板角点")
