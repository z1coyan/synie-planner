class_name ElementGeometry
extends RefCounted

## 几何与材质构建工具集：全部 static，负责地板/墙/楼梯网格重建、玻璃片与材质工厂。
## 由 world_store.gd 抽出（内部逻辑与数值阈值逐字保留），供仓库与楼梯预览工具共用。

## 楼梯踏步数：按舒适踏步高（Config.STAIR_RISE）取整，至少 1 级。
static func stair_step_count(height: float) -> int:
	return maxi(1, int(round(maxf(height, 0.2) / Config.STAIR_RISE)))

## 在 parent 局部空间生成踏步网格；with_collision 时附加踏步盒 + 坡面凸包。
static func attach_stair_geom(parent: Node3D, width: float, length: float, height: float, mat: Material, with_collision: bool) -> void:
	var n := stair_step_count(height)
	var rise := height / float(n)
	var tread := length / float(n)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.name = "Step_%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(width, rise, tread)
		if mat != null:
			bm.material = mat
		mi.mesh = bm
		mi.position = Vector3(
			0.0,
			-height * 0.5 + (float(i) + 0.5) * rise,
			length * 0.5 - (float(i) + 0.5) * tread)
		parent.add_child(mi)
		if with_collision:
			var cs := CollisionShape3D.new()
			cs.name = "StepCol_%d" % i
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			cs.position = mi.position
			parent.add_child(cs)
	if with_collision:
		var ramp := CollisionShape3D.new()
		ramp.name = "RampCol"
		var conv := ConvexPolygonShape3D.new()
		var hw := width * 0.5
		var hl := length * 0.5
		var hh := height * 0.5
		conv.points = PackedVector3Array([
			Vector3(-hw, -hh, hl),
			Vector3(hw, -hh, hl),
			Vector3(-hw, -hh, -hl),
			Vector3(hw, -hh, -hl),
			Vector3(-hw, hh, -hl),
			Vector3(hw, hh, -hl),
		])
		ramp.shape = conv
		parent.add_child(ramp)

## 归一化地板碎片读取：优先取 meta["pieces"]，否则按中心+尺寸推导单块。
## 只读 body meta、无实例依赖，故可作 static。
static func floor_pieces(body: StaticBody3D) -> Array:
	if body != null and body.has_meta("pieces") and body.get_meta("pieces") is Array:
		var pcs: Array = RectOps.sanitize_floor_pieces(body.get_meta("pieces"))
		if not pcs.is_empty():
			return pcs
	var c: Vector3 = body.global_position if body.is_inside_tree() else body.position
	var size: Vector3 = body.get_meta("size")
	return RectOps.xz_rect_from_box(c, size)

## 地板开洞读取：只读 body meta、无实例依赖，故可作 static。
static func floor_openings(body: StaticBody3D) -> Array:
	if body != null and body.has_meta("openings") and body.get_meta("openings") is Array:
		return RectOps.sanitize_floor_openings(body.get_meta("openings"))
	return []

## 重建地板几何：按 pieces 重新剖分网格与碰撞，剔除开洞并更新尺寸/meta。
static func rebuild_floor_geom(body: StaticBody3D) -> void:
	clear_body_geom(body)
	var pieces := RectOps.sanitize_floor_pieces(floor_pieces(body))
	if pieces.is_empty():
		return
	var h: float = float(body.get_meta("size").y)
	var top_y: float
	if body.is_inside_tree():
		top_y = body.global_position.y + h * 0.5
	else:
		top_y = body.position.y + h * 0.5
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in pieces:
		min_x = minf(min_x, float(p["x0"]))
		max_x = maxf(max_x, float(p["x1"]))
		min_z = minf(min_z, float(p["z0"]))
		max_z = maxf(max_z, float(p["z1"]))
	var new_size := Vector3(max_x - min_x, h, max_z - min_z)
	var new_pos := Vector3((min_x + max_x) * 0.5, top_y - h * 0.5, (min_z + max_z) * 0.5)
	if body.is_inside_tree():
		body.global_position = new_pos
	else:
		body.position = new_pos
	body.set_meta("size", new_size)
	body.set_meta("pieces", pieces)
	body.set_meta("yaw", 0.0)
	var mat_id := Config.DEFAULT_MATERIAL
	if body.has_meta("material"):
		mat_id = Config.normalize_material(String(body.get_meta("material")))
	var mat := surface_mat(mat_id)
	body.set_meta("material", mat_id)
	body.set_meta("color", mat.albedo_color)
	var leftover := RectOps.subtract_xz_rects(pieces, floor_openings(body))
	if leftover.is_empty():
		leftover = pieces
	for i in leftover.size():
		var p: Dictionary = leftover[i]
		var sx := float(p["x1"]) - float(p["x0"])
		var sz := float(p["z1"]) - float(p["z0"])
		var lp := Vector3(
			(float(p["x0"]) + float(p["x1"])) * 0.5 - new_pos.x,
			0.0,
			(float(p["z0"]) + float(p["z1"])) * 0.5 - new_pos.z)
		var psz := Vector3(sx, h, sz)
		var mi := MeshInstance3D.new()
		mi.name = "FloorPiece_%d" % i
		var bm := BoxMesh.new()
		bm.size = psz
		bm.material = mat
		mi.mesh = bm
		mi.position = lp
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.name = "FloorCol_%d" % i
		var bs := BoxShape3D.new()
		bs.size = psz
		cs.shape = bs
		cs.position = lp
		body.add_child(cs)

