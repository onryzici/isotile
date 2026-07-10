class_name TutorialCoach
extends Control
## TUTORIAL SAVAŞI KOÇU (gelistirme §3.3): SPOTLIGHT yaklaşımı — ekran hafif
## siyahla kararır, yalnız İLGİLİ bölge (yumuşak kenarlı delik) açık kalır;
## kısa tek cümlelik yazı o bölgenin HEMEN YANINDA durur. Ok/işaret yok.
## Oyuncu adımı YAPANA KADAR ilerlemez (gated); tek-tık.
##
## Adımlar: A kart seç / kareye koy · B SAVAŞ + izle · C sancak tanıtımı (Tamam)
## · D yeni birim / taşı / Kumandan (Geç'lenebilir) · E sancağı yık → zafer.
## Zafer gelirse hangi adımda olursa olsun tamamlanır.

signal finished

var _steps: Array = []
var _step := 0
var _awaiting_replace := false      # taşıma tespiti: recall → deploy dizisi
var _dim: ColorRect
var _dim_mat: ShaderMaterial
var _panel: PanelContainer
var _label: Label
var _pips: Label
var _btn: Button
var _done := false

var _battle: Node
var _ui: DeploymentUI

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# karartma katmanı (tıklamayı YUTMAZ — gating zaten yanlış tıkı boşa düşürür)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_mat = ShaderMaterial.new()
	_dim_mat.shader = preload("res://shaders/tutorial_spotlight.gdshader")
	_dim_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	_dim.material = _dim_mat
	add_child(_dim)
	# Yazı balonu — DİKKAT: koç CanvasLayer'a doğrudan ekli olduğundan tema
	# MİRAS ALMAZ; font/stil açıkça verilir (stok Godot fontu = "amatör" hissi).
	theme = UITheme.make()
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.05, 0.085, 0.9)
	sb.border_color = UITheme.BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_panel.add_child(v)
	_label = Label.new()
	_label.add_theme_font_override("font", UITheme.body_font())
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", UITheme.TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_pips = Label.new()
	_pips.add_theme_font_override("font", UITheme.body_font())
	_pips.add_theme_font_size_override("font_size", 13)
	_pips.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	row.add_child(_pips)
	_btn = Button.new()
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.custom_minimum_size = Vector2(84, 28)
	_btn.add_theme_font_size_override("font_size", 15)
	_btn.pressed.connect(func() -> void: _gate(&"btn"))
	row.add_child(_btn)
	set_process(true)

## battle_screen kurar: sinyaller + spotlight bölge sağlayıcıları
func attach(dep_ui: DeploymentUI, battle: Node) -> void:
	_ui = dep_ui
	_battle = battle
	var kartlar := func() -> Rect2: return dep_ui.card_bar_rect()
	var savas := func() -> Rect2:
		return dep_ui.battle_button.get_global_rect().grow(12.0) \
			if dep_ui.battle_button else Rect2()
	var sancak := func() -> Rect2: return battle.banner_screen_rect()
	var kumandan := func() -> Rect2: return dep_ui.commander_rect()
	var saha := func() -> Rect2: return battle.deploy_zone_screen_rect()
	var yok := func() -> Rect2: return Rect2()
	_steps = [
		{"text": "Bir kuzu kartı seç", "gate": &"card", "rect": kartlar},
		{"text": "Yeşil parlayan karelerden birine tıkla", "gate": &"deploy", "rect": saha},
		{"text": "SAVAŞ'a bas — turu başlat", "gate": &"battle", "rect": savas},
		{"text": "Kuzular HIZ sırasıyla kendiliğinden savaşır — izle",
			"gate": &"planning", "rect": yok, "nodim": true},
		{"text": "Hedefin bu sancak: onu yıkarsan kazanırsın", "gate": &"btn",
			"rect": sancak, "btn": "Tamam"},
		{"text": "Her tur Mevzi yenilenir — yeni bir kuzu dizebilirsin",
			"gate": &"deploy", "rect": kartlar, "btn": "Geç →"},
		{"text": "Yerleşmiş kuzuya tıkla, başka kareye taşı",
			"gate": &"move", "rect": saha, "btn": "Geç →"},
		{"text": "Kumandan yeteneğin Yıldırım: bas ve bir düşman seç",
			"gate": &"commander", "rect": kumandan, "btn": "Geç →"},
		{"text": "Sancak düşene dek savaş — SAVAŞ'a bas", "gate": &"win", "rect": savas},
	]
	dep_ui.card_pressed.connect(func(_i: int) -> void: _gate(&"card"))
	dep_ui.battle_pressed.connect(func() -> void: _gate(&"battle"))
	EventBus.piece_deployed.connect(_on_deployed)
	EventBus.piece_recalled.connect(func(_id: StringName) -> void:
		_awaiting_replace = true)
	EventBus.commander_used.connect(func() -> void: _gate(&"commander"))
	EventBus.battle_finished.connect(_on_battle_finished)
	# koç konuşurken üstteki genel ipucu yazısı susar
	if dep_ui._hint:
		dep_ui._hint.visible = false
	_show_step()

