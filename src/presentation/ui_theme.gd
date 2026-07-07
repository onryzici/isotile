class_name UITheme
extends RefCounted
## Ortak koyu UI teması — referans ton: koyu panel, ince sıcak kenarlık,
## kırık beyaz metin. Godot varsayılan grisinin "tarayıcı oyunu" hissini kırar.

const TEXT := Color(0.87, 0.82, 0.7)
const TEXT_DIM := Color(0.6, 0.57, 0.5)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const BORDER := Color(0.32, 0.27, 0.2)
const BORDER_HOT := Color(0.85, 0.65, 0.3)

static func make() -> Theme:
	var theme := Theme.new()

	var normal := _box(PANEL_BG, BORDER)
	var hover := _box(Color(0.12, 0.11, 0.16, 0.96), BORDER_HOT)
	var pressed := _box(Color(0.16, 0.13, 0.1, 0.98), BORDER_HOT)
	var disabled := _box(Color(0.06, 0.06, 0.09, 0.85), Color(0.18, 0.16, 0.13))

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.75))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.92, 0.75))
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, BORDER))
	theme.set_stylebox("panel", "Panel", _box(PANEL_BG, BORDER))
	return theme

static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(10)
	return box
