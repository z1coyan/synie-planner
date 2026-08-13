class_name WorldStore
extends Node3D

## 已放置物体的统一仓库：负责创建碰撞体、查询干涉、拾取表面。

const MATERIAL_KINDS := ["floor_tile", "column", "wall"]

var content: Node3D
var ground_body: StaticBody3D
var placed: Array = []
var labels_visible := true

func setup(content_parent: Node3D, ground: StaticBody3D) -> void:
	content = content_parent
	ground_body = ground

func place_box(cx: Vector3, size: Vector3, color: Color, kind: String, yaw: float = 0.0, floor: int = 0, name: String = "", material: String = "") -> StaticBody3D:
	if kind == "device" and name == PunchMeshMachineParams.DISPLAY_NAME:
		return _place_punch_mesh_machine(cx, yaw, floor)
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
	return body


func _place_punch_mesh_machine(cx: Vector3, yaw: float, floor: int) -> StaticBody3D:
	var body := PunchMeshMachineBuilder.build()
	body.name = "device_%d" % body.get_instance_id()
	body.position = cx
	body.rotation.y = yaw
	var fp := PunchMeshMachineParams.FOOTPRINT
	body.set_meta("kind", "device")
	body.set_meta("size", fp)
	body.set_meta("color", PunchMeshMachineParams.COLOR_BODY)
	body.set_meta("yaw", yaw)
	body.set_meta("floor", floor)
	body.set_meta("name", PunchMeshMachineParams.DISPLAY_NAME)
	body.set_meta("device_id", PunchMeshMachineParams.ID)
	_add_label(body, fp, PunchMeshMachineParams.DISPLAY_NAME)
	content.add_child(body)
	placed.append(body)
	return body

## 立即更新柱/墙/地板的材质外观与 meta。
func set_body_material(body: StaticBody3D, material_id: String) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.has_meta("kind") or not MATERIAL_KINDS.has(body.get_meta("kind")):
		return
	var mat_id := Config.normalize_material(material_id)
	var mat := _surface_mat(mat_id)
	body.set_meta("material", mat_id)
	body.set_meta("color", mat.albedo_color)
	for child in body.get_children():
		if String(child.name) == "_SelectHL":
			continue
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var bm: BoxMesh = child.mesh
			bm.material = mat
			child.material_override = null


## 按逻辑尺寸更新柱/墙/地板几何（立即生效，底面或顶面尽量保持）。
## dims: column/wall → height, thickness；floor_tile → thickness。墙长度保持不变。
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
			# 保持顶面标高（与铺设一致）
			var top_y := pos.y + old_size.y * 0.5
			new_size = Vector3(old_size.x, h3, old_size.z)
			pos.y = top_y - h3 * 0.5
		_:
			return
	body.global_position = pos
	body.set_meta("size", new_size)
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
	if is_instance_valid(body):
		body.queue_free()

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
## 返回最近的角点；否则返回 p。角点取物体底面矩形四角（考虑 yaw 旋转）。
func snap_to_corners(p: Vector3, kinds: Array, max_dist: float) -> Vector3:
	var best := p
	var best_d := max_dist
	for obj in placed:
		if not obj.has_meta("kind") or not kinds.has(obj.get_meta("kind")):
			continue
		for corner in obb_corners(obj):
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
		origin = cc.global_position
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
