class_name WorldStore
extends Node3D

## 已放置物体的统一仓库：负责创建碰撞体、查询干涉、拾取表面。

const MATERIAL_KINDS := ["floor_tile", "column", "wall", "stair"]

var content: Node3D
var ground_body: StaticBody3D
var placed: Array = []
var labels_visible := true
var dirty := false

func setup(content_parent: Node3D, ground: StaticBody3D) -> void:
	content = content_parent
	ground_body = ground

func place_box(cx: Vector3, size: Vector3, color: Color, kind: String, yaw: float = 0.0, floor: int = 0, name: String = "", material: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind, body.get_instance_id()]
	body.position = cx
	body.collision_layer = 1
	body.collision_mask = 0

	var mat_id := ""
	if material != "":
		mat_id = Config.normalize_material(material)
	elif MATERIAL_KINDS.has(kind):
		mat_id = Config.DEFAULT_MATERIAL

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat: StandardMaterial3D
	if mat_id != "":
		mat = _surface_mat(mat_id)
		color = mat.albedo_color
	else:
		mat = _clay_mat(color)
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
	content.add_child(body)
	placed.append(body)
	dirty = true
	return body

func place_stair(center: Vector3, width: float, length: float, height: float, yaw: float, material: String = "") -> StaticBody3D:
	var mat_id := Config.normalize_material(material if material != "" else Config.DEFAULT_MATERIAL)
	var body := StaticBody3D.new()
	body.name = "stair_%d" % body.get_instance_id()
	body.position = center
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := _surface_mat(mat_id)
	attach_stair_geom(body, width, length, height, mat, true)
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

## 楼梯最高踏步顶面四角（世界坐标），供地板磁吸。
static func stair_top_corners(obj: StaticBody3D) -> Array:
	var width := float(obj.get_meta("width"))
	var length := float(obj.get_meta("length"))
	var height := float(obj.get_meta("height"))
	var yaw := float(obj.get_meta("yaw")) if obj.has_meta("yaw") else 0.0
	var n := stair_step_count(height)
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

func snap_corners_of(obj: StaticBody3D) -> Array:
	if obj != null and obj.has_meta("kind") and obj.get_meta("kind") == "stair":
		return stair_top_corners(obj)
	return obb_corners(obj)

## 立即更新柱/墙/地板/楼梯的材质外观与 meta。
func set_body_material(body: StaticBody3D, material_id: String) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.has_meta("kind") or not MATERIAL_KINDS.has(body.get_meta("kind")):
		return
	var mat_id := Config.normalize_material(material_id)
	var mat := _surface_mat(mat_id)
	body.set_meta("material", mat_id)
	body.set_meta("color", mat.albedo_color)
	dirty = true
	for child in body.get_children():
		if String(child.name) == "_SelectHL":
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
	if not MATERIAL_KINDS.has(kind):
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
		"floor_tile":
			var th2 := float(dims.get("thickness", Config.FLOOR_THICKNESS))
			var h3 := th2 + Config.EMBED
			var top_y := pos.y + old_size.y * 0.5
			new_size = Vector3(old_size.x, h3, old_size.z)
			pos.y = top_y - h3 * 0.5
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
			_rebuild_stair_geom(body, nw, nl, nh)
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

func _rebuild_stair_geom(body: StaticBody3D, width: float, length: float, height: float) -> void:
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
	attach_stair_geom(body, width, length, height, _surface_mat(mat_id), true)

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
			place_box(pos, size, col, kind, yaw, floor_i, name_s, mat)
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

func _clay_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic = 0.0
	return m

## 柱/墙/地板共用材质外观：混凝土冷灰 / 泥土棕。
func _surface_mat(material: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.metallic = 0.0
	if Config.normalize_material(material) == "dirt":
		m.albedo_color = Config.COLOR_FLOOR_DIRT
		m.roughness = 0.95
	else:
		m.albedo_color = Config.COLOR_FLOOR_CONCRETE
		m.roughness = 0.85
	return m

func _floor_mat(material: String) -> StandardMaterial3D:
	return _surface_mat(material)

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
## 返回最近的角点；否则返回 p。楼梯取最高踏步顶面四角，其余取底面矩形四角。
func snap_to_corners(p: Vector3, kinds: Array, max_dist: float) -> Vector3:
	var best := p
	var best_d := max_dist
	for obj in placed:
		if not obj.has_meta("kind") or not kinds.has(obj.get_meta("kind")):
			continue
		for corner in snap_corners_of(obj):
			var d := Vector2(p.x - corner.x, p.z - corner.z).length()
			if d < best_d:
				best_d = d
				best = Vector3(corner.x, p.y, corner.z)
	return best

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

## 由相机瞄准点计算放置表面：返回 { point, surface_y }，未命中返回空字典。
func aim_surface(cc) -> Dictionary:
	var cam: Camera3D = cc.camera
	var origin: Vector3
	var dir: Vector3
	if cc.is_top_down():
		var mpos: Vector2 = cc.get_viewport().get_mouse_position()
		origin = cam.project_ray_origin(mpos)
		dir = cam.project_ray_normal(mpos)
	else:
		origin = cam.global_position
		dir = -cam.global_transform.basis.z
	var hit := surface_ray(origin, dir, 400.0)
	if hit.is_empty():
		return {}
	var collider: CollisionObject3D = hit["collider"]
	return {
		"point": hit["position"],
		"surface_y": top_surface_y(collider),
		"body": collider,
	}
