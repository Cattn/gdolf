extends Node
class_name GameManager

static var _levels: Array = []
static var _current_level_index: int = 0
var _last_scene_path: String = ""

static func levels() -> Array:
	if _levels.is_empty():
		_levels = _load_levels()
	return _levels

static func reset_progress() -> void:
	_current_level_index = 0

static func get_current_level_index() -> int:
	return _current_level_index

static func set_current_level_index(idx: int) -> void:
	_current_level_index = clamp(idx, 0, max(levels().size() - 1, 0))

static func get_level_path(idx: int) -> String:
	var ls := levels()
	if idx >= 0 and idx < ls.size():
		var d = ls[idx]
		if typeof(d) == TYPE_DICTIONARY and d.has("path") and typeof(d["path"]) == TYPE_STRING:
			return d["path"]
	return ""

static func get_current_level_path() -> String:
	return get_level_path(_current_level_index)

static func advance_to_next_level() -> void:
	set_current_level_index(_current_level_index + 1)

static func _load_levels() -> Array:
	var cfg_path := "res://config/gamemanager.json"
	if not FileAccess.file_exists(cfg_path):
		return []
	var text := FileAccess.get_file_as_string(cfg_path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	if not data.has("campaign_levels") or typeof(data["campaign_levels"]) != TYPE_ARRAY:
		return []
	return data["campaign_levels"]

func _ready() -> void:
	var cs := get_tree().current_scene
	if cs:
		_last_scene_path = cs.scene_file_path
		if _last_scene_path.ends_with("/main_menu.tscn"):
			reset_progress()

func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs:
		var path := cs.scene_file_path
		if path != _last_scene_path:
			_last_scene_path = path
			if path.ends_with("/main_menu.tscn"):
				reset_progress()
