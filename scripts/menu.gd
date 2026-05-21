extends Node

@onready var btn_start_solo: Button = $"UI/Buttons/StartSolo"
@onready var btn_start_coop: Button = $"UI/Buttons/StartSolo2"
@onready var opt_coop_players: OptionButton = $"UI/Buttons/StartCoop"
@onready var btn_start_vs: Button = $"UI/Buttons/StartVS"
@onready var btn_online_create: Button = $"UI/Buttons/OnlineCreate"
@onready var input_online_code: LineEdit = $"UI/Buttons/OnlineCode"
@onready var btn_online_join: Button = $"UI/Buttons/OnlineJoin"
@onready var btn_online_reconnect: Button = $"UI/Buttons/OnlineReconnect"
@onready var network_client: Node = get_node_or_null("/root/NetworkClient")

var _online_request_pending: bool = false

func _ready() -> void:
	if btn_start_solo:
		btn_start_solo.pressed.connect(_on_start_solo_pressed)
	if btn_start_coop:
		btn_start_coop.pressed.connect(_on_start_coop_pressed)
	if btn_start_vs:
		btn_start_vs.pressed.connect(_on_start_vs_pressed)
	if btn_online_create:
		btn_online_create.pressed.connect(_on_online_create_pressed)
	if btn_online_join:
		btn_online_join.pressed.connect(_on_online_join_pressed)
	if btn_online_reconnect:
		btn_online_reconnect.pressed.connect(_on_online_reconnect_pressed)
	if network_client:
		if network_client.has_signal("match_ready") and not network_client.match_ready.is_connected(_on_online_match_ready):
			network_client.match_ready.connect(_on_online_match_ready)
		if network_client.has_signal("error") and not network_client.error.is_connected(_on_online_error):
			network_client.error.connect(_on_online_error)

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

func _on_online_create_pressed() -> void:
	_begin_online_request("create")

func _on_online_join_pressed() -> void:
	var code := ""
	if input_online_code:
		code = input_online_code.text.strip_edges()
	if code.is_empty():
		_on_online_error("Enter a match code first.")
		return
	_begin_online_request("join", code)

func _on_online_reconnect_pressed() -> void:
	_begin_online_request("reconnect")

func _begin_online_request(action: String, code: String = "") -> void:
	if _online_request_pending:
		return
	if not network_client:
		_on_online_error("Online client not available.")
		return
	_online_request_pending = true
	_set_online_controls_enabled(false)
	var player_name := _get_player_name()
	var scene_path := "res://versus/vs_map_1.tscn"
	match action:
		"create":
			if network_client.has_method("create_match"):
				network_client.create_match(player_name, scene_path)
		"join":
			if network_client.has_method("join_match"):
				network_client.join_match(code, player_name, scene_path)
		"reconnect":
			if network_client.has_method("reconnect_match"):
				network_client.reconnect_match(player_name, scene_path)

func _on_online_match_ready(scene_path: String) -> void:
	_online_request_pending = false
	_set_online_controls_enabled(true)
	var target_scene := scene_path if not scene_path.is_empty() else "res://versus/vs_map_1.tscn"
	var players_count := 2
	if network_client and network_client.has_method("get_players"):
		var players: Array = network_client.get_players()
		players_count = max(players.size(), 2)
	_save_players_to_user_data(players_count)
	PlayerManager.number_of_players = players_count
	get_tree().change_scene_to_file(target_scene)

func _on_online_error(message: String) -> void:
	_online_request_pending = false
	_set_online_controls_enabled(true)
	print("Online menu error: %s" % message)

func _set_online_controls_enabled(enabled: bool) -> void:
	if btn_online_create:
		btn_online_create.disabled = not enabled
	if btn_online_join:
		btn_online_join.disabled = not enabled
	if btn_online_reconnect:
		btn_online_reconnect.disabled = not enabled
	if input_online_code:
		input_online_code.editable = enabled

func _get_player_name() -> String:
	var fallback := "Player 1"
	var user_data_path := "user://userdat.json"
	if not FileAccess.file_exists(user_data_path):
		return fallback
	var text := FileAccess.get_file_as_string(user_data_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = parsed
	if not data.has("player") or typeof(data["player"]) != TYPE_DICTIONARY:
		return fallback
	var player: Dictionary = data["player"]
	if not player.has("name"):
		return fallback
	var player_name := str(player["name"]).strip_edges()
	return fallback if player_name.is_empty() else player_name

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
