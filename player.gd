class_name Player
extends CharacterBody3D

## 玩家角色：Quaternius CC0 人形、行走/奔跑/跳跃，以及退出飞行后的重力坠落。
## 相机朝向与 F 飞行开关由 CameraController 负责；本节点负责身体与位移。

const COLLISION_LAYER := 4
const HEAD_LAYER := 2
const SKIN_SCENE := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
const ANIM_BLEND := 0.12

var camera_rig: CameraController
var hud: Hud
var host: Node

var _model: Node3D
var _skin: Node3D
var _anim: AnimationPlayer
var _anim_clip := ""
var _clip_idle := ""
var _clip_walk := ""
var _clip_run := ""
var _clip_air := ""
var _was_flying := false
var _jump_queued := false
## 离地时记住的水平速度，跳跃/滞空沿用，避免被行走速度覆盖
var _air_speed := 0.0

func setup(main_host: Node) -> void:
	host = main_host
	collision_layer = COLLISION_LAYER
	collision_mask = 1
	floor_snap_length = 0.2
	up_direction = Vector3.UP
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_build_collision()
	_build_model()
	camera_rig = CameraController.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.host = host
	camera_rig.setup()
	camera_rig.process_physics_priority = 10
	global_position = Vector3(0.0, Config.FLOOR_TOP_OFFSET + 0.04, 10.0)

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = Config.PLAYER_RADIUS
	cap.height = Config.PLAYER_HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, Config.PLAYER_HEIGHT * 0.5, 0.0)
	add_child(cs)

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var packed := load(SKIN_SCENE) as PackedScene
	if packed == null:
		push_error("Player: 缺少人形场景 %s" % SKIN_SCENE)
		return
	_skin = packed.instantiate() as Node3D
	if _skin == null:
		push_error("Player: 人形场景实例化失败")
		return
	_skin.name = "Skin"
	_model.add_child(_skin)
	_fit_skin_to_capsule()
	_apply_mesh_cull_layers(_skin)
	_anim = _skin.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_clip_idle = _resolve_clip(["Idle"])
		_clip_walk = _resolve_clip(["Walk"])
		_clip_run = _resolve_clip(["Sprint", "Jog_Fwd", "Run"])
		_clip_air = _resolve_clip(["Jump", "Jump_Start"])
		if _clip_idle != "":
			_play_clip(_clip_idle)

func _fit_skin_to_capsule() -> void:
	if _skin == null:
		return
	var aabb := _collect_mesh_aabb(_skin)
	if aabb.size.y < 0.2:
		return
	var s := Config.PLAYER_HEIGHT / aabb.size.y
	_skin.scale = Vector3(s, s, s)
	_skin.position.y = -aabb.position.y * s

func _collect_mesh_aabb(root: Node) -> AABB:
	var acc := AABB()
	var started := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.get_aabb()
		var xf := mi.global_transform
		for i in 8:
			var world_pt := xf * local.get_endpoint(i)
			var local_pt := to_local(world_pt)
			if not started:
				acc = AABB(local_pt, Vector3.ZERO)
				started = true
			else:
				acc = acc.expand(local_pt)
	return acc

func _apply_mesh_cull_layers(root: Node) -> void:
	# 整个人形放到 HEAD_LAYER：第一人称相机剔除，避免镜头穿颅；俯视 Tab 显示全身
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null:
			mi.layers = HEAD_LAYER

func _resolve_clip(keys: PackedStringArray) -> String:
	if _anim == null:
		return ""
	var names := _anim.get_animation_list()
	for key in keys:
		if _anim.has_animation(key):
			return key
		var libkey := "UAL1_Standard/%s" % key
		if _anim.has_animation(libkey):
			return libkey
	var low_keys: PackedStringArray = []
	for key in keys:
		low_keys.append(key.to_lower())
	for n in names:
		var low := n.to_lower()
		for key in low_keys:
			if low.ends_with("/" + key) or low == key:
				return n
	return ""

func _play_clip(clip: String) -> void:
	if _anim == null or clip == "" or clip == _anim_clip:
		return
	if not _anim.has_animation(clip):
		return
	_anim.play(clip, ANIM_BLEND)
	_anim_clip = clip

func _update_facing() -> void:
	if _model == null or camera_rig == null:
		return
	if camera_rig.is_top_down():
		var hx := velocity.x
		var hz := velocity.z
		if (hx * hx + hz * hz) > 0.04:
			_model.rotation.y = atan2(-hx, -hz)
	else:
		_model.rotation.y = camera_rig.yaw

