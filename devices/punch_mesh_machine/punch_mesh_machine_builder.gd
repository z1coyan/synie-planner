class_name PunchMeshMachineBuilder
extends RefCounted

## 精密高速冲网机：全部用 BoxMesh / CylinderMesh / Label3D 在代码里搭出来。
## 返回的 StaticBody3D 原点在完整 footprint AABB 中心；前脸 / 白臂朝 +Z，控制台在 +X。

const P := preload("res://devices/punch_mesh_machine/punch_mesh_machine_params.gd")


static func build() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "PunchMeshMachine"
	body.collision_layer = 1
	body.collision_mask = 0
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)

	var mats := {
		"body": _mat(P.COLOR_BODY, 0.86, 0.02),
		"inner": _mat(P.COLOR_BODY_INNER, 0.88, 0.02),
		"blue": _mat(P.COLOR_BLUE, 0.48, 0.08),
		"yellow": _mat(P.COLOR_YELLOW, 0.52, 0.04),
		"die": _mat(P.COLOR_DIE, 0.42, 0.35),
		"slot": _mat(P.COLOR_SLOT, 0.55, 0.20),
		"motor": _mat(P.COLOR_MOTOR, 0.38, 0.45),
		"arm": _mat(P.COLOR_ARM, 0.72, 0.04),
		"estop": _mat(P.COLOR_ESTOP, 0.35, 0.05),
		"screen": _mat(P.COLOR_SCREEN, 0.22, 0.10),
		"rail": _mat(P.COLOR_RAIL, 0.28, 0.70),
		"cable": _mat(P.COLOR_CABLE, 0.70, 0.02),
		"bolt": _mat(P.COLOR_BOLT, 0.40, 0.50),
		"door": _mat(P.COLOR_DOOR, 0.80, 0.02),
		"warn_red": _mat(P.COLOR_WARN_RED, 0.50, 0.04),
	}

	var fp := P.FOOTPRINT
	var cab := P.CABINET
	var con := P.CONSOLE
	var y_bot := -fp.y * 0.5
	var z_back := -fp.z * 0.5
	var x_left := -fp.x * 0.5

	var cab_c := Vector3(x_left + cab.x * 0.5, 0.0, z_back + cab.z * 0.5)
	var cab_front := cab_c.z + cab.z * 0.5
	var con_c := Vector3(
		x_left + cab.x + P.CONSOLE_GAP + con.x * 0.5,
		y_bot + con.y * 0.5,
		cab_front - con.z * 0.5,
	)

	_add_cabinet(visuals, mats, cab, cab_c, cab_front, y_bot)
	_add_punch_zone(visuals, mats, cab, cab_c, cab_front, y_bot)
	_add_branding(visuals, mats, cab, cab_c, cab_front, y_bot)
	_add_warning(visuals, mats, cab, cab_c, y_bot)
	var motor_at := _add_arms(visuals, mats, cab, cab_c, cab_front, y_bot)
	_add_console(visuals, mats, con, con_c, y_bot)
	_add_cables(visuals, mats, motor_at, con_c)
	_add_collision(body, cab, cab_c, con, con_c, cab_front, y_bot)
	# 透明 footprint 盒：给选中高亮一个整体轮廓，避免对每个零件描边
	var foot := MeshInstance3D.new()
	foot.name = "Footprint"
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = fp
	var foot_mat := StandardMaterial3D.new()
	foot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foot_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	foot_mesh.material = foot_mat
	foot.mesh = foot_mesh
	foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(foot)
	return body


