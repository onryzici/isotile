class_name StatBadges
extends Control
## Birim stat rozetleri (§16.5) — referans (Master of Piece): 3 ayrı koyu
## KALKAN/gem şekli, yan yana hafif üst üste; üstte renkli minik ikon, altta
## büyük beyaz sayı. Yüksek çözünürlükte çizilir (keskin), 3B'de ayak dibinde
## billboard olarak gösterilir. game-icons.net ikonları (CC BY 3.0).

const ICON_ATK := preload("res://assets/icons/attack.svg")
const ICON_HP := preload("res://assets/icons/health.svg")
const ICON_SPD := preload("res://assets/icons/speed.svg")

# Yüksek iç çözünürlük → 3B'ye küçültülünce keskin kalır (supersample)
const VP_SIZE := Vector2(216, 108)

const FILL := Color(0.07, 0.07, 0.085, 0.97)     # koyu kömür
const EDGE := Color(0.0, 0.0, 0.0, 0.85)          # dış hat
const TOP_HI := Color(0.28, 0.28, 0.32, 0.9)      # üst bevel highlight
const NUM := Color(0.97, 0.95, 0.90)
const C_ATK := Color(0.36, 0.74, 0.74)            # teal kılıç
const C_HP := Color(0.83, 0.30, 0.28)             # kızıl kalp
const C_SPD := Color(0.86, 0.72, 0.36)            # kehribar

var _atk := 0
var _hp := 0
var _spd := 0
var _hp_max := -1
var _font: Font

func _init() -> void:
	size = VP_SIZE
	_font = UITheme.body_font()

func set_stats(atk: int, hp: int, spd: int, hp_max: int = -1) -> void:
	_atk = atk; _hp = hp; _spd = spd; _hp_max = hp_max
	queue_redraw()

func _draw() -> void:
	var w := 54.0
	var h := 76.0
	var gap := -6.0                    # hafif üst üste bin
	var total := 3.0 * w + 2.0 * gap
	var start_x := (VP_SIZE.x - total) * 0.5 + w * 0.5
	var cy := VP_SIZE.y * 0.5 + 2.0
	var data := [
		[ICON_ATK, C_ATK, _atk],
		[ICON_HP, C_HP, _hp],
		[ICON_SPD, C_SPD, _spd],
	]
	# ortadaki (CAN) en üstte çizilsin → sıra: 0, 2, 1
	for i: int in [0, 2, 1]:
		var cx := start_x + i * (w + gap)
		var col: Color = data[i][1]
		var num_col := NUM
		if i == 1 and _hp_max > 0 and _hp < _hp_max:
			num_col = Color(0.95, 0.55, 0.48)
		_draw_shield(Vector2(cx, cy), w, h)
		_draw_icon(data[i][0], Vector2(cx, cy - h * 0.22), h * 0.23, col)
		_draw_num(str(data[i][2]), Vector2(cx, cy + h * 0.36), w, num_col)

## Kalkan/gem: beveled düz tepe + aşağı sivri uç
func _draw_shield(c: Vector2, w: float, h: float) -> void:
	var hw := w * 0.5
	var bev := w * 0.20
	var top := c.y - h * 0.5
	var pts := PackedVector2Array([
		Vector2(c.x - hw, top + bev),
		Vector2(c.x - hw + bev, top),
		Vector2(c.x + hw - bev, top),
		Vector2(c.x + hw, top + bev),
		Vector2(c.x + hw, c.y + h * 0.18),
		Vector2(c.x, c.y + h * 0.5),
		Vector2(c.x - hw, c.y + h * 0.18),
	])
	draw_colored_polygon(pts, FILL)

func _draw_icon(tex: Texture2D, center: Vector2, s: float, tint: Color) -> void:
	draw_texture_rect(tex, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)

func _draw_num(text: String, baseline: Vector2, w: float, col: Color) -> void:
	draw_string(_font, Vector2(baseline.x - w * 0.5, baseline.y), text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 50, col)
