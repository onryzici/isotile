extends Node
## Main / ScreenManager (CLAUDE.md §17.5): run akışını orkestre eder.
## Harita → düğüm seç → Savaş/Dükkan → sonuç → katman ilerle → Harita ...
## Boss katmanı geçilince veya oyuncu bayrağı düşünce run biter → yeni run.

const BATTLE_SCREEN := preload("res://scenes/battle_screen.tscn")

var _current: Node
var _last_won := false
var _node_type: StringName = &"savas"   # son ziyaret edilen düğüm tipi

func _ready() -> void:
	# Özel fare imleci (oyunun stiline uygun ok) — hotspot ucu
	var cur := load("res://assets/ui/cursor.png")
	if cur:
		Input.set_custom_mouse_cursor(cur, Input.CURSOR_ARROW, Vector2(2, 1))
	_setup_grain()
	EventBus.map_node_selected.connect(_on_map_node)
	EventBus.return_to_map.connect(_on_return_to_map)

## P → ekran görüntüsü al (res://screenshots/). Herhangi bir ekranda çalışır.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_take_screenshot()

## --shot[=saniye] : belirtilen süre sonra otomatik screenshot al + çık (görsel CI)
func _maybe_autoshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--shot" or arg.begins_with("--shot="):
			var secs := 2.5
			if arg.begins_with("--shot="):
				secs = float(arg.substr(7))
			var t := get_tree().create_timer(secs)
			await t.timeout
			await _take_screenshot()
			await get_tree().create_timer(0.2).timeout
			get_tree().quit()
			return

func _take_screenshot() -> void:
	# Kare tam çizildikten sonra yakala (aksi hâlde eksik/boş frame olabilir)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir_abs := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var ts := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path := "%s/shot_%s.png" % [dir_abs, ts]
	var err := img.save_png(path)
	if err == OK:
		print("📸 screenshot: ", path)
	else:
		push_warning("screenshot kaydedilemedi (err %d): %s" % [err, path])

## Global film grain — tüm ekranların üstünde ince gürültü + vinyet
## NOT: fonksiyon ekran akışı bootstrap'ini de içeriyor; grain katmanı
## kapalı (test — Onur isteği), akış duruyor.
func _setup_grain() -> void:
	# grain katmanı devre dışı:
	# var grain := CanvasLayer.new()
	# grain.layer = 100
	# var rect := ColorRect.new()
	# rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# var gmat := ShaderMaterial.new()
	# gmat.shader = preload("res://shaders/grain.gdshader")
	# rect.material = gmat
	# grain.add_child(rect)
	# add_child(grain)

	var args := OS.get_cmdline_user_args()
	var enc_override := false
	for arg in args:
		if arg.begins_with("--enc="):
			enc_override = true

	# Debug ekranları (test) — hep taze run
	if enc_override or "--merge" in args or "--autobattle" in args \
			or "--shop" in args or "--reward" in args or "--map" in args \
			or "--garrison" in args or "--runend" in args:
		GameState.start_new_run()
		for arg in args:
			if arg.begins_with("--enc="):
				GameState.current_encounter = StringName(arg.substr(6))
		if "--merge" in args:
			_show(_make_merge())
		elif "--shop" in args:
			_show(_make_shop())
		elif "--reward" in args:
			var rs := RewardScreen.new()
			rs.done.connect(_show_map)
			_show(rs)
		elif "--garrison" in args:
			var g := GarrisonScreen.new()
			g.closed.connect(_show_map)
			_show(g)
		elif "--runend" in args:
			_end_layers = 3
			_show_run_end()
		elif "--map" in args:
			_show_map()
		else:
			_show(BATTLE_SCREEN.instantiate())
		_maybe_autoshot()
		return

	# Normal: başlangıç menüsü
	_show_menu()
	_maybe_autoshot()

## Başlangıç menüsü → Yeni Sefer / Devam / Garnizon
func _show_menu() -> void:
	var m := MainMenuScreen.new()
	m.new_run.connect(func() -> void:
		GameState.start_new_run()
		_show_map())
	m.continue_run.connect(func() -> void:
		if not GameState.load_run():
			GameState.start_new_run()
		_show_map())
	m.open_garrison.connect(func() -> void:
		var g := GarrisonScreen.new()
		g.closed.connect(_show_menu)
		_show(g))
	_show(m)

func _save() -> void:
	GameState.save_run()

func _show(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(node)

func _show_map() -> void:
	_show(MapScreen.new())

func _make_merge() -> MergeScreen:
	var ms := MergeScreen.new()
	ms.closed.connect(_on_return_to_map.bind(true))   # dükkan ziyareti katmanı ilerletir
	return ms

# ------------------------------------------------------------- akış

## Harita düğümü seçildi → uygun ekranı aç
func _on_map_node(node: Dictionary) -> void:
	_node_type = node.get("type", &"savas")
	match _node_type:
		&"savas", &"elit", &"boss":
			GameState.current_encounter = node.get("enc", &"orta")
			_show(BATTLE_SCREEN.instantiate())
		&"dukkan":
			_show(_make_shop())
		_:
			_show_map()

## Düğüm bitti → haritaya dön. Savaş zaferinde önce ÖDÜL ekranı; her ziyaret
## katmanı ilerletir (kaybetmek de ilerlemedir §1.5); bayrak düşünce sefer biter.
func _on_return_to_map(won: bool) -> void:
	if GameState.run_over:
		_end_run(false)   # oyuncu bayrağı düştü → bozgun
		return
	if won and _node_type in [&"savas", &"elit", &"boss"]:
		var rs := RewardScreen.new()
		rs.done.connect(_advance_and_map)
		_show(rs)
		return
	_advance_and_map()

func _advance_and_map() -> void:
	GameState.layer_index += 1
	if GameState.layer_index >= Encounters.MAP_TEMPLATE.size():
		_end_run(true)   # boss katmanı geçildi → zafer
		return
	_save()
	_show_map()

# ------------------------------------------------------------- sefer sonu (B.3)

var _end_victory := false
var _end_layers := 0
var _end_earned := 0

func _end_run(victory: bool) -> void:
	_end_victory = victory
	_end_layers = GameState.layer_index
	_end_earned = GameState.award_meta(_end_layers, victory)
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	_show_run_end()

func _show_run_end() -> void:
	var rs := RunEndScreen.new()
	rs.setup(_end_victory, _end_layers, _end_earned)
	rs.new_run.connect(func() -> void:
		GameState.start_new_run()
		_show_map())
	rs.open_garrison.connect(func() -> void:
		var gs := GarrisonScreen.new()
		gs.closed.connect(_show_run_end)   # Garnizon'dan sefer-sonu'na dön
		_show(gs))
	_show(rs)

func _make_shop() -> ShopScreen:
	var s := ShopScreen.new()
	s.closed.connect(_on_return_to_map.bind(true))
	return s
