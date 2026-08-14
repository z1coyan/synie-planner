class_name RectOps
extends RefCounted

## 纯几何/纯函数工具集：全部 static，不触碰场景树、不依赖任何实例状态。
## 由 world_store.gd 抽出（内部逻辑与数值阈值逐字保留），供仓库与单元测试共用。

## 归一化地板碎片：翻转反向坐标，丢弃宽/长窄于 0.001 的碎片。
static func sanitize_floor_pieces(pieces: Array) -> Array:
	var out: Array = []
	for p_v in pieces:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		var x0 := float(p.get("x0", 0.0))
		var x1 := float(p.get("x1", 0.0))
		var z0 := float(p.get("z0", 0.0))
		var z1 := float(p.get("z1", 0.0))
		if x1 < x0:
			var tx := x0
			x0 = x1
			x1 = tx
		if z1 < z0:
			var tz := z0
			z0 = z1
			z1 = tz
		if x1 - x0 < 0.001 or z1 - z0 < 0.001:
			continue
		out.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1})
	return out


## 由盒中心与尺寸得到 XZ 矩形（地板无 yaw，按轴对齐）。
static func xz_rect_from_box(cx: Vector3, size: Vector3) -> Array:
	return [{
		"x0": cx.x - size.x * 0.5,
		"x1": cx.x + size.x * 0.5,
		"z0": cx.z - size.z * 0.5,
		"z1": cx.z + size.z * 0.5,
	}]


## 两矩形是否可合并为一块（重叠或共边）。
static func xz_rects_joinable(a: Dictionary, b: Dictionary, eps: float = 0.002) -> bool:
	var x_ov := minf(float(a["x1"]), float(b["x1"])) - maxf(float(a["x0"]), float(b["x0"]))
	var z_ov := minf(float(a["z1"]), float(b["z1"])) - maxf(float(a["z0"]), float(b["z0"]))
	if x_ov < -eps or z_ov < -eps:
		return false
	# 仅角点相触不算共边，避免对角两块被合成一块。
	return x_ov > eps or z_ov > eps


## 轴对齐矩形并集：按边线剖分格子，只保留被覆盖的单元再合并成块。
## 不会填上 L 形缺口；重叠区只覆盖一次，避免双层厚度。
static func union_xz_rects(rects: Array) -> Array:
	var cleaned := sanitize_floor_pieces(rects)
	if cleaned.is_empty():
		return []
	if cleaned.size() == 1:
		return cleaned
	var xs: Array = []
	var zs: Array = []
	for r in cleaned:
		xs.append(float(r["x0"]))
		xs.append(float(r["x1"]))
		zs.append(float(r["z0"]))
		zs.append(float(r["z1"]))
	xs.sort()
	zs.sort()
	var ux := unique_floats(xs)
	var uz := unique_floats(zs)
	var nx := ux.size() - 1
	var nz := uz.size() - 1
	if nx < 1 or nz < 1:
		return cleaned
	var covered: Array = []
	for i in nx:
		var row: Array = []
		for j in nz:
			var cx := (ux[i] + ux[i + 1]) * 0.5
			var cz := (uz[j] + uz[j + 1]) * 0.5
			var hit := false
			for r in cleaned:
				if cx > float(r["x0"]) + 0.0002 and cx < float(r["x1"]) - 0.0002 \
						and cz > float(r["z0"]) + 0.0002 and cz < float(r["z1"]) - 0.0002:
					hit = true
					break
			row.append(hit)
		covered.append(row)
	var used: Array = []
	for i in nx:
		var urow: Array = []
		for j in nz:
			urow.append(false)
		used.append(urow)
	var out: Array = []
	for j in nz:
		for i in nx:
			if not covered[i][j] or used[i][j]:
				continue
			var i2 := i
			while i2 + 1 < nx and covered[i2 + 1][j] and not used[i2 + 1][j]:
				i2 += 1
			var j2 := j
			while j2 + 1 < nz:
				var ok := true
				for ii in range(i, i2 + 1):
					if not covered[ii][j2 + 1] or used[ii][j2 + 1]:
						ok = false
						break
				if not ok:
					break
				j2 += 1
			for ii in range(i, i2 + 1):
				for jj in range(j, j2 + 1):
					used[ii][jj] = true
			var x0b := ux[i]
			var x1b := ux[i2 + 1]
			var z0b := uz[j]
			var z1b := uz[j2 + 1]
			if x1b - x0b < 0.001 or z1b - z0b < 0.001:
				continue
			out.append({"x0": x0b, "x1": x1b, "z0": z0b, "z1": z1b})
	return out if not out.is_empty() else cleaned


