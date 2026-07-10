class_name MapScreen
extends Node
## Bölge haritası (CLAUDE.md §2). İZOMETRİK sunum (referans: Master of Piece /
## Darkest Dungeon world map): küp-tile arazi + düğüm madalyonları + bağlayan
## yollar + mevcut katman mavi vurgulu. Olay düğümü overlay kartla çözülür (§13).

var _ui: CanvasLayer
var _root: Control
var _map: Control                 # arazi + yol çizen katman
var _pulse := 0.0

# İzometrik metrik (2:1 elmas + küp gövde)
const TW := 116.0                 # tile top genişliği
const TH := 60.0                  # tile top yüksekliği
const CUBE := 24.0                # küp yan yüz yüksekliği
const NODE_LIFT := 30.0           # madalyon tile üstünde ne kadar yüksek

const TOP_MOSS := Color(0.205, 0.255, 0.165)
const FACE_L := Color(0.085, 0.085, 0.065)
const FACE_R := Color(0.135, 0.125, 0.095)
const EDGE := Color(0.05, 0.06, 0.05, 0.85)

const ROAD := Color(0.42, 0.34, 0.22)
const ROAD_DIM := Color(0.24, 0.22, 0.18)
const ROAD_BLUE := Color(0.35, 0.62, 0.90)
const SEL_BLUE := Color(0.40, 0.70, 1.0)

const IC_SKULL := preload("res://assets/icons/skull.svg")
const IC_GOLD := preload("res://assets/icons/gold.svg")
const IC_BOOK := preload("res://assets/icons/book.svg")
const IC_PACK := preload("res://assets/icons/pack.svg")
const IC_SHAMAN := preload("res://assets/icons/shaman.svg")
const IC_MEDIC := preload("res://assets/icons/medic.svg")
const IC_GRAVE := preload("res://assets/icons/grave.svg")
const IC_TRAIT := preload("res://assets/icons/trait.svg")
const IC_GEM := preload("res://assets/icons/gem.svg")
const IC_GALLOWS := preload("res://assets/icons/gallows.svg")

const TYPE_ICON := {
	&"savas": IC_SKULL, &"elit": IC_SKULL, &"boss": IC_SKULL,
	&"dukkan": IC_GOLD, &"olay": IC_BOOK,
	&"saman": IC_SHAMAN, &"revir": IC_MEDIC, &"mezar": IC_GRAVE,
	&"nitelik": IC_TRAIT, &"yadigar": IC_GEM, &"daragaci": IC_GALLOWS,
	&"meydan": preload("res://assets/icons/dice.svg"),
}
const TYPE_COL := {
	&"savas": Color(0.82, 0.32, 0.27), &"elit": Color(0.92, 0.56, 0.22),
	&"boss": Color(0.70, 0.38, 0.80), &"dukkan": Color(0.86, 0.72, 0.36),
	&"olay": Color(0.48, 0.64, 0.88),
	&"saman": Color(0.42, 0.72, 0.52), &"revir": Color(0.55, 0.82, 0.78),
	&"mezar": Color(0.56, 0.56, 0.62),
	&"nitelik": Color(0.65, 0.72, 0.35), &"yadigar": Color(0.88, 0.78, 0.42),
	&"daragaci": Color(0.62, 0.30, 0.26), &"meydan": Color(0.84, 0.52, 0.6),
}
const REGION_NAMES := ["I · PUS ORMANI", "II · KEMİK BATAKLIĞI"]

var _origin := Vector2.ZERO
var _terrain: Array[Vector2i] = []
var _edges: Array = []            # {a:Vector2, b:Vector2, state:int}  (0 dim,1 traveled,2 active)
var _cur_tiles: Array = []        # mevcut katman tile tepe pozisyonları (mavi vurgu)

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build()
	set_process(true)

func _process(dt: float) -> void:
	_pulse += dt
	if _map:
		_map.queue_redraw()

## Tile (col,row) → ekran tepe-orta noktası. row0 = başlangıç (ekranın altı).
func _iso(col: float, row: float) -> Vector2:
	var ur := float(Encounters.MAP_TEMPLATE.size() - 1) - row
	return _origin + Vector2((col - ur) * TW * 0.5, (col + ur) * TH * 0.5)

