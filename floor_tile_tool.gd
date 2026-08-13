class_name FloorTileTool
extends Node3D

## 地板工具：两段式点击。点击起点（点1）、移动鼠标预览、点击终点（点2），
## 铺设两点间的矩形地板（单块，任意尺寸，与画墙一致）。
## 端点磁吸柱子 / 墙体顶面四角 / 其他地板 / 楼梯顶踏四角，便于对齐拼接（无全局网格吸附）。
## 吸到墙顶角时地板顶面与墙顶齐平，该角即为地板矩形顶点（含墙厚，非墙中心线）。
## 起点必须在地面、已有地板或墙柱表面；墙体/柱子不阻挡（地板从其下方铺过），
## 不与其他地板做碰撞检测；重叠或共边且同标高的地板合并为一块。绿=可放 / 红=与设备重叠，右键取消笔画或退出工具。

signal exit_requested

var world: WorldStore
var camera_rig: CameraController
var hud: Hud

var material_id := Config.DEFAULT_MATERIAL
var floor_thickness := Config.FLOOR_THICKNESS
var host: Node

var active := false
var valid := false

var _drawing := false
var _start := Vector3.ZERO      # 起点（XZ，Y=0）
var _end := Vector3.ZERO        # 终点（XZ，Y=0）
var _base_y := Config.FLOOR_TOP_OFFSET
var _place_rect: Dictionary = {}  # 预览通过的待铺矩形（含边缘外推回退结果）

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _wire_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

var _start_marker: MeshInstance3D
var _hover_marker: MeshInstance3D

func setup(w: WorldStore, cc: CameraController, h: Hud, main_host: Node = null) -> void:
	world = w
	camera_rig = cc
	hud = h
	host = main_host
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = Node3D.new()
	_preview_root.name = "FloorTilePreview"
	_preview_root.visible = false
	add_child(_preview_root)
	_fill_mi = MeshInstance3D.new()
	_wire_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)
	_preview_root.add_child(_wire_mi)
	_start_marker = _make_marker(Config.COLOR_ACCENT)
	_hover_marker = _make_marker(Config.COLOR_PATH)

