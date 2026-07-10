class_name ShamanScreen
extends NodeDiorama
## Şaman Çadırı (gelistirme §9, diyorama): mor-yeşil büyülü çadır adası.
## Alt şeritten kuzu seç → seçilen birim çadırın önüne çıkar → çadır üstünde
## 2 elmas yükseltme seçeneği (+2 Saldırı / +3 Can / +1 Hız'dan seed'li 2'si).
## Her birim EN ÇOK 2 kez yükseltilir (◆ pip).

signal closed

const IC_ATK := preload("res://assets/icons/attack.svg")
const IC_HP := preload("res://assets/icons/health.svg")
const IC_SPD := preload("res://assets/icons/speed.svg")
const MYSTIC := Color(0.42, 0.72, 0.52)

const UPGRADES := [
	{"alan": &"saldiri", "ad": "+2 Saldırı", "miktar": 2, "ikon": "atk",
		"renk": Color(0.85, 0.5, 0.24)},
	{"alan": &"can", "ad": "+3 Can", "miktar": 3, "ikon": "hp",
		"renk": Color(0.78, 0.32, 0.32)},
	{"alan": &"hiz", "ad": "+1 Hız", "miktar": 1, "ikon": "spd",
		"renk": Color(0.36, 0.56, 0.85)},
]

var _selected := -1
var _unit_sprite: Node3D
var _unit_btns: Array = []

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(4, 3)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(1, 0)] = 1
	build_island(cells)

	# çadır arkada tepede, önünde büyü plakası; şaman plakanın başında
	add_tent(Vector2i(1, 0), Color(0.46, 0.30, 0.54))
	add_glow_slab(Vector2i(2, 1), Color(0.06, 0.09, 0.07), MYSTIC, 0.7, 0.5)
	add_sprite_prop("res://assets/units/priest.png", Vector2i(0, 2), 1.05)
	add_dead_tree(Vector2i(4, 0), 3)
	add_mist(Vector2i(0, 3))
	add_mist(Vector2i(4, 1))
	add_omni(Vector2i(1, 0), Color(0.5, 0.9, 0.6), 2.0, 1.3)

	set_description("ŞAMAN ÇADIRI",
		"Şaman bir kuzuya el basacak — statı KALICI büyür. Her birim en çok 2 kez.")
	set_footer("Aşağıdan bir kuzu seç")
	_build_unit_row()
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

## Alt şerit: kadro butonları (yükseltme pipleri ◆ ile)
func _build_unit_row() -> void:
	for b in _unit_btns:
		b.queue_free()
	_unit_btns.clear()
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 84)
		b.focus_mode = Control.FOCUS_NONE
		var pips := "◆".repeat(p.upgrades) + "◇".repeat(maxi(0, 2 - p.upgrades))
		b.text = "%s\n%s\n%s" % [p.ad, p.stat_text(), pips]
		b.disabled = p.upgrades >= 2
		if not b.disabled:
			b.pressed.connect(_pick_unit.bind(i))
		_footer_row.add_child(b)
		_footer_row.move_child(b, _unit_btns.size())   # Geç butonu hep sonda
		_unit_btns.append(b)

## Birim seçildi: figürü çadırın önüne çıkar + 2 elmas seçenek göster
func _pick_unit(i: int) -> void:
	_selected = i
	var p: PieceData = GameState.squad[i]
	set_footer("%s  ·  %s   —  şamanın sunduğu iki güçten birini seç" % [p.ad, p.stat_text()])
	if _unit_sprite:
		_unit_sprite.queue_free()
		_unit_sprite = null
	if p.mesh_id != &"":
		_unit_sprite = add_sprite_prop("res://assets/units/%s.png" % p.mesh_id,
			Vector2i(2, 1), 1.1)
	clear_choices()
	var opts: Array = UPGRADES.duplicate()
	RNG.shuffle(opts)
	# elmaslar seçilen birimin iki yanında (x−z farklı kolonlar — çakışmaz)
	var anchors := [cell_point(Vector2i(3, 1), 1.35), cell_point(Vector2i(2, 2), 1.3)]
	for k in 2:
		var opt: Dictionary = opts[k]
		add_choice(anchors[k], _icon_for(opt["ikon"]), opt["ad"], opt["renk"],
			"%s — kalıcı" % opt["ad"], _apply.bind(opt))

func _icon_for(key: String) -> Texture2D:
	match key:
		"atk": return IC_ATK
		"hp": return IC_HP
	return IC_SPD

## Uygula + canlı stat pop → kapan
func _apply(opt: Dictionary) -> void:
	GameState.upgrade_unit(_selected, opt["alan"], opt["miktar"])
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	var pop := Label.new()
	pop.text = opt["ad"]
	pop.add_theme_font_size_override("font_size", 54)
	pop.add_theme_color_override("font_color", opt["renk"].lightened(0.2))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.25, 1.25), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.45)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
