class_name MapScreen
extends Node
## Bölge haritası (CLAUDE.md §2, M2): alttan üste katmanlar, sıradaki
## katmandan düğüm seç. Olay düğümü burada overlay kartla çözülür (§13).

var _ui: CanvasLayer
var _root: Control

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build()

func _build() -> void:
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	_ui.add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color("0d0f1a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = preload("res://shaders/fog_vignette.gdshader")
	fog.material = fog_mat
	_root.add_child(fog)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "BÖLGE 1 — PUS ORMANI"
	title.add_theme_font_size_override("font_size", 30)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_root.add_child(title)

	var info := Label.new()
	info.text = "Altın: %d      Bölük: %d birim" % [GameState.gold, GameState.squad.size()]
	info.add_theme_font_size_override("font_size", 20)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 18)
	_root.add_child(info)

	# Kumandan seçimi (§B.0/4): tıkla → 2 kumandan arasında geçiş
	var cmd_names := {&"cesur": "Cesur Serdar ⚡", &"bilge": "Bilge Kâhin ✚"}
	var cmd_btn := Button.new()
	cmd_btn.text = "Kumandan: %s" % cmd_names.get(GameState.commander_id, "Cesur Serdar ⚡")
	cmd_btn.focus_mode = Control.FOCUS_NONE
	cmd_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	cmd_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cmd_btn.pressed.connect(func() -> void:
		GameState.commander_id = &"bilge" if GameState.commander_id == &"cesur" else &"cesur"
		_build())
	_root.add_child(cmd_btn)

	# Katmanlar: alttan (başlangıç) üste (boss). VBox'ı ters doldur.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	var layers: Array = Encounters.MAP_TEMPLATE
	for li in range(layers.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		for node: Dictionary in layers[li]:
			var btn := Button.new()
			btn.text = node["ad"]
			btn.custom_minimum_size = Vector2(150, 52)
			btn.focus_mode = Control.FOCUS_NONE
			if li < GameState.layer_index:
				btn.disabled = true
				btn.modulate = Color(1, 1, 1, 0.35)   # geçildi
			elif li > GameState.layer_index:
				btn.disabled = true                    # henüz uzak
			else:
				btn.modulate = Color(1.0, 0.95, 0.8)   # seçilebilir
				btn.pressed.connect(_on_node_pressed.bind(node))
			row.add_child(btn)

	var hint := Label.new()
	hint.text = "Parlayan düğümü seç. Ölen birimler yaralı (1 CAN) döner — Şifahane'yi unutma."
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.add_theme_font_size_override("font_size", 15)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(hint)

func _on_node_pressed(node: Dictionary) -> void:
	if node["type"] == &"olay":
		_show_event()
	else:
		EventBus.map_node_selected.emit(node)

# ---------------------------------------------------------------- olay kartı (§13)
## Dallanan olay havuzu: rastgele bir olay + seçim → tipli etki.

const EVENTS := [
	{"baslik": "Pus İçinde Bir Yaralı Asker",
	 "metin": "Sisin içinden bir inilti geliyor. Mızrağına yaslanmış bir asker size bakıyor.",
	 "secenekler": [
		{"ad": "İyileştir (−5 Altın): asker katılır", "sart": 5, "etki": "recruit_mizrak"},
		{"ad": "Soy (+20 Altın, bayrak −3 CAN)", "etki": "yagma"},
		{"ad": "Geç", "etki": "none"}]},
	{"baslik": "Terk Edilmiş Sunak",
	 "metin": "Kanlı bir taş sunak; üstünde soluk bir kalıntı parıldıyor.",
	 "secenekler": [
		{"ad": "Kalıntıyı al (bayrak −5 CAN)", "etki": "relic_kan"},
		{"ad": "Dua et (+8 bayrak CAN)", "etki": "heal_flag"},
		{"ad": "Geç", "etki": "none"}]},
	{"baslik": "Gezgin Tüccar",
	 "metin": "Kapüşonlu bir tüccar cübbesinin altından bir şeyler gösteriyor.",
	 "secenekler": [
		{"ad": "Kalıntı al (−15 Altın)", "sart": 15, "etki": "buy_relic"},
		{"ad": "Erzak al (−10 Altın: bölük iyileşir)", "sart": 10, "etki": "heal_squad_paid"},
		{"ad": "Geç", "etki": "none"}]},
	{"baslik": "Pus Fırtınası",
	 "metin": "Yoğun pus çöküyor; içinden bir şeyler fısıldıyor.",
	 "secenekler": [
		{"ad": "İçine dal (½: +25 Altın / bayrak −4)", "etki": "riziko"},
		{"ad": "Sığın (−3 Altın)", "sart": 3, "etki": "gold_m3"},
		{"ad": "Geç", "etki": "none"}]},
]

func _show_event() -> void:
	var ev: Dictionary = RNG.pick(EVENTS)
	var overlay := CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(480, 0)
	panel.add_child(vbox)
	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = ev["baslik"]
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var body := Label.new()
	body.text = ev["metin"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)
	for opt: Dictionary in ev["secenekler"]:
		var b := Button.new()
		b.text = opt["ad"]
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = GameState.gold < int(opt.get("sart", 0))
		b.pressed.connect(_apply_event.bind(opt["etki"]))
		vbox.add_child(b)

func _apply_event(etki: String) -> void:
	var cap := GameState.PLAYER_FLAG_MAX + GameState.meta_flag_lv * 5
	match etki:
		"recruit_mizrak":
			GameState.gold -= 5
			GameState.add_unit(Database.get_resource("pieces", &"mizrakli"))
		"yagma":
			GameState.gold += 20
			GameState.player_flag_hp = maxi(1, GameState.player_flag_hp - 3)
		"relic_kan":
			GameState.player_flag_hp = maxi(1, GameState.player_flag_hp - 5)
			_grant_random_relic()
		"heal_flag":
			GameState.player_flag_hp = mini(cap, GameState.player_flag_hp + 8)
		"buy_relic":
			GameState.gold -= 15
			_grant_random_relic()
		"heal_squad_paid":
			GameState.gold -= 10
			GameState.heal_all()
		"riziko":
			if RNG.randi_range(0, 1) == 0:
				GameState.gold += 25
			else:
				GameState.player_flag_hp = maxi(1, GameState.player_flag_hp - 4)
		"gold_m3":
			GameState.gold -= 3
		_:
			pass
	_finish_event()

func _grant_random_relic() -> void:
	var owned := {}
	for r in GameState.relics:
		owned[r.id] = true
	var avail: Array = []
	for r: RelicData in Database.get_all("relics"):
		if not owned.has(r.id):
			avail.append(r)
	if not avail.is_empty():
		GameState.relics.append(RNG.pick(avail))

func _finish_event() -> void:
	GameState.layer_index += 1
	_build()   # haritayı yenile