func _update_anim() -> void:
	if _anim == null:
		return
	var clip := _clip_idle
	var flying := camera_rig != null and camera_rig.flying
	if flying or not is_on_floor():
		clip = _clip_air if _clip_air != "" else _clip_idle
	else:
		var spd := Vector2(velocity.x, velocity.z).length()
		if spd < 0.35:
			clip = _clip_idle
		elif spd >= Config.RUN_SPEED * 0.8:
			clip = _clip_run if _clip_run != "" else _clip_walk
		else:
			clip = _clip_walk if _clip_walk != "" else _clip_idle
	if clip != "":
		_play_clip(clip)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if _is_blocked():
				return
			_jump_queued = true

func _is_blocked() -> bool:
	if camera_rig != null and camera_rig.is_input_blocked():
		return true
	return false

func _move_axis() -> Vector3:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		mv.z += 1.0
	if Input.is_key_pressed(KEY_S):
		mv.z -= 1.0
	if Input.is_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		mv.x += 1.0
	return mv

func _ground_speed() -> float:
	if camera_rig != null and camera_rig.is_top_down():
		return Config.TOP_DOWN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		return Config.RUN_SPEED
	return Config.WALK_SPEED

func _sync_fly_state() -> void:
	var flying := camera_rig != null and camera_rig.flying
	if flying == _was_flying:
		return
	_was_flying = flying
	velocity = Vector3.ZERO
	if flying:
		collision_mask = 0
		floor_snap_length = 0.0
		if hud != null:
			hud.set_status("飞行：空格上升 · Ctrl/C 下降 · 再按 F 关闭并重力坠落")
	else:
		collision_mask = 1
		floor_snap_length = 0.2
		if hud != null:
			hud.set_status("已关闭飞行：保持当前高度，重力坠落至落地")

func _physics_process(delta: float) -> void:
	if camera_rig == null:
		return
	_sync_fly_state()
	var blocked := _is_blocked()
	if camera_rig.flying:
		_fly_move(delta, blocked)
		_jump_queued = false
	else:
		_ground_move(delta, blocked)
	_update_facing()
	_update_anim()

func _fly_move(delta: float, blocked: bool) -> void:
	if blocked:
		return
	var mv := _move_axis()
	var vel := CameraController.fp_velocity(mv, camera_rig.yaw)
	if Input.is_key_pressed(KEY_SPACE):
		vel.y += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		vel.y -= 1.0
	var speed := Config.FLY_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed = Config.RUN_SPEED * 1.35
	if vel.length_squared() > 0.001:
		global_position += vel.normalized() * speed * delta
	global_position.y = clampf(global_position.y, 0.1, Config.TOP_DOWN_MAX)

func _ground_move(delta: float, blocked: bool) -> void:
	var g := get_gravity()
	if not is_on_floor():
		velocity += g * delta
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.2
		if velocity.y < 0.0:
			velocity.y = 0.0
	var jumping := false
	if _jump_queued and not blocked and is_on_floor() and not camera_rig.flying:
		var gy := absf(g.y)
		if gy < 0.01:
			gy = Config.GRAVITY
		velocity.y = sqrt(2.0 * gy * Config.JUMP_HEIGHT)
		jumping = true
		floor_snap_length = 0.0
	_jump_queued = false
	if blocked:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var mv := _move_axis()
	var wish := Vector3.ZERO
	if camera_rig.is_top_down():
		wish = Vector3(mv.x, 0.0, -mv.z)
	else:
		wish = CameraController.fp_velocity(mv, camera_rig.yaw)
	if wish.length_squared() > 0.001:
		wish = wish.normalized()
	else:
		wish = Vector3.ZERO
	# 起跳当帧 is_on_floor 仍为 true，不得按地面逻辑重写 xz，否则跑步初速被行走速度盖掉
	if is_on_floor() and not jumping:
		var speed := _ground_speed()
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		_air_speed = Vector2(velocity.x, velocity.z).length()
	else:
		var spd := _air_speed
		if not camera_rig.is_top_down() and Input.is_key_pressed(KEY_SHIFT):
			spd = maxf(spd, Config.RUN_SPEED)
		if wish.length_squared() > 0.001:
			if spd < 0.01:
				spd = _ground_speed() * Config.AIR_CONTROL
			var keep := maxf(spd, Vector2(velocity.x, velocity.z).length())
			var target := wish * keep
			velocity.x = lerpf(velocity.x, target.x, 0.18)
			velocity.z = lerpf(velocity.z, target.z, 0.18)
	move_and_slide()
