class_name GarrisonScreen
extends NodeDiorama
## GARNİZON / AĞIL KAMPI (gelistirme §12 — MoP Campsite): meta ilerleme artık
## metin menüsü değil, izometrik kamp adası. Ortada şenlik ateşi, etrafında
## tesis prop'ları; her tesisin üstünde seviye+bedel elması. Kalıntı harca →
## seviye KALICI artar (user://garrison.json).

signal closed

const IC_GOLD := preload("res://assets/icons/gold.svg")
const IC_SHIELD := preload("res://assets/icons/shield.svg")
const IC_ATK := preload("res://assets/icons/attack.svg")
const IC_DICE := preload("res://assets/icons/dice.svg")

var _left := false

## Tesisler (gelistirme §12 adlarıyla): alan → GameState meta seviyesi
func _facilities() -> Array:
	return [
		{"ad": "İkmal İstasyonu", "cell": Vector2i(0, 1),
			"ikon": IC_GOLD, "renk": Color(0.86, 0.72, 0.36),
			"etki": "+5 başlangıç altını", "lv": GameState.meta_gold_lv,
			"inc": func() -> void: GameState.meta_gold_lv += 1},
		{"ad": "Atölye", "cell": Vector2i(0, 3),
			"ikon": IC_SHIELD, "renk": Color(0.55, 0.70, 0.85),
			"etki": "+5 başlangıç sancak CAN'ı", "lv": GameState.meta_flag_lv,
			"inc": func() -> void: GameState.meta_flag_lv += 1},
		{"ad": "Talimhane", "cell": Vector2i(4, 0),
			"ikon": IC_ATK, "renk": Color(0.85, 0.50, 0.24),
			"etki": "+1 başlangıç Mevzi (AP)", "lv": GameState.meta_mevzi_lv,
			"inc": func() -> void: GameState.meta_mevzi_lv += 1},
		{"ad": "Değirmen", "cell": Vector2i(4, 3),
			"ikon": IC_DICE, "renk": Color(0.84, 0.52, 0.60),
			"etki": "+2 sefer başı zar", "lv": GameState.meta_degirmen_lv,
			"inc": func() -> void: GameState.meta_degirmen_lv += 1},
	]

func _cost(level: int) -> int:
	return (level + 1) * 10

func _ready() -> void:
	force_home_biome = true
	super()
	var cells := {}
	for y in 5:
		for x in 6:
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 4), Vector2i(5, 4)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(0, 1)] = 1
	cells[Vector2i(4, 0)] = 1
	build_island(cells)

	# ── Kamp prop'ları ──
	add_campfire(Vector2i(2, 2))
	add_tent(Vector2i(0, 1), Color(0.62, 0.50, 0.26))            # İkmal (sıcak sarı)
	add_flag(Vector2i(0, 3), true)                                # Atölye (sancak onarımı)
	add_glow_slab(Vector2i(0, 3), Color(0.07, 0.07, 0.08),
		Color(0.55, 0.70, 0.85), 0.35, 0.25)
	add_tent(Vector2i(4, 0), Color(0.55, 0.32, 0.24))             # Talimhane
	_add_windmill(Vector2i(4, 3))                                 # Değirmen
	add_dead_tree(Vector2i(3, 0), 7)
	add_mist(Vector2i(1, 0))
	add_mist(Vector2i(5, 2))
	add_sprite_prop("res://assets/units/kuzu.png", Vector2i(3, 3), 1.0)
	add_omni(Vector2i(0, 1), Color(1.0, 0.78, 0.42), 1.5, 1.3)

	set_description("GARNİZON",
		"Ağıl kampı. Kalıntı harca, tesisleri yükselt — etkiler her seferde kalıcı.")
	add_footer_button("← Geri", func() -> void:
		if not _left:
			_left = true
			closed.emit()
			queue_free())
	_refresh()

## Elmasları ve alt şeridi mevcut seviyelere/Kalıntıya göre yeniden kur
func _refresh() -> void:
	clear_choices()
	for f: Dictionary in _facilities():
		var cost := _cost(f["lv"])
		var lift := 1.85 if f["cell"] != Vector2i(4, 3) else 2.1   # değirmen yüksek
		var d := add_choice(cell_point(f["cell"], lift), f["ikon"],
			"%s Sv.%d · %d" % [f["ad"], f["lv"], cost], f["renk"],
			"%s — %s (bedel %d Kalıntı)" % [f["ad"], f["etki"], cost],
			_buy.bind(f))
		if GameState.meta_kalinti < cost:
			set_choice_enabled(d, false)
	set_footer("Kalıntı: %d  ·  soluk elmaslara gücün yetmiyor" % GameState.meta_kalinti)

func _buy(f: Dictionary) -> void:
	var cost := _cost(f["lv"])
	if GameState.meta_kalinti < cost:
		return
	GameState.meta_kalinti -= cost
	(f["inc"] as Callable).call()
	GameState.save_meta()
	AudioDirector.play_sfx(&"deploy_clunk", 0.08)
	# canlı geri bildirim: tesis adı + yeni seviye pop'u
	var pop := Label.new()
	pop.text = "%s → Sv.%d" % [f["ad"], int(f["lv"]) + 1]
	pop.add_theme_font_size_override("font_size", 46)
	pop.add_theme_color_override("font_color", (f["renk"] as Color).lightened(0.25))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.4)
	tw.tween_property(pop, "modulate:a", 0.0, 0.25)
	tw.tween_callback(pop.queue_free)
	_refresh()

## Değirmen prop'u: konik kule + dönen 4 kanat (zar tesisinin imzası)
func _add_windmill(c: Vector2i) -> Node3D:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	add_child(grp)
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.13
	tm.bottom_radius = 0.24
	tm.height = 0.95
	tm.radial_segments = 7
	tower.mesh = tm
	tower.material_override = _toon_mat(Color(0.50, 0.42, 0.30), Color(0.20, 0.16, 0.11))
	tower.position.y = 0.475
	grp.add_child(tower)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.17
	cm.height = 0.22
	cm.radial_segments = 7
	cap.mesh = cm
	cap.material_override = _toon_mat(Color(0.34, 0.26, 0.30), Color(0.14, 0.10, 0.12))
	cap.position.y = 1.06
	grp.add_child(cap)
	# kanat göbeği: kameraya dönük düzlemde döner
	var axis := Node3D.new()
	axis.position = Vector3(0.13, 0.98, 0.13)
	axis.rotation_degrees.y = 45.0     # kamera yaw'ına dik → kanatlar okunur
	grp.add_child(axis)
	for i in 4:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.44, 0.02)
		blade.mesh = bm
		blade.material_override = _toon_mat(Color(0.78, 0.72, 0.60), Color(0.30, 0.28, 0.22))
		var holder := Node3D.new()
		holder.rotation_degrees.z = 90.0 * i
		blade.position.y = 0.25
		holder.add_child(blade)
		axis.add_child(holder)
	var tw := axis.create_tween().set_loops()
	tw.tween_property(axis, "rotation_degrees:z", 360.0, 7.0).from(0.0)
	return grp
