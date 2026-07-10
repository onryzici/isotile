class_name IntroScreen
extends Node
## COLD OPEN (gelistirme §3.1): ilk açılışta kısa anlatı kartı — Kara Pus,
## boş ağıl, "son sürüyü topla". 3-4 cümle, tek tıkla geçilir; bir daha
## zorlanmaz (meta_intro_seen). Fiziksel kart dili EventCard'dan gelir.

signal done

const LORE := {
	"baslik": "KARA PUS",
	"metin": "Yıllar önce gökten inen Kara Pus, ışığı ve hafızayı yuttu; " +
		"köyler birbirinden koptu.\n\nPusun içinde Kurt Tarikatı türedi — " +
		"bir zamanlar çoban olanlar, şimdi pusa tapıyor.\n\nSen son ayakta " +
		"kalan Ağıl'ın çobanısın.",
	"secenekler": [{"ad": "Son sürüyü topla", "etki": "none"}],
}

var _left := false

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.make()
	ui.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://shaders/bg_gradient.gdshader")
	bg.material = bg_mat
	root.add_child(bg)
	var card := EventCard.new()
	root.add_child(card)
	card.open(LORE)
	card.choice_made.connect(func(_opt: Dictionary) -> void:
		if not _left:
			_left = true
			done.emit()
			queue_free())