func _make_marker(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	bm.material = m
	mi.mesh = bm
	mi.visible = false
	add_child(mi)
	return mi

func _holo_mat(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = base
	m.emission_enabled = true
	var e := base
	e.a = 1.0
	m.emission = e
	return m

func set_active(a: bool) -> void:
	active = a
	_cancel_drawing()
	_hover_marker.visible = false
	if not a:
		return
	hud.set_status("地板：点击起点、再点击终点铺设（当前：%s，F1 参数 / F3 材质），右键取消" % Config.material_label(material_id))
	_update_hud()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if _dialog_open():
		_hover_marker.visible = false
		_preview_root.visible = false
		return
	# 点1 前的悬停标记：显示端点落点（含角点磁吸后的位置）
	var p: Variant = _aim_point()
	if p == null:
		_hover_marker.visible = false
		if not _drawing:
			_preview_root.visible = false
			valid = false
			hud.set_length("仅可放在地面或地板边缘")
			return
	else:
		_hover_marker.position = Vector3(p.x, _mark_y(p), p.z)
		_hover_marker.visible = true
	if not _drawing:
		_preview_root.visible = false
		valid = p != null
		if p != null:
			hud.set_length("点击确定起点")
		return
	# 已确定起点：更新终点与矩形预览
	_start_marker.position = Vector3(_start.x, _mark_y(_start), _start.z)
	_start_marker.visible = true
	if p != null:
		_end = p
	_update_rect_preview()

## 标记悬浮高度：略高于当前铺设标高（地面或墙顶/梯顶），避免与地板面穿插。
func _mark_y(p: Vector3 = Vector3.ZERO) -> float:
	if _drawing:
		return _base_y + 0.11
	if p.y > Config.FLOOR_TOP_OFFSET + 0.05:
		return p.y + 0.11
	return Config.FLOOR_TOP_OFFSET + 0.11

## 由当前瞄准点计算端点：地面 / 地板 / 墙 / 柱表面 → 角点磁吸（无网格）；其它 → null。
func _aim_point() -> Variant:
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		return null
	var body: Object = aim.get("body")
	if body == world.ground_body:
		return _snap_point(aim["point"])
	if body != null and body.has_meta("kind") \
			and ["floor_tile", "wall", "column", "stair"].has(body.get_meta("kind")):
		return _snap_point(aim["point"])
	return null

## 先在原始点附近磁吸柱子 / 墙顶四角 / 地板 / 楼梯顶四角；找不到则用原始 XZ。
## 墙/楼梯角点保留顶面世界 Y，供铺板对齐墙顶标高。
func _snap_point(p: Vector3) -> Vector3:
	var hit := world.pick_snap_corner(p, ["column", "wall", "floor_tile", "stair"], Config.SNAP_TO_CORNER)
	if hit.is_empty():
		return Vector3(p.x, 0.0, p.z)
	var kind := String(hit["kind"])
	var c: Vector3 = hit["point"]
	if kind == "stair":
		return c
	if kind == "wall":
		# 瞄到墙顶附近才带上墙顶 Y；地面铺板只吸 XZ，避免墙角把一层地板抬到墙顶。
		if p.y >= c.y - 1.0:
			return c
		return Vector3(c.x, 0.0, c.z)
	return Vector3(c.x, 0.0, c.z)

func _is_elevated() -> bool:
	return _base_y > Config.FLOOR_TOP_OFFSET + 0.05

## 起点若吸到墙顶/梯顶角，铺板顶面与该标高齐平；否则沿用瞄准表面（已有地板/楼梯顶）。
func _elevation_for_start(p: Vector3) -> float:
	if p.y > Config.FLOOR_TOP_OFFSET + 0.05:
		return p.y
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		return Config.FLOOR_TOP_OFFSET
	var body: Object = aim.get("body")
	if body == null or not body.has_meta("kind"):
		return Config.FLOOR_TOP_OFFSET
	var k: String = body.get_meta("kind")
	if k == "stair" or k == "floor_tile":
		return world.top_surface_y(body)
	if k == "wall":
		var top := world.top_surface_y(body)
		if float(aim["point"].y) >= top - 1.0:
			return top
	return Config.FLOOR_TOP_OFFSET

## 地板矩形：水平方向四周外扩 EMBED、底部下沉 EMBED（顶面标高不变）。
## 侧边埋入相邻地板/墙体、底面埋入地面，相交面互相穿过而非共面，消除闪烁。
## 边缘若停在墙/柱 footprint 附近，先收进构件体内（_extend_edges），
## 使墙/柱侧面遮住地板边——既无根部凹槽，也无外凸沿口。
func _rect() -> Dictionary:
	var min_x: float = minf(_start.x, _end.x)
	var max_x: float = maxf(_start.x, _end.x)
	var min_z: float = minf(_start.z, _end.z)
	var max_z: float = maxf(_start.z, _end.z)
	# 墙顶铺板：顶点必须落在墙顶外角，不再把边收进墙厚带。
	if not _is_elevated():
		var ex := _extend_edges(min_x, max_x, min_z, max_z)
		min_x = ex[0]
		max_x = ex[1]
		min_z = ex[2]
		max_z = ex[3]
	var h := floor_thickness + Config.EMBED
	return {
		"size": Vector3(max_x - min_x + Config.EMBED * 2.0, h, max_z - min_z + Config.EMBED * 2.0),
		"center": Vector3((min_x + max_x) * 0.5,
			_base_y + h * 0.5 - Config.EMBED,
			(min_z + max_z) * 0.5),
	}

## 矩形边停在墙/柱 footprint（厚度带）内或贴近其侧面（≤2×EMBED，含角点吸附
## 恰好在侧面的情况）时，把该边收进构件体内：最终地板边埋在最浅那个构件的
## 侧面内侧 EMBED 处——侧面遮住地板边，无凹槽、无凸沿、不共面。
## 多个构件（如柱贴墙）对同一边给出不同收边目标时，取移动量最小的，
## 避免被深层构件推过浅层构件的侧面形成凸沿。仅处理近轴对齐的墙；斜墙跳过。
func _extend_edges(min_x: float, max_x: float, min_z: float, max_z: float) -> Array:
	var m := Config.EMBED * 2.0
	# 收边目标：min 边取各带 smin+m 的最大值，max 边取各带 smax-m 的最小值
	var pull_min_x := -INF
	var pull_max_x := INF
	var pull_min_z := -INF
	var pull_max_z := INF
	for obj in world.placed:
		if not obj.has_meta("kind"):
			continue
		var kind: String = obj.get_meta("kind")
		if kind != "wall" and kind != "column":
			continue
		var c: Vector3 = obj.global_position
		var size: Vector3 = obj.get_meta("size")
		var yaw: float = obj.get_meta("yaw")
		if kind == "column":
			var hx: float = size.x * 0.5
			var hz: float = size.z * 0.5
			# x 厚度带：z 向需与柱 footprint 重叠
			if max_z >= c.z - hz and min_z <= c.z + hz:
				if min_x >= c.x - hx - m and min_x <= c.x + hx + m:
					pull_min_x = maxf(pull_min_x, c.x - hx + m)
				if max_x >= c.x - hx - m and max_x <= c.x + hx + m:
					pull_max_x = minf(pull_max_x, c.x + hx - m)
			# z 厚度带：x 向需与柱 footprint 重叠
			if max_x >= c.x - hx and min_x <= c.x + hx:
				if min_z >= c.z - hz - m and min_z <= c.z + hz + m:
					pull_min_z = maxf(pull_min_z, c.z - hz + m)
				if max_z >= c.z - hz - m and max_z <= c.z + hz + m:
					pull_max_z = minf(pull_max_z, c.z + hz - m)
		else:
			var half_t: float = size.z * 0.5
			var half_l: float = size.x * 0.5
			if absf(cos(yaw)) >= absf(sin(yaw)):
				# 墙沿 x 走向：厚度在 z，收 z 边；x 向需与墙段跨度重叠
				if max_x >= c.x - half_l and min_x <= c.x + half_l:
					if min_z >= c.z - half_t - m and min_z <= c.z + half_t + m:
						pull_min_z = maxf(pull_min_z, c.z - half_t + m)
					if max_z >= c.z - half_t - m and max_z <= c.z + half_t + m:
						pull_max_z = minf(pull_max_z, c.z + half_t - m)
			else:
				# 墙沿 z 走向：厚度在 x，收 x 边；z 向需与墙段跨度重叠
				if max_z >= c.z - half_l and min_z <= c.z + half_l:
					if min_x >= c.x - half_t - m and min_x <= c.x + half_t + m:
						pull_min_x = maxf(pull_min_x, c.x - half_t + m)
					if max_x >= c.x - half_t - m and max_x <= c.x + half_t + m:
						pull_max_x = minf(pull_max_x, c.x + half_t - m)
	if pull_min_x > -INF:
		min_x = pull_min_x
	if pull_max_x < INF:
		max_x = pull_max_x
	if pull_min_z > -INF:
		min_z = pull_min_z
	if pull_max_z < INF:
		max_z = pull_max_z
	# 异常保护：收边后矩形翻面则放弃该轴收边（保持原始范围）
	if min_x >= max_x:
		min_x = minf(_start.x, _end.x)
		max_x = maxf(_start.x, _end.x)
	if min_z >= max_z:
		min_z = minf(_start.z, _end.z)
		max_z = maxf(_start.z, _end.z)
	return [min_x, max_x, min_z, max_z]

## 矩形的名义尺寸（不含 EMBED 外扩），用于显示与退化判断。
func _nominal_size(size: Vector3) -> Vector3:
	return Vector3(size.x - Config.EMBED * 2.0, size.y, size.z - Config.EMBED * 2.0)

func _update_rect_preview() -> void:
	var r := _rect()
	var size: Vector3 = r["size"]
	var nom := _nominal_size(size)
	if nom.x < Config.GRID or nom.z < Config.GRID:
		# 退化矩形（长或宽不足一格）
		_preview_root.visible = false
		_place_rect = {}
		valid = false
		hud.set_length("矩形过小")
		return
	valid = _rect_free(r["center"], size)
	_place_rect = r if valid else {}
	_show_preview(r["center"], size, valid)
	hud.set_length("地板 %.1f×%.1f m：%s" % [nom.x, nom.z, "可铺设" if valid else "与设备重叠"])

## 候选矩形是否无干涉。水平方向内缩（EMBED 外扩 + 1cm）。
## 墙体 / 柱子 / 楼梯 / 地板不参与干涉（地板可从墙柱下方铺过，地板之间合并而非互斥），仅与设备互斥。
func _rect_free(center: Vector3, size: Vector3) -> bool:
	var shrink := Config.EMBED * 2.0 + 0.01
	var test := Vector3(size.x - shrink, size.y, size.z - shrink)
	return world.aabb_clear(AABB(center - test * 0.5, test), 0.0, [], ["wall", "column", "stair", "floor_tile"])

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

func _dialog_open() -> bool:
	return host != null and host.has_method("is_any_dialog_open") and host.is_any_dialog_open()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if _dialog_open():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _drawing:
			# 点1：起点必须在地面 / 地板 / 墙柱表面
			var p: Variant = _aim_point()
			if p != null:
				_drawing = true
				_start = p
				_end = p
				_base_y = _elevation_for_start(p)
				_last_size = Vector3.ZERO
				_update_rect_preview()
			else:
				hud.set_status("起点无效：仅可从地面或已有地板边缘起铺")
		else:
			# 点2：确认铺设
			_place()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _drawing:
			_cancel_drawing()
			hud.set_status("已取消铺设")
		else:
			exit_requested.emit()
		get_viewport().set_input_as_handled()

func _cancel_drawing() -> void:
	_drawing = false
	valid = false
	_place_rect = {}
	_base_y = Config.FLOOR_TOP_OFFSET
	_preview_root.visible = false
	_start_marker.visible = false
	hud.set_length("")

## 点2 确认：铺设预览通过的矩形（单块，含边缘外推结果）。
func _place() -> void:
	if not valid or not _preview_root.visible or _place_rect.is_empty():
		_cancel_drawing()
		hud.set_status("区域无效（过小或与设备重叠），未铺设")
		return
	var r: Dictionary = _place_rect
	var color := Config.material_color(material_id)
	var n0: int = world.placed.size()
	world.place_box(r["center"], r["size"], color, "floor_tile", 0.0, 0, "", material_id)
	var nom := _nominal_size(r["size"])
	var merged := world.placed.size() <= n0
	_cancel_drawing()
	if merged:
		hud.set_status("已铺设%s地板 %.1f×%.1f m，并与相邻地板合并" % [Config.material_label(material_id), nom.x, nom.z])
	else:
		hud.set_status("已铺设%s地板 %.1f×%.1f m" % [Config.material_label(material_id), nom.x, nom.z])

func _update_hud() -> void:
	hud.set_tool_info("地板：两点矩形 · 厚 %.2f m · 材质 %s · F1 参数 / F3 材质" % [
		floor_thickness, Config.material_label(material_id),
	])

func refresh_material_hud() -> void:
	_update_hud()

func get_placement_dims() -> Dictionary:
	return {"thickness": floor_thickness}

func apply_placement_dims(dims: Dictionary) -> void:
	floor_thickness = maxf(0.1, float(dims.get("thickness", floor_thickness)))
	_last_size = Vector3.ZERO
	_update_hud()

## 放置网格脚点：跟随当前光标/终点。无效时返回 null。
func get_grid_origin() -> Variant:
	if not active or _hover_marker == null or not _hover_marker.visible:
		return null
	var p := _hover_marker.position
	return Vector3(p.x, 0.0, p.z)

func get_grid_extent() -> float:
	return 6.5