## 归一化地板开洞：翻转反向坐标，丢弃窄于 0.001 的洞，补全 width/length。
static func sanitize_floor_openings(ops: Array) -> Array:
	var out: Array = []
	for p_v in ops:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		var x0 := float(p.get("x0", 0.0))
		var x1 := float(p.get("x1", 0.0))
		var z0 := float(p.get("z0", 0.0))
		var z1 := float(p.get("z1", 0.0))
		if x1 < x0:
			var tx := x0
			x0 = x1
			x1 = tx
		if z1 < z0:
			var tz := z0
			z0 = z1
			z1 = tz
		if x1 - x0 < 0.001 or z1 - z0 < 0.001:
			continue
		out.append({
			"type": "floor_hole",
			"x0": x0, "x1": x1, "z0": z0, "z1": z1,
			"width": x1 - x0, "length": z1 - z0,
		})
	return out


## 单个地板开洞的归一化数据（类型固定为 floor_hole，含 width/length）。
static func floor_opening_data(op: Dictionary) -> Dictionary:
	var x0 := float(op.get("x0", 0.0))
	var x1 := float(op.get("x1", 0.0))
	var z0 := float(op.get("z0", 0.0))
	var z1 := float(op.get("z1", 0.0))
	if x1 < x0:
		var tx := x0
		x0 = x1
		x1 = tx
	if z1 < z0:
		var tz := z0
		z0 = z1
		z1 = tz
	return {
		"type": "floor_hole",
		"x0": x0, "x1": x1, "z0": z0, "z1": z1,
		"width": x1 - x0, "length": z1 - z0,
	}


## 从实心矩形中减去地洞，格子剖分后合并。洞口不填实，玩家可从洞落下。
static func subtract_xz_rects(solids: Array, holes: Array) -> Array:
	var cleaned := sanitize_floor_pieces(solids)
	var hole_r := sanitize_floor_openings(holes)
	if cleaned.is_empty():
		return []
	if hole_r.is_empty():
		return cleaned
	var xs: Array = []
	var zs: Array = []
	for r in cleaned:
		xs.append(float(r["x0"]))
		xs.append(float(r["x1"]))
		zs.append(float(r["z0"]))
		zs.append(float(r["z1"]))
	for r in hole_r:
		xs.append(float(r["x0"]))
		xs.append(float(r["x1"]))
		zs.append(float(r["z0"]))
		zs.append(float(r["z1"]))
	xs.sort()
	zs.sort()
	var ux := unique_floats(xs)
	var uz := unique_floats(zs)
	var nx := ux.size() - 1
	var nz := uz.size() - 1
	if nx < 1 or nz < 1:
		return cleaned
	var covered: Array = []
	for i in nx:
		var row: Array = []
		for j in nz:
			var cx := (ux[i] + ux[i + 1]) * 0.5
			var cz := (uz[j] + uz[j + 1]) * 0.5
			var solid := false
			for r in cleaned:
				if cx > float(r["x0"]) + 0.0002 and cx < float(r["x1"]) - 0.0002 \
						and cz > float(r["z0"]) + 0.0002 and cz < float(r["z1"]) - 0.0002:
					solid = true
					break
			if solid:
				for h in hole_r:
					if cx > float(h["x0"]) + 0.0002 and cx < float(h["x1"]) - 0.0002 \
							and cz > float(h["z0"]) + 0.0002 and cz < float(h["z1"]) - 0.0002:
						solid = false
						break
			row.append(solid)
		covered.append(row)
	var used: Array = []
	for i in nx:
		var urow: Array = []
		for j in nz:
			urow.append(false)
		used.append(urow)
	var out: Array = []
	for j in nz:
		for i in nx:
			if not covered[i][j] or used[i][j]:
				continue
			var i2 := i
			while i2 + 1 < nx and covered[i2 + 1][j] and not used[i2 + 1][j]:
				i2 += 1
			var j2 := j
			while j2 + 1 < nz:
				var ok := true
				for ii in range(i, i2 + 1):
					if not covered[ii][j2 + 1] or used[ii][j2 + 1]:
						ok = false
						break
				if not ok:
					break
				j2 += 1
			for ii in range(i, i2 + 1):
				for jj in range(j, j2 + 1):
					used[ii][jj] = true
			var x0b := ux[i]
			var x1b := ux[i2 + 1]
			var z0b := uz[j]
			var z1b := uz[j2 + 1]
			if x1b - x0b < 0.001 or z1b - z0b < 0.001:
				continue
			out.append({"x0": x0b, "x1": x1b, "z0": z0b, "z1": z1b})
	return out


## 碎片集合的 XZ 包围盒（{x0,x1,z0,z1}），空输入返回 {}。
static func floor_aabb_xz(pieces: Array) -> Dictionary:
	var cleaned := sanitize_floor_pieces(pieces)
	if cleaned.is_empty():
		return {}
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in cleaned:
		min_x = minf(min_x, float(p["x0"]))
		max_x = maxf(max_x, float(p["x1"]))
		min_z = minf(min_z, float(p["z0"]))
		max_z = maxf(max_z, float(p["z1"]))
	return {"x0": min_x, "x1": max_x, "z0": min_z, "z1": max_z}


