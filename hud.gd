class_name Hud
extends CanvasLayer

var _status: Label
var _tool_info: Label
var _length: Label
var _floor: Label

func setup() -> void:
	layer = 40
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.theme = UiTheme.make_theme()

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var accent := ColorRect.new()
	accent.color = UiTheme.ACCENT
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.custom_minimum_size = Vector2(0.0, 3.0)
	vb.add_child(accent)

	_status = _make_label(20, UiTheme.ACCENT)
	_tool_info = _make_label(15, UiTheme.TEXT)
	_length = _make_label(15, UiTheme.TEXT)
	_floor = _make_label(15, Color(0.20, 0.78, 0.85))
	vb.add_child(_status)
	vb.add_child(_tool_info)
	vb.add_child(_length)
	vb.add_child(_floor)
	add_child(panel)

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

func set_floor_text(text: String) -> void:
	_floor.text = text
