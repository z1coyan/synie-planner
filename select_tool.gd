class_name SelectTool
extends Node3D

## 交互工具（快捷栏「无」）：准星点选已放置物体。
## 柱/墙/地板选中后由 ParamBar 提供 F1 工具参数 / F2 阵列 / F3 材质。
## 设备选中后仅快捷栏 F2 阵列。取消选中用右键或点空白。

const INTERACT_KINDS := ["wall", "column", "device", "floor_tile"]
const KIND_NAMES := {"wall": "墙体", "column": "柱子", "device": "设备", "floor_tile": "地板"}
const MATERIAL_KINDS := ["wall", "column", "floor_tile"]
const HL_NAME := "_SelectHL"
const HL_PAD_HOVER := 0.03
const HL_PAD_SELECTED := 0.05
const HL_EMISSION_HOVER := 1.0
const HL_EMISSION_SELECTED := 1.8
## 底边相对几何底面抬高：先抵消构件 EMBED 埋地，再高出支撑面约 1.6cm，
## 避免倒挤外壳底面被泥土/地面挡住。
const HL_BOTTOM_CLEAR := 0.016
const HL_EDGE_HOVER := 0.014
const HL_EDGE_SELECTED := 0.022

var world: WorldStore
var camera_rig: CameraController
var hud: Hud
var hotbar: Hotbar
var host: Node

var active := false
## hover | selected | array_dialog | array
var mode := "hover"

var _hover: StaticBody3D
var _hover_mis: Array = []
var _selected: StaticBody3D
var _selected_mis: Array = []

var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D

# array (2D on XZ; counts/spacing from panel; mouse only picks direction signs)
const ARRAY_COUNT_MAX := 40

var _array_panel: ArrayPanel
var _array_spacing_u := 0.0
var _array_spacing_v := 0.0
var _array_count_u := 1
var _array_count_v := 1
var _array_step_u := 0.0
var _array_step_v := 0.0
var _array_dir_u := Vector3.ZERO
var _array_dir_v := Vector3.ZERO
var _array_ghosts: Array = []
var _array_valids: Array = []
var _array_centers: Array = []

# snapshot for array place
var _array_kind := ""
var _array_size := Vector3.ZERO
var _array_color := Color.WHITE
var _array_yaw := 0.0
var _array_floor := 0
var _array_name := ""
var _array_material := ""

func setup(w: WorldStore, cc: CameraController, h: Hud, hb: Hotbar, main_host: Node = null) -> void:
	world = w
	camera_rig = cc
	hud = h
	hotbar = hb
	host = main_host
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_array_panel = ArrayPanel.new()
	_array_panel.name = "ArrayPanel"
	add_child(_array_panel)
	_array_panel.setup(camera_rig)
	if not _array_panel.confirmed.is_connected(_on_array_dialog_confirmed):
		_array_panel.confirmed.connect(_on_array_dialog_confirmed)
	if not _array_panel.cancelled.is_connected(_cancel_array):
		_array_panel.cancelled.connect(_cancel_array)
	if hotbar != null and not hotbar.action_chosen.is_connected(_on_hotbar_action):
		hotbar.action_chosen.connect(_on_hotbar_action)

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

