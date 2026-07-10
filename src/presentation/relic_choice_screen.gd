class_name RelicChoiceScreen
extends NodeDiorama
## Yadigar Dükkanı (gelistirme §10, diyorama): iki kaidede iki parlayan emanet —
## BEDAVA birini seç (MoP relic shop). Altınlı dükkandan ayrı, seçim baskısı burada:
## ikisi de iyi, tek hak.

signal closed

const IC_GEM := preload("res://assets/icons/gem.svg")
const GOLD := Color(0.88, 0.78, 0.42)

var _offers: Array = []

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 3), Vector2i(4, 3)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(1, 1)] = 1
	cells[Vector2i(3, 1)] = 1
	build_island(cells)

	# iki emanet kaidesi (altın parıltılı) + tüccar figürü
	_add_pedestal(Vector2i(1, 1))
	_add_pedestal(Vector2i(3, 1))
	add_glow_slab(Vector2i(1, 1), Color(0.1, 0.09, 0.05), GOLD, 0.55, 0.12)
	add_glow_slab(Vector2i(3, 1), Color(0.1, 0.09, 0.05), GOLD, 0.55, 0.12)
	add_sprite_prop("res://assets/units/priest.png", Vector2i(2, 3), 1.0)
	add_mist(Vector2i(0, 1), Color(0.85, 0.8, 0.65, 0.1))
	add_omni(Vector2i(1, 1), Color(1.0, 0.85, 0.5), 1.6, 1.0)
	add_omni(Vector2i(3, 1), Color(1.0, 0.85, 0.5), 1.6, 1.0)

	_roll_offers()
	set_description("YADİGAR DÜKKANI",
		"Kapüşonlu tüccar iki emanet sunuyor — biri senin, bedava. Ama yalnız biri.")
	if _offers.is_empty():
		set_footer("Raflar boş — sahip olmadığın yadigar kalmadı.")
	else:
		var anchors := [cell_point(Vector2i(1, 1), 1.05), cell_point(Vector2i(3, 1), 1.05)]
		var parts: Array[String] = []
		for k in _offers.size():
			var r: RelicData = _offers[k]
			add_choice(anchors[k], IC_GEM, r.ad, GOLD,
				"%s — %s" % [r.ad, r.aciklama], _pick.bind(r))
			parts.append("✦ %s — %s" % [r.ad, r.aciklama])
		set_footer("\n".join(parts))
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

func _add_pedestal(c: Vector2i) -> void:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var col := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.3, 0.5, 0.3)
	col.mesh = cm
	col.material_override = _toon_mat(Color(0.42, 0.38, 0.3), Color(0.22, 0.2, 0.16))
	col.position.y = 0.25
	grp.add_child(col)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.08, 0.42)
	top.mesh = tm
	top.material_override = _toon_mat(Color(0.52, 0.47, 0.38), Color(0.26, 0.24, 0.2))
	top.position.y = 0.54
	grp.add_child(top)
	add_child(grp)

## Sahip olunmayanlardan seed'li 2 teklif
func _roll_offers() -> void:
	var owned := {}
	for r in GameState.relics:
		owned[r.id] = true
	var avail: Array = []
	for r: RelicData in Database.get_all("relics"):
		if not owned.has(r.id):
			avail.append(r)
	RNG.shuffle(avail)
	_offers = avail.slice(0, 2)

func _pick(r: RelicData) -> void:
	GameState.relics.append(r)
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	var pop := Label.new()
	pop.text = "✦ %s" % r.ad
	pop.add_theme_font_size_override("font_size", 48)
	pop.add_theme_color_override("font_color", GOLD.lightened(0.2))
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
