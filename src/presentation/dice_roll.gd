class_name DiceRoll
extends CanvasLayer
## Zar atışı overlay'i (gelistirme §6). Ekran ortasında pip'li D6: zıplar, döner,
## yüzler hızla değişir, yavaşlar, sonuç yüzünde durur + parlar. Fizik YOK —
## sonuç çağıran tarafından verilir (determinizm: animasyon sadece gösterim).
## Kullanım: DiceRoll.play(parent, sonuç, callback)

signal finished

const SIZE := 110.0
const ROLL_TIME := 0.85

var _die: _Die
var _result := 4

static func play(parent: Node, result: int, on_done: Callable = Callable()) -> void:
	var d := DiceRoll.new()
	d._result = clampi(result, 1, 6)
	d.layer = 90
	parent.add_child(d)
	if on_done.is_valid():
		d.finished.connect(on_done)

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # atış bitene dek tıklamayı yut
	add_child(root)

	_die = _Die.new()
	_die.face = 1 + randi() % 6
	_die.size = Vector2(SIZE, SIZE)
	_die.pivot_offset = Vector2(SIZE, SIZE) * 0.5
	var vp := root.get_viewport_rect().size
	_die.position = (vp - Vector2(SIZE, SIZE)) * 0.5 + Vector2(0, -40)
	root.add_child(_die)

	AudioDirector.play_sfx(&"deploy_clunk", 0.15)   # tok "clack" (eldeki en yakın ses)

	# Zıplama + dönme: yukarı fırla → düş → küçük sekme → otur
	var start_y := _die.position.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_die, "rotation", TAU * 2.1, ROLL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var bounce := create_tween()
	bounce.tween_property(_die, "position:y", start_y - 130.0, ROLL_TIME * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_die, "position:y", start_y, ROLL_TIME * 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bounce.tween_property(_die, "position:y", start_y - 34.0, ROLL_TIME * 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_die, "position:y", start_y, ROLL_TIME * 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Yüz karıştırma: gitgide yavaşlayan aralıklarla rastgele yüz; sonunda SONUÇ
	var faces := create_tween()
	var t := 0.0
	var step := 0.055
	while t + step < ROLL_TIME * 0.9:
		t += step
		step *= 1.22
		faces.tween_interval(step)
		faces.tween_callback(func() -> void:
			_die.face = 1 + randi() % 6
			_die.queue_redraw())
	faces.tween_callback(func() -> void:
		_die.face = _result
		_die.glow = 1.0
		_die.queue_redraw()
		AudioDirector.play_sfx(&"deploy_clunk", 0.1))
	# Sonuç parlaması → sön → kapan
	faces.tween_interval(0.12)
	faces.tween_method(func(v: float) -> void:
		_die.glow = v
		_die.queue_redraw(), 1.0, 0.0, 0.4)
	faces.tween_interval(0.1)
	faces.tween_callback(func() -> void:
		finished.emit()
		queue_free())

## Pip'li D6 çizimi: koyu kemik zar, yuvarlak köşe, kalın outline, sonuçta altın glow
class _Die extends Control:
	var face := 1
	var glow := 0.0
	const PIPS := {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.28, 0.28), Vector2(0.72, 0.72)],
		3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
		4: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
		5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5),
			Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
		6: [Vector2(0.28, 0.22), Vector2(0.72, 0.22), Vector2(0.28, 0.5),
			Vector2(0.72, 0.5), Vector2(0.28, 0.78), Vector2(0.72, 0.78)],
	}
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if glow > 0.0:
			draw_style_box(_box(Color(0.95, 0.8, 0.42, glow * 0.55), 18.0),
				r.grow(10.0 + glow * 8.0))
		draw_style_box(_box(Color(0.12, 0.11, 0.14), 14.0), r.grow(3.5))   # outline
		draw_style_box(_box(Color(0.87, 0.83, 0.74).lerp(Color(1, 0.95, 0.75), glow), 12.0), r)
		for p: Vector2 in PIPS[face]:
			draw_circle(p * size, size.x * 0.075, Color(0.14, 0.12, 0.12))
	func _box(c: Color, rad: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(rad))
		return sb
