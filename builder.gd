class_name Builder
extends PlacementToolBase

## 柱子 / 设备放置：全息预览跟随鼠标准星（无全局网格吸附；柱子可磁吸墙中心线），
## R 键旋转 90°，绿=可放，红=干涉。设备尺寸/颜色取自元素库。
## 右键退出放置，经 exit_requested 切回工具「无」。

var library: ElementLibrary

var tool := "none"          # "none" | "column" | "device"
var rot_steps := 0           # 0..3 → 旋转 0/90/180/270°
var col_size_index := 0      # 柱子截面预设下标（Config.COLUMN_SIZES），E 键快速切换
var column_height := Config.COLUMN_HEIGHT
var column_thickness := Config.COLUMN_WIDTH
var valid := false

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _wire_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

func setup(w: WorldStore, cc: CameraController, h: Hud, lib: ElementLibrary, main_host: Node = null) -> void:
	world = w
	camera_rig = cc
	hud = h
	library = lib
	host = main_host
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = _make_preview_root("PlacementPreview")
	_fill_mi = MeshInstance3D.new()
	_wire_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)
	_preview_root.add_child(_wire_mi)

func refresh_device() -> void:
	_last_size = Vector3.ZERO
	_update_hud()

func refresh_material_hud() -> void:
	_update_hud()

func set_tool(t: String) -> void:
	tool = t
	rot_steps = 0
	_last_size = Vector3.ZERO
	if tool == "none":
		_preview_root.visible = false
	_update_hud()

func _current_size() -> Vector3:
	var s: Vector3
	if tool == "column":
		# 截面与高度均外扩 EMBED：柱顶高出墙面、柱侧穿出墙面，杜绝与墙共面
		var w: float = column_thickness + Config.EMBED * 2.0
		s = Vector3(w, column_height + Config.EMBED * 2.0, w)
	else:
		s = library.current_device()["size"]
	if rot_steps % 2 == 1:
		s = Vector3(s.z, s.y, s.x)
	return s

func _current_color() -> Color:
	if tool == "column":
		return Config.material_color(material_id)
	return library.current_device()["color"]

func _current_name() -> String:
	if tool == "column":
		return ""
	return String(library.current_device()["name"])

func _physics_process(_delta: float) -> void:
	if tool == "none":
		return
	if _dialog_open():
		_preview_root.visible = false
		return
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_preview_root.visible = false
		return
	var size := _current_size()
	var point: Vector3 = aim["point"]
	var xz := Vector3(point.x, 0.0, point.z)
	if tool == "column":
		# 柱子磁吸到附近墙的中心线，使柱嵌入墙内、消除接缝
		xz = world.snap_to_wall(xz, Config.SNAP_TO_WALL)
	var center := Vector3(xz.x, aim["surface_y"] + size.y * 0.5, xz.z)
	if tool == "column":
		# 柱底下沉 EMBED 埋入支撑面（顶面仍高出墙面 EMBED），底面不与支撑面共面
		center.y -= Config.EMBED
	var aabb := AABB(center - size * 0.5, size).grow(Config.CLEARANCE)
	# 柱子允许与墙体、地板相交（嵌入），设备仍检测全部干涉
	var ignore: Array = ["wall", "floor_tile"] if tool == "column" else []
	valid = world.aabb_clear(aabb, Config.CLEARANCE, [], ignore)
	_show_preview(center, size, valid)
	_update_hud()

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
	if get_viewport().gui_get_focus_owner() != null:
		return
	if _dialog_open():
		return
	if event is InputEventKey and event.pressed and tool != "none":
		if event.keycode == KEY_E and tool == "column":
			col_size_index = (col_size_index + 1) % Config.COLUMN_SIZES.size()
			column_thickness = float(Config.COLUMN_SIZES[col_size_index])
			_last_size = Vector3.ZERO
			_update_hud()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			rot_steps = (rot_steps + 1) % 4
			_last_size = Vector3.ZERO
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and tool != "none" and valid:
			_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and tool != "none":
			exit_requested.emit()
			get_viewport().set_input_as_handled()

func _place() -> void:
	if not _preview_root.visible:
		return
	var size := _current_size()
	if tool == "column":
		world.place_box(_preview_root.position, size, _current_color(), tool, 0.0, 0, "", material_id)
	else:
		world.place_box(_preview_root.position, size, _current_color(), tool, 0.0, 0, _current_name())

func _update_hud() -> void:
	var name_map := {"none": "无", "column": "柱子", "device": "设备"}
	if tool == "none":
		hud.set_tool_info("")
		return
	if tool == "column":
		var label := "柱子  高:%.1f 粗:%.2f  旋转:%d°  材质:%s" % [
			column_height, column_thickness, rot_steps * 90,
			Config.material_label(material_id),
		]
		hud.set_tool_info(label)
		hud.set_status("放置：柱子（F1 参数 / F3 材质，R 旋转，E 切粗细预设）")
		return
	var label2 := "%s  旋转:%d°  尺寸:%.1f×%.1f×%.1f m" % [
		_current_name(),
		rot_steps * 90, _current_size().x, _current_size().y, _current_size().z,
	]
	hud.set_tool_info(label2)
	hud.set_status("放置：%s（绿色可放 / 红色干涉，R 旋转）" % _current_name())

func get_placement_dims() -> Dictionary:
	return {"height": column_height, "thickness": column_thickness}

func apply_placement_dims(dims: Dictionary) -> void:
	column_height = float(dims.get("height", column_height))
	column_thickness = float(dims.get("thickness", column_thickness))
	# 同步最近预设下标（仅用于 E 键循环起点）
	var best_i := 0
	var best_d := absf(column_thickness - float(Config.COLUMN_SIZES[0]))
	for i in Config.COLUMN_SIZES.size():
		var d := absf(column_thickness - float(Config.COLUMN_SIZES[i]))
		if d < best_d:
			best_d = d
			best_i = i
	col_size_index = best_i
	_last_size = Vector3.ZERO
	_update_hud()

## 放置网格脚点（预览底面 XZ）。无效时返回 null。
func get_grid_origin() -> Variant:
	if tool == "none" or _preview_root == null or not _preview_root.visible:
		return null
	var p := _preview_root.position
	return Vector3(p.x, 0.0, p.z)

func get_grid_extent() -> float:
	var s := _current_size()
	return clampf(maxf(s.x, s.z) * 2.5 + 4.5, 4.0, 10.0)
