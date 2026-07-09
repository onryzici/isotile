class_name MainMenuScreen
extends Node
## Başlangıç menüsü (ana ekran). Atmosferik koyu arka plan + gotik başlık +
## Yeni Sefer / Devam Et / Garnizon / Çıkış. main.gd sinyalleri bağlar.

signal new_run
signal continue_run
signal open_garrison

var _ui: CanvasLayer
var _root: Control

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	_ui.add_child(_root)

	# Arka plan: radyal koyu gradyan + pus vinyet (savaş ekranıyla aynı dil)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://shaders/bg_gradient.gdshader")
	bg.material = bg_mat
	_root.add_child(bg)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = preload("res://shaders/fog_vignette.gdshader")
	fog.material = fog_mat
	_root.add_child(fog)

	# ── Tek ortalanmış dikey yığın: başlık + alt başlık + boşluk + butonlar ──
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER   # grubu dikey ortala
	stack.add_theme_constant_override("separation", 12)
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stack)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "PUS"
	title.add_theme_font_size_override("font_size", 132)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.58))
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.42, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)

	var sub := Label.new()
	sub.text = "dünyayı yutan kara sis inmeden önce"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.62, 0.58, 0.66))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 56)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gap)

	var has_save := FileAccess.file_exists(GameState.SAVE_PATH)
	if has_save:
		stack.add_child(_menu_button("SEFERE DEVAM", true, func() -> void: continue_run.emit()))
	stack.add_child(_menu_button("YENİ SEFER", not has_save, func() -> void:
		if has_save:
			_confirm_new_run()
		else:
			new_run.emit()))
	stack.add_child(_menu_button("GARNİZON", false, func() -> void: open_garrison.emit()))
	stack.add_child(_menu_button("MASAÜSTÜNE ÇIK", false, func() -> void: get_tree().quit()))

	var ver := Label.new()
	ver.text = "erken geliştirme sürümü"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.5, 0.47, 0.42, 0.7))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(ver)

func _menu_button(text: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	# Birincil buton (Devam/Yeni) altın vurgulu, diğerleri sade
	var accent := Color(0.85, 0.65, 0.3) if primary else Color(0.34, 0.29, 0.21)
	b.add_theme_stylebox_override("normal", _btn_box(Color(0.09, 0.085, 0.12, 0.94), accent))
	b.add_theme_stylebox_override("hover", _btn_box(Color(0.14, 0.12, 0.10, 0.97), Color(0.9, 0.7, 0.35)))
	b.add_theme_stylebox_override("pressed", _btn_box(Color(0.16, 0.13, 0.10, 0.98), Color(1.0, 0.82, 0.45)))
	b.add_theme_color_override("font_color", Color(0.90, 0.82, 0.62) if not primary else Color(0.98, 0.90, 0.68))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.76))
	b.pressed.connect(cb)
	return b

func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(10)
	return box

## Kayıt varken "Yeni Sefer": mevcut seferi silme onayı
func _confirm_new_run() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 18)
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(380, 0)
	pad.add_child(col)
	var q := Label.new()
	q.text = "Mevcut sefer silinecek. Emin misin?"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 20)
	col.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var yes := _menu_button("YENİ SEFER", true, func() -> void: new_run.emit())
	yes.custom_minimum_size = Vector2(160, 48)
	row.add_child(yes)
	var no := _menu_button("VAZGEÇ", false, func() -> void:
		dim.queue_free())
	no.custom_minimum_size = Vector2(160, 48)
	row.add_child(no)
