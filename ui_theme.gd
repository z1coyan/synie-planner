class_name UiTheme
extends RefCounted

## 白模风浅色主题：半透明浅灰面板 + 细线边框 + 橙色强调。
## 纯代码构建 Theme，供 HUD / 元素库 / 暂停菜单 / 快捷栏复用。

const ACCENT := Color(0.96, 0.60, 0.15)
const ACCENT_SOFT := Color(0.96, 0.60, 0.15, 0.16)
const PANEL_BG := Color(0.96, 0.96, 0.97, 0.82)
const PANEL_BG_2 := Color(0.92, 0.92, 0.94, 0.85)
const BORDER := Color(0.62, 0.63, 0.66, 0.8)
const TEXT := Color(0.22, 0.23, 0.25)
const TEXT_DIM := Color(0.45, 0.46, 0.48)
const WHITE := Color(1.0, 1.0, 1.0)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	t.set_stylebox("panel", "PanelContainer", panel_style())

	t.set_stylebox("normal", "Button", button_style())
	t.set_stylebox("hover", "Button", button_style(true))
	t.set_stylebox("pressed", "Button", button_style(false, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", WHITE)
	t.set_color("font_focus_color", "Button", TEXT)

	t.set_stylebox("normal", "LineEdit", input_style())
	t.set_stylebox("focus", "LineEdit", input_style(true))
	t.set_stylebox("normal", "SpinBox", input_style())
	t.set_stylebox("focus", "SpinBox", input_style(true))

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "SpinBox", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("placeholder_font_color", "LineEdit", TEXT_DIM)

	t.set_stylebox("panel", "ItemList", panel_style(4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", WHITE)
	t.set_color("selection_color", "ItemList", ACCENT_SOFT)
	t.set_color("guide_color", "ItemList", ACCENT)

	var line := StyleBoxLine.new()
	line.color = Color(0.72, 0.73, 0.76, 0.6)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	return t

static func panel_style(corner := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(corner)
	s.set_content_margin_all(12)
	return s

static func button_style(hovered := false, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if pressed:
		s.bg_color = Color(0.96, 0.60, 0.15, 0.85)
	elif hovered:
		s.bg_color = Color(0.96, 0.60, 0.15, 0.18)
	else:
		s.bg_color = Color(0.97, 0.97, 0.98, 0.9)
	s.border_color = ACCENT if (hovered or pressed) else BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	return s

static func input_style(focus := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG_2
	s.border_color = ACCENT if focus else BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func slot_style(active := false, secondary := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = ACCENT_SOFT
		s.border_color = ACCENT
		s.set_border_width_all(2)
	else:
		s.bg_color = Color(0.96, 0.96, 0.97, 0.62)
		s.border_color = Color(0.45, 0.46, 0.48) if secondary else BORDER
		s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(6)
	return s
