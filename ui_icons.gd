class_name UiIcons
extends RefCounted

## 纯代码矢量图标：以 draw_* 原语绘制快捷栏工具 / 楼层图标，无外部贴图。
## 绘制坐标以图标中心为原点、UNIT 为基准设计网格，size 传入时整体缩放。

const UNIT := 24.0

static func draw(canvas: CanvasItem, icon: String, color: Color, size: float = 24.0, param := 0) -> void:
	var c := Vector2(size, size) * 0.5
	var u := size / UNIT
	match icon:
		"cancel": _cancel(canvas, c, u, color)
		"wall": _wall(canvas, c, u, color)
		"column": _column(canvas, c, u, color)
		"device": _device(canvas, c, u, color)
		"floor_tile": _floor_tile(canvas, c, u, color)
		"stair": _stair(canvas, c, u, color)
		"delete": _delete(canvas, c, u, color)
		"pickup": _pickup(canvas, c, u, color)
		"array": _array(canvas, c, u, color)
		"material": _material(canvas, c, u, color)
		"params": _params(canvas, c, u, color)

## 取消：外圈 + 斜叉
static func _cancel(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var w := 2.4 * u
	canvas.draw_arc(c, 8.6 * u, 0.0, TAU, 32, color, w, true)
	var d := 4.6 * u
	canvas.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), color, w, true)
	canvas.draw_line(c + Vector2(d, -d), c + Vector2(-d, d), color, w, true)

