class_name TutorialCoach
extends Control
## TUTORIAL SAVAŞI KOÇU (gelistirme §3.3, tam akış): ilk savaşta A'dan E'ye
## elle yönlendirme. Kısa TEK cümlelik balon + hedefe İŞARET OKU; oyuncu adımı
## YAPANA KADAR ilerlemez (gated). Tek-tık, net highlight (MoP şikayeti çözümü).
##
## Adımlar:
##   A  kart seç → yeşil kareye koy
##   B  SAVAŞ'a bas → çarpışmayı izle (HIZ sırası)
##   C  düşman sancağı işaretlenir: "yık = kazan" (Tamam ile geçilir)
##   D  yeni tur: yeni birim koy / birimi taşı / Kumandan yeteneği (Geç'lenebilir)
##   E  sancak düşer → zafer; ödül tanıtımı RewardScreen'de sürer
##
## Zafer gelirse hangi adımda olursa olsun tamamlanır; yenilgide bayrak
## yazılmaz → tutorial bir sonraki savaşta baştan gelir.

signal finished

## gate: hangi olay ilerletir. arrow: her kare çağrılan ekran-noktası (ZERO = ok yok)
## btn: balona eklenen mini buton ("Tamam"/"Geç")
var _steps: Array = []
var _step := 0
var _awaiting_replace := false      # taşıma tespiti: recall → deploy dizisi
var _panel: PanelContainer
var _label: Label
var _pips: Label
var _btn: Button
var _arrow_target := Vector2.ZERO
var _t := 0.0
var _done := false

var _battle: Node                   # battle_screen (banner_screen_pos için)
var _ui: DeploymentUI

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.09, 0.95)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.resized.connect(_recenter)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_pips = Label.new()
	_pips.add_theme_font_size_override("font_size", 13)
	_pips.add_theme_color_override("font_color", Color(0.7, 0.62, 0.45))
	row.add_child(_pips)
	_btn = Button.new()
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.custom_minimum_size = Vector2(90, 30)
	_btn.add_theme_font_size_override("font_size", 15)
	_btn.pressed.connect(func() -> void: _gate(&"btn"))
	row.add_child(_btn)
	set_process(true)
	# nabız
	var tw := create_tween().set_loops()
	tw.tween_property(_panel, "modulate:a", 0.85, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

## battle_screen kurar: sinyaller + ok çipaları buradan
func attach(dep_ui: DeploymentUI, battle: Node) -> void:
	_ui = dep_ui
	_battle = battle
	var kartlar := func() -> Vector2: return dep_ui.card_bar_center()
	var savas := func() -> Vector2:
		return dep_ui.battle_button.get_global_rect().get_center() \
			if dep_ui.battle_button else Vector2.ZERO
	var sancak := func() -> Vector2: return battle.banner_screen_pos()
	var kumandan := func() -> Vector2: return dep_ui.commander_center()
	var yok := func() -> Vector2: return Vector2.ZERO
	_steps = [
		{"text": "Alttaki kartlardan bir kuzu seç", "gate": &"card", "arrow": kartlar},
		{"text": "Yeşil parlayan kareye tıkla", "gate": &"deploy", "arrow": yok},
		{"text": "SAVAŞ'a bas — turu başlat", "gate": &"battle", "arrow": savas},
		{"text": "Kuzular HIZ sırasıyla kendiliğinden savaşır — izle", "gate": &"planning", "arrow": yok},
		{"text": "Hedefin bu kırmızı sancak: onu yıkarsan kazanırsın", "gate": &"btn",
			"arrow": sancak, "btn": "Tamam"},
		{"text": "Her tur Mevzi yenilenir — yeni bir kuzu dizebilirsin", "gate": &"deploy",
			"arrow": kartlar, "btn": "Geç →"},
		{"text": "Yerleşmiş kuzuya tıkla, başka kareye taşı", "gate": &"move",
			"arrow": yok, "btn": "Geç →"},
		{"text": "Kumandan yeteneğin Yıldırım: bas ve bir düşman seç", "gate": &"commander",
			"arrow": kumandan, "btn": "Geç →"},
		{"text": "Sancak düşene dek savaş — SAVAŞ'a bas", "gate": &"win", "arrow": sancak},
	]
	dep_ui.card_pressed.connect(func(_i: int) -> void: _gate(&"card"))
	dep_ui.battle_pressed.connect(func() -> void: _gate(&"battle"))
	EventBus.piece_deployed.connect(_on_deployed)
	EventBus.piece_recalled.connect(func(_id: StringName) -> void:
		_awaiting_replace = true)
	EventBus.commander_used.connect(func() -> void: _gate(&"commander"))
	EventBus.battle_finished.connect(_on_battle_finished)
	# koç konuşurken üstteki genel ipucu yazısı susar (aynı yere çakışıyordu)
	if dep_ui._hint:
		dep_ui._hint.visible = false
	_show_step()

## battle_screen._enter_planning çağırır (tur çözümü bitti, planlama döndü)
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
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(1.06, 1.06)
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_step() -> void:
	var s: Dictionary = _steps[_step]
	_label.text = s["text"]
	_btn.visible = s.has("btn")
	if _btn.visible:
		_btn.text = s["btn"]
	var pip := ""
	for i in _steps.size():
		pip += "●" if i <= _step else "○"
	_pips.text = pip

func _recenter() -> void:
	_panel.position = Vector2(
		(get_viewport_rect().size.x - _panel.size.x) * 0.5, 68.0)

func _complete() -> void:
	if _done:
		return
	_done = true
	GameState.meta_tutorial_done = true
	GameState.tutorial_just_done = true   # ödül + harita tanıtımı devam eder
	GameState.save_meta()
	finished.emit()
	_arrow_target = Vector2.ZERO
	_label.text = "Sancak düştü — zafer!"
	_btn.visible = false
	_pips.text = ""
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

# ------------------------------------------------------------------ işaret oku

func _process(dt: float) -> void:
	_t += dt
	if _done or _step >= _steps.size():
		return
	var cb: Callable = _steps[_step]["arrow"]
	_arrow_target = cb.call()
	queue_redraw()

## Balondan hedefe süzülen ok: gövde çizgisi + hedefe doğru zıplayan uç
func _draw() -> void:
	if _done or _arrow_target == Vector2.ZERO:
		return
	var from := _panel.position + Vector2(_panel.size.x * 0.5, _panel.size.y)
	var to := _arrow_target
	if to.distance_to(from) < 60.0:
		return
	var dir := (to - from).normalized()
	var bob := sin(_t * 5.0) * 7.0
	var tip := to - dir * (26.0 - bob)
	var tail := from + dir * 10.0
	var col := Color(0.95, 0.78, 0.35, 0.9)
	draw_line(tail, tip - dir * 14.0, Color(col.r, col.g, col.b, 0.45), 3.0, true)
	# uç üçgeni
	var n := dir.rotated(PI * 0.5) * 9.0
	var base := tip - dir * 18.0
	draw_colored_polygon(PackedVector2Array([tip, base + n, base - n]), col)
