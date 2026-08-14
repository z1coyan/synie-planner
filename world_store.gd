class_name WorldStore
extends Node3D

## 已放置物体的统一仓库：负责创建碰撞体、查询干涉、拾取表面。

var content: Node3D
var ground_body: StaticBody3D
var placed: Array = []
var labels_visible := true
var dirty := false

func setup(content_parent: Node3D, ground: StaticBody3D) -> void:
	content = content_parent
	ground_body = ground

func place_box(cx: Vector3, size: Vector3, color: Color, kind: String, yaw: float = 0.0, floor: int = 0, name: String = "", material: String = "", pieces: Array = [], openings: Array = []) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind, body.get_instance_id()]
	body.position = cx
	body.collision_layer = 1
	body.collision_mask = 0

	var mat_id := ""
	if material != "":
		mat_id = Config.normalize_material(material)
	elif Kinds.MATERIAL_KINDS.has(kind):
		mat_id = Config.DEFAULT_MATERIAL

	# 地板：层 1 供玩家站立与设备干涉；mask=0 故静体互不碰撞。
	# 铺设查询另行忽略 floor_tile，重叠/共边的共面地板在此合并为一块。
	if kind == "floor_tile":
		var floor_mat := ElementGeometry.surface_mat(mat_id if mat_id != "" else Config.DEFAULT_MATERIAL)
		body.set_meta("kind", kind)
		body.set_meta("size", size)
		body.set_meta("color", floor_mat.albedo_color)
		body.set_meta("yaw", 0.0)
		body.set_meta("floor", floor)
		body.set_meta("material", mat_id if mat_id != "" else Config.DEFAULT_MATERIAL)
		var pcs: Array = pieces.duplicate(true) if not pieces.is_empty() else _xz_rect_from_box(cx, size)
		body.set_meta("pieces", _sanitize_floor_pieces(pcs))
		body.set_meta("openings", _sanitize_floor_openings(openings))
		content.add_child(body)
		placed.append(body)
		ElementGeometry.rebuild_floor_geom(body)
		dirty = true
		return _merge_connected_floors(body)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat: StandardMaterial3D
	if mat_id != "":
		mat = ElementGeometry.surface_mat(mat_id)
		color = mat.albedo_color
	else:
		mat = ElementGeometry.clay_mat(color)
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)

	if yaw != 0.0:
		mi.rotation.y = yaw
		cs.rotation.y = yaw

	body.set_meta("kind", kind)
	body.set_meta("size", size)
	body.set_meta("color", color)
	body.set_meta("yaw", yaw)
	body.set_meta("floor", floor)
	if mat_id != "":
		body.set_meta("material", mat_id)
	if kind == "device":
		body.set_meta("name", name if name != "" else "设备")
		_add_label(body, size, body.get_meta("name"))
	if kind == "wall":
		body.set_meta("openings", [])
	content.add_child(body)
	placed.append(body)
	dirty = true
	return body

## 由盒中心与尺寸得到 XZ 矩形（地板无 yaw，按轴对齐）。纯几何，见 RectOps。
func _xz_rect_from_box(cx: Vector3, size: Vector3) -> Array:
	return RectOps.xz_rect_from_box(cx, size)


## 归一化地板碎片：翻转反向坐标、丢弃窄于 0.001 的碎片。纯几何，见 RectOps。
func _sanitize_floor_pieces(pieces: Array) -> Array:
	return RectOps.sanitize_floor_pieces(pieces)


## 两矩形是否可合并为一块（重叠或共边）。纯几何，见 RectOps。
func _xz_rects_joinable(a: Dictionary, b: Dictionary, eps: float = 0.002) -> bool:
	return RectOps.xz_rects_joinable(a, b, eps)


func _floors_coplanar(a: StaticBody3D, b: StaticBody3D) -> bool:
	var ta := top_surface_y(a)
	var tb := top_surface_y(b)
	var ha: float = a.get_meta("size").y
	var hb: float = b.get_meta("size").y
	return absf(ta - tb) <= 0.002 and absf(ha - hb) <= 0.002


func _floor_pieces_joinable(a: StaticBody3D, b: StaticBody3D) -> bool:
	var pa := ElementGeometry.floor_pieces(a)
	var pb := ElementGeometry.floor_pieces(b)
	for ra in pa:
		for rb in pb:
			if _xz_rects_joinable(ra, rb):
				return true
	return false


func _connected_coplanar_floors(src_floor: StaticBody3D) -> Array:
	var group: Array = [src_floor]
	var queue: Array = [src_floor]
	while not queue.is_empty():
		var cur: StaticBody3D = queue.pop_back()
		for obj in placed:
			if obj == null or not is_instance_valid(obj) or obj == cur:
				continue
			if group.has(obj):
				continue
			if not obj.has_meta("kind") or String(obj.get_meta("kind")) != "floor_tile":
				continue
			if not _floors_coplanar(src_floor, obj):
				continue
			if not _floor_pieces_joinable(cur, obj):
				continue
			group.append(obj)
			queue.append(obj)
	return group


## 轴对齐矩形并集（不填 L 形缺口、重叠区只计一次）。纯几何，见 RectOps。
func _union_xz_rects(rects: Array) -> Array:
	return RectOps.union_xz_rects(rects)