## battle_screen._enter_planning çağırır (tur çözümü bitti)
func on_planning() -> void:
	_gate(&"planning")

func _on_deployed(_id: StringName, _c: Vector2i) -> void:
	if _awaiting_replace:
		_awaiting_replace = false
		_gate(&"move")
	else:
		_gate(&"deploy")

func _on_battle_finished(won: bool) -> void:
	if won:
		_complete()

## Yalnız mevcut adımın beklediği olay ilerletir (gated — sıra atlanamaz)
func _gate(kind: StringName) -> void:
	if _done or _step >= _steps.size():
		return
	if _steps[_step]["gate"] != kind:
		return
	_step += 1
	if _step >= _steps.size():
		return   # son adım (&"win") battle_finished ile kapanır
	_show_step()

func _show_step() -> void:
	var s: Dictionary = _steps[_step]
	_label.text = s["text"]
	_btn.visible = s.has("btn")
	if _btn.visible:
		_btn.text = s["btn"]
	_pips.text = "%d / %d" % [_step + 1, _steps.size()]
	# yumuşak geçiş: balon kısa fade
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

# ---------------------------------------------------- spotlight + yerleşim

## Her kare: mevcut adımın bölgesini karartma deliğine + balonu bölge yanına
func _process(_dt: float) -> void:
	if _done or _step >= _steps.size():
		return
	var s: Dictionary = _steps[_step]
	var r: Rect2 = (s["rect"] as Callable).call()
	var vp := get_viewport_rect().size
	# CanvasLayer altındaki Control FULL_RECT anchor'a rağmen 0x0 kalabiliyor
	# (EventCard'daki sınıfla aynı tuzak) → boyutu her kare elle ver
	position = Vector2.ZERO
	size = vp
	_dim.position = Vector2.ZERO
	_dim.size = vp
	_dim_mat.set_shader_parameter("screen_size", vp)
	if s.get("nodim", false) or r.size.x <= 0.0:
		# hedefsiz adım ("izle"): karartma yok, yazı alt-ortada süzülür
		_dim_mat.set_shader_parameter("dim", 0.0)
		_panel.position = Vector2((vp.x - _panel.size.x) * 0.5, vp.y - 250.0)
		return
	_dim_mat.set_shader_parameter("dim", 0.55)
	_dim_mat.set_shader_parameter("hole", Vector4(r.position.x, r.position.y,
		r.size.x, r.size.y))
	# balon: bölgenin altına sığıyorsa altına, yoksa üstüne; x ekseninde kıskaçla
	var px := clampf(r.get_center().x - _panel.size.x * 0.5,
		12.0, vp.x - _panel.size.x - 12.0)
	var py := r.end.y + 16.0
	if py + _panel.size.y > vp.y - 12.0:
		py = r.position.y - _panel.size.y - 16.0
	_panel.position = Vector2(px, maxf(12.0, py))

func _complete() -> void:
	if _done:
		return
	_done = true
	GameState.meta_tutorial_done = true
	GameState.tutorial_just_done = true   # ödül + harita tanıtımı devam eder
	GameState.save_meta()
	finished.emit()
	_label.text = "Sancak düştü — zafer!"
	_btn.visible = false
	_pips.text = ""
	_dim_mat.set_shader_parameter("dim", 0.0)
	var vp := get_viewport_rect().size
	_panel.position = Vector2((vp.x - _panel.size.x) * 0.5, vp.y - 250.0)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
