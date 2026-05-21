extends Node

signal match_state(state: Dictionary)
signal turn_started(player_id: String, turn_number: int)
signal shot_applied(data: Dictionary)
signal player_joined(player: Dictionary)
signal player_left(player_id: String)
signal match_finished(data: Dictionary)
signal error(message: String)
signal match_ready(scene_path: String)

const MatchStateScript = preload("res://Online/MatchState.gd")

@export var backend_http_url: String = ""
@export var backend_ws_url: String = ""

var match_state_data = MatchStateScript.new()
var _http: HTTPRequest
var _ws := WebSocketPeer.new()
var _ws_connected: bool = false
var _request_context: String = ""
var _request_payload: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_request_completed)
	if backend_http_url.is_empty():
		var cfg = ProjectSettings.get_setting("online/backend_http_url", "")
		if cfg is String:
			backend_http_url = str(cfg)
	if backend_ws_url.is_empty():
		var cfg_ws = ProjectSettings.get_setting("online/backend_ws_url", "")
		if cfg_ws is String:
			backend_ws_url = str(cfg_ws)

func _process(_delta: float) -> void:
	if not _ws_connected:
		return
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_ws.poll()
		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			_handle_ws_message(raw)
	elif state in [WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED]:
		_ws_connected = false
		match_state_data.connected = false
		match_state.emit(match_state_data.to_dict())
		error.emit("Online connection lost.")

func is_online_match() -> bool:
	return match_state_data.online_enabled

func is_synchronized() -> bool:
	return match_state_data.synchronized

func can_local_player_shoot() -> bool:
	return match_state_data.can_local_shoot()

func has_pending_local_shot() -> bool:
	return match_state_data.pending_local_shot

func get_local_player_id() -> String:
	return match_state_data.local_player_id

func get_active_player_id() -> String:
	return match_state_data.active_player_id

func get_turn_number() -> int:
	return match_state_data.turn_number

func get_players() -> Array:
	return match_state_data.players.duplicate(true)

func create_match(player_name: String, scene_path: String = "res://versus/vs_map_1.tscn") -> void:
	if _has_backend():
		_request_context = "create"
		_request_payload = {"player_name": player_name, "scene_path": scene_path}
		_http_json("/matches/create", HTTPClient.METHOD_POST, _request_payload)
		return
	_start_local_online_match(player_name, scene_path, "")

func join_match(join_code: String, player_name: String, scene_path: String = "res://versus/vs_map_1.tscn") -> void:
	if _has_backend():
		_request_context = "join"
		_request_payload = {"join_code": join_code, "player_name": player_name, "scene_path": scene_path}
		_http_json("/matches/join", HTTPClient.METHOD_POST, _request_payload)
		return
	_start_local_online_match(player_name, scene_path, join_code)

func reconnect_match(player_name: String, scene_path: String = "res://versus/vs_map_1.tscn") -> void:
	if _has_backend():
		_request_context = "reconnect"
		_request_payload = {"player_name": player_name, "scene_path": scene_path}
		_http_json("/matches/reconnect", HTTPClient.METHOD_POST, _request_payload)
		return
	_start_local_online_match(player_name, scene_path, "LOCAL")

func submit_shot(payload: Dictionary) -> bool:
	if not can_local_player_shoot():
		return false
	match_state_data.pending_local_shot = true
	match_state.emit(match_state_data.to_dict())
	if _has_backend() and _ws_connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var packet := {
			"type": "submit_shot",
			"match_id": match_state_data.match_id,
			"payload": payload
		}
		_ws.send_text(JSON.stringify(packet))
	else:
		var accepted := payload.duplicate(true)
		accepted["player_id"] = match_state_data.local_player_id
		call_deferred("_emit_local_shot_applied", accepted)
	return true

func notify_shot_settled() -> void:
	if not is_online_match():
		return
	if _has_backend() and _ws_connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var packet := {
			"type": "shot_settled",
			"match_id": match_state_data.match_id,
			"turn_number": match_state_data.turn_number
		}
		_ws.send_text(JSON.stringify(packet))

func report_win(player_id: String) -> bool:
	if not is_online_match():
		return false
	var payload := {"type": "win", "player_id": player_id, "match_id": match_state_data.match_id}
	if _has_backend() and _ws_connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(payload))
	else:
		call_deferred("_emit_local_match_finished", {"winner_player_id": player_id})
	return true

func report_out_of_bounds(player_id: String, position: Vector2) -> void:
	if not is_online_match():
		return
	var payload := {
		"type": "out_of_bounds",
		"player_id": player_id,
		"match_id": match_state_data.match_id,
		"x": position.x,
		"y": position.y
	}
	_send_optional_ws_event(payload)

func report_tee_event(player_id: String, event_name: String) -> void:
	if not is_online_match():
		return
	var payload := {
		"type": "tee_event",
		"event_name": event_name,
		"player_id": player_id,
		"match_id": match_state_data.match_id
	}
	_send_optional_ws_event(payload)

func _send_optional_ws_event(payload: Dictionary) -> void:
	if _has_backend() and _ws_connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(payload))

