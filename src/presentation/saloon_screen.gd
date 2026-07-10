class_name SaloonScreen
extends NodeDiorama
## Meydan / Talim (gelistirme §7, MoP Bootcamp — diyorama): KUMAR masası.
## Kuzu seç → statları (Saldırı/Can/Hız) seed'li yeniden dağıtılır VE yanına
## bir bonus gelir: Upgrade (+stat) YA DA Söylenti (§14, zayıf kalıcı pasif).
## Beğenmedin mi? 1 zar harca, yeniden çevir. KABUL edersen geri dönüş yok.

signal closed

const IC_DICE := preload("res://assets/icons/dice.svg")
const IC_TRAIT := preload("res://assets/icons/trait.svg")
const FELT := Color(0.84, 0.52, 0.6)
const UNIT_CELL := Vector2i(2, 2)   # kuzunun masaya sürüldüğü hücre (zar elması tam üstünde)

const UP_OPTS := [
	{"alan": &"saldiri", "ad": "+2 Saldırı", "miktar": 2},
	{"alan": &"can", "ad": "+3 Can", "miktar": 3},
	{"alan": &"hiz", "ad": "+1 Hız", "miktar": 1},
]

var _selected := -1
var _unit_sprite: Node3D
var _unit_btns: Array = []
var _preview := {}          # {a,c,h, bonus_tip:"up"/"rumor", up:Dictionary, rumor:TraitData}
var _accept_d: Control
var _reroll_d: Control

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 3)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(2, 0)] = 1
	build_island(cells)

	_add_dice_table(Vector2i(2, 0))
	add_glow_slab(Vector2i(2, 2), Color(0.10, 0.07, 0.08), FELT, 0.5, 0.2)
	add_sprite_prop("res://assets/units/baltaci.png", Vector2i(0, 2), 1.05)
	add_tent(Vector2i(4, 1), Color(0.5, 0.38, 0.28))
	add_mist(Vector2i(1, 3), Color(0.85, 0.75, 0.7, 0.1))
	add_omni(Vector2i(2, 0), Color(1.0, 0.7, 0.55), 2.2, 1.2)

	set_description("MEYDAN — TALİM KUMARI",
		"Zar masası kuzunun kaderini yeniden yazar: statlar YENİDEN dağılır,\nyanında bir armağan gelir. Ateşle oynamak budur.")
	set_footer("Masaya sürülecek kuzuyu seç")
	_build_unit_row()
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

## Zar masası: keçe kaplı masa + üstünde iki minik zar
func _add_dice_table(c: Vector2i) -> void:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.72, 0.1, 0.5)
	top.mesh = tm
	top.material_override = _toon_mat(Color(0.28, 0.4, 0.3), Color(0.24, 0.17, 0.1))
	top.position.y = 0.42
	grp.add_child(top)
	var leg := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.56, 0.38, 0.36)
	leg.mesh = lm
	leg.material_override = _toon_mat(Color(0.3, 0.22, 0.14), Color(0.16, 0.12, 0.08))
	leg.position.y = 0.19
	grp.add_child(leg)
	for i in 2:
		var die := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.11, 0.11, 0.11)
		die.mesh = dm
		die.material_override = _toon_mat(Color(0.9, 0.87, 0.78), Color(0.6, 0.58, 0.5))
		die.position = Vector3(-0.12 + i * 0.22, 0.525, 0.05 - i * 0.12)
		die.rotation_degrees.y = 20.0 + i * 35.0
		grp.add_child(die)
	add_child(grp)

func _build_unit_row() -> void:
	for b in _unit_btns:
		b.queue_free()
	_unit_btns.clear()
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 84)
		b.focus_mode = Control.FOCUS_NONE
		var r := "℞ %s" % p.rumor.ad if p.rumor else ""
		b.text = "%s\n%s\n%s" % [p.ad, p.stat_text(), r]
		b.tooltip_text = p.rumor.aciklama if p.rumor else ""
		b.pressed.connect(_pick_unit.bind(i))
		_footer_row.add_child(b)
		_footer_row.move_child(b, _unit_btns.size())
		_unit_btns.append(b)

