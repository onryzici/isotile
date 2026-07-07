class_name DeploymentUI
extends CanvasLayer
## Savaş ekranı UI'ı (CLAUDE.md §19).
## Deployment modu: bölük kartları + Mevzi + SAVAŞ butonu.
## Savaş modu: 1x/2x/Atla kontrolleri + tur göstergesi.
## Sonuç: ZAFER/YENİLGİ + tekrar butonu.

signal card_pressed(index: int)
signal battle_pressed
signal speed_selected(mult: float)
signal skip_pressed
signal restart_pressed

const SINIF_AD := ["Yakın", "Menzilli", "Destek"]

var battle_button: Button

var _root: Control
var _cards: Array[Button] = []
var _mevzi_label: Label
var _hint: Label
var _bar: HBoxContainer
var _round_label: Label
var _speed_box: HBoxContainer
var _result_panel: Control

func build(squad: Array) -> void:
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.make()
	add_child(_root)

	_mevzi_label = Label.new()
	_mevzi_label.add_theme_font_size_override("font_size", 26)
	_mevzi_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_root.add_child(_mevzi_label)

	_hint = Label.new()
	_hint.text = "Karttan birim seç → yeşil tile'a tıkla  •  Yerleşmiş birime tıkla: taşı  •  Sağ tık: geri al  •  Q/E: kamera, tekerlek: zoom"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.modulate = Color(1, 1, 1, 0.7)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	_root.add_child(_hint)

	_round_label = Label.new()
	_round_label.add_theme_font_size_override("font_size", 28)
	_round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_round_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_round_label.visible = false
	_root.add_child(_round_label)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_bar)

	for i in squad.size():
		var piece: PieceData = squad[i]
		var btn := Button.new()
		var traits_line := piece.trait_names()
		btn.text = "%s\n%s  (%s)\n%s\nMevzi %d" % [piece.ad, piece.stat_text(),
			SINIF_AD[piece.sinif], traits_line if traits_line != "" else "—", piece.mevzi_maliyeti]
		btn.custom_minimum_size = Vector2(165, 108)
		btn.focus_mode = Control.FOCUS_NONE
		# Tooltip: tabya açıklamaları (canlı Güç×Kat dökümü M1 cilasında — §19)
		var tips: Array[String] = []
		for t in piece.base_traits:
			tips.append("%s: %s" % [t.ad, t.aciklama])
		btn.tooltip_text = "\n".join(tips)
		btn.pressed.connect(_on_card_button.bind(i))
		_bar.add_child(btn)
		_cards.append(btn)

	battle_button = Button.new()
	battle_button.text = "SAVAŞ"
	battle_button.custom_minimum_size = Vector2(160, 64)
	battle_button.focus_mode = Control.FOCUS_NONE
	battle_button.disabled = true
	battle_button.tooltip_text = "En az bir birim yerleştir"
	battle_button.add_theme_font_size_override("font_size", 24)
	battle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	battle_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	battle_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	battle_button.pressed.connect(func(): battle_pressed.emit())
	_root.add_child(battle_button)

	_build_speed_controls()

func _build_speed_controls() -> void:
	_speed_box = HBoxContainer.new()
	_speed_box.add_theme_constant_override("separation", 8)
	_speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_speed_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speed_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speed_box.visible = false
	_root.add_child(_speed_box)
	for cfg in [["1x", 1.0], ["2x", 2.0]]:
		var btn := Button.new()
		btn.text = cfg[0]
		btn.custom_minimum_size = Vector2(70, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): speed_selected.emit(cfg[1]))
		_speed_box.add_child(btn)
	var skip_btn := Button.new()
	skip_btn.text = "Atla ≫"
	skip_btn.custom_minimum_size = Vector2(90, 48)
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(func(): skip_pressed.emit())
	_speed_box.add_child(skip_btn)

func _on_card_button(index: int) -> void:
	card_pressed.emit(index)

# ------------------------------------------------------------- durum geçişleri

func enter_battle_mode() -> void:
	_bar.visible = false
	battle_button.visible = false
	_hint.visible = false
	_speed_box.visible = true
	_round_label.visible = true
	set_round(1)

func set_round(round_no: int) -> void:
	_round_label.text = "Tur %d" % round_no

func show_result(player_won: bool) -> void:
	_speed_box.visible = false
	_result_panel = CenterContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_result_panel)
	var panel := PanelContainer.new()
	_result_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "ZAFER" if player_won else "YENİLGİ"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if player_won else Color(0.9, 0.25, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "M0 dikey dilim savaşı tamamlandı." if player_won \
		else "Kaybetmek ilerlemedir — yeni kurulum dene."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var again := Button.new()
	again.text = "TEKRAR SAVAŞ"
	again.custom_minimum_size = Vector2(0, 52)
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func(): restart_pressed.emit())
	vbox.add_child(again)

# ------------------------------------------------------------- deployment durumu

func set_mevzi(value: int) -> void:
	_mevzi_label.text = "Mevzi: %d" % value

func set_selected(index: int) -> void:
	for i in _cards.size():
		_cards[i].modulate = Color(1.0, 0.95, 0.5) if i == index else Color.WHITE

func set_card_deployed(index: int, deployed: bool) -> void:
	_cards[index].disabled = deployed
	_cards[index].modulate = Color(1, 1, 1, 0.5) if deployed else Color.WHITE
