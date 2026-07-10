class_name GarrisonScreen
extends CanvasLayer
## Garnizon (gelistirme B.3, A.10): Kalıntı ile kalıcı meta upgrade seviyeleri.
## Her seviye başlangıç durumunu güçlendirir (altın / bayrak CAN / Mevzi).

signal closed

var _root: Control

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.035, 0.05, 0.96)
	_root.add_child(bg)
	_build()

func _cost(level: int) -> int:
	return (level + 1) * 10

func _build() -> void:
	for c in _root.get_children():
		if c is CenterContainer:
			c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "GARNİZON"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var kal := Label.new()
	kal.text = "Kalıntı: %d" % GameState.meta_kalinti
	kal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kal.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	col.add_child(kal)

	col.add_child(_upgrade("Başlangıç Altını", "+5 altın", GameState.meta_gold_lv, func():
		GameState.meta_gold_lv += 1))
	col.add_child(_upgrade("Bayrak Dayanıklılığı", "+5 başlangıç CAN", GameState.meta_flag_lv, func():
		GameState.meta_flag_lv += 1))
	col.add_child(_upgrade("Seferberlik", "+1 başlangıç Mevzi", GameState.meta_mevzi_lv, func():
		GameState.meta_mevzi_lv += 1))
	col.add_child(_upgrade("Değirmen", "+2 sefer başı zar", GameState.meta_degirmen_lv, func():
		GameState.meta_degirmen_lv += 1))

	var back := Button.new()
	back.text = "← GERİ"
	back.custom_minimum_size = Vector2(0, 46)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): closed.emit(); queue_free())
	col.add_child(back)

func _upgrade(ad: String, etki: String, level: int, apply: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "%s (Sv.%d) — %s" % [ad, level, etki]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var cost := _cost(level)
	var b := Button.new()
	b.text = "Yükselt (%d)" % cost
	b.custom_minimum_size = Vector2(150, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = GameState.meta_kalinti < cost
	b.pressed.connect(func():
		if GameState.meta_kalinti >= cost:
			GameState.meta_kalinti -= cost
			apply.call()
			GameState.save_meta()
			_build())
	row.add_child(b)
	return row
