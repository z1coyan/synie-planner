class_name FloorOpeningTool
extends PlacementToolBase

## 地板开洞：瞄准地板预览矩形洞口，单击切割。洞口可吸附地板/已有地洞/墙顶/梯顶角点。
## F1 改下次开洞默认尺寸。右键退回「无」。

var hole_width := Config.FLOOR_HOLE_WIDTH
var hole_length := Config.FLOOR_HOLE_LENGTH

var _preview_root: Node3D
var _fill_mi: MeshInstance3D
var _fill_mat_ok: StandardMaterial3D
var _fill_mat_bad: StandardMaterial3D
var _last_size := Vector3.ZERO

var _valid := false
var _clamped := false
var _target: StaticBody3D
var _place_x0 := 0.0
var _place_x1 := 0.0
var _place_z0 := 0.0
var _place_z1 := 0.0

func setup(w: WorldStore, cc: CameraController, h: Hud, main_host: Node) -> void:
	world = w
	camera_rig = cc
	hud = h
	host = main_host
	_fill_mat_ok = _holo_mat(Config.COLOR_OK)
	_fill_mat_bad = _holo_mat(Config.COLOR_BAD)
	_preview_root = _make_preview_root("FloorOpeningPreview")
	_fill_mi = MeshInstance3D.new()
	_preview_root.add_child(_fill_mi)

func set_active(a: bool) -> void:
	active = a
	_valid = false
	_clamped = false
	_target = null
	if not a:
		_preview_root.visible = false
		return
	_update_hud()

## 参数变更后的 HUD 刷新（地洞无材质，参数即尺寸）。
func refresh_param_hud() -> void:
	_update_hud()

## 外部兼容：原 refresh_hud 入口保留，转发到 refresh_param_hud。
func refresh_hud() -> void:
	refresh_param_hud()

## 地洞无材质：材质 id 恒为空。
func get_material_id() -> String:
	return ""

## 地洞无材质：忽略材质写入。
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
		_show_invalid("请瞄准地板开地洞")
		return
	var body: Object = aim.get("body")
	if body == null or not (body is StaticBody3D):
		_show_invalid("请瞄准地板开地洞")
		return
	var floor_body: StaticBody3D = body
	if not floor_body.has_meta("kind") or String(floor_body.get_meta("kind")) != "floor_tile":
		_show_invalid("请瞄准地板开地洞")
		return
	if floor_body.collision_layer == 0:
		_show_invalid("请瞄准地板开地洞")
		return
	var prep := world.prepare_floor_opening(
		floor_body, aim["point"], hole_width, hole_length)
	if prep.is_empty() or not bool(prep.get("ok", false)):
		_show_invalid("无法在此开地洞（洞口过大或将掏空地板）")
		return
	_target = floor_body
	_place_x0 = float(prep["x0"])
	_place_x1 = float(prep["x1"])
	_place_z0 = float(prep["z0"])
	_place_z1 = float(prep["z1"])
	_clamped = bool(prep.get("clamped", false))
	_valid = true
	_show_preview(prep["center"], prep["size"], true)
	_update_hud()

func _show_invalid(status: String) -> void:
	_preview_root.visible = false
	_valid = false
	_clamped = false
	_target = null
	hud.set_status(status)
	_update_hud_dims()
	hud.set_length("")

func _show_preview(center: Vector3, size: Vector3, ok: bool) -> void:
	if not size.is_equal_approx(_last_size):
		_last_size = size
		var bm := BoxMesh.new()
		bm.size = size
		_fill_mi.mesh = bm
	_fill_mi.material_override = _fill_mat_ok if ok else _fill_mat_bad
	_preview_root.position = center
	_preview_root.rotation.y = 0.0
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
	var r := world.add_floor_opening(_target, _place_x0, _place_x1, _place_z0, _place_z1)
	if not bool(r.get("ok", false)):
		hud.set_status("无法开地洞：洞口过大或地板将被掏空")
		return
	var extra := "（已钳制在地板内）" if bool(r.get("clamped", false)) or _clamped else ""
	hud.set_status("已开地洞  %.2f×%.2f m%s" % [
		_place_x1 - _place_x0, _place_z1 - _place_z0, extra,
	])

func _update_hud() -> void:
	if not active:
		hud.set_tool_info("")
		return
	_update_hud_dims()
	if _valid:
		if _clamped:
			hud.set_status("地洞：瞄准地板单击开洞（已钳制在地板内，F1 参数）")
			hud.set_length("已钳制 · 左键开洞 · 右键取消")
		else:
			hud.set_status("地洞：瞄准地板单击开洞（角点吸附，F1 参数），右键取消")
			hud.set_length("左键开洞 · 右键取消")
	else:
		hud.set_status("请瞄准地板开地洞（F1 参数）")

func _update_hud_dims() -> void:
	hud.set_tool_info("地洞  横向:%.2f  纵向:%.2f m   F1 参数" % [hole_width, hole_length])

func get_placement_dims() -> Dictionary:
	return {"width": hole_width, "length": hole_length}

func apply_placement_dims(dims: Dictionary) -> void:
	hole_width = maxf(Config.OPENING_MIN, float(dims.get("width", hole_width)))
	hole_length = maxf(Config.OPENING_MIN, float(dims.get("length", hole_length)))
	_last_size = Vector3.ZERO
	_update_hud()

func get_grid_origin() -> Variant:
	if not active or _preview_root == null or not _preview_root.visible:
		return null
	var p := _preview_root.position
	return Vector3(p.x, 0.0, p.z)

func get_grid_extent() -> float:
	return 6.5