func _build() -> void:
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	_ui.add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://shaders/bg_gradient.gdshader")
	bg.material = bg_mat
	_root.add_child(bg)

	# ── Düğüm yerleşimi: kıvrılan yol (her katman bir sıra, dallar yan yana) ──
	var layers: Array = Encounters.MAP_TEMPLATE
	var layout: Array = []            # per layer: Array of {node, cell:Vector2i, pos:Vector2}
	var min_c := 999
	var max_c := -999
	for i in layers.size():
		var n: int = layers[i].size()
		var center := 3 + int(round(1.7 * sin(i * 0.8)))
		var cells: Array = []
		for j in n:
			var col := center + int(round((j - (n - 1) / 2.0) * 2.0))
			min_c = mini(min_c, col)
			max_c = maxi(max_c, col)
			cells.append({"node": layers[i][j], "cell": Vector2i(col, i)})
		layout.append(cells)

	# Origin: düğüm bbox'ını gerçek viewport ortasına oturt (build anında _root.size=0)
	_origin = Vector2.ZERO
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for layer in layout:
		for e: Dictionary in layer:
			var p := _iso(e["cell"].x, e["cell"].y)
			minp = minp.min(p)
			maxp = maxp.max(p)
	minp.y -= NODE_LIFT + 34.0     # madalyonlar tile üstünde
	maxp.y += CUBE + 10.0
	var center := (minp + maxp) * 0.5
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_origin = Vector2(vp.x * 0.5, vp.y * 0.5 + 24.0) - center

	# Arazi hücreleri (düğüm alanı + kenar dolgu)
	_terrain.clear()
	for r in range(-1, layers.size() + 1):
		for c in range(min_c - 2, max_c + 3):
			_terrain.append(Vector2i(c, r))
	# arka→ön sırala (üst/uzak önce)
	_terrain.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _iso(a.x, a.y).y < _iso(b.x, b.y).y)

	# Yollar (katmanlar arası, hepsini bağla) + kenar durumları
	_edges.clear()
	for i in layers.size() - 1:
		for a in layout[i]:
			for b in layout[i + 1]:
				var st := 0
				if i + 1 < GameState.layer_index:
					st = 1                     # geçilmiş yol
				elif i + 1 == GameState.layer_index:
					st = 2                     # mevcut adıma giden (mavi)
				_edges.append({
					"a": _iso(a["cell"].x, a["cell"].y),
					"b": _iso(b["cell"].x, b["cell"].y), "state": st})

	# Mevcut katman tile'ları (mavi elmas vurgu)
	_cur_tiles.clear()
	if GameState.layer_index < layers.size():
		for a in layout[GameState.layer_index]:
			_cur_tiles.append(_iso(a["cell"].x, a["cell"].y))

	# Çizim katmanı
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	_root.add_child(_map)

	# Düğüm madalyonları (çizimin üstünde)
	for i in layers.size():
		for entry: Dictionary in layout[i]:
			var pos: Vector2 = _iso(entry["cell"].x, entry["cell"].y)
			var state := 0                     # 0 geçildi,1 mevcut,2 uzak
			if i == GameState.layer_index:
				state = 1
			elif i > GameState.layer_index:
				state = 2
			_add_node(entry["node"], pos, state)

	# KARA PUS fog-of-war (§4/§15.3): keşfedilmemiş katmanlar halftone pusla örtülü.
	# Düğümlerin ÜSTÜNDE (uzak madalyonları gizler) ama HUD'un altında.
	_build_fog_of_war(layout)

	# Pus vinyet (atmosfer, kenarlar)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = preload("res://shaders/fog_vignette.gdshader")
	fog.material = fog_mat
	_root.add_child(fog)

	_build_hud()