## 立柱：轴测长方体柱（顶面受光、左右面渐暗）
static func _column(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var hw := 4.5 * u
	var hi := 2.25 * u
	var ch := 8.5 * u
	var apex := c + Vector2(0.0, -2.0 * hi)
	var fr := c + Vector2(hw, -hi)
	var bc := c + Vector2(0.0, 0.0)
	var bl := c + Vector2(-hw, -hi)
	var frb := fr + Vector2(0.0, ch)
	var bcb := bc + Vector2(0.0, ch)
	var blb := bl + Vector2(0.0, ch)
	canvas.draw_colored_polygon(PackedVector2Array([apex, fr, bc, bl]), color.lightened(0.1))
	canvas.draw_colored_polygon(PackedVector2Array([bl, bc, bcb, blb]), color.darkened(0.15))
	canvas.draw_colored_polygon(PackedVector2Array([bc, fr, frb, bcb]), color.darkened(0.35))
	canvas.draw_polyline(PackedVector2Array([apex, fr, frb, bcb, blb, bl, apex]), color, 1.2 * u, true)

## 墙体：轴测墙体，长面做错缝砖墙质感
static func _wall(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var hw_fr := 7.5 * u
	var hw_bl := 2.5 * u
	var hi := 1.25 * u
	var ch := 5.5 * u
	var apex := c + Vector2(0.0, -2.0 * hi)
	var fr := c + Vector2(hw_fr, -hi)
	var bc := c + Vector2(0.0, 0.0)
	var bl := c + Vector2(-hw_bl, -hi)
	var frb := fr + Vector2(0.0, ch)
	var bcb := bc + Vector2(0.0, ch)
	var blb := bl + Vector2(0.0, ch)
	canvas.draw_colored_polygon(PackedVector2Array([apex, fr, bc, bl]), color.lightened(0.1))
	canvas.draw_colored_polygon(PackedVector2Array([bl, bc, bcb, blb]), color.darkened(0.15))
	var mortar := color.darkened(0.55)
	canvas.draw_colored_polygon(PackedVector2Array([bc, fr, frb, bcb]), mortar)
	_draw_bricks(canvas, bc, fr, bcb, color.darkened(0.3), 0.13)
	canvas.draw_polyline(PackedVector2Array([apex, fr, frb, bcb, blb, bl, apex]), color, 1.2 * u, true)

## 在平行四边形（tl 顶左、tr_ 顶右、bl_ 底左）内绘制错缝砖块
static func _draw_bricks(canvas: CanvasItem, tl: Vector2, tr_: Vector2, bl_: Vector2, color: Color, m: float) -> void:
	var rows := 5
	for r in range(rows):
		var t_top := float(r) / rows
		var t_bot := float(r + 1) / rows
		var dt := m * (t_bot - t_top)
		var cols: Array = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0] if r % 2 == 0 else [1.0 / 6.0, 0.5, 5.0 / 6.0, 1.0]
		for k in range(cols.size() - 1):
			var f1 := float(cols[k])
			var f2 := float(cols[k + 1])
			var df := m * (f2 - f1)
			var a := _brick_pt(tl, tr_, bl_, t_bot, f1 + df)
			var b := _brick_pt(tl, tr_, bl_, t_bot, f2 - df)
			var d := _brick_pt(tl, tr_, bl_, t_top + dt, f1 + df)
			var e := _brick_pt(tl, tr_, bl_, t_top + dt, f2 - df)
			canvas.draw_colored_polygon(PackedVector2Array([a, b, e, d]), color)

static func _brick_pt(tl: Vector2, tr_: Vector2, bl_: Vector2, t: float, f: float) -> Vector2:
	return tl + (bl_ - tl) * t + (tr_ - tl) * f

## 设备：机身 + 屏幕 + 旋钮
static func _device(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var body := Rect2(c + Vector2(-9.0 * u, -5.0 * u), Vector2(18.0 * u, 10.0 * u))
	canvas.draw_rect(body, color, false, 2.0 * u)
	var scr := Rect2(body.position + Vector2(2.0 * u, 2.0 * u), Vector2(9.0 * u, 6.0 * u))
	canvas.draw_rect(scr, color, true)
	canvas.draw_circle(Vector2(body.end.x - 2.6 * u, body.get_center().y), 2.2 * u, color)

## 地板：扁平轴测楼板（顶面受光、左右面渐暗），顶面 2×2 分格
static func _floor_tile(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var hw := 8.0 * u
	var hi := 3.0 * u
	var ch := 2.2 * u
	var apex := c + Vector2(0.0, -2.0 * hi)
	var fr := c + Vector2(hw, -hi)
	var bc := c + Vector2(0.0, 0.0)
	var bl := c + Vector2(-hw, -hi)
	var frb := fr + Vector2(0.0, ch)
	var bcb := bc + Vector2(0.0, ch)
	var blb := bl + Vector2(0.0, ch)
	canvas.draw_colored_polygon(PackedVector2Array([apex, fr, bc, bl]), color.lightened(0.1))
	canvas.draw_colored_polygon(PackedVector2Array([bl, bc, bcb, blb]), color.darkened(0.15))
	canvas.draw_colored_polygon(PackedVector2Array([bc, fr, frb, bcb]), color.darkened(0.35))
	var grid_col := color.darkened(0.3)
	canvas.draw_line((apex + bl) * 0.5, (fr + bc) * 0.5, grid_col, 1.0 * u, true)
	canvas.draw_line((apex + fr) * 0.5, (bl + bc) * 0.5, grid_col, 1.0 * u, true)
	canvas.draw_polyline(PackedVector2Array([apex, fr, frb, bcb, blb, bl, apex]), color, 1.2 * u, true)

## 楼梯：轴测三级踏步
static func _stair(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var w := 1.2 * u
	var steps := [
		PackedVector2Array([
			c + Vector2(-8.0 * u, 7.0 * u), c + Vector2(2.0 * u, 7.0 * u),
			c + Vector2(2.0 * u, 3.2 * u), c + Vector2(-8.0 * u, 3.2 * u),
		]),
		PackedVector2Array([
			c + Vector2(-4.5 * u, 3.2 * u), c + Vector2(5.5 * u, 3.2 * u),
			c + Vector2(5.5 * u, -0.6 * u), c + Vector2(-4.5 * u, -0.6 * u),
		]),
		PackedVector2Array([
			c + Vector2(-1.0 * u, -0.6 * u), c + Vector2(9.0 * u, -0.6 * u),
			c + Vector2(9.0 * u, -4.4 * u), c + Vector2(-1.0 * u, -4.4 * u),
		]),
	]
	var shades := [0.35, 0.18, 0.0]
	for i in range(steps.size()):
		canvas.draw_colored_polygon(steps[i], color.darkened(shades[i]))
		canvas.draw_polyline(steps[i], color, w, true)

## 拆除：垃圾桶（桶身梯形 + 盖子 + 提手 + 内部竖线）
static func _delete(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var w := 2.0 * u
	canvas.draw_line(c + Vector2(-7.0 * u, -5.0 * u), c + Vector2(7.0 * u, -5.0 * u), color, w, true)
	canvas.draw_polyline(PackedVector2Array([
		c + Vector2(-2.5 * u, -5.0 * u), c + Vector2(-2.5 * u, -8.5 * u),
		c + Vector2(2.5 * u, -8.5 * u), c + Vector2(2.5 * u, -5.0 * u),
	]), color, w, true)
	canvas.draw_polyline(PackedVector2Array([
		c + Vector2(-5.5 * u, -3.0 * u), c + Vector2(-4.0 * u, 8.0 * u),
		c + Vector2(4.0 * u, 8.0 * u), c + Vector2(5.5 * u, -3.0 * u),
		c + Vector2(-5.5 * u, -3.0 * u),
	]), color, w, true)
	canvas.draw_line(c + Vector2(-1.8 * u, -0.5 * u), c + Vector2(-1.2 * u, 5.5 * u), color, w * 0.7, true)
	canvas.draw_line(c + Vector2(1.8 * u, -0.5 * u), c + Vector2(1.2 * u, 5.5 * u), color, w * 0.7, true)

## 拿起：上箭头 + 方块
static func _pickup(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var w := 2.0 * u
	var box := Rect2(c + Vector2(-5.0 * u, 1.0 * u), Vector2(10.0 * u, 7.0 * u))
	canvas.draw_rect(box, color, false, w)
	canvas.draw_line(c + Vector2(0.0, 0.5 * u), c + Vector2(0.0, -8.0 * u), color, w, true)
	canvas.draw_line(c + Vector2(0.0, -8.0 * u), c + Vector2(-3.5 * u, -4.0 * u), color, w, true)
	canvas.draw_line(c + Vector2(0.0, -8.0 * u), c + Vector2(3.5 * u, -4.0 * u), color, w, true)

## 阵列：三枚小方块横排
static func _array(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var w := 1.6 * u
	var s := 4.2 * u
	var gap := 1.6 * u
	var total := s * 3.0 + gap * 2.0
	var x0 := c.x - total * 0.5
	var y0 := c.y - s * 0.5
	for i in 3:
		var r := Rect2(Vector2(x0 + float(i) * (s + gap), y0), Vector2(s, s))
		canvas.draw_rect(r, color, false, w)


## 材质：色板方块 + 对角线
static func _material(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var r1 := Rect2(c + Vector2(-8.0 * u, -8.0 * u), Vector2(10.0 * u, 10.0 * u))
	var r2 := Rect2(c + Vector2(-2.0 * u, -2.0 * u), Vector2(10.0 * u, 10.0 * u))
	canvas.draw_rect(r1, color.darkened(0.25), true)
	canvas.draw_rect(r2, color.lightened(0.15), true)
	canvas.draw_rect(r2, color, false, 1.4 * u)

## 工具参数：滑块 + 刻度
static func _params(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var track := Rect2(c + Vector2(-9.0 * u, -1.0 * u), Vector2(18.0 * u, 2.0 * u))
	canvas.draw_rect(track, color, true)
	canvas.draw_circle(c + Vector2(3.0 * u, 0.0), 3.2 * u, color)
	canvas.draw_line(c + Vector2(-9.0 * u, -6.0 * u), c + Vector2(-9.0 * u, 6.0 * u), color, 1.4 * u, true)
	canvas.draw_line(c + Vector2(9.0 * u, -6.0 * u), c + Vector2(9.0 * u, 6.0 * u), color, 1.4 * u, true)