## Kuzu masaya sürüldü: ilk çevirme bedava
func _pick_unit(i: int) -> void:
	_selected = i
	var p: PieceData = GameState.squad[i]
	if _unit_sprite:
		_unit_sprite.queue_free()
		_unit_sprite = null
	if p.mesh_id != &"":
		_unit_sprite = add_sprite_prop("res://assets/units/%s.png" % p.mesh_id,
			UNIT_CELL, 1.1)
	_roll_preview()
	if _accept_d == null:
		_accept_d = add_choice(cell_point(Vector2i(3, 1), 1.0), IC_TRAIT,
			"KABUL", Color(0.83, 0.66, 0.28), "Yeni kaderi mühürle", _accept)
		# Zar kuzunun tam kafasının üstünde döner — bedel yazısı yok, sayaç alt şeritte.
		_reroll_d = add_choice(cell_point(UNIT_CELL, 1.62), IC_DICE, "",
			Color(0.34, 0.55, 0.86), "1 zar harca — kaderi yeniden çevir", _reroll)
		set_choice_spin(_reroll_d, 1.5)
	_refresh()

## Seed'li kader çevirimi: stat havuzu yeniden dağılır + bonus (upgrade VEYA söylenti)
func _roll_preview() -> void:
	var p: PieceData = GameState.squad[_selected]
	var pool := p.saldiri + p.can + p.hiz
	var wa := RNG.randf() + 0.25
	var wc := RNG.randf() + 0.55
	var wh := RNG.randf() + 0.3
	var sw := wa + wc + wh
	var c := clampi(int(round(pool * wc / sw)), 2, pool - 2)
	var a := clampi(int(round(pool * wa / sw)), 0, pool - c - 1)
	var h := pool - c - a
	_preview = {"a": a, "c": c, "h": h}
	if RNG.randi_range(0, 1) == 0 and p.upgrades < 2:
		_preview["bonus_tip"] = "up"
		_preview["up"] = RNG.pick(UP_OPTS)
	else:
		_preview["bonus_tip"] = "rumor"
		_preview["rumor"] = RNG.pick(Database.get_all("rumors"))

func _refresh() -> void:
	var p: PieceData = GameState.squad[_selected]
	var bonus: String
	if _preview["bonus_tip"] == "up":
		bonus = "Armağan: %s (upgrade)" % _preview["up"]["ad"]
	elif _preview["rumor"] != null:
		bonus = "Söylenti: %s — %s" % [_preview["rumor"].ad, _preview["rumor"].aciklama]
	else:
		bonus = "Armağan yok"
	set_footer("%s:  %s  →  %d/%d/%d\n%s\nZar: %d  ·  kafasının üstündeki zara bas, kaderi yeniden çevir" \
		% [p.ad, p.stat_text(), _preview["a"], _preview["c"], _preview["h"], bonus, GameState.zar])
	set_choice_enabled(_reroll_d, GameState.zar > 0)

## Mühürle: statlar + bonus uygulanır → kapan
func _accept() -> void:
	var p: PieceData = GameState.squad[_selected]
	GameState.apply_gamble(_selected, _preview["a"], _preview["c"], _preview["h"])
	var bonus_ad := ""
	if _preview["bonus_tip"] == "up":
		GameState.upgrade_unit(_selected, _preview["up"]["alan"], _preview["up"]["miktar"])
		bonus_ad = _preview["up"]["ad"]
	elif _preview["rumor"] != null:
		GameState.set_rumor(_selected, _preview["rumor"])
		bonus_ad = "℞ %s" % _preview["rumor"].ad
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	_accept_d = null
	_reroll_d = null
	var pop := Label.new()
	pop.text = "%s  %d/%d/%d\n%s" % [p.ad, _preview["a"], _preview["c"], _preview["h"], bonus_ad]
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_font_size_override("font_size", 44)
	pop.add_theme_color_override("font_color", FELT.lightened(0.25))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.6)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())

## 1 zar → kader yeniden çevrilir
func _reroll() -> void:
	if not GameState.spend_zar():
		return
	set_choice_enabled(_accept_d, false)
	set_choice_enabled(_reroll_d, false)
	DiceRoll.play(self, 1 + randi() % 6, func() -> void:
		_roll_preview()
		set_choice_enabled(_accept_d, true)
		_refresh())