func _emit_local_shot_applied(data: Dictionary) -> void:
	match_state_data.pending_local_shot = false
	shot_applied.emit(data)
	match_state.emit(match_state_data.to_dict())

func _emit_local_match_finished(data: Dictionary) -> void:
	match_state_data.match_status = "finished"
	match_finished.emit(data)
	match_state.emit(match_state_data.to_dict())

func _has_backend() -> bool:
	return not backend_http_url.strip_edges().is_empty()

func _http_json(path: String, method: int, payload: Dictionary) -> void:
	if not _http:
		error.emit("HTTP client unavailable.")
		return
	var base := backend_http_url.strip_edges()
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	var url := base + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify(payload)
	var req_err := _http.request(url, headers, method, body)
	if req_err != OK:
		error.emit("Network request failed to start.")
		_start_local_online_match(str(payload.get("player_name", "Player")), str(payload.get("scene_path", "res://versus/vs_map_1.tscn")), str(payload.get("join_code", "")))

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		error.emit("Backend request failed (%s)." % response_code)
		_start_local_online_match(str(_request_payload.get("player_name", "Player")), str(_request_payload.get("scene_path", "res://versus/vs_map_1.tscn")), str(_request_payload.get("join_code", "")))
		return
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		error.emit("Backend returned invalid match payload.")
		_start_local_online_match(str(_request_payload.get("player_name", "Player")), str(_request_payload.get("scene_path", "res://versus/vs_map_1.tscn")), str(_request_payload.get("join_code", "")))
		return
	_apply_backend_snapshot(parsed as Dictionary)
	_try_open_ws()
	match_ready.emit(match_state_data.scene_path)

func _apply_backend_snapshot(data: Dictionary) -> void:
	var snapshot := data
	if data.has("match") and data["match"] is Dictionary:
		snapshot = data["match"]
	match_state_data.reset()
	match_state_data.online_enabled = true
	match_state_data.synchronized = true
	match_state_data.connected = true
	match_state_data.apply_snapshot(snapshot)
	if match_state_data.local_player_id.is_empty():
		match_state_data.local_player_id = str(data.get("local_player_id", "p1"))
	if match_state_data.scene_path.is_empty():
		match_state_data.scene_path = "res://versus/vs_map_1.tscn"
	if match_state_data.players.is_empty():
		match_state_data.players = [{"id": match_state_data.local_player_id, "name": "Player 1"}]
	if match_state_data.active_player_id.is_empty():
		match_state_data.active_player_id = match_state_data.players[0].get("id", match_state_data.local_player_id)
	match_state.emit(match_state_data.to_dict())
	turn_started.emit(match_state_data.active_player_id, match_state_data.turn_number)

func _start_local_online_match(player_name: String, scene_path: String, join_code: String) -> void:
	var local_name := player_name.strip_edges()
	if local_name.is_empty():
		local_name = "Player 1"
	match_state_data.reset()
	match_state_data.online_enabled = true
	match_state_data.synchronized = true
	match_state_data.connected = true
	match_state_data.match_id = "local_%s" % Time.get_ticks_msec()
	match_state_data.join_code = join_code if not join_code.is_empty() else "LOCAL"
	match_state_data.scene_path = scene_path
	match_state_data.players = [{"id": "p1", "name": local_name}, {"id": "p2", "name": "Remote"}]
	match_state_data.local_player_id = "p1"
	match_state_data.active_player_id = "p1"
	match_state_data.turn_number = 1
	match_state_data.match_status = "ready"
	match_state.emit(match_state_data.to_dict())
	turn_started.emit(match_state_data.active_player_id, match_state_data.turn_number)
	match_ready.emit(scene_path)

func _try_open_ws() -> void:
	if backend_ws_url.strip_edges().is_empty():
		return
	var url := backend_ws_url.strip_edges()
	var ws_err := _ws.connect_to_url(url)
	if ws_err != OK:
		error.emit("WebSocket connection failed.")
		return
	_ws_connected = true

func _handle_ws_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var msg_type := str(data.get("type", ""))
	match msg_type:
		"snapshot":
			if data.has("match") and data["match"] is Dictionary:
				match_state_data.apply_snapshot(data["match"])
				match_state_data.synchronized = true
				match_state.emit(match_state_data.to_dict())
		"turn_started":
			match_state_data.active_player_id = str(data.get("player_id", match_state_data.active_player_id))
			match_state_data.turn_number = int(data.get("turn_number", match_state_data.turn_number + 1))
			match_state_data.pending_local_shot = false
			turn_started.emit(match_state_data.active_player_id, match_state_data.turn_number)
			match_state.emit(match_state_data.to_dict())
		"shot_applied":
			match_state_data.pending_local_shot = false
			shot_applied.emit(data)
			match_state.emit(match_state_data.to_dict())
		"player_joined":
			if data.has("player") and data["player"] is Dictionary:
				player_joined.emit(data["player"])
		"player_left":
			player_left.emit(str(data.get("player_id", "")))
		"match_finished":
			match_state_data.match_status = "finished"
			match_finished.emit(data)
			match_state.emit(match_state_data.to_dict())
		"error":
			error.emit(str(data.get("message", "Online error.")))