## 新铺地板与共面、重叠或共边的已有地板合并为一块（材质取新铺）。
## 优先保留已有物体作为主体，避免阵列原点被删掉。
func _merge_connected_floors(src_floor: StaticBody3D) -> StaticBody3D:
	if src_floor == null or not is_instance_valid(src_floor):
		return src_floor
	var group := _connected_coplanar_floors(src_floor)
	if group.size() <= 1:
		return src_floor
	var all_pieces: Array = []
	var all_ops: Array = []
	for f_v in group:
		var f: StaticBody3D = f_v
		all_pieces.append_array(ElementGeometry.floor_pieces(f))
		all_ops.append_array(ElementGeometry.floor_openings(f))
	var unioned := _union_xz_rects(all_pieces)
	if unioned.is_empty():
		return src_floor
	var top_y := top_surface_y(src_floor)
	var h: float = float(src_floor.get_meta("size").y)
	var mat := Config.DEFAULT_MATERIAL
	if src_floor.has_meta("material"):
		mat = Config.normalize_material(String(src_floor.get_meta("material")))
	var floor_i := int(src_floor.get_meta("floor")) if src_floor.has_meta("floor") else 0
	var survivor: StaticBody3D = src_floor
	for obj in placed:
		if obj != src_floor and group.has(obj) and is_instance_valid(obj):
			survivor = obj
			break
	var to_drop: Array = []
	for f_v2 in group:
		if f_v2 != survivor:
			to_drop.append(f_v2)
	for d in to_drop:
		remove(d)
	if not is_instance_valid(survivor):
		return src_floor
	var pos := survivor.global_position
	pos.y = top_y - h * 0.5
	survivor.global_position = pos
	survivor.set_meta("floor", floor_i)
	survivor.set_meta("material", mat)
	survivor.set_meta("size", Vector3(1.0, h, 1.0))
	survivor.set_meta("pieces", unioned)
	survivor.set_meta("openings", _sanitize_floor_openings(all_ops))
	survivor.set_meta("yaw", 0.0)
	ElementGeometry.rebuild_floor_geom(survivor)
	dirty = true
	return survivor


func _floor_piece_corners(obj: StaticBody3D) -> Array:
	var out: Array = []
	var y: float = obj.global_position.y
	for p_v in ElementGeometry.floor_pieces(obj):
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		var x0 := float(p["x0"])
		var x1 := float(p["x1"])
		var z0 := float(p["z0"])
		var z1 := float(p["z1"])
		out.append(Vector3(x0, y, z0))
		out.append(Vector3(x1, y, z0))
		out.append(Vector3(x0, y, z1))
		out.append(Vector3(x1, y, z1))
	if out.is_empty():
		return obb_corners(obj)
	return out

## 归一化地板开洞（补全 width/length）。纯几何，见 RectOps。
func _sanitize_floor_openings(ops: Array) -> Array:
	return RectOps.sanitize_floor_openings(ops)


## 单个地板开洞的归一化数据。纯几何，见 RectOps。
func _floor_opening_data(op: Dictionary) -> Dictionary:
	return RectOps.floor_opening_data(op)


## 从实心矩形中减去地洞（洞口不填实）。纯几何，见 RectOps。
func _subtract_xz_rects(solids: Array, holes: Array) -> Array:
	return RectOps.subtract_xz_rects(solids, holes)


## 碎片集合的 XZ 包围盒。纯几何，见 RectOps。
func _floor_aabb_xz(pieces: Array) -> Dictionary:
	return RectOps.floor_aabb_xz(pieces)


func floor_hole_snap_points(body: StaticBody3D) -> Array:
	var out: Array = []
	if body == null or not is_instance_valid(body):
		return out
	var top := top_surface_y(body)
	var aabb := _floor_aabb_xz(ElementGeometry.floor_pieces(body))
	if aabb.is_empty():
		return out
	var grow := Config.SNAP_TO_CORNER
	for p_v in ElementGeometry.floor_pieces(body):
		var p: Dictionary = p_v
		out.append(Vector3(float(p["x0"]), top, float(p["z0"])))
		out.append(Vector3(float(p["x1"]), top, float(p["z0"])))
		out.append(Vector3(float(p["x0"]), top, float(p["z1"])))
		out.append(Vector3(float(p["x1"]), top, float(p["z1"])))
	for h_v in ElementGeometry.floor_openings(body):
		var h: Dictionary = h_v
		out.append(Vector3(float(h["x0"]), top, float(h["z0"])))
		out.append(Vector3(float(h["x1"]), top, float(h["z0"])))
		out.append(Vector3(float(h["x0"]), top, float(h["z1"])))
		out.append(Vector3(float(h["x1"]), top, float(h["z1"])))
	for obj in placed:
		if obj == null or not is_instance_valid(obj) or obj == body or not obj.has_meta("kind"):
			continue
		var kind := String(obj.get_meta("kind"))
		var corners: Array = []
		if kind == "wall":
			corners = wall_top_corners(obj)
		elif kind == "stair":
			corners = stair_top_corners(obj)
		else:
			continue
		for c_v in corners:
			var c: Vector3 = c_v
			if absf(c.y - top) > 0.08:
				continue
			if c.x < float(aabb["x0"]) - grow or c.x > float(aabb["x1"]) + grow:
				continue
			if c.z < float(aabb["z0"]) - grow or c.z > float(aabb["z1"]) + grow:
				continue
			out.append(Vector3(c.x, top, c.z))
	return out


func _snap_floor_hole_center(body: StaticBody3D, cx: float, cz: float, width: float, length: float) -> Vector2:
	var hw := width * 0.5
	var hl := length * 0.5
	var corners := [
		Vector2(cx - hw, cz - hl),
		Vector2(cx + hw, cz - hl),
		Vector2(cx - hw, cz + hl),
		Vector2(cx + hw, cz + hl),
	]
	var best_d := Config.SNAP_TO_CORNER
	var best_dx := 0.0
	var best_dz := 0.0
	var found := false
	for cand_v in floor_hole_snap_points(body):
		var cand: Vector3 = cand_v
		for corner in corners:
			var d := Vector2(corner.x - cand.x, corner.y - cand.z).length()
			if d < best_d:
				best_d = d
				best_dx = cand.x - corner.x
				best_dz = cand.z - corner.y
				found = true
	if found:
		return Vector2(cx + best_dx, cz + best_dz)
	return Vector2(cx, cz)


