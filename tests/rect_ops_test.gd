extends SceneTree

## RectOps 纯函数单元测试：以 --headless --script 方式运行。
## 全部用例在 _init() 内执行：通过 quit(0)，失败 quit(1)（失败同时 push_error 说明用例）。

var _fail_count := 0

func _init() -> void:
	_test_sanitize_floor_pieces()
	_test_xz_rects_joinable()
	_test_union_xz_rects()
	_test_sanitize_floor_openings()
	_test_floor_opening_data()
	_test_subtract_xz_rects()
	_test_floor_aabb_xz()
	_test_wall_leftover_boxes()
	_test_ray_aabb_t()
	if _fail_count > 0:
		push_error("rect_ops_test 失败用例数: %d" % _fail_count)
		quit(1)
	else:
		print("rect_ops_test: 全部用例通过")
		quit(0)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_fail_count += 1
		push_error("断言失败: " + msg)


static func _rect_area(r: Dictionary) -> float:
	return (float(r["x1"]) - float(r["x0"])) * (float(r["z1"]) - float(r["z0"]))


static func _pieces_area(pieces: Array) -> float:
	var total := 0.0
	for p in pieces:
		total += _rect_area(p)
	return total


func _test_sanitize_floor_pieces() -> void:
	# x1<x0 的输入被翻转
	var flipped := RectOps.sanitize_floor_pieces([{"x0": 4.0, "x1": 1.0, "z0": 0.0, "z1": 2.0}])
	_expect(flipped.size() == 1, "sanitize: x1<x0 应保留 1 块 (实际 %d)" % flipped.size())
	if flipped.size() == 1:
		_expect(flipped[0]["x0"] == 1.0 and flipped[0]["x1"] == 4.0, "sanitize: x0/x1 应翻转")
	# z1<z0 的输入被翻转
	var flipped_z := RectOps.sanitize_floor_pieces([{"x0": 0.0, "x1": 2.0, "z0": 3.0, "z1": 0.5}])
	_expect(flipped_z.size() == 1, "sanitize: z1<z0 应保留 1 块 (实际 %d)" % flipped_z.size())
	if flipped_z.size() == 1:
		_expect(flipped_z[0]["z0"] == 0.5 and flipped_z[0]["z1"] == 3.0, "sanitize: z0/z1 应翻转")
	# 宽窄于 0.001 的被丢弃
	var thin_w := RectOps.sanitize_floor_pieces([{"x0": 0.0, "x1": 0.0005, "z0": 0.0, "z1": 2.0}])
	_expect(thin_w.is_empty(), "sanitize: 宽 <0.001 应丢弃")
	# 长窄于 0.001 的被丢弃
	var thin_l := RectOps.sanitize_floor_pieces([{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 0.0005}])
	_expect(thin_l.is_empty(), "sanitize: 长 <0.001 应丢弃")
	# 非字典项被跳过
	var mixed := RectOps.sanitize_floor_pieces([42, "bad", {"x0": 0.0, "x1": 1.0, "z0": 0.0, "z1": 1.0}])
	_expect(mixed.size() == 1, "sanitize: 非字典项应跳过 (实际 %d)" % mixed.size())