## 移除 body 的几何子节点（网格/碰撞），保留 _SelectHL / Label / Leader。
static func clear_body_geom(body: StaticBody3D) -> void:
	var to_free: Array = []
	for child in body.get_children():
		var n := String(child.name)
		if n == "_SelectHL" or n == "Label" or n == "Leader":
			continue
		if child is MeshInstance3D or child is CollisionShape3D:
			to_free.append(child)
	for node in to_free:
		body.remove_child(node)
		node.free()

## 重建墙体几何：按开洞剖分实体块并生成网格与碰撞，再补窗洞玻璃。
static func rebuild_wall_geom(body: StaticBody3D) -> void:
	clear_body_geom(body)
	var size: Vector3 = body.get_meta("size")
	var yaw := float(body.get_meta("yaw")) if body.has_meta("yaw") else 0.0
	var mat_id := Config.DEFAULT_MATERIAL
	if body.has_meta("material"):
		mat_id = Config.normalize_material(String(body.get_meta("material")))
	var mat := surface_mat(mat_id)
	body.set_meta("color", mat.albedo_color)
	var openings: Array = []
	if body.has_meta("openings"):
		openings = body.get_meta("openings")
	var pieces: Array = RectOps.wall_leftover_boxes(size, openings)
	if pieces.is_empty() and openings.is_empty():
		pieces = [{"pos": Vector3.ZERO, "size": size}]
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var across := Vector3(sin(yaw), 0.0, cos(yaw))
	for i in pieces.size():
		var piece: Dictionary = pieces[i]
		var psz: Vector3 = piece["size"]
		var lp: Vector3 = piece["pos"]
		var pos := along * lp.x + Vector3(0.0, lp.y, 0.0) + across * lp.z
		var mi := MeshInstance3D.new()
		mi.name = "WallPiece_%d" % i
		var bm := BoxMesh.new()
		bm.size = psz
		bm.material = mat
		mi.mesh = bm
		mi.position = pos
		mi.rotation.y = yaw
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.name = "WallCol_%d" % i
		var bs := BoxShape3D.new()
		bs.size = psz
		cs.shape = bs
		cs.position = pos
		cs.rotation.y = yaw
		body.add_child(cs)
	attach_window_panes(body, size, yaw, openings, along, across)

## 窗洞玻璃片：填在开洞矩形内的薄片，无碰撞、不投影。
static func attach_window_panes(body: StaticBody3D, size: Vector3, yaw: float, openings: Array, along: Vector3, across: Vector3) -> void:
	var glass := glass_mat()
	var gi := 0
	for op_v in openings:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		if String(op_v.get("type", "door")) != "window":
			continue
		var b := RectOps.opening_local_bounds(size, op_v)
		var gw := float(b["x1"]) - float(b["x0"])
		var gh := float(b["y1"]) - float(b["y0"])
		if gw < 0.001 or gh < 0.001:
			continue
		var gt := minf(Config.WINDOW_GLASS_THICKNESS, maxf(size.z * 0.25, 0.01))
		var lp := Vector3(
			(float(b["x0"]) + float(b["x1"])) * 0.5,
			(float(b["y0"]) + float(b["y1"])) * 0.5,
			0.0)
		var pos := along * lp.x + Vector3(0.0, lp.y, 0.0) + across * lp.z
		var mi := MeshInstance3D.new()
		mi.name = "WindowGlass_%d" % gi
		var bm := BoxMesh.new()
		bm.size = Vector3(gw, gh, gt)
		bm.material = glass
		mi.mesh = bm
		mi.position = pos
		mi.rotation.y = yaw
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		gi += 1

## 重建楼梯几何：清除旧网格/碰撞后按当前宽长高重新生成（含踏步与坡面凸包）。
static func rebuild_stair_geom(body: StaticBody3D, width: float, length: float, height: float) -> void:
	var to_free: Array = []
	for child in body.get_children():
		if String(child.name) == "_SelectHL":
			continue
		if child is MeshInstance3D or child is CollisionShape3D:
			to_free.append(child)
	for n in to_free:
		body.remove_child(n)
		n.free()
	var mat_id := Config.DEFAULT_MATERIAL
	if body.has_meta("material"):
		mat_id = Config.normalize_material(String(body.get_meta("material")))
	attach_stair_geom(body, width, length, height, surface_mat(mat_id), true)

## 白模设备材质：哑光、无金属。
static func clay_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic = 0.0
	return m

## 窗洞玻璃：半透明冷青、可透视、双面、低粗糙、无金属。无碰撞。
static func glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.albedo_color = Config.COLOR_WINDOW_GLASS
	m.roughness = 0.06
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.refraction_enabled = false
	return m

## 柱/墙/地板共用材质外观：混凝土冷灰 / 泥土棕。
static func surface_mat(material: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.metallic = 0.0
	if Config.normalize_material(material) == "dirt":
		m.albedo_color = Config.COLOR_FLOOR_DIRT
		m.roughness = 0.95
	else:
		m.albedo_color = Config.COLOR_FLOOR_CONCRETE
		m.roughness = 0.85
	return m