## Fog-of-war açıklık noktaları (gelistirme.md §4): gezilen katmanlar açık, mevcut
## katman geniş açık (yeni açılış animasyonlu), SONRAKİ katman dar önizleme (noktalı
## sisin içinden seçilir), son katman (boss) hedef olarak hayal meyal görünür.
func _build_fog_of_war(layout: Array) -> void:
	var pts := PackedVector4Array()
	var li := GameState.layer_index
	var last := layout.size() - 1
	for i in layout.size():
		var radius := 0.0
		var animated := 0.0
		if i < li:
			radius = 185.0
		elif i == li:
			radius = 240.0
			animated = 1.0
		elif i == li + 1:
			radius = 100.0
			animated = 1.0
		elif i == last:
			radius = 70.0     # boss hedefi: pusun içinde belli belirsiz
		else:
			continue
		for e: Dictionary in layout[i]:
			var p: Vector2 = _iso(e["cell"].x, e["cell"].y) + Vector2(0, -NODE_LIFT * 0.5)
			pts.append(Vector4(p.x, p.y, radius, animated))
		if pts.size() >= 48:
			break
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fog_of_war.gdshader")
	mat.set_shader_parameter("points", pts)
	mat.set_shader_parameter("point_count", pts.size())
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("reveal_t", 0.0)
	rect.material = mat
	_root.add_child(rect)
	# Pus çekilme animasyonu: yeni açılan bölgeler sıfırdan büyür
	var tw := rect.create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("reveal_t", v), 0.0, 1.0, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _draw_map() -> void:
	# ── Arazi küpleri ──
	for cell: Vector2i in _terrain:
		var p := _iso(cell.x, cell.y)
		var hash_v := absi((cell.x * 73856093) ^ (cell.y * 19349663))
		var tint := 0.86 + float(hash_v % 100) / 100.0 * 0.22
		var top := TOP_MOSS * tint
		# hafif yükselti varyasyonu
		var lift := 0.0
		if hash_v % 7 == 0:
			lift = CUBE * 0.6
			p.y -= lift
		var hw := TW * 0.5
		var hh := TH * 0.5
		var t := p + Vector2(0, -hh)
		var rt := p + Vector2(hw, 0)
		var bt := p + Vector2(0, hh)
		var lf := p + Vector2(-hw, 0)
		var dy := CUBE + lift
		# yan yüzler
		_map.draw_colored_polygon(PackedVector2Array([lf, bt, bt + Vector2(0, dy), lf + Vector2(0, dy)]), FACE_L)
		_map.draw_colored_polygon(PackedVector2Array([bt, rt, rt + Vector2(0, dy), bt + Vector2(0, dy)]), FACE_R)
		# üst elmas
		_map.draw_colored_polygon(PackedVector2Array([t, rt, bt, lf]), top)
		# ince kenar (toon)
		_map.draw_polyline(PackedVector2Array([t, rt, bt, lf, t]), EDGE, 1.0, true)

	# ── Yollar ──
	for e: Dictionary in _edges:
		var col := ROAD_DIM
		var w := 5.0
		if e["state"] == 1:
			col = ROAD
			w = 7.0
		elif e["state"] == 2:
			var g := 0.6 + 0.4 * sin(_pulse * 3.0)
			col = ROAD_BLUE.lerp(Color(0.7, 0.85, 1.0), g)
			w = 7.0
		_map.draw_line(e["a"], e["b"], Color(0, 0, 0, 0.5), w + 4.0)
		_map.draw_line(e["a"], e["b"], col, w)

	# ── Mevcut tile mavi elmas vurgu (pulse) ──
	var a := 0.5 + 0.35 * sin(_pulse * 3.0)
	for p: Vector2 in _cur_tiles:
		var hw := TW * 0.5
		var hh := TH * 0.5
		var pts := PackedVector2Array([
			p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0),
			p + Vector2(0, -hh)])
		_map.draw_polyline(pts, Color(SEL_BLUE.r, SEL_BLUE.g, SEL_BLUE.b, a), 3.0, true)

# ---------------------------------------------------------------- düğüm madalyonu

