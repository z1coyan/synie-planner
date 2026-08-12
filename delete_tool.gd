class_name DeleteTool
extends Node3D

## 拆除工具：X 键进入。左键点选墙体/柱子/设备/地板立即删除；
## 在空白处按住左键拖拽出矩形框，松开批量删除框内物体（框选过程实时橙色高亮 + 计数）。
## 右键 / X / 0 退出工具。不可见（无碰撞层）的物体不参与点选与框选。

signal exit_requested

const DELETABLE_KINDS := ["wall", "column", "device", "floor_tile"]
const KIND_NAMES := {"wall": "墙体", "column": "柱子", "device": "设备", "floor_tile": "地板"}

var world: WorldStore
var camera_rig: CameraController
var hud: Hud

var active := false

var _hover: StaticBody3D
var _hover_mis: Array = []
var _hl_mat: StandardMaterial3D

var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_mis: Array = []
var _marquee_layer: CanvasLayer
var _marquee: MarqueeRect

func setup(w: WorldStore, cc: CameraController, h: Hud) -> void:
	world = w
	camera_rig = cc
	hud = h
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hl_mat.albedo_color = Color(0.96, 0.42, 0.15, 0.55)
	_hl_mat.emission_enabled = true
	_hl_mat.emission = Color(0.96, 0.42, 0.15, 1.0)
	_marquee_layer = CanvasLayer.new()
	_marquee_layer.layer = 55
	add_child(_marquee_layer)
	_marquee = MarqueeRect.new()
	_marquee.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.visible = false
	_marquee_layer.add_child(_marquee)

func set_active(a: bool) -> void:
	active = a
	cancel()
	if a:
		hud.set_status("拆除：左键点删 / 按住左键拖拽框选批量删除（右键 / X 退出）")

## 清除悬停高亮与框选状态（切楼层、切工具时调用）
func cancel() -> void:
	_clear_hover()
	_cancel_drag()

func _clear_hover() -> void:
	for mi in _hover_mis:
		if is_instance_valid(mi):
			mi.material_override = null
	_hover_mis.clear()
	_hover = null

func _cancel_drag() -> void:
	_dragging = false
	_marquee.visible = false
	_clear_drag_highlight()

func _clear_drag_highlight() -> void:
	for mi in _drag_mis:
		if is_instance_valid(mi):
			mi.material_override = null
	_drag_mis.clear()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if _dragging:
		_update_marquee()
		return
	var aim := world.aim_surface(camera_rig)
	var target: StaticBody3D = null
	if not aim.is_empty():
		var body: Object = aim.get("body")
		if body != null and body is StaticBody3D and body.has_meta("kind") \
				and DELETABLE_KINDS.has(body.get_meta("kind")) and body.collision_layer != 0:
			target = body
	if target != _hover:
		_clear_hover()
		_hover = target
		if _hover != null:
			_apply_highlight(_hover, _hover_mis)
	_update_hud()

func _apply_highlight(body: StaticBody3D, out: Array) -> void:
	for child in body.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			child.material_override = _hl_mat
			out.append(child)

func _update_hud() -> void:
	if _hover == null:
		hud.set_tool_info("")
		hud.set_length("")
		return
	var size: Vector3 = _hover.get_meta("size")
	var kind_name: String = KIND_NAMES.get(_hover.get_meta("kind"), "物体")
	hud.set_tool_info("目标: %s%s   %.1f×%.1f×%.1f m" % [
		kind_name,
		"（%s）" % _hover.get_meta("name") if _hover.has_meta("name") else "",
		size.x, size.y, size.z,
	])
	hud.set_length("左键删除")

func _drag_rect() -> Rect2:
	var cur := get_viewport().get_mouse_position()
	return Rect2(_drag_start, cur - _drag_start).abs()

## 屏幕矩形内的可删物体（仅当前可见、有碰撞层的物体）
func _marquee_victims(rect: Rect2) -> Array:
	var cam: Camera3D = camera_rig.camera
	var victims: Array = []
	for obj in world.placed:
		if obj.collision_layer == 0:
			continue
		if not obj.has_meta("kind") or not DELETABLE_KINDS.has(obj.get_meta("kind")):
			continue
		var pos: Vector3 = obj.global_position
		if cam.is_position_behind(pos):
			continue
		if rect.has_point(cam.unproject_position(pos)):
			victims.append(obj)
	return victims

func _update_marquee() -> void:
	var rect := _drag_rect()
	_marquee.rect = rect
	_marquee.visible = true
	_marquee.queue_redraw()
	_clear_drag_highlight()
	var victims := _marquee_victims(rect)
	for v in victims:
		_apply_highlight(v, _drag_mis)
	hud.set_tool_info("框选: %d 个物体" % victims.size())
	hud.set_length("松开左键删除")

func _finish_drag() -> void:
	var victims := _marquee_victims(_drag_rect())
	_cancel_drag()
	_clear_hover()
	for v in victims:
		world.remove(v)
	if victims.is_empty():
		hud.set_status("框选为空，未删除任何物体")
	else:
		hud.set_status("已批量删除 %d 个物体" % victims.size())
	hud.set_tool_info("")
	hud.set_length("")

func _delete_hover() -> void:
	var body := _hover
	_clear_hover()
	var kind_name: String = KIND_NAMES.get(body.get_meta("kind"), "物体")
	if body.has_meta("name"):
		kind_name += "（%s）" % body.get_meta("name")
	world.remove(body)
	hud.set_status("已删除：%s" % kind_name)
	hud.set_tool_info("")
	hud.set_length("")

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			exit_requested.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _hover != null:
					_delete_hover()
				else:
					_dragging = true
					_drag_start = event.position
					_clear_hover()
				get_viewport().set_input_as_handled()
			elif _dragging:
				_finish_drag()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _dragging:
				_cancel_drag()
				hud.set_tool_info("")
				hud.set_length("")
			else:
				exit_requested.emit()
			get_viewport().set_input_as_handled()

class MarqueeRect:
	extends Control

	## 框选矩形：半透明橙填充 + 橙色描边。

	var rect := Rect2()

	func _draw() -> void:
		if rect.size.x < 2.0 and rect.size.y < 2.0:
			return
		draw_rect(rect, Color(0.96, 0.60, 0.15, 0.12), true)
		draw_rect(rect, Color(0.96, 0.60, 0.15, 0.9), false, 1.5)