func prepare_floor_opening(body: StaticBody3D, world_point: Vector3, width: float, length: float) -> Dictionary:
	if body == null or not is_instance_valid(body):
		return {}
	if not body.has_meta("kind") or String(body.get_meta("kind")) != "floor_tile":
		return {}
	var pieces := ElementGeometry.floor_pieces(body)
	var aabb := _floor_aabb_xz(pieces)
	if aabb.is_empty():
		return {}
	var w := maxf(width, Config.OPENING_MIN)
	var l := maxf(length, Config.OPENING_MIN)
	var hole_c := _snap_floor_hole_center(body, world_point.x, world_point.z, w, l)
	return _clamp_floor_opening(body, pieces, aabb, hole_c.x, hole_c.y, w, l)


func _clamp_floor_opening(body: StaticBody3D, pieces: Array, aabb: Dictionary, cx: float, cz: float, width: float, length: float) -> Dictionary:
	var clamped := false
	var min_x := float(aabb["x0"])
	var max_x := float(aabb["x1"])
	var min_z := float(aabb["z0"])
	var max_z := float(aabb["z1"])
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	if width > span_x:
		width = span_x
		clamped = true
	if length > span_z:
		length = span_z
		clamped = true
	if width < Config.OPENING_MIN or length < Config.OPENING_MIN:
		return {"ok": false, "clamped": clamped}
	var hw := width * 0.5
	var hl := length * 0.5
	var cx_c := clampf(cx, min_x + hw, max_x - hw)
	var cz_c := clampf(cz, min_z + hl, max_z - hl)
	if absf(cx_c - cx) > 0.0005 or absf(cz_c - cz) > 0.0005:
		clamped = true
	var x0 := cx_c - hw
	var x1 := cx_c + hw
	var z0 := cz_c - hl
	var z1 := cz_c + hl
	var overlaps := false
	for p_v in pieces:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var pr: Dictionary = p_v
		var x_ov := minf(x1, float(pr["x1"])) - maxf(x0, float(pr["x0"]))
		var z_ov := minf(z1, float(pr["z1"])) - maxf(z0, float(pr["z0"]))
		if x_ov > 0.001 and z_ov > 0.001:
			overlaps = true
			break
	if not overlaps:
		return {"ok": false, "clamped": clamped}
	var trial: Array = ElementGeometry.floor_openings(body).duplicate()
	trial.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1})
	var leftover := _subtract_xz_rects(pieces, trial)
	if leftover.is_empty():
		return {"ok": false, "clamped": clamped}
	var h: float = float(body.get_meta("size").y)
	var cy: float = body.global_position.y
	return {
		"ok": true,
		"clamped": clamped,
		"body": body,
		"x0": x0, "x1": x1, "z0": z0, "z1": z1,
		"width": width, "length": length,
		"center": Vector3((x0 + x1) * 0.5, cy, (z0 + z1) * 0.5),
		"size": Vector3(width, h + 0.04, length),
	}


