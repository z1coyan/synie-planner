class_name OpeningTool
extends PlacementToolBase

## 门洞 / 窗洞：瞄准墙面预览开洞矩形，单击切割。F1 改下次开洞默认尺寸。右键退回「无」。

var opening_type := "door"
var width := Config.DOOR_WIDTH
var height := Config.DOOR_HEIGHT
var sill := Config.DOOR_SILL

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

var _valid := false
var _clamped := false
var _target: StaticBody3D
var _place_u := 0.0
var _place_width := 0.0
var _place_height := 0.0
var _place_sill := 0.0

func setup(w: WorldStore, cc: CameraController, h: Hud, main_host: Node, p_type: String) -> void:
	world = w
	camera_rig = cc
	hud = h
	host = main_host
	opening_type = "window" if p_type == "window" else "door"
	if opening_type == "window":
		width = Config.WINDOW_WIDTH
		height = Config.WINDOW_HEIGHT
		sill = Config.WINDOW_SILL
	else:
		width = Config.DOOR_WIDTH
		height = Config.DOOR_HEIGHT
		sill = Config.DOOR_SILL
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = _make_preview_root("OpeningPreview")
	_fill_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)

func type_label() -> String:
	return "窗洞" if opening_type == "window" else "门洞"

func set_active(a: bool) -> void:
	active = a
	_valid = false
	_clamped = false
	_target = null
	if not a:
		_preview_root.visible = false
		return
	_update_hud()

## 参数变更后的 HUD 刷新（开洞无材质，参数即尺寸）。
func refresh_param_hud() -> void:
	_update_hud()

## 外部兼容：原 refresh_hud 入口保留，转发到 refresh_param_hud。
func refresh_hud() -> void:
	refresh_param_hud()

## 开洞无材质：材质 id 恒为空。
func get_material_id() -> String:
	return ""

## 开洞无材质：忽略材质写入。
func set_material_id(_m: String) -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if _dialog_open():
		_preview_root.visible = false
		_valid = false
		return
	var aim := world.aim_surface(camera_rig)
	if aim.is_empty():
		_show_invalid("请瞄准墙体开%s" % type_label())
		return
	var body: Object = aim.get("body")
	if body == null or not (body is StaticBody3D):
		_show_invalid("请瞄准墙体开%s" % type_label())
		return
	var wall: StaticBody3D = body
	if not wall.has_meta("kind") or String(wall.get_meta("kind")) != "wall":
		_show_invalid("请瞄准墙体开%s" % type_label())
		return
	if wall.collision_layer == 0:
		_show_invalid("请瞄准墙体开%s" % type_label())
		return
	var prep := world.prepare_wall_opening(
		wall, opening_type, width, height, _effective_sill(), aim["point"])
	if prep.is_empty() or not bool(prep.get("ok", false)):
		_show_invalid("无法在此墙开%s" % type_label())
		return
	_target = wall
	_place_u = float(prep["u"])
	_place_width = float(prep["width"])
	_place_height = float(prep["height"])
	_place_sill = float(prep["sill"])
	_clamped = bool(prep.get("clamped", false))
	_valid = true
	var box := world.opening_world_box(wall, {
		"type": opening_type,
		"width": _place_width,
		"height": _place_height,
		"sill": _place_sill,
		"u": _place_u,
	})
	_show_preview(box["center"], box["size"], float(box["yaw"]), true)
	_update_hud()

func _effective_sill() -> float:
	return 0.0 if opening_type == "door" else sill

func _show_invalid(status: String) -> void:
	_preview_root.visible = false
	_valid = false
	_clamped = false
	_target = null
	hud.set_status(status)
	_update_hud_dims()
	hud.set_length("")

func _show_preview(center: Vector3, size: Vector3, yaw: float, ok: bool) -> void:
	if not size.is_equal_approx(_last_size):
		_last_size = size
		var bm := BoxMesh.new()
		bm.size = size
		_fill_mi.mesh = bm
	_fill_mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
	_preview_root.position = center
	_preview_root.rotation.y = yaw
	_preview_root.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if _dialog_open():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			exit_requested.emit()
			get_viewport().set_input_as_handled()

func _on_left_click() -> void:
	if not _valid or _target == null or not is_instance_valid(_target):
		return
	var r := world.add_wall_opening(
		_target, opening_type, _place_width, _place_height, _place_sill, _place_u)
	if not bool(r.get("ok", false)):
		hud.set_status("无法开%s：洞口过大或墙体将被掏空" % type_label())
		return
	var extra := "（已钳制在墙体内）" if bool(r.get("clamped", false)) or _clamped else ""
	hud.set_status("已开%s  %.2f×%.2f m%s" % [type_label(), _place_width, _place_height, extra])

func _update_hud() -> void:
	if not active:
		hud.set_tool_info("")
		return
	_update_hud_dims()
	if _valid:
		if _clamped:
			hud.set_status("%s：瞄准墙面单击开洞（已钳制在墙体内，F1 参数）" % type_label())
			hud.set_length("已钳制 · 左键开洞 · 右键取消")
		else:
			hud.set_status("%s：瞄准墙面单击开洞（F1 参数），右键取消" % type_label())
			hud.set_length("左键开洞 · 右键取消")
	else:
		hud.set_status("请瞄准墙体开%s（F1 参数）" % type_label())

func _update_hud_dims() -> void:
	if opening_type == "window":
		hud.set_tool_info("%s  宽:%.2f  高:%.2f  窗台:%.2f m   F1 参数" % [
			type_label(), width, height, sill,
		])
	else:
		hud.set_tool_info("%s  宽:%.2f  高:%.2f m   F1 参数" % [
			type_label(), width, height,
		])

func get_placement_dims() -> Dictionary:
	if opening_type == "window":
		return {"width": width, "height": height, "sill": sill}
	return {"width": width, "height": height, "sill": 0.0}

func apply_placement_dims(dims: Dictionary) -> void:
	width = maxf(Config.OPENING_MIN, float(dims.get("width", width)))
	height = maxf(Config.OPENING_MIN, float(dims.get("height", height)))
	if opening_type == "window":
		sill = maxf(0.0, float(dims.get("sill", sill)))
	else:
		sill = 0.0
	_last_size = Vector3.ZERO
	_update_hud()

func get_grid_origin() -> Variant:
	if not active or _preview_root == null or not _preview_root.visible:
		return null
	var p := _preview_root.position
	return Vector3(p.x, 0.0, p.z)

func get_grid_extent() -> float:
	return 6.5
