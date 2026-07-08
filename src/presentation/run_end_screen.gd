class_name RunEndScreen
extends CanvasLayer
## Sefer sonu (gelistirme B.3, A.10): zafer (boss geçildi) veya bozgun (bayrak
## düştü). Kazanılan Kalıntı + Garnizon'a geç veya yeni sefer.

signal new_run
signal open_garrison

var _victory: bool
var _layers: int
var _earned: int

func setup(victory: bool, layers: int, earned: int) -> void:
	_victory = victory
	_layers = layers
	_earned = earned

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.make()
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.02, 0.04, 0.96)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(460, 0)
	center.add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "ZAFER!" if _victory else "SEFER SONA ERDİ"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if _victory else Color(0.85, 0.3, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var stats := Label.new()
	stats.text = "Geçilen katman: %d\nKazanılan Kalıntı: %d\nToplam Kalıntı: %d" % [
		_layers, _earned, GameState.meta_kalinti]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stats)

	var sub := Label.new()
	sub.text = "Başarısızlık bir tohumdur — Garnizon'da güçlen."
	sub.modulate = Color(1, 1, 1, 0.65)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var g := Button.new()
	g.text = "GARNİZON"
	g.custom_minimum_size = Vector2(0, 50)
	g.focus_mode = Control.FOCUS_NONE
	g.pressed.connect(func(): open_garrison.emit())
	col.add_child(g)
	var n := Button.new()
	n.text = "YENİ SEFER →"
	n.custom_minimum_size = Vector2(0, 50)
	n.focus_mode = Control.FOCUS_NONE
	n.pressed.connect(func(): new_run.emit())
	col.add_child(n)