## 排序去重浮点数组（相邻差 > 0.0005 视为不同值）。
static func unique_floats(vals: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in vals:
		var f := float(v)
		if out.is_empty() or absf(f - out[out.size() - 1]) > 0.0005:
			out.append(f)
	return out


## 射线与 AABB 相交：返回最近命中 t，未命中或背离返回 INF；起点在内返回 0.0。
static func ray_aabb_t(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for i in 3:
		var origin_i := o[i]
		var dir_i := d[i]
		var min_i := bmin[i]
		var max_i := bmax[i]
		if absf(dir_i) < 0.0000001:
			if origin_i < min_i or origin_i > max_i:
				return INF
			continue
		var inv := 1.0 / dir_i
		var t0 := (min_i - origin_i) * inv
		var t1 := (max_i - origin_i) * inv
		if t0 > t1:
			var tmp := t0
			t0 = t1
			t1 = tmp
		tmin = maxf(tmin, t0)
		tmax = minf(tmax, t1)
		if tmax < tmin:
			return INF
	if tmax < 0.0:
		return INF
	if tmin >= 0.0:
		return tmin
	return 0.0


## 墙开洞后的剩余实体块：按洞矩形剖分墙立面，返回 {pos, size} 列表。
static func wall_leftover_boxes(size: Vector3, openings: Array) -> Array:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var xs: Array = [-hx, hx]
	var ys: Array = [-hy, hy]
	var rects: Array = []
	for op_v in openings:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var b := opening_local_bounds(size, op_v)
		var x0 := float(b["x0"])
		var x1 := float(b["x1"])
		var y0 := float(b["y0"])
		var y1 := float(b["y1"])
		if x1 - x0 < 0.001 or y1 - y0 < 0.001:
			continue
		xs.append(x0)
		xs.append(x1)
		ys.append(y0)
		ys.append(y1)
		rects.append({"x0": x0, "x1": x1, "y0": y0, "y1": y1})
	xs.sort()
	ys.sort()
	var ux := unique_floats(xs)
	var uy := unique_floats(ys)
	if ux.size() < 2 or uy.size() < 2:
		return []
	var nx := ux.size() - 1
	var ny := uy.size() - 1
	var solid: Array = []
	for i in nx:
		var row: Array = []
		for j in ny:
			var cx := (ux[i] + ux[i + 1]) * 0.5
			var cy := (uy[j] + uy[j + 1]) * 0.5
			var hole := false
			for r in rects:
				if cx > float(r["x0"]) + 0.0002 and cx < float(r["x1"]) - 0.0002 \
						and cy > float(r["y0"]) + 0.0002 and cy < float(r["y1"]) - 0.0002:
					hole = true
					break
			row.append(not hole)
		solid.append(row)
	var used: Array = []
	for i in nx:
		var urow: Array = []
		for j in ny:
			urow.append(false)
		used.append(urow)
	var out: Array = []
	for j in ny:
		for i in nx:
			if not solid[i][j] or used[i][j]:
				continue
			var i2 := i
			while i2 + 1 < nx and solid[i2 + 1][j] and not used[i2 + 1][j]:
				i2 += 1
			var j2 := j
			while j2 + 1 < ny:
				var ok := true
				for ii in range(i, i2 + 1):
					if not solid[ii][j2 + 1] or used[ii][j2 + 1]:
						ok = false
						break
				if not ok:
					break
				j2 += 1
			for ii in range(i, i2 + 1):
				for jj in range(j, j2 + 1):
					used[ii][jj] = true
			var x0b := ux[i]
			var x1b := ux[i2 + 1]
			var y0b := uy[j]
			var y1b := uy[j2 + 1]
			var pw := x1b - x0b
			var ph := y1b - y0b
			if pw < 0.001 or ph < 0.001:
				continue
			out.append({
				"pos": Vector3((x0b + x1b) * 0.5, (y0b + y1b) * 0.5, 0.0),
				"size": Vector3(pw, ph, size.z),
			})
	return out


## 开洞在墙局部坐标下的边界（x 沿墙长、y 竖向）。门洞贴地，窗洞有窗台。
static func opening_local_bounds(size: Vector3, op: Dictionary) -> Dictionary:
	var w := maxf(float(op.get("width", Config.DOOR_WIDTH)), 0.05)
	var h := maxf(float(op.get("height", Config.DOOR_HEIGHT)), 0.05)
	var s := maxf(float(op.get("sill", 0.0)), 0.0)
	var u := float(op.get("u", 0.0))
	var typ := String(op.get("type", "door"))
	var hy := size.y * 0.5
	var floor_y := -hy + Config.EMBED
	var y0 := floor_y + s
	var y1 := y0 + h
	if typ == "door" or s <= 0.001:
		y0 = -hy
	return {
		"x0": u - w * 0.5,
		"x1": u + w * 0.5,
		"y0": y0,
		"y1": y1,
	}