func add_floor_opening(body: StaticBody3D, x0: float, x1: float, z0: float, z1: float) -> Dictionary:
	if body == null or not is_instance_valid(body) or not body.has_meta("kind") or String(body.get_meta("kind")) != "floor_tile":
		return {"ok": false}
	var pieces := ElementGeometry.floor_pieces(body)
	var aabb := _floor_aabb_xz(pieces)
	if aabb.is_empty():
		return {"ok": false}
	var w := absf(x1 - x0)
	var l := absf(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var prep := _clamp_floor_opening(body, pieces, aabb, cx, cz, w, l)
	if prep.is_empty() or not bool(prep.get("ok", false)):
		return {"ok": false, "clamped": bool(prep.get("clamped", false))}
	var stored := _floor_opening_data(prep)
	var openings: Array = ElementGeometry.floor_openings(body)
	openings.append(stored)
	body.set_meta("openings", openings)
	ElementGeometry.rebuild_floor_geom(body)
	dirty = true
	return {"ok": true, "clamped": bool(prep.get("clamped", false)), "opening": stored}


func remove_floor_opening(body: StaticBody3D, index: int) -> void:
	if body == null or not is_instance_valid(body) or not body.has_meta("openings"):
		return
	var openings: Array = ElementGeometry.floor_openings(body)
	if index < 0 or index >= openings.size():
		return
	openings.remove_at(index)
	body.set_meta("openings", openings)
	ElementGeometry.rebuild_floor_geom(body)
	dirty = true


func set_floor_openings(body: StaticBody3D, openings: Array) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.set_meta("openings", _sanitize_floor_openings(openings))
	ElementGeometry.rebuild_floor_geom(body)
	dirty = true

func place_stair(center: Vector3, width: float, length: float, height: float, yaw: float, material: String = "") -> StaticBody3D:
	var mat_id := Config.normalize_material(material if material != "" else Config.DEFAULT_MATERIAL)
	var body := StaticBody3D.new()
	body.name = "stair_%d" % body.get_instance_id()
	body.position = center
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := ElementGeometry.surface_mat(mat_id)
	ElementGeometry.attach_stair_geom(body, width, length, height, mat, true)
	var size := Vector3(width, height, length)
	body.set_meta("kind", "stair")
	body.set_meta("size", size)
	body.set_meta("width", width)
	body.set_meta("length", length)
	body.set_meta("height", height)
	body.set_meta("yaw", yaw)
	body.set_meta("facing", yaw)
	body.set_meta("material", mat_id)
	body.set_meta("color", mat.albedo_color)
	body.set_meta("floor", 0)
	content.add_child(body)
	placed.append(body)
	dirty = true
	return body

## 兼容转发：几何生成已移至 ElementGeometry，保留静态入口供楼梯预览工具调用。
static func attach_stair_geom(parent: Node3D, width: float, length: float, height: float, mat: Material, with_collision: bool) -> void:
	ElementGeometry.attach_stair_geom(parent, width, length, height, mat, with_collision)

## 楼梯最高踏步顶面四角（世界坐标），供地板磁吸。
static func stair_top_corners(obj: StaticBody3D) -> Array:
	var width := float(obj.get_meta("width"))
	var length := float(obj.get_meta("length"))
	var height := float(obj.get_meta("height"))
	var yaw := float(obj.get_meta("yaw")) if obj.has_meta("yaw") else 0.0
	var n := ElementGeometry.stair_step_count(height)
	var tread := length / float(n)
	var c: Vector3 = obj.global_position
	var dx := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dz := Vector3(sin(yaw), 0.0, cos(yaw))
	var hx := width * 0.5
	var z_front := -length * 0.5
	var z_back := z_front + tread
	var top := Vector3(0.0, height * 0.5, 0.0)
	return [
		c + dx * hx + dz * z_front + top,
		c + dx * -hx + dz * z_front + top,
		c + dx * hx + dz * z_back + top,
		c + dx * -hx + dz * z_back + top,
	]

## 墙体顶面四角（世界坐标，含墙厚，非中心线），供地板磁吸对齐。
static func wall_top_corners(obj: StaticBody3D) -> Array:
	var size: Vector3 = obj.get_meta("size")
	var yaw: float = float(obj.get_meta("yaw")) if obj.has_meta("yaw") else 0.0
	var c: Vector3 = obj.global_position
	var dx := Vector3(cos(yaw), 0.0, -sin(yaw)) * size.x * 0.5
	var dz := Vector3(sin(yaw), 0.0, cos(yaw)) * size.z * 0.5
	var top := Vector3(0.0, size.y * 0.5, 0.0)
	return [
		c + dx + dz + top,
		c + dx - dz + top,
		c - dx + dz + top,
		c - dx - dz + top,
	]

func snap_corners_of(obj: StaticBody3D) -> Array:
	if obj == null or not obj.has_meta("kind"):
		return obb_corners(obj)
	var kind := String(obj.get_meta("kind"))
	if kind == "stair":
		return stair_top_corners(obj)
	if kind == "wall":
		return wall_top_corners(obj)
	if kind == "floor_tile":
		return _floor_piece_corners(obj)
	return obb_corners(obj)

## 立即更新柱/墙/地板/楼梯的材质外观与 meta。
func set_body_material(body: StaticBody3D, material_id: String) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.has_meta("kind") or not Kinds.MATERIAL_KINDS.has(body.get_meta("kind")):
		return
	var mat_id := Config.normalize_material(material_id)
	var mat := ElementGeometry.surface_mat(mat_id)
	body.set_meta("material", mat_id)
	body.set_meta("color", mat.albedo_color)
	dirty = true
	for child in body.get_children():
		var cname := String(child.name)
		if cname == "_SelectHL" or cname.begins_with("WindowGlass"):
			continue
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var bm: BoxMesh = child.mesh
			bm.material = mat
			child.material_override = null

## 按逻辑尺寸更新柱/墙/地板/楼梯几何（立即生效，底面或顶面尽量保持）。
## dims: column/wall → height, thickness；floor_tile → thickness；stair → width, length, height。
func set_body_dims(body: StaticBody3D, dims: Dictionary) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.has_meta("kind"):
		return
	var kind: String = body.get_meta("kind")
	if not Kinds.MATERIAL_KINDS.has(kind):
		return
	var old_size: Vector3 = body.get_meta("size")
	var yaw: float = float(body.get_meta("yaw")) if body.has_meta("yaw") else 0.0
	var new_size := old_size
	var pos := body.global_position
	match kind:
		"column":
			var h := float(dims.get("height", Config.COLUMN_HEIGHT))
			var t := float(dims.get("thickness", Config.COLUMN_SIZES[0]))
			var base_y := pos.y - old_size.y * 0.5
			new_size = Vector3(t + Config.EMBED * 2.0, h + Config.EMBED * 2.0, t + Config.EMBED * 2.0)
			pos.y = base_y + new_size.y * 0.5
		"wall":
			var h2 := float(dims.get("height", Config.WALL_HEIGHT))
			var th := float(dims.get("thickness", Config.WALL_THICKNESS_DEFAULT))
			var length := maxf(old_size.x - Config.EMBED * 2.0, Config.GRID)
			var base_y2 := pos.y - old_size.y * 0.5 + Config.EMBED
			new_size = Vector3(length + Config.EMBED * 2.0, h2 + Config.EMBED, th)
			pos.y = base_y2 + new_size.y * 0.5 - Config.EMBED
			body.global_position = pos
			body.set_meta("size", new_size)
			if body.has_meta("openings"):
				var ops: Array = []
				for op_v in body.get_meta("openings"):
					if typeof(op_v) == TYPE_DICTIONARY:
						ops.append(_opening_data(_clamp_opening(new_size, op_v)))
				body.set_meta("openings", ops)
			ElementGeometry.rebuild_wall_geom(body)
			dirty = true
			return
		"floor_tile":
			var th2 := float(dims.get("thickness", Config.FLOOR_THICKNESS))
			var h3 := th2 + Config.EMBED
			var top_y := pos.y + old_size.y * 0.5
			new_size = Vector3(old_size.x, h3, old_size.z)
			pos.y = top_y - h3 * 0.5
			body.global_position = pos
			body.set_meta("size", new_size)
			if not body.has_meta("pieces"):
				body.set_meta("pieces", _xz_rect_from_box(pos, new_size))
			ElementGeometry.rebuild_floor_geom(body)
			dirty = true
			return
		"stair":
			var nw := maxf(0.4, float(dims.get("width", body.get_meta("width"))))
			var nl := maxf(0.5, float(dims.get("length", body.get_meta("length"))))
			var nh := maxf(0.3, float(dims.get("height", body.get_meta("height"))))
			var old_h := float(body.get_meta("height"))
			var old_l := float(body.get_meta("length"))
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var start := pos - fwd * (old_l * 0.5)
			var base_y3 := pos.y - old_h * 0.5
			pos = start + fwd * (nl * 0.5)
			pos.y = base_y3 + nh * 0.5
			new_size = Vector3(nw, nh, nl)
			body.global_position = pos
			body.rotation.y = yaw
			body.set_meta("size", new_size)
			body.set_meta("width", nw)
			body.set_meta("length", nl)
			body.set_meta("height", nh)
			ElementGeometry.rebuild_stair_geom(body, nw, nl, nh)
			dirty = true
			return
		_:
			return
	body.global_position = pos
	body.set_meta("size", new_size)
	dirty = true
	for child in body.get_children():
		if String(child.name) == "_SelectHL":
			continue
		if child is MeshInstance3D and child.mesh is BoxMesh:
			(child.mesh as BoxMesh).size = new_size
			child.rotation.y = yaw
		elif child is CollisionShape3D and child.shape is BoxShape3D:
			(child.shape as BoxShape3D).size = new_size
			child.rotation.y = yaw

## 删除已放置物体：从仓库登记中移除并销毁节点。
func remove(body: StaticBody3D) -> void:
	placed.erase(body)
	dirty = true
	if is_instance_valid(body):
		body.queue_free()

func clear_placed() -> void:
	var copy := placed.duplicate()
	placed.clear()
	for obj in copy:
		if is_instance_valid(obj):
			obj.queue_free()
	dirty = false

func serialize_placed() -> Array:
	var out: Array = []
	for obj in placed:
		if not is_instance_valid(obj) or not obj.has_meta("kind"):
			continue
		var kind := String(obj.get_meta("kind"))
		var rec := {
			"kind": kind,
			"position": _vec_to_arr(obj.global_position),
			"yaw": float(obj.get_meta("yaw")) if obj.has_meta("yaw") else 0.0,
			"floor": int(obj.get_meta("floor")) if obj.has_meta("floor") else 0,
		}
		if obj.has_meta("size"):
			rec["size"] = _vec_to_arr(obj.get_meta("size"))
		if obj.has_meta("material"):
			rec["material"] = String(obj.get_meta("material"))
		if obj.has_meta("name"):
			rec["name"] = String(obj.get_meta("name"))
		if obj.has_meta("color"):
			var col: Color = obj.get_meta("color")
			rec["color"] = [col.r, col.g, col.b, col.a]
		if kind == "stair":
			rec["width"] = float(obj.get_meta("width"))
			rec["length"] = float(obj.get_meta("length"))
			rec["height"] = float(obj.get_meta("height"))
			rec["facing"] = float(obj.get_meta("facing")) if obj.has_meta("facing") else rec["yaw"]
		if kind == "wall" and obj.has_meta("openings"):
			var ops: Array = []
			for op_v in obj.get_meta("openings"):
				if typeof(op_v) == TYPE_DICTIONARY:
					ops.append(_opening_data(op_v))
			if not ops.is_empty():
				rec["openings"] = ops
		if kind == "floor_tile" and obj.has_meta("pieces"):
			var pcs: Array = []
			for p_v in obj.get_meta("pieces"):
				if typeof(p_v) != TYPE_DICTIONARY:
					continue
				var p: Dictionary = p_v
				pcs.append({
					"x0": float(p.get("x0", 0.0)),
					"x1": float(p.get("x1", 0.0)),
					"z0": float(p.get("z0", 0.0)),
					"z1": float(p.get("z1", 0.0)),
				})
			if not pcs.is_empty():
				rec["pieces"] = pcs
		if kind == "floor_tile" and obj.has_meta("openings"):
			var fops: Array = []
			for op_v in obj.get_meta("openings"):
				if typeof(op_v) == TYPE_DICTIONARY:
					fops.append(_floor_opening_data(op_v))
			if not fops.is_empty():
				rec["openings"] = fops
		out.append(rec)
	return out

func restore_placed(records: Array) -> void:
	clear_placed()
	for rec_v in records:
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_v
		var kind := String(rec.get("kind", ""))
		var pos := _arr_to_vec(rec.get("position", [0.0, 0.0, 0.0]))
		var yaw := float(rec.get("yaw", 0.0))
		var floor_i := int(rec.get("floor", 0))
		var mat := String(rec.get("material", ""))
		var name_s := String(rec.get("name", ""))
		if kind == "stair":
			place_stair(
				pos,
				float(rec.get("width", Config.STAIR_WIDTH)),
				float(rec.get("length", Config.STAIR_LENGTH)),
				float(rec.get("height", Config.STAIR_HEIGHT)),
				yaw, mat)
		elif kind != "":
			var size := _arr_to_vec(rec.get("size", [1.0, 1.0, 1.0]))
			var col := Config.COLOR_DEVICE
			if rec.has("color") and rec["color"] is Array:
				var ca: Array = rec["color"]
				if ca.size() >= 3:
					col = Color(float(ca[0]), float(ca[1]), float(ca[2]), float(ca[3]) if ca.size() > 3 else 1.0)
			var floor_pieces: Array = []
			var floor_ops: Array = []
			if kind == "floor_tile" and rec.get("pieces") is Array:
				floor_pieces = rec["pieces"]
			if kind == "floor_tile" and rec.get("openings") is Array:
				floor_ops = rec["openings"]
			var placed_body := place_box(pos, size, col, kind, yaw, floor_i, name_s, mat, floor_pieces, floor_ops)
			if kind == "wall" and rec.get("openings") is Array:
				set_wall_openings(placed_body, rec["openings"])
	dirty = false

static func _vec_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _arr_to_vec(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

func _add_label(body: StaticBody3D, size: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.0032
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, size.y * 0.5 + 0.4, 0.0)
	label.modulate = Color(0.24, 0.25, 0.27, 0.95)
	label.outline_size = 8
	label.outline_modulate = Color(0.94, 0.95, 0.96, 0.95)
	label.visible = labels_visible
	body.add_child(label)
	_add_leader(body, size)

func _add_leader(body: StaticBody3D, size: Vector3) -> void:
	var leader := MeshInstance3D.new()
	leader.name = "Leader"
	leader.position = Vector3(0.0, size.y * 0.5 + 0.2, 0.0)
	var line := CylinderMesh.new()
	line.top_radius = 0.015
	line.bottom_radius = 0.015
	line.height = 0.4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 0.46, 0.48, 1.0)
	line.material = m
	leader.mesh = line
	leader.visible = labels_visible
	body.add_child(leader)

func toggle_labels() -> void:
	labels_visible = not labels_visible
	for obj in placed:
		if obj.has_meta("name"):
			var l: Node = obj.get_node_or_null("Label")
			if l != null:
				l.visible = labels_visible
			var lead: Node = obj.get_node_or_null("Leader")
			if lead != null:
				lead.visible = labels_visible

func top_surface_y(body: Node3D) -> float:
	if body == ground_body:
		return Config.FLOOR_TOP_OFFSET
	if body != null and body.has_meta("kind") and body.get_meta("kind") == "stair" and body.has_meta("height"):
		return body.global_position.y + float(body.get_meta("height")) * 0.5
	if not body.has_meta("size"):
		return 0.0
	var size: Vector3 = body.get_meta("size")
	return body.global_position.y + size.y * 0.5

## 该 AABB 范围内是否无干涉（仅检测已放置物体，忽略地面）。
func aabb_clear(aabb: AABB, grow: float, exclude: Array = [], exclude_kinds: Array = []) -> bool:
	var bs := BoxShape3D.new()
	bs.size = aabb.size
	return shape_clear(bs, Transform3D(Basis(), aabb.get_center()), grow, exclude, exclude_kinds)

## 以指定形状/变换检测干涉。exclude_kinds 非空时忽略这些 kind 的物体
## （如墙互不阻挡、墙与柱互相嵌入以消除接缝）。
func shape_clear(shape: Shape3D, xform: Transform3D, grow: float, exclude: Array = [], exclude_kinds: Array = []) -> bool:
	if shape is BoxShape3D and grow > 0.0:
		var bs := BoxShape3D.new()
		bs.size = (shape as BoxShape3D).size + Vector3.ONE * grow
		shape = bs
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = xform
	params.collision_mask = 1
	var ex := exclude.duplicate()
	if ground_body != null:
		ex.append(ground_body)
	params.exclude = ex
	var hits := space.intersect_shape(params, 16)
	if exclude_kinds.is_empty():
		return hits.is_empty()
	for h in hits:
		var col: CollisionObject3D = h["collider"]
		if not col.has_meta("kind") or not exclude_kinds.has(col.get_meta("kind")):
			return false
	return true

## 磁吸：若 p（XZ 平面）距某指定 kind 物体中心小于 max_dist，
## 返回最近物体的中心；否则返回 p。
func snap_to_kind(p: Vector3, kind: String, max_dist: float) -> Vector3:
	var best := p
	var best_d := max_dist
	for obj in placed:
		if not obj.has_meta("kind") or obj.get_meta("kind") != kind:
			continue
		var c: Vector3 = obj.global_position
		var d := Vector2(p.x - c.x, p.z - c.z).length()
		if d < best_d:
			best_d = d
			best = Vector3(c.x, p.y, c.z)
	return best

## 磁吸：若 p（XZ 平面）距某柱子角点小于 max_dist，返回该角点向柱心方向
## 各轴内缩 inset 后的位置——墙端（半厚 = inset）完全嵌入柱内且与柱面齐平；
## 否则返回 p。
func snap_to_column_inset(p: Vector3, inset: float, max_dist: float) -> Vector3:
	var best := p
	var best_d := max_dist
	for obj in placed:
		if not obj.has_meta("kind") or obj.get_meta("kind") != "column":
			continue
		var c: Vector3 = obj.global_position
		for corner in obb_corners(obj):
			var d := Vector2(p.x - corner.x, p.z - corner.z).length()
			if d < best_d:
				best_d = d
				best = Vector3(
					corner.x - signf(corner.x - c.x) * inset,
					p.y,
					corner.z - signf(corner.z - c.z) * inset)
	return best

## 磁吸：若 p（XZ 平面）距某指定 kinds 物体的角点小于 max_dist，
## 返回最近的角点；否则返回 p。墙取顶面四角（含墙厚），楼梯取最高踏步顶面四角，其余取底面矩形四角。
## 墙/楼梯命中时保留角点世界 Y（墙顶 / 梯顶标高）；柱/地板仍用瞄准点 Y。
func pick_snap_corner(p: Vector3, kinds: Array, max_dist: float) -> Dictionary:
	var best_d := max_dist
	var best: Dictionary = {}
	for obj in placed:
		if not is_instance_valid(obj) or not obj.has_meta("kind"):
			continue
		var kind := String(obj.get_meta("kind"))
		if not kinds.has(kind):
			continue
		for corner in snap_corners_of(obj):
			var d := Vector2(p.x - corner.x, p.z - corner.z).length()
			if d < best_d:
				best_d = d
				best = {"point": corner, "kind": kind, "body": obj}
	return best

func snap_to_corners(p: Vector3, kinds: Array, max_dist: float) -> Vector3:
	var hit := pick_snap_corner(p, kinds, max_dist)
	if hit.is_empty():
		return p
	var c: Vector3 = hit["point"]
	var kind := String(hit["kind"])
	if kind == "wall" or kind == "stair":
		return c
	return Vector3(c.x, p.y, c.z)

## 物体底面矩形的四个角点（考虑 yaw 旋转）。
static func obb_corners(obj: StaticBody3D) -> Array:
	var size: Vector3 = obj.get_meta("size")
	var yaw: float = obj.get_meta("yaw")
	var c: Vector3 = obj.global_position
	var dx := Vector3(cos(yaw), 0.0, -sin(yaw)) * size.x * 0.5
	var dz := Vector3(sin(yaw), 0.0, cos(yaw)) * size.z * 0.5
	return [c + dx + dz, c + dx - dz, c - dx + dz, c - dx - dz]

## 磁吸：若 p（XZ 平面）距某面墙的中心线段小于 max_dist，
## 返回该线段上最近的点（钳制在墙段范围内）；否则返回 p。
func snap_to_wall(p: Vector3, max_dist: float) -> Vector3:
	var best := p
	var best_d := max_dist
	for obj in placed:
		if not obj.has_meta("kind") or obj.get_meta("kind") != "wall":
			continue
		var size: Vector3 = obj.get_meta("size")
		var yaw: float = obj.get_meta("yaw")
		var dir := Vector3(cos(yaw), 0.0, -sin(yaw))
		var c: Vector3 = obj.global_position
		var rel := Vector3(p.x - c.x, 0.0, p.z - c.z)
		var t := clampf(rel.dot(dir), -size.x * 0.5, size.x * 0.5)
		var q := c + dir * t
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < best_d:
			best_d = d
			best = Vector3(q.x, p.y, q.z)
	return best

func surface_ray(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_dist, 1 | 2)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	return hit

func camera_ray(cc) -> Dictionary:
	var cam: Camera3D = cc.camera
	if cc.is_top_down():
		var mpos: Vector2 = cc.get_viewport().get_mouse_position()
		return {
			"origin": cam.project_ray_origin(mpos),
			"dir": cam.project_ray_normal(mpos),
		}
	return {
		"origin": cam.global_position,
		"dir": -cam.global_transform.basis.z,
	}

## 由相机瞄准点计算放置表面：返回 { point, surface_y }，未命中返回空字典。
func aim_surface(cc) -> Dictionary:
	var ray := camera_ray(cc)
	var origin: Vector3 = ray["origin"]
	var dir: Vector3 = ray["dir"]
	var hit := surface_ray(origin, dir, 400.0)
	if hit.is_empty():
		return {}
	var collider: CollisionObject3D = hit["collider"]
	return {
		"point": hit["position"],
		"surface_y": top_surface_y(collider),
		"body": collider,
		"origin": origin,
		"dir": dir,
	}

func aim_opening(cc) -> Dictionary:
	var ray := camera_ray(cc)
	return pick_opening(ray["origin"], ray["dir"], 400.0)

func pick_opening(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var best_t := max_dist
	var best: Dictionary = {}
	for obj in placed:
		if not is_instance_valid(obj) or not obj.has_meta("kind"):
			continue
		var kind := String(obj.get_meta("kind"))
		if obj.collision_layer == 0 or not obj.has_meta("openings"):
			continue
		var ops: Array = obj.get_meta("openings")
		if ops.is_empty():
			continue
		if kind == "floor_tile":
			var hy := float(obj.get_meta("size").y) * 0.5 + 0.04
			var cy: float = obj.global_position.y
			for i in ops.size():
				var op_v: Variant = ops[i]
				if typeof(op_v) != TYPE_DICTIONARY:
					continue
				var opd := _floor_opening_data(op_v)
				var bmin := Vector3(float(opd["x0"]), cy - hy, float(opd["z0"]))
				var bmax := Vector3(float(opd["x1"]), cy + hy, float(opd["z1"]))
				var t := _ray_aabb_t(origin, dir, bmin, bmax)
				if t >= 0.0 and t < best_t:
					best_t = t
					best = {
						"body": obj,
						"index": i,
						"point": origin + dir * t,
						"opening": opd,
					}
			continue
		if kind != "wall":
			continue
		var yaw := float(obj.get_meta("yaw")) if obj.has_meta("yaw") else 0.0
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var across := Vector3(sin(yaw), 0.0, cos(yaw))
		var rel: Vector3 = origin - obj.global_position
		var lo := Vector3(rel.dot(along), rel.y, rel.dot(across))
		var ld := Vector3(dir.dot(along), dir.y, dir.dot(across))
		var size: Vector3 = obj.get_meta("size")
		var hz := size.z * 0.5 + 0.02
		for i in ops.size():
			var op_v: Variant = ops[i]
			if typeof(op_v) != TYPE_DICTIONARY:
				continue
			var b := RectOps.opening_local_bounds(size, op_v)
			var bmin := Vector3(float(b["x0"]), float(b["y0"]), -hz)
			var bmax := Vector3(float(b["x1"]), float(b["y1"]), hz)
			var t := _ray_aabb_t(lo, ld, bmin, bmax)
			if t >= 0.0 and t < best_t:
				best_t = t
				best = {
					"body": obj,
					"index": i,
					"point": origin + dir * t,
					"opening": _opening_data(op_v),
				}
	return best

func prepare_wall_opening(body: StaticBody3D, typ: String, width: float, height: float, sill: float, world_point: Vector3) -> Dictionary:
	if body == null or not is_instance_valid(body):
		return {}
	if not body.has_meta("kind") or body.get_meta("kind") != "wall":
		return {}
	var size: Vector3 = body.get_meta("size")
	var yaw := float(body.get_meta("yaw")) if body.has_meta("yaw") else 0.0
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var u := (world_point - body.global_position).dot(along)
	var op := _clamp_opening(size, {
		"type": typ, "width": width, "height": height, "sill": sill, "u": u,
	})
	op["ok"] = true
	op["body"] = body
	op["yaw"] = yaw
	op["size"] = size
	return op

func add_wall_opening(body: StaticBody3D, typ: String, width: float, height: float, sill: float, u: float) -> Dictionary:
	if body == null or not is_instance_valid(body) or not body.has_meta("kind") or body.get_meta("kind") != "wall":
		return {"ok": false}
	var size: Vector3 = body.get_meta("size")
	var op := _clamp_opening(size, {
		"type": typ, "width": width, "height": height, "sill": sill, "u": u,
	})
	var stored := _opening_data(op)
	var openings: Array = []
	if body.has_meta("openings"):
		openings = (body.get_meta("openings") as Array).duplicate()
	var trial := openings.duplicate()
	trial.append(stored)
	var pieces := _wall_leftover_boxes(size, trial)
	if pieces.is_empty():
		return {"ok": false, "clamped": bool(op.get("clamped", false))}
	openings.append(stored)
	body.set_meta("openings", openings)
	ElementGeometry.rebuild_wall_geom(body)
	dirty = true
	return {"ok": true, "clamped": bool(op.get("clamped", false)), "opening": stored}

func remove_wall_opening(body: StaticBody3D, index: int) -> void:
	if body == null or not is_instance_valid(body) or not body.has_meta("openings"):
		return
	var openings: Array = (body.get_meta("openings") as Array).duplicate()
	if index < 0 or index >= openings.size():
		return
	openings.remove_at(index)
	body.set_meta("openings", openings)
	ElementGeometry.rebuild_wall_geom(body)
	dirty = true

func set_wall_openings(body: StaticBody3D, openings: Array) -> void:
	if body == null or not is_instance_valid(body):
		return
	var size: Vector3 = body.get_meta("size")
	var copy: Array = []
	for op_v in openings:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		copy.append(_opening_data(_clamp_opening(size, op_v)))
	body.set_meta("openings", copy)
	ElementGeometry.rebuild_wall_geom(body)
	dirty = true

func opening_world_box(body: StaticBody3D, op: Dictionary) -> Dictionary:
	if body.has_meta("kind") and String(body.get_meta("kind")) == "floor_tile":
		var fod := _floor_opening_data(op)
		var h: float = float(body.get_meta("size").y)
		return {
			"center": Vector3(
				(float(fod["x0"]) + float(fod["x1"])) * 0.5,
				body.global_position.y,
				(float(fod["z0"]) + float(fod["z1"])) * 0.5),
			"size": Vector3(float(fod["width"]), h + 0.04, float(fod["length"])),
			"yaw": 0.0,
		}
	var size: Vector3 = body.get_meta("size")
	var yaw := float(body.get_meta("yaw")) if body.has_meta("yaw") else 0.0
	var b := RectOps.opening_local_bounds(size, op)
	var u := (float(b["x0"]) + float(b["x1"])) * 0.5
	var y := (float(b["y0"]) + float(b["y1"])) * 0.5
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	return {
		"center": body.global_position + along * u + Vector3(0.0, y, 0.0),
		"size": Vector3(float(b["x1"]) - float(b["x0"]), float(b["y1"]) - float(b["y0"]), size.z + 0.04),
		"yaw": yaw,
	}

func _opening_data(op: Dictionary) -> Dictionary:
	var typ := String(op.get("type", "door"))
	if typ != "window":
		typ = "door"
	return {
		"type": typ,
		"width": float(op.get("width", Config.DOOR_WIDTH)),
		"height": float(op.get("height", Config.DOOR_HEIGHT)),
		"sill": float(op.get("sill", 0.0)),
		"u": float(op.get("u", 0.0)),
	}


func _clamp_opening(size: Vector3, op: Dictionary) -> Dictionary:
	var typ := String(op.get("type", "door"))
	if typ != "window":
		typ = "door"
	var w := float(op.get("width", Config.DOOR_WIDTH if typ == "door" else Config.WINDOW_WIDTH))
	var h := float(op.get("height", Config.DOOR_HEIGHT if typ == "door" else Config.WINDOW_HEIGHT))
	var s := float(op.get("sill", 0.0 if typ == "door" else Config.WINDOW_SILL))
	var u := float(op.get("u", 0.0))
	var clamped := false
	if typ == "door":
		s = 0.0
	w = maxf(w, Config.OPENING_MIN)
	h = maxf(h, Config.OPENING_MIN)
	var hx := size.x * 0.5
	var wall_h := maxf(size.y - Config.EMBED, Config.OPENING_MIN)
	if w > size.x:
		w = size.x
		clamped = true
	var half_w := w * 0.5
	var u_c := clampf(u, -hx + half_w, hx - half_w)
	if absf(u_c - u) > 0.0005:
		clamped = true
	u = u_c
	if s < 0.0:
		s = 0.0
		clamped = true
	if s + h > wall_h:
		if h >= wall_h:
			s = 0.0
			h = wall_h
			clamped = true
		else:
			s = wall_h - h
			clamped = true
	if typ == "door":
		s = 0.0
	return {
		"type": typ,
		"width": w,
		"height": h,
		"sill": s,
		"u": u,
		"clamped": clamped,
	}

## 墙开洞后的剩余实体块。纯几何，见 RectOps。
func _wall_leftover_boxes(size: Vector3, openings: Array) -> Array:
	return RectOps.wall_leftover_boxes(size, openings)

## 射线与 AABB 相交最近命中 t（未命中/背离返回 INF）。纯几何，见 RectOps。
func _ray_aabb_t(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> float:
	return RectOps.ray_aabb_t(o, d, bmin, bmax)