func _make_outline_mat(emission_energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Config.COLOR_ACCENT
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = Config.COLOR_ACCENT
	m.emission_energy_multiplier = emission_energy
	return m

func set_active(a: bool) -> void:
	active = a
	cancel()
	if a:
		mode = "hover"
		_show_tool_bar()
		hud.set_status("交互：准星点选已放置物体（柱/墙/地板选中后用参数栏 F1/F2/F3）")
		hud.set_tool_info("")
		hud.set_length("")
	else:
		_show_tool_bar()

func cancel() -> void:
	_hide_array_panel()
	_clear_array_ghosts()
	_clear_hover()
	_clear_selected()
	mode = "hover"
	_array_spacing_u = 0.0
	_array_spacing_v = 0.0
	_array_count_u = 1
	_array_count_v = 1
	_show_tool_bar()
	_notify_host_param()

func wants_param_bar() -> bool:
	return mode == "selected" and is_instance_valid(_selected) \
			and MATERIAL_KINDS.has(String(_selected.get_meta("kind")))

func sync_param_bar(pb: ParamBar) -> void:
	if not wants_param_bar():
		pb.hide_bar()
		return
	var kind := String(_selected.get_meta("kind"))
	var mat := String(_selected.get_meta("material")) if _selected.has_meta("material") else Config.DEFAULT_MATERIAL
	pb.show_context("selection", kind, mat, true)

func apply_selected_material(mat: String) -> void:
	if not is_instance_valid(_selected):
		return
	world.set_body_material(_selected, mat)

func apply_selected_dims(dims: Dictionary) -> void:
	if not is_instance_valid(_selected):
		return
	world.set_body_dims(_selected, dims)
	# 尺寸变了，重建选中描边
	_clear_selected_highlight_only()
	_apply_highlight(_selected, HL_PAD_SELECTED, HL_EMISSION_SELECTED, _selected_mis)
	_update_hud()

func get_selected_logical_dims() -> Dictionary:
	if not is_instance_valid(_selected):
		return {}
	var kind := String(_selected.get_meta("kind"))
	var size: Vector3 = _selected.get_meta("size")
	match kind:
		"column":
			return {
				"height": size.y - Config.EMBED * 2.0,
				"thickness": size.x - Config.EMBED * 2.0,
			}
		"wall":
			return {
				"height": size.y - Config.EMBED,
				"thickness": size.z,
			}
		"floor_tile":
			return {"thickness": size.y - Config.EMBED}
		_:
			return {}

func get_selected_material() -> String:
	if not is_instance_valid(_selected):
		return Config.DEFAULT_MATERIAL
	if _selected.has_meta("material"):
		return Config.normalize_material(String(_selected.get_meta("material")))
	return Config.DEFAULT_MATERIAL

func begin_array_from_param() -> void:
	if mode == "selected":
		_begin_array()

func refresh_status_after_material() -> void:
	_update_hud()

func _notify_host_param() -> void:
	if host != null and host.has_method("sync_param_bar"):
		host.sync_param_bar()

func _show_tool_bar() -> void:
	if hotbar != null:
		hotbar.show_tools()

func _show_device_action_bar() -> void:
	if hotbar == null:
		return
	var title := "物体"
	if is_instance_valid(_selected):
		title = _kind_label(_selected)
	hotbar.show_actions(title, "")

func _clear_hover() -> void:
	for mi in _hover_mis:
		if is_instance_valid(mi):
			mi.queue_free()
	_hover_mis.clear()
	_hover = null

func _clear_selected() -> void:
	_clear_selected_highlight_only()
	_selected = null

func _clear_selected_highlight_only() -> void:
	for mi in _selected_mis:
		if is_instance_valid(mi):
			mi.queue_free()
	_selected_mis.clear()

func _apply_highlight(body: StaticBody3D, pad: float, emission: float, out: Array) -> void:
	# AABB 12 棱描边（非倒挤外壳）：底 4 棱抬到地面之上，薄板/埋地柱墙也能看见一圈底边。
	var edge := HL_EDGE_SELECTED if pad >= HL_PAD_SELECTED - 0.001 else HL_EDGE_HOVER
	var mat := _make_outline_mat(emission)
	for child in body.get_children():
		if String(child.name) == HL_NAME:
			continue
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var src: MeshInstance3D = child
			var root := Node3D.new()
			root.name = HL_NAME
			root.rotation = src.rotation
			root.position = src.position
			var size: Vector3 = (src.mesh as BoxMesh).size
			for spec in _outline_edge_specs(size, pad, edge):
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = spec[1]
				mi.mesh = bm
				mi.position = spec[0]
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
			body.add_child(root)
			out.append(root)


func _outline_edge_specs(size: Vector3, pad: float, edge: float) -> Array:
	var hx := size.x * 0.5 + pad * 0.5
	var hz := size.z * 0.5 + pad * 0.5
	var y_top := size.y * 0.5 + pad * 0.5
	var y_bot := -size.y * 0.5 + Config.EMBED + HL_BOTTOM_CLEAR
	if y_bot > y_top - edge:
		y_bot = y_top - edge
	var y_mid := (y_bot + y_top) * 0.5
	var h := maxf(y_top - y_bot, edge)
	var lx := hx * 2.0
	var lz := hz * 2.0
	return [
		[Vector3(0.0, y_bot, -hz), Vector3(lx, edge, edge)],
		[Vector3(0.0, y_bot, hz), Vector3(lx, edge, edge)],
		[Vector3(-hx, y_bot, 0.0), Vector3(edge, edge, lz)],
		[Vector3(hx, y_bot, 0.0), Vector3(edge, edge, lz)],
		[Vector3(0.0, y_top, -hz), Vector3(lx, edge, edge)],
		[Vector3(0.0, y_top, hz), Vector3(lx, edge, edge)],
		[Vector3(-hx, y_top, 0.0), Vector3(edge, edge, lz)],
		[Vector3(hx, y_top, 0.0), Vector3(edge, edge, lz)],
		[Vector3(-hx, y_mid, -hz), Vector3(edge, h, edge)],
		[Vector3(hx, y_mid, -hz), Vector3(edge, h, edge)],
		[Vector3(-hx, y_mid, hz), Vector3(edge, h, edge)],
		[Vector3(hx, y_mid, hz), Vector3(edge, h, edge)],
	]

func _is_interactable(body: Object) -> bool:
	return body != null and body is StaticBody3D and body.has_meta("kind") \
			and INTERACT_KINDS.has(body.get_meta("kind")) and (body as StaticBody3D).collision_layer != 0

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if host != null and host.has_method("is_any_dialog_open") and host.is_any_dialog_open():
		return
	match mode:
		"hover":
			_process_hover()
		"selected":
			_process_selected_aim()
		"array":
			_process_array()

func _aim_body() -> StaticBody3D:
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		return null
	var body: Object = aim.get("body")
	if _is_interactable(body):
		return body as StaticBody3D
	return null

func _process_hover() -> void:
	var target := _aim_body()
	if target != _hover:
		_clear_hover()
		_hover = target
		if _hover != null:
			_apply_highlight(_hover, HL_PAD_HOVER, HL_EMISSION_HOVER, _hover_mis)
	_update_hud()

func _process_selected_aim() -> void:
	var target := _aim_body()
	if target != null and target != _selected:
		if _hover != target:
			_clear_hover()
			_hover = target
			_apply_highlight(_hover, HL_PAD_HOVER, HL_EMISSION_HOVER, _hover_mis)
	else:
		if _hover != null:
			_clear_hover()
	_update_hud()

func _kind_label(body: StaticBody3D) -> String:
	var kind_name: String = KIND_NAMES.get(body.get_meta("kind"), "物体")
	if body.has_meta("name"):
		kind_name += "（%s）" % body.get_meta("name")
	return kind_name

func _update_hud() -> void:
	match mode:
		"hover":
			if _hover == null:
				hud.set_status("交互：准星点选已放置物体（柱/墙/地板选中后用参数栏）")
				hud.set_tool_info("")
				hud.set_length("")
			else:
				var size: Vector3 = _hover.get_meta("size")
				hud.set_status("交互：准星点选已放置物体（柱/墙/地板选中后用参数栏）")
				hud.set_tool_info("%s   %.1f×%.1f×%.1f m" % [
					_kind_label(_hover), size.x, size.y, size.z,
				])
				hud.set_length("左键选中")
		"selected":
			if not is_instance_valid(_selected):
				return
			var size2: Vector3 = _selected.get_meta("size")
			var kind := String(_selected.get_meta("kind"))
			if MATERIAL_KINDS.has(kind):
				hud.set_status("已选中：%s — F1 参数 / F2 阵列 / F3 材质" % _kind_label(_selected))
				hud.set_length("F1 参数 · F2 阵列 · F3 材质 · 右键取消选中")
			else:
				hud.set_status("已选中：%s — F2 阵列" % _kind_label(_selected))
				hud.set_length("F2 阵列 · 右键取消选中")
			hud.set_tool_info("%s   %.1f×%.1f×%.1f m" % [
				_kind_label(_selected), size2.x, size2.y, size2.z,
			])
		"array_dialog":
			hud.set_status("填写阵列参数")
			if is_instance_valid(_selected):
				hud.set_tool_info("原点：%s" % _kind_label(_selected))
			else:
				hud.set_tool_info("")
			hud.set_length("确认后准星定方向 · Esc/取消 关闭")
		"array":
			hud.set_status("阵列放置：%d×%d  间距 U %.2f / V %.2fm（准星定方向）" % [
				_array_count_u, _array_count_v, _array_spacing_u, _array_spacing_v,
			])
			if is_instance_valid(_selected):
				hud.set_tool_info("原点：%s" % _kind_label(_selected))
			hud.set_length("左键放置 · 右键取消")

func _select_body(body: StaticBody3D) -> void:
	_clear_hover()
	_clear_selected()
	_selected = body
	_apply_highlight(_selected, HL_PAD_SELECTED, HL_EMISSION_SELECTED, _selected_mis)
	mode = "selected"
	var kind := String(body.get_meta("kind"))
	if MATERIAL_KINDS.has(kind):
		_show_tool_bar()
	else:
		_show_device_action_bar()
	_notify_host_param()
	_update_hud()

func _deselect() -> void:
	_clear_hover()
	_clear_selected()
	mode = "hover"
	_show_tool_bar()
	_notify_host_param()
	_update_hud()

func _ignore_kinds(kind: String) -> Array:
	match kind:
		"column":
			return ["wall", "floor_tile"]
		"wall":
			return ["wall", "column", "floor_tile"]
		"floor_tile":
			return ["wall", "column"]
		_:
			return []

func _check_clear(center: Vector3, size: Vector3, yaw: float, kind: String, exclude: Array) -> bool:
	var ignore := _ignore_kinds(kind)
	if kind == "wall":
		var bs := BoxShape3D.new()
		bs.size = size
		return world.shape_clear(bs, Transform3D(Basis(Vector3.UP, yaw), center), Config.CLEARANCE, exclude, ignore)
	var aabb := AABB(center - size * 0.5, size).grow(Config.CLEARANCE)
	return world.aabb_clear(aabb, Config.CLEARANCE, exclude, ignore)

func _hide_array_panel() -> void:
	if _array_panel != null:
		_array_panel.hide_dialog()

func _begin_array() -> void:
	if not is_instance_valid(_selected):
		return
	mode = "array_dialog"
	_array_spacing_u = 0.0
	_array_spacing_v = 0.0
	_array_count_u = 1
	_array_count_v = 1
	_array_step_u = 0.0
	_array_step_v = 0.0
	_array_dir_u = Vector3.ZERO
	_array_dir_v = Vector3.ZERO
	_clear_hover()
	_clear_array_ghosts()
	if _array_panel != null:
		_array_panel.reset_defaults()
		_array_panel.show_dialog()
	_notify_host_param()
	_update_hud()

func _on_array_dialog_confirmed() -> void:
	if not is_instance_valid(_selected):
		_cancel_array()
		return
	if _array_panel != null:
		_array_count_u = clampi(_array_panel.get_count_u(), 1, ARRAY_COUNT_MAX)
		_array_count_v = clampi(_array_panel.get_count_v(), 1, ARRAY_COUNT_MAX)
		_array_spacing_u = maxf(0.0, _array_panel.get_spacing_u())
		_array_spacing_v = maxf(0.0, _array_panel.get_spacing_v())
		_array_panel.hide_dialog()
	mode = "array"
	if camera_rig != null:
		camera_rig.apply_mouse_mode()
	_notify_host_param()
	_update_hud()

func _cancel_array() -> void:
	_hide_array_panel()
	_clear_array_ghosts()
	_array_spacing_u = 0.0
	_array_spacing_v = 0.0
	_array_count_u = 1
	_array_count_v = 1
	if is_instance_valid(_selected):
		mode = "selected"
		var kind := String(_selected.get_meta("kind"))
		if MATERIAL_KINDS.has(kind):
			_show_tool_bar()
		else:
			_show_device_action_bar()
	else:
		mode = "hover"
		_show_tool_bar()
	_notify_host_param()
	_update_hud()

func _clear_array_ghosts() -> void:
	for g in _array_ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_array_ghosts.clear()
	_array_valids.clear()
	_array_centers.clear()

func _ensure_ghosts(n: int, size: Vector3) -> void:
	while _array_ghosts.size() < n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.visible = false
		add_child(mi)
		_array_ghosts.append(mi)
	for i in _array_ghosts.size():
		var mi2: MeshInstance3D = _array_ghosts[i]
		if i < n:
			if mi2.mesh == null or not (mi2.mesh as BoxMesh).size.is_equal_approx(size):
				var bm2 := BoxMesh.new()
				bm2.size = size
				mi2.mesh = bm2
			mi2.visible = true
		else:
			mi2.visible = false

func _process_array() -> void:
	if not is_instance_valid(_selected):
		_cancel_array()
		return
	var origin: Vector3 = _selected.global_position
	var size: Vector3 = _selected.get_meta("size")
	var kind: String = _selected.get_meta("kind")
	var yaw: float = float(_selected.get_meta("yaw")) if _selected.has_meta("yaw") else 0.0
	var dir_u: Vector3
	var dir_v: Vector3
	var foot_u: float
	var foot_v: float
	if kind == "wall":
		dir_u = Vector3(cos(yaw), 0.0, -sin(yaw))
		dir_v = Vector3(-dir_u.z, 0.0, dir_u.x)
		foot_u = size.x if size.x >= 0.001 else Config.GRID
		foot_v = size.z if size.z >= 0.001 else Config.GRID
	else:
		dir_u = Vector3(1.0, 0.0, 0.0)
		dir_v = Vector3(0.0, 0.0, 1.0)
		foot_u = size.x if size.x >= 0.001 else Config.GRID
		foot_v = size.z if size.z >= 0.001 else Config.GRID
	_array_step_u = foot_u + _array_spacing_u
	_array_step_v = foot_v + _array_spacing_v
	if _array_step_u < 0.001:
		_array_step_u = Config.GRID
	if _array_step_v < 0.001:
		_array_step_v = Config.GRID
	var aim := world.aim_surface(camera_rig)
	if not aim.is_empty():
		var point: Vector3 = aim["point"]
		var dx := point.x - origin.x
		var dz := point.z - origin.z
		var proj_u := dx * dir_u.x + dz * dir_u.z
		var proj_v := dx * dir_v.x + dz * dir_v.z
		var sgn_u := 1.0 if proj_u >= 0.0 else -1.0
		var sgn_v := 1.0 if proj_v >= 0.0 else -1.0
		_array_dir_u = dir_u * sgn_u
		_array_dir_v = dir_v * sgn_v
	else:
		if _array_dir_u == Vector3.ZERO:
			_array_dir_u = dir_u
		if _array_dir_v == Vector3.ZERO:
			_array_dir_v = dir_v
	var ghost_n := _array_count_u * _array_count_v - 1
	_ensure_ghosts(ghost_n, size)
	_array_valids.clear()
	_array_centers.clear()
	var exclude: Array = [_selected]
	var color: Color = _selected.get_meta("color")
	var floor_i: int = int(_selected.get_meta("floor")) if _selected.has_meta("floor") else 0
	var name_s: String = String(_selected.get_meta("name")) if _selected.has_meta("name") else ""
	var mat_s := String(_selected.get_meta("material")) if _selected.has_meta("material") else ""
	_array_kind = kind
	_array_size = size
	_array_color = color
	_array_yaw = yaw
	_array_floor = floor_i
	_array_name = name_s
	_array_material = mat_s
	var gi := 0
	for j in _array_count_v:
		for i in _array_count_u:
			if i == 0 and j == 0:
				continue
			var center: Vector3 = (
				origin
				+ _array_dir_u * (_array_step_u * float(i))
				+ _array_dir_v * (_array_step_v * float(j))
			)
			center.y = origin.y
			var ok := _check_clear(center, size, yaw, kind, exclude)
			_array_centers.append(center)
			_array_valids.append(ok)
			var mi: MeshInstance3D = _array_ghosts[gi]
			mi.position = center
			mi.rotation.y = yaw
			mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
			gi += 1
	_update_hud()

func _confirm_array() -> void:
	if _array_centers.is_empty():
		return
	var placed_n := 0
	for i in _array_centers.size():
		if not _array_valids[i]:
			continue
		world.place_box(
			_array_centers[i], _array_size, _array_color, _array_kind,
			_array_yaw, _array_floor, _array_name, _array_material)
		placed_n += 1
	_hide_array_panel()
	_clear_array_ghosts()
	_array_spacing_u = 0.0
	_array_spacing_v = 0.0
	_array_count_u = 1
	_array_count_v = 1
	if is_instance_valid(_selected):
		mode = "selected"
		var kind := String(_selected.get_meta("kind"))
		if MATERIAL_KINDS.has(kind):
			_show_tool_bar()
		else:
			_show_device_action_bar()
	else:
		mode = "hover"
		_show_tool_bar()
	_notify_host_param()
	hud.set_status("阵列已放置 %d 个" % placed_n)
	_update_hud()

func _on_hotbar_action(action_id: String) -> void:
	if not active:
		return
	match action_id:
		"array":
			if mode == "selected":
				_begin_array()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if host != null and host.has_method("is_any_dialog_open") and host.is_any_dialog_open():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pass
		return
	if get_viewport().gui_get_focus_owner() != null and mode != "array_dialog":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)
	elif event is InputEventMouseButton and event.pressed:
		_on_mouse(event as InputEventMouseButton)

func _on_key(event: InputEventKey) -> void:
	# 设备选中时 F2 走快捷栏；柱墙地板 F1/F2/F3 由 ParamBar 处理
	if mode == "selected" and is_instance_valid(_selected):
		var kind := String(_selected.get_meta("kind"))
		if kind == "device" and event.keycode == KEY_F2:
			_on_hotbar_action("array")
			get_viewport().set_input_as_handled()

func _on_mouse(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		match mode:
			"hover":
				var body := _aim_body()
				if body != null:
					_select_body(body)
					get_viewport().set_input_as_handled()
			"selected":
				var body2 := _aim_body()
				if body2 == null:
					_deselect()
				elif body2 != _selected:
					_select_body(body2)
				get_viewport().set_input_as_handled()
			"array_dialog":
				get_viewport().set_input_as_handled()
			"array":
				_confirm_array()
				get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		match mode:
			"selected":
				_deselect()
				get_viewport().set_input_as_handled()
			"array_dialog", "array":
				_cancel_array()
				get_viewport().set_input_as_handled()
