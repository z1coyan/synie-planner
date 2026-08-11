class_name WorldStore
extends Node3D

## 已放置物体的统一仓库：负责创建碰撞体、查询干涉、拾取表面。

var content: Node3D
var ground_body: StaticBody3D
var placed: Array = []

func setup(content_parent: Node3D, ground: StaticBody3D) -> void:
	content = content_parent
	ground_body = ground

func place_box(cx: Vector3, size: Vector3, color: Color, kind: String, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind, body.get_instance_id()]
	body.position = cx
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.05
	mat.roughness = 0.9
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
	content.add_child(body)
	placed.append(body)
	return body

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
