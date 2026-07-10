class_name GallowsScreen
extends NodeDiorama
## Darağacı (gelistirme §5, diyorama): bir kuzuyu İNFAZ et → tabyaları başka
## kuzuya geçer (sığdığı kadar). Deste inceltme + tabya taşıma tek düğümde.
## Akış: alt şeritten kurban seç → mirasçı seç → darağacının üstünde İNFAZ elması.

signal closed

const IC_GALLOWS := preload("res://assets/icons/gallows.svg")
const DOOM := Color(0.62, 0.30, 0.26)

var _victim := -1
var _heir := -1
var _unit_btns: Array = []
var _victim_sprite: Node3D

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(0, 3), Vector2i(4, 3)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(2, 0)] = 1
	build_island(cells)

	_add_gallows(Vector2i(2, 0))
	add_glow_slab(Vector2i(2, 1), Color(0.09, 0.05, 0.05), DOOM, 0.5, 0.25)
	add_dead_tree(Vector2i(4, 0), 5)
	add_dead_tree(Vector2i(0, 2), 6)
	add_mist(Vector2i(1, 3), Color(0.7, 0.68, 0.75, 0.14))
	add_mist(Vector2i(4, 1))
	add_omni(Vector2i(2, 0), Color(0.85, 0.4, 0.3), 1.5, 1.6)

	set_description("DARAĞACI",
		"Bir kuzu sürü için feda edilir — tabyaları seçtiğin mirasçıya geçer.")
	set_footer("Önce KURBANI seç (tabyası olan)")
	_build_unit_row()
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

## Darağacı prop'u: iki direk + kiriş + sarkan ilmek (toon kutular)
func _add_gallows(c: Vector2i) -> void:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var wood := Color(0.26, 0.19, 0.12)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 1.35, 0.12)
	post.mesh = pm
	post.material_override = _toon_mat(wood, wood.darkened(0.5))
	post.position = Vector3(-0.32, 0.675, 0)
	grp.add_child(post)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.85, 0.1, 0.12)
	beam.mesh = bm
	beam.material_override = _toon_mat(wood, wood.darkened(0.5))
	beam.position = Vector3(0.06, 1.3, 0)
	grp.add_child(beam)
	var brace := MeshInstance3D.new()
	var brm := BoxMesh.new()
	brm.size = Vector3(0.08, 0.42, 0.08)
	brace.mesh = brm
	brace.material_override = _toon_mat(wood, wood.darkened(0.5))
	brace.position = Vector3(-0.12, 1.12, 0)
	brace.rotation_degrees.z = 45.0
	grp.add_child(brace)
	var rope := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.03, 0.3, 0.03)
	rope.mesh = rm
	rope.material_override = _toon_mat(Color(0.55, 0.48, 0.34))
	rope.position = Vector3(0.36, 1.1, 0)
	grp.add_child(rope)
	var loop := MeshInstance3D.new()
	var lm := TorusMesh.new()
	lm.inner_radius = 0.05
	lm.outer_radius = 0.09
	loop.mesh = lm
	loop.material_override = _toon_mat(Color(0.55, 0.48, 0.34))
	loop.position = Vector3(0.36, 0.9, 0)
	grp.add_child(loop)
	add_child(grp)

## Alt şerit: adım 1 kurban (tabyalı + kadro ≥2), adım 2 mirasçı (kurban dışı)
func _build_unit_row() -> void:
	for b in _unit_btns:
		b.queue_free()
	_unit_btns.clear()
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 84)
		b.focus_mode = Control.FOCUS_NONE
		var rol := ""
		if i == _victim:
			rol = "☠ KURBAN"
		b.text = "%s\n%s\n%s" % [p.ad, p.trait_names() if p.trait_names() != "" else "tabyasız", rol]
		b.tooltip_text = p.stat_text()
		if _victim < 0:
			b.disabled = p.base_traits.is_empty() or GameState.squad.size() < 2
			if not b.disabled:
				b.pressed.connect(_pick_victim.bind(i))
		else:
			b.disabled = i == _victim
			if not b.disabled:
				b.pressed.connect(_pick_heir.bind(i))
		_footer_row.add_child(b)
		_footer_row.move_child(b, _unit_btns.size())
		_unit_btns.append(b)

func _pick_victim(i: int) -> void:
	_victim = i
	var p: PieceData = GameState.squad[i]
	if p.mesh_id != &"" and _victim_sprite == null:
		_victim_sprite = add_sprite_prop("res://assets/units/%s.png" % p.mesh_id,
			Vector2i(2, 1), 1.05)
	set_footer("Kurban: %s (%s)  —  şimdi MİRASÇIYI seç" % [p.ad, p.trait_names()])
	_build_unit_row()

func _pick_heir(i: int) -> void:
	_heir = i
	var v: PieceData = GameState.squad[_victim]
	var h: PieceData = GameState.squad[_heir]
	set_footer("%s infaz edilecek → tabyaları %s'e geçer (sığdığı kadar)" % [v.ad, h.ad])
	clear_choices()
	add_choice(cell_point(Vector2i(2, 0), 1.35), IC_GALLOWS, "İNFAZ", DOOM,
		"%s → %s: geri dönüşü yok" % [v.ad, h.ad], _execute)

## İnfaz: kurbanın tabyaları mirasçının boş slotlarına, kurban kadrodan çıkar
func _execute() -> void:
	var v: PieceData = GameState.squad[_victim]
	var moved: Array[String] = []
	for t: TraitData in v.base_traits:
		if GameState.give_trait(_heir, t):
			moved.append(t.ad)
	GameState.remove_unit(_victim)
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	if _victim_sprite:
		# kurban görselini karart + eriterek yok et
		var tw0 := create_tween()
		tw0.tween_property(_victim_sprite, "scale", Vector3(0.01, 0.01, 0.01), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var pop := Label.new()
	pop.text = "☠ %s feda edildi\n%s" % [v.ad,
		("→ " + ", ".join(moved)) if not moved.is_empty() else "(tabya sığmadı)"]
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_font_size_override("font_size", 42)
	pop.add_theme_color_override("font_color", DOOM.lightened(0.35))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.7)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
