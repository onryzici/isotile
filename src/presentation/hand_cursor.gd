class_name HandCursor
extends CanvasLayer
## Deployment "tanrı eli" (referans hand-el.png): karttan/board'dan bir birim
## seçilince el yukarıdan iner, birimi TEPE-ORTASINDAN kavrar ve imleci takip
## eder; tile'a bırakınca el daldırıp bırakır, sonra yukarı çekilir.
##
## Katmanlama (Onur'un isteği): el iki parçaya bölünür — ARKA parmaklar/avuç
## birimin ARKASINDA, ÖN parmak ucu birimin ÖNÜNDE kalır → birim ele gömülü.
## Çizim sırası (arkadan öne): _back → _held → _front. Tamamen ekran-uzayı.

const HAND_TEX := preload("res://assets/hand.png")
const HAND_W := 698.0
const HAND_H := 679.0

## Ayarlar (offline compositor cmp_y ile bulundu — scratchpad/composite.ps1)
## BAŞ PARMAK = soldaki aşağı parmak → ÖNDE (birimin üstünde, kesilmez, hep görünür).
## İşaret parmağı (sağ) birimin ARKASINDA/altında kalır. Birim notch'a oturur, yukarıda.
const HAND_SCALE := 0.33
const PINCH := Vector2(475, 500)   # işaret-baş parmak boşluğu (birim tepe-ortası) pikseli
## Öne çizilecek el bölgesi = SOL (baş) parmak; sağ (işaret) parmak bu dikdörtgenin
## dışında kaldığından arkada/altta kalır. (x,y,w,h — el art'ı pikselleri)
## Baş parmağı TAM saracak şekilde sağa+alta genişletildi (parmak ucu art'ın en
## altına ve x~545'e uzanıyor); sağdaki işaret parmağı (x>560) dışarıda → arkada kalır.
const FRONT_REGION := Rect2(350, 380, 205, 299)
const HELD_H := 115.0              # taşınan birim yüksekliği (px)
const TOP_OFF := 2.0             # birim tepesi grip'e göre y (küçük = yukarı)
const MODEL_DX := 44.0            # birimi yatayda kaydır (+ = sağa)

## Takip + giriş hissi
const FOLLOW_LERP := 22.0
const GRAB_RISE := 220.0

var _root: Control          # kavrama noktası — imleci (grip origin) takip eder
var _back: TextureRect      # elin tamamı (birimin arkasında)
var _front: TextureRect     # elin ön parmak ucu şeridi (birimin önünde)
var _held: Control          # taşınan birim önizlemesi (ortada)

var _back_base := Vector2.ZERO
var _front_base := Vector2.ZERO

var _active := false
var _releasing := false
var _idle := false
var _target := Vector2.ZERO
var _bob_t := 0.0
var _tw: Tween

func _kill_tween() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = null

func _ready() -> void:
	layer = 3               # UI (layer 1) üstünde
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_root)

	# Ölçek boyuta gömülür (Control.scale/pivot yok) → hizalama matematiği basit:
	# el pikseli (x,y) → root uzayında (x,y - PINCH) * HAND_SCALE, pinch = origin.
	_back_base = -PINCH * HAND_SCALE
	_back = TextureRect.new()
	_back.texture = HAND_TEX
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_SCALE
	_back.size = Vector2(HAND_W, HAND_H) * HAND_SCALE
	_back.position = _back_base
	_root.add_child(_back)

	# Ön katman: aynı art'ın FRONT_REGION bölgesi (yalnız baş parmak), aynı transformda hizalı.
	# Bir el pikseli (x,y) → root uzayında ((x,y)-PINCH)*scale; bölge sol-üstü buna oturur.
	var atlas := AtlasTexture.new()
	atlas.atlas = HAND_TEX
	atlas.region = FRONT_REGION
	_front_base = (FRONT_REGION.position - PINCH) * HAND_SCALE
	_front = TextureRect.new()
	_front.texture = atlas
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_front.stretch_mode = TextureRect.STRETCH_SCALE
	_front.size = FRONT_REGION.size * HAND_SCALE
	_front.position = _front_base
	# _front, grab'de _held'in ÜSTÜNe eklenir (çizim sırası: back, held, front)

	visible = false
	set_process(true)

## Birimi kavra: el yukarıdan inip birimi tepe-ortasından tutar; imleci takip eder.
func grab(tex: Texture2D, tint: Color, at: Vector2) -> void:
	_kill_tween()
	_clear_held()
	if _front.get_parent():
		_front.get_parent().remove_child(_front)
	_active = true
	_releasing = false
	_idle = false
	visible = true
	_root.modulate.a = 1.0
	_root.rotation = 0.0
	_target = at
	_root.position = at

	_held = _make_preview(tex, tint)
	_root.add_child(_held)     # _back (index0) ile _front arasında → ortada
	_root.add_child(_front)    # en üstte (ön parmak ucu)

	# Giriş: el yukarıdan iner, birim grip'e pop eder
	_root.modulate.a = 0.0
	_back.position = _back_base + Vector2(24, -GRAB_RISE)
	_front.position = _front_base + Vector2(24, -GRAB_RISE)
	_held.scale = Vector2(0.45, 0.45)
	_held.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	_tw = tw
	tw.tween_property(_root, "modulate:a", 1.0, 0.12)
	tw.tween_property(_back, "position", _back_base, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_front, "position", _front_base, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_held, "modulate:a", 1.0, 0.14).set_delay(0.05)
	tw.tween_property(_held, "scale", Vector2.ONE, 0.24) \
		.set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: _idle = true)

