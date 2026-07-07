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
	title.text = "BÖLGE 1 — PUS ORMANI"
	title.add_theme_font_size_override("font_size", 30)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_root.add_child(title)

	var info := Label.new()
	info.text = "Altın: %d      Bölük: %d birim" % [GameState.gold, GameState.squad.size()]
	info.add_theme_font_size_override("font_size", 20)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 18)
	_root.add_child(info)

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
## M2: tek elle yazılmış olay; M3'te EventData .tres havuzuna taşınır.

func _show_event() -> void:
	var overlay := CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(460, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Pus İçinde Bir Yaralı Asker"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var body := Label.new()
	body.text = "Sisin içinden bir inilti geliyor. Mızrağına yaslanmış bir asker,\nsize bakıyor. Teçhizatı değerli görünüyor."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var iyilestir := Button.new()
	iyilestir.text = "İyileştir (−5 Altın): Mızraklı bölüğe katılır"
	iyilestir.disabled = GameState.gold < 5
	iyilestir.focus_mode = Control.FOCUS_NONE
	iyilestir.pressed.connect(func():
		GameState.gold -= 5
		GameState.add_unit(Database.get_resource("pieces", &"mizrakli"))
		_finish_event())
	vbox.add_child(iyilestir)

	var soy := Button.new()
	soy.text = "Soy (+20 Altın)"
	soy.focus_mode = Control.FOCUS_NONE
	soy.pressed.connect(func():
		GameState.gold += 20
		_finish_event())
	vbox.add_child(soy)

	var gec := Button.new()
	gec.text = "Geç"
	gec.focus_mode = Control.FOCUS_NONE
	gec.pressed.connect(_finish_event)
	vbox.add_child(gec)

func _finish_event() -> void:
	GameState.layer_index += 1
	_build()   # haritayı yenile
