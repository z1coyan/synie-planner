class_name FloorManager
extends Node3D

## 楼层系统：1F~4F 楼板（网格化 ArrayMesh 支持开洞）、单层显隐切换、
## 各层描图网格。开洞由 opening_tool 调用 add_opening 写入。

signal floor_changed(index: int)
signal show_all_changed(value: bool)

var world: WorldStore
var current_floor := 0
var show_all := false

var slabs: Array = []       # 每层 StaticBody3D
var grids: Array = []       # 每层描图网格 MeshInstance3D（1F 用地面网格）
var openings: Array = []    # 每层 Array of {center: Vector2, size: Vector2, yaw: float}

func setup(w: WorldStore) -> void:
	world = w
	for f in Config.FLOOR_COUNT:
		openings.append([])
		slabs.append(_build_slab(f))
		grids.append(_build_floor_grid(f))
	_apply_visibility()

func floor_top(f: int) -> float:
	return Config.FLOOR_TOP_OFFSET + f * Config.FLOOR_HEIGHT

func floor_from_y(y: float) -> int:
	var rel := y - Config.FLOOR_TOP_OFFSET
	if rel < 0.0:
		return 0
	return clampi(int(floorf(rel / Config.FLOOR_HEIGHT)), 0, Config.FLOOR_COUNT - 1)

func current_top() -> float:
	return floor_top(current_floor)

func set_floor(i: int) -> void:
	i = clampi(i, 0, Config.FLOOR_COUNT - 1)
	if i == current_floor:
		return
	current_floor = i
	_apply_visibility()
	floor_changed.emit(i)

func toggle_show_all() -> void:
	show_all = not show_all
	_apply_visibility()
	show_all_changed.emit(show_all)

func set_show_all(v: bool) -> void:
	if show_all == v:
		return
	show_all = v
	_apply_visibility()
	show_all_changed.emit(show_all)

## 开洞：矩形洞口，center 为 XZ 平面坐标。link_all 时贯通全部楼层。
func add_opening(f: int, center: Vector2, size: Vector2, yaw: float, link_all := false) -> bool:
	if not rect_fits(center, size, yaw):
		return false
	if link_all:
		for i in Config.FLOOR_COUNT:
			openings[i].append({"center": center, "size": size, "yaw": yaw})
			_rebuild_slab(i)
	else:
		openings[f].append({"center": center, "size": size, "yaw": yaw})
		_rebuild_slab(f)
	return true

func rect_fits(center: Vector2, size: Vector2, yaw: float) -> bool:
	var hw := Config.FLOOR_SIZE.x * 0.5
	var hd := Config.FLOOR_SIZE.y * 0.5
	var cs := cos(yaw)
	var sn := sin(yaw)
	for lx in [size.x * 0.5, -size.x * 0.5]:
		for ly in [size.y * 0.5, -size.y * 0.5]:
			var wx: float = lx * cs - ly * sn + center.x
			var wy: float = lx * sn + ly * cs + center.y
			if absf(wx) > hw + 0.001 or absf(wy) > hd + 0.001:
				return false
	return true

