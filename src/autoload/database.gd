extends Node
## Database — tüm res://data/**/*.tres kaynaklarını açılışta yükler, id -> Resource sözlüğü.
## Yeni içerik eklemek = yeni .tres dosyası; bu kod değişmez (CLAUDE.md §17.3).

const DATA_ROOT := "res://data"

# kategori (klasör adı) -> { id: Resource }
var _tables: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_tables.clear()
	var dir := DirAccess.open(DATA_ROOT)
	if dir == null:
		return # data klasörü henüz yok (erken milestone)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_load_category(entry)
		entry = dir.get_next()

func _load_category(category: String) -> void:
	var table: Dictionary = {}
	var path := DATA_ROOT.path_join(category)
	for file in ResourceLoader.list_directory(path):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(path.path_join(file))
			if res != null and "id" in res:
				table[StringName(res.id)] = res
	_tables[category] = table

func get_resource(category: String, id: StringName) -> Resource:
	return _tables.get(category, {}).get(id)

func get_all(category: String) -> Array:
	return _tables.get(category, {}).values()
