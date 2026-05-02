extends Node

const PANEL_BG := Color(0.075, 0.065, 0.055, 0.94)
const PANEL_BG_SOFT := Color(0.09, 0.08, 0.07, 0.9)
const PANEL_BORDER := Color(0.82, 0.62, 0.34, 1.0)
const PANEL_BORDER_DIM := Color(0.36, 0.28, 0.2, 1.0)
const TEXT_MAIN := Color(0.96, 0.9, 0.76, 1.0)
const TEXT_MUTED := Color(0.68, 0.64, 0.56, 1.0)
const TEXT_COIN := Color(1.0, 0.78, 0.2, 1.0)
const TEXT_ORE := Color(0.68, 0.9, 1.0, 1.0)
const TEXT_HP := Color(0.62, 0.95, 0.62, 1.0)
const TEXT_DANGER := Color(0.96, 0.32, 0.24, 1.0)
const OUTLINE := Color(0.025, 0.02, 0.015, 1.0)

const BAR_BG := Color(0.045, 0.04, 0.035, 1.0)
const BAR_HP := Color(0.88, 0.18, 0.14, 1.0)
const BAR_ALLY_HP := Color(0.24, 0.82, 0.35, 1.0)
const BAR_ORE := Color(0.22, 0.78, 0.95, 1.0)


func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	return style


func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := panel_style(bg, border, 8, 2)
	style.set_content_margin_all(8)
	return style


func style_button(button: Button, font_size: int = 15) -> void:
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", TEXT_MAIN)
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_color_override(&"font_pressed_color", TEXT_COIN)
	button.add_theme_color_override(&"font_disabled_color", Color(0.45, 0.42, 0.36, 1.0))
	button.add_theme_stylebox_override(&"normal", button_style(Color(0.13, 0.105, 0.075, 0.96), PANEL_BORDER_DIM))
	button.add_theme_stylebox_override(&"hover", button_style(Color(0.19, 0.145, 0.09, 0.98), PANEL_BORDER))
	button.add_theme_stylebox_override(&"pressed", button_style(Color(0.09, 0.07, 0.05, 0.98), TEXT_COIN))
	button.add_theme_stylebox_override(&"disabled", button_style(Color(0.06, 0.055, 0.05, 0.78), Color(0.18, 0.16, 0.13, 1.0)))


func style_label(label: Label, color: Color = TEXT_MAIN, font_size: int = 20, outline_size: int = 4) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", OUTLINE)
	label.add_theme_constant_override(&"outline_size", outline_size)


func style_label3d(label: Label3D, color: Color = TEXT_MAIN, font_size: int = 24, outline_size: int = 8) -> void:
	label.font_size = font_size
	label.outline_size = outline_size
	label.modulate = color
	label.outline_modulate = OUTLINE
	label.no_depth_test = true


func bar_bg_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BAR_BG
	mat.roughness = 0.85
	return mat


func bar_fill_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.darkened(0.55)
	mat.emission_energy_multiplier = 0.28
	mat.roughness = 0.42
	return mat
