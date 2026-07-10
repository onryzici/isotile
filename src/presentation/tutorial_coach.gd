class_name TutorialCoach
extends Control
## SAVAŞ İÇİ ÖĞRETİCİ (gelistirme §3.3, hafif sürüm): ilk savaşta ekranın
## üstünde tek cümlelik yönlendirme şeridi. Oyuncu adımı YAPANA KADAR sonraki
## adım gelmez (gated); metin kısa, tek cümle (§3 tasarım kuralı). Tamamlanınca
## meta_tutorial_done yazılır, bir daha görünmez. "Nasıl Oynanır" modalının
## yerini alır (o, "?" butonundan hâlâ açılabilir).

signal finished

const STEPS := [
	"Alttaki kartlardan bir kuzu seç",
	"Yeşil parlayan bir kareye tıkla — kuzu mevzilenir",
	"Hedef karşıdaki KIRMIZI SANCAK: onu yıkarsan kazanırsın. Hazırsan SAVAŞ'a bas",
]

var _step := 0
var _label: Label
var _pips: Label
var _panel: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.09, 0.95)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP,
		Control.PRESET_MODE_MINSIZE, 74)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_label)
	_pips = Label.new()
	_pips.add_theme_font_size_override("font_size", 14)
	_pips.add_theme_color_override("font_color", Color(0.7, 0.62, 0.45))
	_pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_pips)
	_show_step()
	# dikkat çekme: hafif nabız
	_panel.pivot_offset = Vector2(0, 0)
	var tw := create_tween().set_loops()
	tw.tween_property(_panel, "modulate:a", 0.82, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

## Savaş ekranı sinyallerine bağlan (battle_screen._setup_ui çağırır)
func attach(dep_ui: DeploymentUI) -> void:
	dep_ui.card_pressed.connect(_on_card)
	EventBus.piece_deployed.connect(_on_deployed)
	dep_ui.battle_pressed.connect(_on_battle)

func _on_card(_i: int) -> void:
	_advance_from(0)

func _on_deployed(_id: StringName, _c: Vector2i) -> void:
	_advance_from(1)

func _on_battle() -> void:
	_advance_from(2)

## Yalnız beklenen adımdan ilerlet (gated — sıra atlanamaz)
func _advance_from(step: int) -> void:
	if _step != step:
		return
	_step += 1
	if _step >= STEPS.size():
		_complete()
		return
	_show_step()
	# adım geçişi: küçük pop
	_panel.scale = Vector2(1.06, 1.06)
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_step() -> void:
	_label.text = STEPS[_step]
	var pip := ""
	for i in STEPS.size():
		pip += "● " if i <= _step else "○ "
	_pips.text = pip.strip_edges()

func _complete() -> void:
	GameState.meta_tutorial_done = true
	GameState.save_meta()
	_label.text = "Sürü savaşta — izle"
	_pips.text = "● ● ●"
	finished.emit()
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
