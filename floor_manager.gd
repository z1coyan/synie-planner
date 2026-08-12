class_name FloorManager
extends Node3D

## 楼层系统：1F~4F 楼板（网格化 ArrayMesh 支持开洞）、单层显隐切换、
## 各层描图网格。开洞由 opening_tool 调用 add_opening 写入。

signal floor_changed(index: int)
signal show_all_changed(value: bool)

var world: WorldStore
var current_floor := 0
var show_all := false
var camera_cc: CameraController

const GRID_PLANE_SIZE := 1000.0
const GRID_FADE_START := 100.0
const GRID_FADE_END := 320.0

var slabs: Array = []       # 每层 StaticBody3D
var grids: Array = []       # 每层描图网格 MeshInstance3D（1F 用地面网格）
var openings: Array = []    # 每层 Array of {center: Vector2, size: Vector2, yaw: float}

func setup(w: WorldStore) -> void:
	world = w
	var grid_mat := _make_grid_material()
	for f in Config.FLOOR_COUNT:
		openings.append([])
		slabs.append(_build_slab(f))
		grids.append(_build_infinite_grid(f, grid_mat))
	_apply_visibility()

## 无限地面网格：跟随相机的巨大平面 + 世界坐标网格着色器，随距离淡出。
func _process(_delta: float) -> void:
	if camera_cc == null:
		return
	var c := camera_cc.global_position
	for g in grids:
		(g as MeshInstance3D).position.x = c.x
		(g as MeshInstance3D).position.z = c.z

func set_camera(cc: CameraController) -> void:
	camera_cc = cc

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

func _build_infinite_grid(f: int, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Grid%dF" % (f + 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_PLANE_SIZE, GRID_PLANE_SIZE)
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = floor_top(f) + 0.002
	add_child(mi)
	return mi

func _make_grid_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _grid_shader()
	mat.set_shader_parameter("minor_color", Config.COLOR_FLOOR_GRID)
	mat.set_shader_parameter("major_color", Config.COLOR_GRID_MAJOR)
	mat.set_shader_parameter("minor_cell", Config.GRID)
	mat.set_shader_parameter("major_cell", Config.GRID_MAJOR)
	mat.set_shader_parameter("fade_start", GRID_FADE_START)
	mat.set_shader_parameter("fade_end", GRID_FADE_END)
	return mat

static var _grid_shader_res: Shader

static func _grid_shader() -> Shader:
	if _grid_shader_res == null:
		var s := Shader.new()
		s.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 minor_color : source_color = vec4(0.66, 0.67, 0.69, 0.5);
uniform vec4 major_color : source_color = vec4(0.60, 0.61, 0.63, 1.0);
uniform float minor_cell = 0.5;
uniform float major_cell = 5.0;
uniform float fade_start = 100.0;
uniform float fade_end = 320.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 g, float cell) {
	vec2 gr = g / cell;
	vec2 fw = max(fwidth(gr), vec2(1e-5));
	vec2 a = abs(fract(gr - 0.5) - 0.5) / fw;
	return max(1.0 - a.x, 1.0 - a.y);
}

void fragment() {
	vec2 g = v_world.xz;
	float minor = grid_line(g, minor_cell);
	float major = grid_line(g, major_cell);
	float a = clamp(max(minor, major), 0.0, 1.0);
	vec3 col = mix(minor_color.rgb, major_color.rgb, step(0.5, major));
	float d = length(g);
	a *= 1.0 - smoothstep(fade_start, fade_end, d);
	ALBEDO = col;
	ALPHA = a;
}
"""
		_grid_shader_res = s
	return _grid_shader_res

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
		if world.ground_body != null:
			world.ground_body.collision_layer = 1 if (show_all or current_floor == 0) else 0
