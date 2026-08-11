class_name Vignette
extends CanvasLayer

## 轻微暗角：Godot 4 已移除 Environment 的 vignette 属性，
## 改用全屏 CanvasLayer + 着色器实现，保持白模氛围统一。

const SHADER_CODE := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.15;
uniform float smoothing : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = pow(d.x * d.y * 4.0, smoothing);
	edge = clamp(edge, 0.0, 1.0);
	COLOR = vec4(tint.rgb, (1.0 - edge) * intensity);
}
"""

func setup() -> void:
	layer = 5
	var rect := ColorRect.new()
	rect.name = "VignetteRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = _build_shader()
	mat.set_shader_parameter("intensity", 0.15)
	mat.set_shader_parameter("smoothing", 0.35)
	rect.material = mat
	add_child(rect)

func _build_shader() -> Shader:
	var s := Shader.new()
	s.code = SHADER_CODE
	return s