static func _add_cabinet(
		body: Node3D, mats: Dictionary, cab: Vector3, cab_c: Vector3,
		cab_front: float, y_bot: float) -> void:
	var skin := 0.05
	var side_w := 0.22
	var header_h := 0.58
	var sill_h := 0.40
	var recess_d := 0.50
	var recess_w := cab.x - side_w * 2.0
	var recess_h := cab.y - header_h - sill_h
	var z_back := cab_c.z - cab.z * 0.5

	# 底板 / 顶板 / 背板
	_box(body, Vector3(cab.x, 0.10, cab.z), Vector3(cab_c.x, y_bot + 0.05, cab_c.z), mats["body"])
	_box(body, Vector3(cab.x, 0.06, cab.z), Vector3(cab_c.x, y_bot + cab.y - 0.03, cab_c.z), mats["body"])
	_box(body, Vector3(cab.x, cab.y, 0.06), Vector3(cab_c.x, cab_c.y, z_back + 0.03), mats["body"])

	# 左右侧板（整高）
	var left_x := cab_c.x - cab.x * 0.5 + side_w * 0.5
	var right_x := cab_c.x + cab.x * 0.5 - side_w * 0.5
	_box(body, Vector3(side_w, cab.y, cab.z), Vector3(left_x, cab_c.y, cab_c.z), mats["body"])
	_box(body, Vector3(side_w, cab.y, cab.z), Vector3(right_x, cab_c.y, cab_c.z), mats["body"])

	# 前脸：开口四周
	var header_y := y_bot + cab.y - header_h * 0.5
	var sill_y := y_bot + sill_h * 0.5
	_box(body, Vector3(cab.x, header_h, skin), Vector3(cab_c.x, header_y, cab_front - skin * 0.5), mats["body"])
	_box(body, Vector3(cab.x, sill_h, skin), Vector3(cab_c.x, sill_y, cab_front - skin * 0.5), mats["body"])

	# 凹腔后壁与顶/底内衬
	var recess_back_z := cab_front - recess_d
	var recess_mid_y := y_bot + sill_h + recess_h * 0.5
	_box(body, Vector3(recess_w, recess_h, 0.04), Vector3(cab_c.x, recess_mid_y, recess_back_z + 0.02), mats["inner"])
	_box(body, Vector3(recess_w, 0.03, recess_d), Vector3(cab_c.x, y_bot + sill_h + 0.015, cab_front - recess_d * 0.5), mats["inner"])
	_box(body, Vector3(recess_w, 0.03, recess_d), Vector3(cab_c.x, y_bot + sill_h + recess_h - 0.015, cab_front - recess_d * 0.5), mats["inner"])

	# 左右内衬
	var inner_side := 0.04
	_box(body, Vector3(inner_side, recess_h, recess_d), Vector3(
		cab_c.x - recess_w * 0.5 + inner_side * 0.5, recess_mid_y, cab_front - recess_d * 0.5), mats["inner"])
	_box(body, Vector3(inner_side, recess_h, recess_d), Vector3(
		cab_c.x + recess_w * 0.5 - inner_side * 0.5, recess_mid_y, cab_front - recess_d * 0.5), mats["inner"])

	# 下部踢脚暗条
	_box(body, Vector3(cab.x + 0.01, 0.08, 0.02), Vector3(cab_c.x, y_bot + 0.12, cab_front + 0.005), mats["bolt"])


static func _add_punch_zone(
		body: Node3D, mats: Dictionary, cab: Vector3, cab_c: Vector3,
		cab_front: float, y_bot: float) -> void:
	var side_w := 0.22
	var header_h := 0.58
	var sill_h := 0.40
	var recess_w := cab.x - side_w * 2.0
	var recess_h := cab.y - header_h - sill_h
	var bar_h := 0.09
	var bar_d := 0.14
	var bar_y := y_bot + sill_h + recess_h - 0.16
	var bar_z := cab_front - 0.22
	var bar_size := Vector3(recess_w - 0.10, bar_h, bar_d)
	_box(body, bar_size, Vector3(cab_c.x, bar_y, bar_z), mats["yellow"])

	# 压紧梁螺栓
	for i in 5:
		var t := (float(i) / 4.0) - 0.5
		var bx := cab_c.x + t * (bar_size.x - 0.18)
		_cyl(body, Vector3(bx, bar_y, bar_z + bar_d * 0.5 + 0.008), 0.016, 0.012, mats["bolt"], Vector3(PI * 0.5, 0.0, 0.0))

	# 下模：厚钢板 + 竖槽
	var die_h := 0.16
	var die_d := 0.18
	var die_y := bar_y - 0.28
	var die_z := cab_front - 0.24
	var die_w := recess_w - 0.16
	_box(body, Vector3(die_w, die_h, die_d), Vector3(cab_c.x, die_y, die_z), mats["die"])
	var slot_n := 11
	var slot_w := 0.028
	var span := die_w - 0.16
	for i in slot_n:
		var t := 0.0 if slot_n == 1 else float(i) / float(slot_n - 1)
		var sx := cab_c.x - span * 0.5 + span * t
		_box(body, Vector3(slot_w, die_h * 0.82, 0.03), Vector3(sx, die_y, die_z + die_d * 0.5 - 0.01), mats["slot"])

	# 凹腔内两侧导轨
	var rail_h := recess_h - 0.08
	var rail_y := y_bot + sill_h + recess_h * 0.5
	_box(body, Vector3(0.03, rail_h, 0.03), Vector3(cab_c.x - recess_w * 0.5 + 0.07, rail_y, cab_front - 0.18), mats["rail"])
	_box(body, Vector3(0.03, rail_h, 0.03), Vector3(cab_c.x + recess_w * 0.5 - 0.07, rail_y, cab_front - 0.18), mats["rail"])


