class_name InfirmaryScreen
extends NodeDiorama
## Sahra Revan (gelistirme §8, diyorama): sıcak fener ışıklı revir adası —
## haç sancaklı çadır, şifacı, sargılı kuzu. İki hizmetten BİRİ, elmas seçimle:
## sancağın üstünde BAYRAK ONARIMI (+10) / kuzunun üstünde SÜRÜ BAKIMI (tam CAN).

signal closed

const FLAG_REPAIR := 10
const WARM := Color(0.55, 0.82, 0.78)
const IC_SHIELD := preload("res://assets/icons/shield.svg")
const IC_HP := preload("res://assets/icons/health.svg")

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(4, 0), Vector2i(0, 3)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(3, 0)] = 1
	build_island(cells)

	# revir çadırı + şifacı + yaralı kuzu + mavi sancak + sıcak fener
	add_tent(Vector2i(3, 0), Color(0.52, 0.44, 0.30))
	# yaw 45'te (x+z) sabit hücreler aynı ekran kolonu — figürleri köşegenlere dağıt
	add_sprite_prop("res://assets/units/sifaci.png", Vector2i(3, 1), 1.05)
	add_sprite_prop("res://assets/units/kuzu.png", Vector2i(1, 2), 0.85)
	add_glow_slab(Vector2i(1, 2), Color(0.10, 0.08, 0.06), Color(0.95, 0.7, 0.35), 0.45, 0.15)
	# sancak sol-ön köşegende (kuzu −1.5, sancak −2.5 → farklı ekran kolonları)
	add_flag(Vector2i(0, 2), true)
	add_mist(Vector2i(4, 2), Color(0.85, 0.8, 0.7, 0.12))
	add_omni(Vector2i(3, 0), Color(1.0, 0.75, 0.45), 2.4, 1.1)
	add_omni(Vector2i(1, 2), Color(1.0, 0.8, 0.5), 1.2, 0.7)

	set_description("SAHRA REVAN",
		"Şifacının vakti dar — yalnız BİR hizmet seçebilirsin.")

	var cap := GameState.flag_cap()
	var gain := mini(FLAG_REPAIR, cap - GameState.player_flag_hp)
	var wounded := 0
	for i in GameState.squad.size():
		if GameState.current_hp(i) < GameState.squad[i].can:
			wounded += 1

	# elmaslar: sancağın üstünde onarım, kuzunun üstünde sürü bakımı
	var d1 := add_choice(cell_point(Vector2i(0, 2), 1.6), IC_SHIELD,
		"⚑ +%d" % gain, Color(0.34, 0.55, 0.86),
		"Bayrak Onarımı: sancak %d/%d → %d/%d" % [GameState.player_flag_hp, cap,
			GameState.player_flag_hp + gain, cap],
		func() -> void:
			GameState.player_flag_hp = mini(cap, GameState.player_flag_hp + FLAG_REPAIR)
			_finish("⚑ +%d" % gain))
	set_choice_enabled(d1, gain > 0)

	var d2 := add_choice(cell_point(Vector2i(1, 2), 1.05), IC_HP,
		"%d yaralı" % wounded, Color(0.78, 0.35, 0.35),
		"Sürü Bakımı: tüm bölük tam CAN'a döner",
		func() -> void:
			GameState.heal_all()
			_finish("♥ Sürü iyileşti"))
	set_choice_enabled(d2, wounded > 0)

	set_footer("Sancak: %d/%d   ·   %d yaralı birim" % [
		GameState.player_flag_hp, cap, wounded])
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())

## Seçim uygulandı: şifa pop → kapan
func _finish(msg: String) -> void:
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	var pop := Label.new()
	pop.text = msg
	pop.add_theme_font_size_override("font_size", 48)
	pop.add_theme_color_override("font_color", WARM.lightened(0.25))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.4)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