## Birimi tile'a bırak: el hedefe daldırır, birimi bırakır, sonra çekilir.
func release(at: Vector2, on_dropped: Callable) -> void:
	if not _active:
		on_dropped.call()
		return
	_kill_tween()
	_releasing = true
	_idle = false
	_target = at
	var tw := create_tween()
	_tw = tw
	# 1) hedefe otur + aşağı kısa daldırma
	tw.tween_property(_root, "position", at, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_back, "position", _back_base + Vector2(0, 20), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_front, "position", _front_base + Vector2(0, 20), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2) bırakma anı → gerçek birim sahneye düşer, önizleme kaybolur
	tw.tween_callback(func() -> void:
		on_dropped.call()
		if _held:
			var d := create_tween().set_parallel(true)
			d.tween_property(_held, "modulate:a", 0.0, 0.12)
			d.tween_property(_held, "position:y", _held.position.y + 24, 0.14))
	# 3) el yukarı geri çekilir + solar
	tw.tween_property(_back, "position", _back_base + Vector2(18, -GRAB_RISE), 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_front, "position", _front_base + Vector2(18, -GRAB_RISE), 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_root, "modulate:a", 0.0, 0.26).set_delay(0.04)
	tw.tween_callback(_finish)

## Yerleştirmeden vazgeç (deselect / sağ tık): el hızlıca yukarı kaçar.
func cancel() -> void:
	if not _active or _releasing:
		return
	_kill_tween()
	_releasing = true
	_idle = false
	var tw := create_tween().set_parallel(true)
	_tw = tw
	tw.tween_property(_back, "position", _back_base + Vector2(0, -GRAB_RISE), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_front, "position", _front_base + Vector2(0, -GRAB_RISE), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_root, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(_finish)

func is_active() -> bool:
	return _active

func _finish() -> void:
	_active = false
	_releasing = false
	_idle = false
	_tw = null
	visible = false
	_clear_held()
	_back.position = _back_base
	_front.position = _front_base

func _clear_held() -> void:
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = null

func _process(dt: float) -> void:
	if not _active:
		return
	if not _releasing:
		# UI barları girdiyi yutsa bile takip sürsün diye imleci doğrudan oku
		_target = get_viewport().get_mouse_position()
		var t := clampf(FOLLOW_LERP * dt, 0.0, 1.0)
		_root.position = _root.position.lerp(_target, t)
	# hafif salınım/eğim — yalnız kavrama oturduktan sonra (grab tween'iyle çakışmaz)
	if _idle:
		_bob_t += dt
		_root.rotation = deg_to_rad(sin(_bob_t * 2.6) * 2.2)
		var sway := sin(_bob_t * 3.4) * 2.0
		_back.position.y = _back_base.y + sway
		_front.position.y = _front_base.y + sway

## Taşınan birim önizlemesi: sprite varsa dokudan, yoksa sınıf renkli kapsül.
## Tepe-ortası grip origin'e (0,0) hizalı: yatayda ortalı, tepesi TOP_OFF'ta.
func _make_preview(tex: Texture2D, tint: Color) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.pivot_offset = Vector2.ZERO
	if tex != null:
		var s := HELD_H / float(tex.get_height())
		var w := tex.get_width() * s
		var tr := TextureRect.new()
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(w, HELD_H)
		tr.position = Vector2(-w * 0.5 + MODEL_DX, TOP_OFF)
		wrap.add_child(tr)
	else:
		var cap := _CapsulePreview.new()
		cap.tint = tint
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cw := HELD_H * 0.62
		cap.size = Vector2(cw, HELD_H)
		cap.position = Vector2(-cw * 0.5 + MODEL_DX, TOP_OFF)
		wrap.add_child(cap)
	return wrap

## Kapsül birimler (mesh_id boş) için basit çizili önizleme
class _CapsulePreview extends Control:
	var tint := Color.GRAY
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := w * 0.5
		_capsule(w, h, r, 3.0, Color(0.05, 0.04, 0.06))
		_capsule(w, h, r, 0.0, tint.lightened(0.12))
	func _capsule(w: float, h: float, r: float, grow: float, col: Color) -> void:
		var cx := w * 0.5
		draw_circle(Vector2(cx, r) + Vector2(0, -grow), r + grow, col)
		draw_circle(Vector2(cx, h - r) + Vector2(0, grow), r + grow, col)
		draw_rect(Rect2(cx - r - grow, r, (r + grow) * 2.0, h - r * 2.0), col)
