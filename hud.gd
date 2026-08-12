class_name Hud
extends CanvasLayer

var _status: Label
var _tool_info: Label
var _length: Label
var _crosshair: Crosshair

func setup() -> void:
	layer = 40
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.theme = UiTheme.make_theme()

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	var accent := ColorRect.new()
	accent.color = UiTheme.ACCENT
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.custom_minimum_size = Vector2(0.0, 2.0)
	vb.add_child(accent)

	_status = _make_label(15, UiTheme.ACCENT)
	_tool_info = _make_label(12, UiTheme.TEXT)
	_length = _make_label(12, UiTheme.TEXT)
	vb.add_child(_status)
	vb.add_child(_tool_info)
	vb.add_child(_length)
	add_child(panel)

	_crosshair = Crosshair.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func set_status(text: String) -> void:
	_status.text = text

func set_tool_info(text: String) -> void:
	_tool_info.text = text

func set_length(text: String) -> void:
	_length.text = text

class Crosshair:
	extends Control

	## 屏幕中心准星：白色圆点，深色描边保证在浅色背景下清晰可见。

	const RADIUS := 2.5
	const RING_RADIUS := 4.5
	const RING_WIDTH := 1.5

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, RING_RADIUS, 0.0, TAU, 24, Color(0.15, 0.16, 0.18, 0.85), RING_WIDTH, true)
		draw_circle(c, RADIUS, Color.WHITE)
