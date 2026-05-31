extends Node

# ── Color constants (unchanged — used throughout codebase) ────────────────────
const PANEL_BG         := Color(0.075, 0.065, 0.055, 0.94)
const PANEL_BG_SOFT    := Color(0.09,  0.08,  0.07,  0.90)
const PANEL_BORDER     := Color(0.82,  0.62,  0.34,  1.0)
const PANEL_BORDER_DIM := Color(0.36,  0.28,  0.20,  1.0)
const TEXT_MAIN        := Color(0.96,  0.90,  0.76,  1.0)
const TEXT_MUTED       := Color(0.68,  0.64,  0.56,  1.0)
const TEXT_COIN        := Color(1.00,  0.78,  0.20,  1.0)
const TEXT_ORE         := Color(0.68,  0.90,  1.00,  1.0)
const TEXT_HP          := Color(0.62,  0.95,  0.62,  1.0)
const TEXT_DANGER      := Color(0.96,  0.32,  0.24,  1.0)
const OUTLINE          := Color(0.025, 0.020, 0.015, 1.0)

const BAR_BG      := Color(0.045, 0.040, 0.035, 1.0)
const BAR_HP      := Color(0.88,  0.18,  0.14,  1.0)
const BAR_ALLY_HP := Color(0.24,  0.82,  0.35,  1.0)
const BAR_ORE     := Color(0.22,  0.78,  0.95,  1.0)

# ── Kenney asset paths ────────────────────────────────────────────────────────
const _K             := "res://assets/ui/PNG/"
const _PANEL_MAIN    := _K + "panel_brown.png"
const _PANEL_SOFT    := _K + "panelInset_beige.png"
const _PANEL_BEIGE   := _K + "panel_beige.png"
const _BTN_NORMAL    := _K + "buttonLong_brown.png"
const _BTN_PRESSED   := _K + "buttonLong_brown_pressed.png"
const _BTN_HOVER     := _K + "buttonLong_beige.png"
const _BTN_DISABLED  := _K + "buttonLong_grey.png"

# ── 9-patch margins for Kenney RPG pack ──────────────────────────────────────
const _PANEL_M   := 10   # panel margin
const _PANEL_C   := 12   # panel content margin
const _BTN_MH    := 14   # button horizontal margin
const _BTN_MV    := 8    # button vertical margin
const _BTN_CH    := 14   # button content horizontal
const _BTN_CV    := 6    # button content vertical


# ── Internal helpers ──────────────────────────────────────────────────────────

func _tex_panel(path: String, margin: int, content: int,
		fallback_bg: Color = PANEL_BG, fallback_border: Color = PANEL_BORDER) -> StyleBox:
	if not ResourceLoader.exists(path):
		return _flat_panel(fallback_bg, fallback_border, 10, 2)
	var tex := load(path) as Texture2D
	if tex == null:
		return _flat_panel(fallback_bg, fallback_border, 10, 2)
	var s := StyleBoxTexture.new()
	s.texture               = tex
	s.texture_margin_left   = margin
	s.texture_margin_right  = margin
	s.texture_margin_top    = margin
	s.texture_margin_bottom = margin
	s.content_margin_left   = content
	s.content_margin_right  = content
	s.content_margin_top    = content - 2
	s.content_margin_bottom = content - 2
	return s


func _tex_btn(path: String,
		fallback_bg: Color = Color(0.13, 0.105, 0.075, 0.96),
		fallback_border: Color = PANEL_BORDER_DIM) -> StyleBox:
	if not ResourceLoader.exists(path):
		return _flat_panel(fallback_bg, fallback_border, 8, 2)
	var tex := load(path) as Texture2D
	if tex == null:
		return _flat_panel(fallback_bg, fallback_border, 8, 2)
	var s := StyleBoxTexture.new()
	s.texture               = tex
	s.texture_margin_left   = _BTN_MH
	s.texture_margin_right  = _BTN_MH
	s.texture_margin_top    = _BTN_MV
	s.texture_margin_bottom = _BTN_MV
	s.content_margin_left   = _BTN_CH
	s.content_margin_right  = _BTN_CH
	s.content_margin_top    = _BTN_CV
	s.content_margin_bottom = _BTN_CV
	return s


func _flat_panel(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	return s


# ── Public API (signatures unchanged) ────────────────────────────────────────

## Returns Kenney texture panel for default colors, flat fallback for custom.
func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER,
		radius: int = 10, border_width: int = 2) -> StyleBox:
	if bg == PANEL_BG:
		return _tex_panel(_PANEL_MAIN, _PANEL_M, _PANEL_C)
	if bg == PANEL_BG_SOFT:
		# Also brown but slightly lighter — NOT the beige inset (too light)
		var s := _tex_panel(_PANEL_MAIN, _PANEL_M, _PANEL_C)
		if s is StyleBoxTexture:
			(s as StyleBoxTexture).modulate_color = Color(0.78, 0.72, 0.65, bg.a)
		return s
	# Custom color → flat with rounded corners (HUD bars, special panels)
	return _flat_panel(bg, border, radius, border_width)


## Flat button style used when a non-Kenney custom color is needed.
func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	return _flat_panel(bg, border, 8, 2)


## Applies full Kenney button theme to a Button node.
func style_button(button: Button, font_size: int = 15) -> void:
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color",          TEXT_MAIN)
	button.add_theme_color_override(&"font_hover_color",    Color(1.0, 0.95, 0.80, 1.0))
	button.add_theme_color_override(&"font_pressed_color",  TEXT_COIN)
	button.add_theme_color_override(&"font_disabled_color", Color(0.50, 0.46, 0.40, 1.0))
	button.add_theme_stylebox_override(&"normal",   _tex_btn(_BTN_NORMAL,   Color(0.13, 0.105, 0.075, 0.96), PANEL_BORDER_DIM))
	button.add_theme_stylebox_override(&"hover",    _tex_btn(_BTN_HOVER,    Color(0.19, 0.145, 0.090, 0.98), PANEL_BORDER))
	button.add_theme_stylebox_override(&"pressed",  _tex_btn(_BTN_PRESSED,  Color(0.09, 0.070, 0.050, 0.98), TEXT_COIN))
	# Disabled: grey texture darkened with modulate so it's visually unavailable
	var disabled_style := _tex_btn(_BTN_DISABLED, Color(0.06, 0.055, 0.050, 0.78), Color(0.18, 0.16, 0.13, 1.0))
	if disabled_style is StyleBoxTexture:
		(disabled_style as StyleBoxTexture).modulate_color = Color(0.35, 0.30, 0.25, 0.85)
	button.add_theme_stylebox_override(&"disabled", disabled_style)


func style_label(label: Label, color: Color = TEXT_MAIN,
		font_size: int = 20, outline_size: int = 4) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color",         color)
	label.add_theme_color_override(&"font_outline_color", OUTLINE)
	label.add_theme_constant_override(&"outline_size",    outline_size)


func style_label3d(label: Label3D, color: Color = TEXT_MAIN,
		font_size: int = 24, outline_size: int = 8) -> void:
	label.font_size      = font_size
	label.outline_size   = outline_size
	label.modulate       = color
	label.outline_modulate = OUTLINE
	label.no_depth_test  = true


func bar_bg_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BAR_BG
	mat.roughness    = 0.85
	return mat


func bar_fill_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = color
	mat.emission_enabled         = true
	mat.emission                 = color.darkened(0.55)
	mat.emission_energy_multiplier = 0.28
	mat.roughness                = 0.42
	return mat