static func _add_branding(
		body: Node3D, mats: Dictionary, cab: Vector3, cab_c: Vector3,
		cab_front: float, y_bot: float) -> void:
	var plate_size := Vector3(1.28, 0.42, 0.02)
	var plate_pos := Vector3(cab_c.x, y_bot + cab.y - 0.32, cab_front + 0.008)
	_box(body, plate_size, plate_pos, mats["blue"])
	_label(body, P.BRAND, plate_pos + Vector3(0.0, 0.11, 0.018), 52, Color(0.95, 0.97, 1.0), 0.0020)
	_label(body, P.FULL_NAME, plate_pos + Vector3(0.0, 0.01, 0.018), 28, Color(0.88, 0.92, 1.0), 0.0016)
	_label(body, P.PHONE, plate_pos + Vector3(0.0, -0.12, 0.018), 26, P.COLOR_PHONE, 0.0016)


static func _add_warning(
		body: Node3D, mats: Dictionary, cab: Vector3, cab_c: Vector3, y_bot: float) -> void:
	var x := cab_c.x - cab.x * 0.5 - 0.008
	var pos := Vector3(x, y_bot + cab.y - 0.42, cab_c.z)
	_box(body, Vector3(0.012, 0.18, 0.26), pos, mats["yellow"])
	_box(body, Vector3(0.013, 0.045, 0.26), pos + Vector3(-0.002, 0.068, 0.0), mats["warn_red"])
	var l := _label(body, "WARNING", pos + Vector3(-0.010, 0.068, 0.0), 18, Color(1.0, 1.0, 1.0), 0.0014)
	l.rotation.y = -PI * 0.5
	var icon := _label(body, "▲ 注意", pos + Vector3(-0.010, -0.02, 0.0), 16, Color(0.12, 0.12, 0.12), 0.0014)
	icon.rotation.y = -PI * 0.5


static func _add_arms(
		body: Node3D, mats: Dictionary, cab: Vector3, cab_c: Vector3,
		cab_front: float, y_bot: float) -> Vector3:
	var arm_w := 0.07
	var arm_h := 0.08
	var arm_len := P.ARM_EXTENT
	var arm_y := y_bot + 0.52
	var inset := 0.28
	var left_x := cab_c.x - cab.x * 0.5 + inset
	var right_x := cab_c.x + cab.x * 0.5 - inset
	var arm_z := cab_front + arm_len * 0.5
	_box(body, Vector3(arm_w, arm_h, arm_len), Vector3(left_x, arm_y, arm_z), mats["arm"])
	_box(body, Vector3(arm_w, arm_h, arm_len), Vector3(right_x, arm_y, arm_z), mats["arm"])

	# 末端横杆
	var rod_z := cab_front + arm_len - 0.04
	var rod_span := right_x - left_x
	_cyl(body, Vector3(cab_c.x, arm_y, rod_z), rod_span, 0.016, mats["rail"], Vector3(0.0, 0.0, PI * 0.5))

	# 右臂电机 + 直角减速机
	var motor_x := right_x + 0.02
	var motor_z := rod_z - 0.04
	var motor_y := arm_y + 0.10
	_cyl(body, Vector3(motor_x, motor_y, motor_z), 0.22, 0.072, mats["motor"], Vector3(0.0, 0.0, PI * 0.5))
	_cyl(body, Vector3(motor_x - 0.10, motor_y, motor_z), 0.02, 0.082, mats["bolt"], Vector3(0.0, 0.0, PI * 0.5))
	_cyl(body, Vector3(motor_x + 0.10, motor_y, motor_z), 0.02, 0.082, mats["bolt"], Vector3(0.0, 0.0, PI * 0.5))
	var gb_pos := Vector3(right_x - 0.04, arm_y + 0.07, motor_z + 0.02)
	_box(body, Vector3(0.16, 0.14, 0.16), gb_pos, mats["blue"])
	_box(body, Vector3(0.10, 0.06, 0.10), Vector3(gb_pos.x, arm_y - 0.02, gb_pos.z), mats["arm"])
	return Vector3(motor_x + 0.12, motor_y, motor_z)