func _test_xz_rects_joinable() -> void:
	var a := {"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0}
	var b_edge := {"x0": 2.0, "x1": 4.0, "z0": 0.0, "z1": 2.0}
	var b_corner := {"x0": 2.0, "x1": 4.0, "z0": 2.0, "z1": 4.0}
	var b_overlap := {"x0": 1.0, "x1": 3.0, "z0": 1.0, "z1": 3.0}
	_expect(RectOps.xz_rects_joinable(a, b_edge), "joinable: 共边矩形应可合并")
	_expect(not RectOps.xz_rects_joinable(a, b_corner), "joinable: 对角相触不应合并")
	_expect(RectOps.xz_rects_joinable(a, b_overlap), "joinable: 重叠矩形应可合并")


func _test_union_xz_rects() -> void:
	# 两重叠矩形（同 z 跨度）并成 1 块，块数最少
	var u1 := RectOps.union_xz_rects([
		{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0},
		{"x0": 1.0, "x1": 3.0, "z0": 0.0, "z1": 2.0},
	])
	_expect(u1.size() == 1, "union: 重叠合并后应 1 块 (实际 %d)" % u1.size())
	if u1.size() == 1:
		_expect(absf((float(u1[0]["x1"]) - float(u1[0]["x0"])) - 3.0) < 0.001, "union: 并集 x 跨度应为 3")
	# 对角相触（仅角点共点）不合并
	var u2 := RectOps.union_xz_rects([
		{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0},
		{"x0": 2.0, "x1": 4.0, "z0": 2.0, "z1": 4.0},
	])
	_expect(u2.size() == 2, "union: 对角相触应 2 块 (实际 %d)" % u2.size())
	# 重叠区面积不重复计算：2x2 + 2x2 - 1x1 = 7
	var u3 := RectOps.union_xz_rects([
		{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0},
		{"x0": 1.0, "x1": 3.0, "z0": 1.0, "z1": 3.0},
	])
	var area3 := _pieces_area(u3)
	_expect(absf(area3 - 7.0) < 0.001, "union: 重叠区面积不重复 (期望 7, 实际 %.4f)" % area3)
	_expect(u3.size() == 3, "union: L 形并集应为 3 块 (实际 %d)" % u3.size())
	# L 形缺口不被填上：三块铺成 U 形，缺口 (2,4)x(2,4) 面积 4 不应被填
	var u4 := RectOps.union_xz_rects([
		{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0},
		{"x0": 2.0, "x1": 4.0, "z0": 0.0, "z1": 2.0},
		{"x0": 0.0, "x1": 2.0, "z0": 2.0, "z1": 4.0},
	])
	var area4 := _pieces_area(u4)
	_expect(absf(area4 - 12.0) < 0.001, "union: U 形缺口不应被填上 (期望 12, 实际 %.4f)" % area4)


func _test_sanitize_floor_openings() -> void:
	var ops := RectOps.sanitize_floor_openings([
		{"x0": 2.0, "x1": 1.0, "z0": 0.0, "z1": 3.0},
		{"x0": 0.0, "x1": 0.0005, "z0": 0.0, "z1": 1.0},
		99,
	])
	_expect(ops.size() == 1, "openings: 应保留 1 个有效洞 (实际 %d)" % ops.size())
	if ops.size() == 1:
		var o: Dictionary = ops[0]
		_expect(String(o["type"]) == "floor_hole", "openings: 类型应为 floor_hole")
		_expect(o["x0"] == 1.0 and o["x1"] == 2.0 and o["z0"] == 0.0 and o["z1"] == 3.0, "openings: 坐标应翻转")
		_expect(absf(float(o["width"]) - 1.0) < 0.001 and absf(float(o["length"]) - 3.0) < 0.001, "openings: width/length 应补全")


func _test_floor_opening_data() -> void:
	var d := RectOps.floor_opening_data({"x0": 5.0, "x1": 3.0, "z0": 1.0, "z1": 4.0})
	_expect(d["x0"] == 3.0 and d["x1"] == 5.0, "opening_data: x 应翻转")
	_expect(d["z0"] == 1.0 and d["z1"] == 4.0, "opening_data: z 应保留")
	_expect(absf(float(d["width"]) - 2.0) < 0.001 and absf(float(d["length"]) - 3.0) < 0.001, "opening_data: width/length 应正确")
	_expect(String(d["type"]) == "floor_hole", "opening_data: 类型应为 floor_hole")


func _test_subtract_xz_rects() -> void:
	# 中间挖洞后剩余面积守恒：16 - 4 = 12
	var s1 := RectOps.subtract_xz_rects(
		[{"x0": 0.0, "x1": 4.0, "z0": 0.0, "z1": 4.0}],
		[{"x0": 1.0, "x1": 3.0, "z0": 1.0, "z1": 3.0}],
	)
	var area1 := _pieces_area(s1)
	_expect(absf(area1 - 12.0) < 0.001, "subtract: 中间挖洞面积守恒 (期望 12, 实际 %.4f)" % area1)
	# 无洞时返回原碎片
	var s2 := RectOps.subtract_xz_rects([{"x0": 0.0, "x1": 4.0, "z0": 0.0, "z1": 4.0}], [])
	_expect(s2.size() == 1 and absf(_pieces_area(s2) - 16.0) < 0.001, "subtract: 无洞应返回原碎片")
	# L 形缺口不被填上：角上挖 2x2，剩余 12 且无碎片覆盖缺口格
	var s3 := RectOps.subtract_xz_rects(
		[{"x0": 0.0, "x1": 4.0, "z0": 0.0, "z1": 4.0}],
		[{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 2.0}],
	)
	var area3 := _pieces_area(s3)
	_expect(absf(area3 - 12.0) < 0.001, "subtract: 角洞 L 形缺口面积 (期望 12, 实际 %.4f)" % area3)
	var gap_filled := false
	for p in s3:
		if float(p["x0"]) < 2.0 and float(p["z0"]) < 2.0:
			gap_filled = true
	_expect(not gap_filled, "subtract: L 形缺口不应被填上")


func _test_floor_aabb_xz() -> void:
	var aabb := RectOps.floor_aabb_xz([
		{"x0": 0.0, "x1": 2.0, "z0": 0.0, "z1": 1.0},
		{"x0": 1.0, "x1": 4.0, "z0": 0.5, "z1": 3.0},
	])
	_expect(aabb["x0"] == 0.0 and aabb["x1"] == 4.0 and aabb["z0"] == 0.0 and aabb["z1"] == 3.0, "aabb: 包围盒范围应正确")
	_expect(RectOps.floor_aabb_xz([]).is_empty(), "aabb: 空输入应返回 {}")


func _test_wall_leftover_boxes() -> void:
	# 墙 4x3（厚 0.2），居中门洞 0.9x2.1：洞局部 x∈[-0.45,0.45], y∈[-1.5,0.62]
	var size := Vector3(4.0, 3.0, 0.2)
	var pieces := RectOps.wall_leftover_boxes(size, [{
		"type": "door", "width": 0.9, "height": 2.1, "sill": 0.0, "u": 0.0,
	}])
	_expect(pieces.size() == 3, "wall_leftover: 应返回 3 块 (实际 %d)" % pieces.size())
	# 洞口内部区域（局部 (0,0)）不得被任何块 AABB 覆盖
	var hole_hit := false
	var total := 0.0
	var z_ok := true
	for p in pieces:
		var pos: Vector3 = p["pos"]
		var psz: Vector3 = p["size"]
		var x0 := pos.x - psz.x * 0.5
		var x1 := pos.x + psz.x * 0.5
		var y0 := pos.y - psz.y * 0.5
		var y1 := pos.y + psz.y * 0.5
		if x0 < 0.0 and x1 > 0.0 and y0 < 0.0 and y1 > 0.0:
			hole_hit = true
		total += psz.x * psz.y
		if absf(psz.z - 0.2) > 0.001:
			z_ok = false
	_expect(not hole_hit, "wall_leftover: 块 AABB 不应包含洞口内部区域")
	# 面积守恒：12 - 0.9 * (0.62 - (-1.5)) = 12 - 1.908 = 10.092
	var expected := 12.0 - 0.9 * 2.12
	_expect(absf(total - expected) < 0.001, "wall_leftover: 面积守恒 (期望 %.4f, 实际 %.4f)" % [expected, total])
	_expect(z_ok, "wall_leftover: 厚度应保留 0.2")


func _test_ray_aabb_t() -> void:
	var bmin := Vector3(0.0, 0.0, 0.0)
	var bmax := Vector3(1.0, 1.0, 1.0)
	# 从外部朝 AABB 的射线命中 t>0
	var t1 := RectOps.ray_aabb_t(Vector3(-1.0, 0.5, 0.5), Vector3(1.0, 0.0, 0.0), bmin, bmax)
	_expect(t1 > 0.0 and absf(t1 - 1.0) < 0.0001, "ray: 外部命中 t 应为 1.0 (实际 %.4f)" % t1)
	# 背离射线返回 INF
	var t2 := RectOps.ray_aabb_t(Vector3(2.0, 0.5, 0.5), Vector3(1.0, 0.0, 0.0), bmin, bmax)
	_expect(is_inf(t2), "ray: 背离射线应返回 INF")
	# 起点在内返回 0.0
	var t3 := RectOps.ray_aabb_t(Vector3(0.5, 0.5, 0.5), Vector3(1.0, 0.0, 0.0), bmin, bmax)
	_expect(t3 == 0.0, "ray: 起点在内应返回 0.0")
	# 平行且未命中返回 INF
	var t4 := RectOps.ray_aabb_t(Vector3(0.5, 5.0, 0.5), Vector3(1.0, 0.0, 0.0), bmin, bmax)
	_expect(is_inf(t4), "ray: 平行未命中应返回 INF")
