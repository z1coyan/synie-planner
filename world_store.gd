class_name WorldStore
extends Node3D

## 已放置物体的统一仓库：负责创建碰撞体、查询干涉、拾取表面。

var content: Node3D
var ground_body: StaticBody3D
var placed: Array = []
var labels_visible := true

func setup(content_parent: Node3D, ground: StaticBody3D) -> void:
	content = content_parent
	ground_body = ground

func place_box(cx: Vector3, size: Vector3, color: Color, kind: String, yaw: float = 0.0, floor: int = 0, name: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind, body.get_instance_id()]
	body.position = cx
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := _clay_mat(color)
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
	if kind == "device":
		body.set_meta("name", name if name != "" else "设备")
		_add_label(body, size, body.get_meta("name"))
	content.add_child(body)
	placed.append(body)
	return body

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
		return 0.0
	if not body.has_meta("size"):
		return 0.0
	var size: Vector3 = body.get_meta("size")
	return body.global_position.y + size.y * 0.5

## 该 AABB 范围内是否无干涉（仅检测已放置物体，忽略地面）。
func aabb_clear(aabb: AABB, grow: float, exclude: Array = [], exclude_kind: String = "") -> bool:
	var bs := BoxShape3D.new()
	bs.size = aabb.size
	return shape_clear(bs, Transform3D(Basis(), aabb.get_center()), grow, exclude, exclude_kind)

## 以指定形状/变换检测干涉。exclude_kind 非空时忽略该 kind 的物体（如墙互不阻挡）。
func shape_clear(shape: Shape3D, xform: Transform3D, grow: float, exclude: Array = [], exclude_kind: String = "") -> bool:
	if shape is BoxShape3D and grow > 0.0:
		var bs := BoxShape3D.new()
		bs.size = (shape as BoxShape3D).size + Vector3.ONE * grow
		shape = bs
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = xform
	params.collision_mask = 1
	params.exclude = exclude
	var hits := space.intersect_shape(params, 16)
	if exclude_kind == "":
		return hits.is_empty()
	for h in hits:
		var col: CollisionObject3D = h["collider"]
		if not col.has_meta("kind") or col.get_meta("kind") != exclude_kind:
			return false
	return true

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
	}
