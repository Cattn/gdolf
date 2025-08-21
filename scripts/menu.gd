extends Node

@onready var btn_start_solo: Button = $"UI/Buttons/StartSolo"
@onready var btn_start_coop: Button = $"UI/Buttons/StartSolo2"
@onready var opt_coop_players: OptionButton = $"UI/Buttons/StartCoop"
@onready var btn_start_vs: Button = $"UI/Buttons/StartVS"

func _ready() -> void:
	if btn_start_solo:
		btn_start_solo.pressed.connect(_on_start_solo_pressed)
	if btn_start_coop:
		btn_start_coop.pressed.connect(_on_start_coop_pressed)
	if btn_start_vs:
		btn_start_vs.pressed.connect(_on_start_vs_pressed)

func _on_start_solo_pressed() -> void:
	_save_players_to_user_data(1)
	PlayerManager.number_of_players = 1
	get_tree().change_scene_to_file("res://campaign_1.tscn")

func _on_start_coop_pressed() -> void:
	var count := _get_coop_players_count()
	_save_players_to_user_data(count)
	PlayerManager.number_of_players = count
	get_tree().change_scene_to_file("res://campaign_1.tscn")

func _on_start_vs_pressed() -> void:
	get_tree().change_scene_to_file("res://versus/map_select.tscn")

func _get_coop_players_count() -> int:
	var idx := 0
	if opt_coop_players:
		idx = opt_coop_players.selected
	return clamp(2 + idx, 2, 4)

func _save_players_to_user_data(players: int) -> void:
	var user_data_source_path := "res://config/userdat.json"
	var user_data_path := "user://userdat.json"
	var defaults: Dictionary = {}
	if FileAccess.file_exists(user_data_source_path):
		var def_text := FileAccess.get_file_as_string(user_data_source_path)
		var def_data = JSON.parse_string(def_text)
		if typeof(def_data) == TYPE_DICTIONARY:
			defaults = def_data
	var user_data: Dictionary = {}
	if FileAccess.file_exists(user_data_path):
		var user_text := FileAccess.get_file_as_string(user_data_path)
		var parsed = JSON.parse_string(user_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			user_data = parsed
	else:
		user_data = defaults.duplicate(true)
	var merged: Dictionary = _merge_defaults(user_data, defaults) as Dictionary
	if not merged.has("options") or typeof(merged["options"]) != TYPE_DICTIONARY:
		merged["options"] = {}
	merged["options"]["players"] = clamp(players, 1, 4)
	var f := FileAccess.open(user_data_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(merged))
		f.close()

func _merge_defaults(user_data: Variant, defaults: Variant) -> Variant:
	if typeof(user_data) == TYPE_DICTIONARY and typeof(defaults) == TYPE_DICTIONARY:
		var out: Dictionary = user_data
		for k in defaults.keys():
			if out.has(k):
				out[k] = _merge_defaults(out[k], defaults[k])
			else:
				out[k] = defaults[k]
		return out
	return user_data
