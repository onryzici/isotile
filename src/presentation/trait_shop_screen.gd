class_name TraitShopScreen
extends NodeDiorama
## Nitelik Dükkanı (gelistirme §5, diyorama): iki taş kaidede iki tabya sunulur.
## Alt şeritten kuzu seç (boş tabya slotu olan) → kaidelerin üstünde 2 elmas →
## seçilen tabya birime KALICI işlenir. Bedava-seçim (MoP trait shop).

signal closed

const IC_TRAIT := preload("res://assets/icons/trait.svg")
const ACCENT := Color(0.65, 0.72, 0.35)

var _offers: Array = []            # 2 TraitData
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
	cells[Vector2i(3, 0)] = 1
	build_island(cells)

	# iki sunum kaidesi (yükseltide) + usta figürü + atölye ateşi
	_add_pedestal(Vector2i(1, 0))
	_add_pedestal(Vector2i(3, 0))
	add_glow_slab(Vector2i(2, 2), Color(0.09, 0.08, 0.05), Color(0.95, 0.72, 0.3), 0.5, 0.2)
	add_sprite_prop("res://assets/units/suikastci.png", Vector2i(0, 2), 1.05)
	add_mist(Vector2i(4, 1), Color(0.8, 0.82, 0.7, 0.1))
	add_omni(Vector2i(2, 0), Color(0.9, 0.9, 0.6), 1.8, 1.4)

	_roll_offers()
	set_description("NİTELİK DÜKKANI",
		"Usta iki tabya sunuyor — birini bir kuzuya KALICI işler. Önce kuzuyu seç.")
	set_footer(_offer_text())
	_build_unit_row()
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

## Taş sunum kaidesi (toon sütun + üst plaka)
func _add_pedestal(c: Vector2i) -> void:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var col := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.3, 0.5, 0.3)
	col.mesh = cm
	col.material_override = _toon_mat(Color(0.4, 0.4, 0.44), Color(0.2, 0.2, 0.24))
	col.position.y = 0.25
	grp.add_child(col)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.08, 0.42)
	top.mesh = tm
	top.material_override = _toon_mat(Color(0.5, 0.5, 0.55), Color(0.25, 0.25, 0.3))
	top.position.y = 0.54
	grp.add_child(top)
	add_child(grp)

## Havuzdan 2 farklı tabya çek (seed'li)
func _roll_offers() -> void:
	var pool: Array = Database.get_all("traits").duplicate()
	RNG.shuffle(pool)
	_offers = pool.slice(0, 2)

func _offer_text() -> String:
	var parts: Array[String] = []
	for t: TraitData in _offers:
		parts.append("✦ %s — %s" % [t.ad, t.aciklama])
	return "\n".join(parts)

## Alt şerit: kadro butonları (boş tabya slotu olmayanlar soluk)
func _build_unit_row() -> void:
	for b in _unit_btns:
		b.queue_free()
	_unit_btns.clear()
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 84)
		b.focus_mode = Control.FOCUS_NONE
		var slots := "%d/%d slot" % [p.base_traits.size(), p.tabya_slotu]
		b.text = "%s\n%s\n%s" % [p.ad, p.stat_text(), slots]
		b.tooltip_text = p.trait_names() if p.trait_names() != "" else "Tabyasız"
		b.disabled = p.base_traits.size() >= p.tabya_slotu
		if not b.disabled:
			b.pressed.connect(_pick_unit.bind(i))
		_footer_row.add_child(b)
		_footer_row.move_child(b, _unit_btns.size())
		_unit_btns.append(b)

## Kuzu seçildi: figür ortaya, kaidelerin üstünde tabya elmasları
func _pick_unit(i: int) -> void:
	_selected = i
	var p: PieceData = GameState.squad[i]
	if _unit_sprite:
		_unit_sprite.queue_free()
		_unit_sprite = null
	if p.mesh_id != &"":
		_unit_sprite = add_sprite_prop("res://assets/units/%s.png" % p.mesh_id,
			Vector2i(2, 2), 1.1)
	clear_choices()
	var anchors := [cell_point(Vector2i(1, 0), 1.0), cell_point(Vector2i(3, 0), 1.0)]
	for k in mini(2, _offers.size()):
		var t: TraitData = _offers[k]
		add_choice(anchors[k], IC_TRAIT, t.ad, ACCENT,
			"%s — %s" % [t.ad, t.aciklama], _apply.bind(t))
	set_footer("%s  ·  %s   —   tabyayı seç\n%s" % [p.ad, p.stat_text(), _offer_text()])

func _apply(t: TraitData) -> void:
	if not GameState.give_trait(_selected, t):
		return
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	var pop := Label.new()
	pop.text = "✦ %s işlendi" % t.ad
	pop.add_theme_font_size_override("font_size", 48)
	pop.add_theme_color_override("font_color", ACCENT.lightened(0.25))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.45)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
