class_name Hud
extends CanvasLayer

var _status: Label
var _tool_info: Label
var _length: Label
var _hint: Label

func setup() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	_status = _make_label("")
	_tool_info = _make_label("")
	_length = _make_label("")
	_hint = _make_label("Tab 视角切换  1 墙  2 柱  3 设备  R 旋转  F 飞行  Esc 取消")
	_status.add_theme_font_size_override("font_size", 18)
	vb.add_child(_status)
	vb.add_child(_tool_info)
	vb.add_child(_length)
	vb.add_child(_hint)
	add_child(panel)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	l.add_theme_constant_override("outline_size", 3)
	return l

func set_status(text: String) -> void:
	_status.text = text

func set_tool_info(text: String) -> void:
	_tool_info.text = text

func set_length(text: String) -> void:
	_length.text = text