## Madalyon: tile üstünde yüzen daire + tip ikonu. state: 0 geçildi,1 mevcut,2 uzak
func _add_node(node: Dictionary, pos: Vector2, state: int) -> void:
	var type: StringName = node["type"]
	var base_col: Color = TYPE_COL.get(type, Color.GRAY)
	var big := type == &"boss"
	var r := 30.0 if big else 24.0
	var center := pos + Vector2(0, -NODE_LIFT - (8 if big else 0))

	var disc := _NodeDisc.new()
	disc.radius = r
	disc.fill = base_col.darkened(0.35) if state != 0 else base_col.darkened(0.6)
	disc.ring = base_col if state == 1 else (base_col.darkened(0.25) if state == 2 else base_col.darkened(0.5))
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = Vector2(r * 2.4, r * 2.4 + NODE_LIFT)
	disc.position = center - Vector2(disc.size.x * 0.5, r + 4)
	disc.stem_to = pos - disc.position    # gövde çizgisi tile'a
	disc.disc_center = Vector2(disc.size.x * 0.5, r + 4)
	disc.dim = state == 2
	_root.add_child(disc)

	var icon := TextureRect.new()
	icon.texture = TYPE_ICON.get(type, IC_SKULL)
	icon.modulate = Color(0.97, 0.93, 0.85) if state != 0 else Color(0.6, 0.58, 0.54)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var isz := r * 1.15
	icon.size = Vector2(isz, isz)
	icon.position = center - Vector2(isz * 0.5, isz * 0.5)
	_root.add_child(icon)

	if state == 1:
		# Tıklanabilir + pulse (mevcut katman)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size = Vector2(r * 2.3, r * 2.3)
		btn.position = center - btn.size * 0.5
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_node_pressed.bind(node))
		_root.add_child(btn)
		var tw := create_tween().set_loops()
		tw.tween_property(disc, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(disc, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		disc.pivot_offset = disc.disc_center
		icon.pivot_offset = Vector2(isz * 0.5, isz * 0.5)

func _on_node_pressed(node: Dictionary) -> void:
	if node["type"] == &"olay":
		_show_event()
	else:
		EventBus.map_node_selected.emit(node)

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	# Üst şerit: koyu panel + bölge başlığı ortada + altın/bölük solda
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.075, 0.9)
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	bar.offset_bottom = 60
	_root.add_child(bar)

	var region := REGION_NAMES[0] if GameState.layer_index < 6 else REGION_NAMES[1]
	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = region
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)

	var left := Label.new()
	left.text = "⛁ %d      ⚑ Sancak %d/%d      %d birim      Zar %d" % [
		GameState.gold, GameState.player_flag_hp, GameState.flag_cap(),
		GameState.squad.size(), GameState.zar]
	left.add_theme_font_size_override("font_size", 18)
	left.add_theme_color_override("font_color", Color(0.82, 0.76, 0.6))
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE)
	left.offset_left = 20
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(left)

	# Menü butonu (sağ) → başlangıç menüsüne
	var menu_btn := Button.new()
	menu_btn.text = "≡"
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.custom_minimum_size = Vector2(44, 40)
	menu_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	menu_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_btn.pressed.connect(_to_menu)
	_root.add_child(menu_btn)

	var hint := Label.new()
	hint.text = "Parlayan mavi düğümü seç"
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.add_theme_font_size_override("font_size", 15)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## Yüzen daire madalyon çizeri (halka + iç dolgu + tile'a gövde çizgisi)
class _NodeDisc extends Control:
	var radius := 24.0
	var fill := Color.GRAY
	var ring := Color.WHITE
	var stem_to := Vector2.ZERO
	var disc_center := Vector2.ZERO
	var dim := false
	func _draw() -> void:
		# gövde (tile'a inen çizgi)
		draw_line(disc_center, stem_to, Color(0.05, 0.05, 0.06, 0.7), 4.0)
		# gölge
		draw_circle(disc_center + Vector2(0, 3), radius, Color(0, 0, 0, 0.4))
		# dış halka
		draw_circle(disc_center, radius, ring)
		# iç dolgu
		draw_circle(disc_center, radius - 3.0, fill)

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
	var cap := GameState.flag_cap()
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
