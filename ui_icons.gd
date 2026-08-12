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
		"opening": _opening(canvas, c, u, color)
		"floors": _floors(canvas, c, u, color, param)
		"showall": _showall(canvas, c, u, color)

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

## 开洞：楼板（方形轮廓）上开圆形吊装孔
static func _opening(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var r := Rect2(c + Vector2(-9.5 * u, -9.5 * u), Vector2(19.0 * u, 19.0 * u))
	canvas.draw_rect(r, color, false, 2.0 * u)
	canvas.draw_arc(c, 4.6 * u, 0.0, TAU, 28, color, 2.0 * u, true)

## 楼层 N：自下而上叠放的楼板条
static func _floors(canvas: CanvasItem, c: Vector2, u: float, color: Color, n: int) -> void:
	var bw := 13.0 * u
	var bh := 3.0 * u
	var step := 4.5 * u
	var x := c.x - bw * 0.5
	for i in range(maxi(n, 1)):
		var y := c.y + 5.0 * u - i * step
		canvas.draw_rect(Rect2(x, y, bw, bh), color, true)

## 全层：四层楼板条置于外框内
static func _showall(canvas: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var bw := 11.0 * u
	var bh := 2.6 * u
	var step := 4.0 * u
	var x := c.x - bw * 0.5
	for i in range(4):
		var y := c.y + 4.5 * u - i * step
		canvas.draw_rect(Rect2(x, y, bw, bh), color, true)
	var box := Rect2(c + Vector2(-8.5 * u, -8.5 * u), Vector2(17.0 * u, 17.0 * u))
	canvas.draw_rect(box, color, false, 1.8 * u)