func _build_slab(f: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Slab%dF" % (f + 1)
	body.collision_layer = 2
	body.collision_mask = 0
	body.position.y = floor_top(f) - Config.FLOOR_THICKNESS * 0.5
	body.set_meta("kind", "floor")
	body.set_meta("size", Vector3(Config.FLOOR_SIZE.x, Config.FLOOR_THICKNESS, Config.FLOOR_SIZE.y))
	body.set_meta("floor", f)
	var mesh := _build_slab_mesh(f)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

func _rebuild_slab(f: int) -> void:
	var body: StaticBody3D = slabs[f]
	var mesh := _build_slab_mesh(f)
	(body.get_node("Mesh") as MeshInstance3D).mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	(body.get_node("Collision") as CollisionShape3D).shape = shape

func _build_slab_mesh(f: int) -> ArrayMesh:
	var cell := Config.SLAB_CELL
	var nx := int(round(Config.FLOOR_SIZE.x / cell))
	var nz := int(round(Config.FLOOR_SIZE.y / cell))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			if _cell_covered(f, ix, iz, nx, nz, cell):
				continue
			var x0 := (ix - nx * 0.5) * cell
			var z0 := (iz - nz * 0.5) * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			st.add_vertex(Vector3(x0, 0.0, z0))
			st.add_vertex(Vector3(x1, 0.0, z0))
			st.add_vertex(Vector3(x1, 0.0, z1))
			st.add_vertex(Vector3(x0, 0.0, z0))
			st.add_vertex(Vector3(x1, 0.0, z1))
			st.add_vertex(Vector3(x0, 0.0, z1))
			st.add_vertex(Vector3(x0, 0.0, z0))
			st.add_vertex(Vector3(x0, 0.0, z1))
			st.add_vertex(Vector3(x1, 0.0, z1))
			st.add_vertex(Vector3(x0, 0.0, z0))
			st.add_vertex(Vector3(x1, 0.0, z1))
			st.add_vertex(Vector3(x1, 0.0, z0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Config.COLOR_FLOOR
	mat.roughness = 1.0
	st.set_material(mat)
	st.generate_normals()
	return st.commit()

func _cell_covered(f: int, ix: int, iz: int, nx: int, nz: int, cell: float) -> bool:
	var cx := (ix - nx * 0.5) * cell
	var cz := (iz - nz * 0.5) * cell
	for o in openings[f]:
		if _point_in_rect(Vector2(cx, cz), o):
			return true
	return false

func _point_in_rect(p: Vector2, rect: Dictionary) -> bool:
	var c: Vector2 = p - rect.center
	var cs: float = cos(rect.yaw)
	var sn: float = sin(rect.yaw)
	var lx: float = c.x * cs + c.y * sn
	var ly: float = -c.x * sn + c.y * cs
	return absf(lx) <= rect.size.x * 0.5 and absf(ly) <= rect.size.y * 0.5

func _build_floor_grid(f: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Grid%dF" % (f + 1)
	var minor := _line_mat(Config.COLOR_FLOOR_GRID)
	var major := _line_mat(Config.COLOR_GRID_MAJOR)
	var hw := Config.FLOOR_SIZE.x * 0.5
	var hd := Config.FLOOR_SIZE.y * 0.5
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, minor)
	var x := -hw
	while x <= hw + 0.001:
		if absf(fmod(x, Config.GRID_MAJOR)) > 0.001:
			im.surface_add_vertex(Vector3(x, 0.0, -hd))
			im.surface_add_vertex(Vector3(x, 0.0, hd))
		x += Config.GRID
	var z := -hd
	while z <= hd + 0.001:
		if absf(fmod(z, Config.GRID_MAJOR)) > 0.001:
			im.surface_add_vertex(Vector3(-hw, 0.0, z))
			im.surface_add_vertex(Vector3(hw, 0.0, z))
		z += Config.GRID
	im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES, major)
	x = -hw
	while x <= hw + 0.001:
		if absf(fmod(x, Config.GRID_MAJOR)) <= 0.001:
			im.surface_add_vertex(Vector3(x, 0.0, -hd))
			im.surface_add_vertex(Vector3(x, 0.0, hd))
		x += Config.GRID
	z = -hd
	while z <= hd + 0.001:
		if absf(fmod(z, Config.GRID_MAJOR)) <= 0.001:
			im.surface_add_vertex(Vector3(-hw, 0.0, z))
			im.surface_add_vertex(Vector3(hw, 0.0, z))
		z += Config.GRID
	im.surface_end()
	mi.mesh = im
	mi.position.y = floor_top(f) + 0.002
	add_child(mi)
	return mi

func _apply_visibility() -> void:
	for f in Config.FLOOR_COUNT:
		var vis := show_all or f == current_floor
		var slab: StaticBody3D = slabs[f]
		slab.visible = vis
		slab.collision_layer = 2 if vis else 0
		var grid: MeshInstance3D = grids[f]
		grid.visible = vis
	if world != null:
		for obj in world.placed:
			var f := int(obj.get_meta("floor", 0))
			var vis := show_all or f == current_floor
			obj.visible = vis
			obj.collision_layer = 1 if vis else 0

func _line_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
