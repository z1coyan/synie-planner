class_name StairTool
extends PlacementToolBase

## 楼梯工具：单击落点放置（底面中心为起点），朝向吸附世界 XZ 四向正交（无自由 yaw）。
## 右键退出到「无」。F1 宽/长/高，F3 材质。局部网格与柱/墙/地板一致。

var stair_width := Config.STAIR_WIDTH
var stair_length := Config.STAIR_LENGTH
var stair_height := Config.STAIR_HEIGHT

var valid := false

var _preview_root: Node3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_key := ""
var _preview_center := Vector3.ZERO
var _preview_yaw := 0.0

func setup(w: WorldStore, cc: CameraController, h: Hud, main_host: Node = null) -> void:
	world = w
	camera_rig = cc
	hud = h
	host = main_host
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = _make_preview_root("StairPreview")

func set_active(a: bool) -> void:
	active = a
	valid = false
	if not a:
		_preview_root.visible = false
		return
	hud.set_status("楼梯：单击地面放置（朝向正交就近轴向，当前：%s，F1 参数 / F3 材质），右键取消" % Config.material_label(material_id))
	_update_hud()

func refresh_material_hud() -> void:
	_update_hud()

## 相机水平朝向吸附到最近世界轴。踏步沿局部 -Z 上行：
## 0 → -Z，π/2 → -X，π → +Z，-π/2 → +X。不使用任意角度。
func _orthogonal_yaw(look_yaw: float) -> float:
	var fx := -sin(look_yaw)
	var fz := -cos(look_yaw)
	if absf(fx) >= absf(fz):
		return -PI * 0.5 if fx >= 0.0 else PI * 0.5
	return PI if fz >= 0.0 else 0.0

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if _dialog_open():
		_preview_root.visible = false
		valid = false
		return
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_preview_root.visible = false
		valid = false
		return
	var yaw := _orthogonal_yaw(camera_rig.yaw)
	var point: Vector3 = aim["point"]
	var xz := Vector3(point.x, 0.0, point.z)
	xz = world.snap_to_corners(xz, ["column", "wall", "floor_tile"], Config.SNAP_TO_CORNER)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var surface_y: float = float(aim["surface_y"])
	var center := Vector3(
		xz.x, surface_y, xz.z) + fwd * (stair_length * 0.5) + Vector3(0.0, stair_height * 0.5, 0.0)
	var bs := BoxShape3D.new()
	bs.size = Vector3(stair_width, stair_height, stair_length)
	var xform := Transform3D(Basis(Vector3.UP, yaw), center)
	valid = world.shape_clear(bs, xform, Config.CLEARANCE, [], ["wall", "column", "floor_tile"])
	_preview_center = center
	_preview_yaw = yaw
	_show_preview(center, yaw, valid)
	_update_hud()

func _show_preview(center: Vector3, yaw: float, ok: bool) -> void:
	var key := "%.3f_%.3f_%.3f" % [stair_width, stair_length, stair_height]
	if key != _last_key:
		_last_key = key
		_rebuild_preview_steps()
	var mat := _fill_mat_ok if ok else _fill_mat_bad
	for child in _preview_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
	_preview_root.position = center
	_preview_root.rotation.y = yaw
	_preview_root.visible = true

func _rebuild_preview_steps() -> void:
	while _preview_root.get_child_count() > 0:
		var ch := _preview_root.get_child(0)
		_preview_root.remove_child(ch)
		ch.free()
	WorldStore.attach_stair_geom(_preview_root, stair_width, stair_length, stair_height, null, false)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if _dialog_open():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and valid:
			_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			exit_requested.emit()
			get_viewport().set_input_as_handled()

func _place() -> void:
	if not _preview_root.visible or not valid:
		return
	world.place_stair(_preview_center, stair_width, stair_length, stair_height, _preview_yaw, material_id)
	hud.set_status("已放置楼梯 %.1f×%.1f×%.1f m（%s）" % [
		stair_width, stair_length, stair_height, Config.material_label(material_id),
	])

func _update_hud() -> void:
	if not active:
		hud.set_tool_info("")
		return
	hud.set_tool_info("楼梯  宽:%.2f  长:%.2f  高:%.2f  材质:%s" % [
		stair_width, stair_length, stair_height, Config.material_label(material_id),
	])
	hud.set_status("放置：楼梯（单击落点，朝向正交就近轴向，F1 参数 / F3 材质）")

func get_placement_dims() -> Dictionary:
	return {"width": stair_width, "length": stair_length, "height": stair_height}

func apply_placement_dims(dims: Dictionary) -> void:
	stair_width = maxf(0.4, float(dims.get("width", stair_width)))
	stair_length = maxf(0.5, float(dims.get("length", stair_length)))
	stair_height = maxf(0.3, float(dims.get("height", stair_height)))
	_last_key = ""
	_update_hud()

func get_grid_origin() -> Variant:
	if not active or _preview_root == null or not _preview_root.visible:
		return null
	var yaw := _preview_yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var p := _preview_center - fwd * (stair_length * 0.5)
	return Vector3(p.x, 0.0, p.z)

func get_grid_extent() -> float:
	return clampf(maxf(stair_width, stair_length) * 2.0 + 4.5, 4.0, 12.0)