static func _add_console(
		body: Node3D, mats: Dictionary, con: Vector3, con_c: Vector3, y_bot: float) -> void:
	var frame := 0.04
	# 蓝色外壳
	_box(body, con, con_c, mats["blue"])
	# 浅灰前门（略凸出）
	var door_h := con.y * 0.62
	var door_pos := Vector3(con_c.x, y_bot + 0.12 + door_h * 0.5, con_c.z + con.z * 0.5 + 0.008)
	_box(body, Vector3(con.x - frame * 2.0, door_h, 0.02), door_pos, mats["door"])
	_box(body, Vector3(0.018, 0.10, 0.03), door_pos + Vector3(con.x * 0.28, 0.0, 0.012), mats["bolt"])

	# 斜面操作台
	var slope := Vector3(con.x - 0.02, 0.045, 0.38)
	var slope_pos := Vector3(con_c.x, y_bot + con.y - 0.10, con_c.z + 0.04)
	var slope_rot := Vector3(deg_to_rad(-24.0), 0.0, 0.0)
	_box(body, slope, slope_pos, mats["blue"], slope_rot)

	var face_n := Vector3(0.0, sin(deg_to_rad(24.0)), cos(deg_to_rad(24.0)))
	var screen_pos := slope_pos + face_n * 0.028 + Vector3(-0.04, 0.0, 0.0)
	_box(body, Vector3(0.20, 0.11, 0.012), screen_pos, mats["screen"], slope_rot)

	# 急停蘑菇头
	var estop_pos := slope_pos + face_n * 0.04 + Vector3(0.12, 0.01, 0.02)
	_cyl(body, estop_pos, 0.024, 0.016, mats["estop"], slope_rot)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.034
	cap_mesh.height = 0.048
	cap_mesh.material = mats["estop"]
	cap.mesh = cap_mesh
	cap.position = estop_pos + face_n * 0.028
	body.add_child(cap)

	# 指示灯
	_cyl(body, slope_pos + face_n * 0.032 + Vector3(0.12, -0.04, -0.04), 0.012, 0.010, mats["yellow"], slope_rot)
	_cyl(body, slope_pos + face_n * 0.032 + Vector3(0.08, -0.04, -0.04), 0.012, 0.010, mats["door"], slope_rot)


static func _add_cables(body: Node3D, mats: Dictionary, motor_at: Vector3, con_c: Vector3) -> void:
	var p0 := motor_at
	var p1 := Vector3(con_c.x - 0.08, motor_at.y + 0.08, motor_at.z)
	var p2 := Vector3(con_c.x - 0.08, con_c.y + P.CONSOLE.y * 0.28, con_c.z + 0.08)
	var p3 := Vector3(con_c.x - P.CONSOLE.x * 0.5 - 0.01, con_c.y + P.CONSOLE.y * 0.22, con_c.z + 0.10)
	_cable(body, p0, p1, 0.014, mats["cable"])
	_cable(body, p1, p2, 0.014, mats["cable"])
	_cable(body, p2, p3, 0.014, mats["cable"])
	_cable(body, p0 + Vector3(0.0, -0.03, 0.0), p1 + Vector3(0.0, -0.04, 0.02), 0.011, mats["cable"])
	_cable(body, p1 + Vector3(0.0, -0.04, 0.02), p2 + Vector3(0.0, -0.05, 0.02), 0.011, mats["cable"])
	_cable(body, p2 + Vector3(0.0, -0.05, 0.02), p3 + Vector3(0.0, -0.04, 0.0), 0.011, mats["cable"])


static func _add_collision(
		body: StaticBody3D, cab: Vector3, cab_c: Vector3, con: Vector3, con_c: Vector3,
		cab_front: float, y_bot: float) -> void:
	_shape(body, cab, cab_c)
	_shape(body, con, con_c)
	var arm_h := 0.28
	var arm_y := y_bot + 0.52
	_shape(body, Vector3(cab.x - 0.20, arm_h, P.ARM_EXTENT), Vector3(
		cab_c.x, arm_y + 0.06, cab_front + P.ARM_EXTENT * 0.5))


static func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _box(
		parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(
		parent: Node3D, pos: Vector3, height: float, radius: float, mat: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cable(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.001:
		return
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.material = mat
	mi.mesh = mesh
	mi.position = (a + b) * 0.5
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.001:
		x_axis = y_axis.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	mi.basis = Basis(x_axis, y_axis, z_axis)
	parent.add_child(mi)


static func _label(
		parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color,
		pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0.05, 0.06, 0.08, 0.85)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.double_sided = true
	parent.add_child(l)
	return l


static func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
