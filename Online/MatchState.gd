extends RefCounted
class_name MatchState

var match_id: String = ""
var join_code: String = ""
var scene_path: String = "res://versus/vs_map_1.tscn"
var players: Array = []
var active_player_id: String = ""
var local_player_id: String = ""
var turn_number: int = 1
var strokes := {}
var ball_transforms := {}
var match_status: String = "idle"
var online_enabled: bool = false
var synchronized: bool = false
var connected: bool = false
var pending_local_shot: bool = false

func reset() -> void:
	match_id = ""
	join_code = ""
	scene_path = "res://versus/vs_map_1.tscn"
	players.clear()
	active_player_id = ""
	local_player_id = ""
	turn_number = 1
	strokes.clear()
	ball_transforms.clear()
	match_status = "idle"
	online_enabled = false
	synchronized = false
	connected = false
	pending_local_shot = false

func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("match_id"):
		match_id = str(snapshot["match_id"])
	if snapshot.has("join_code"):
		join_code = str(snapshot["join_code"])
	if snapshot.has("scene_path"):
		scene_path = str(snapshot["scene_path"])
	if snapshot.has("players") and snapshot["players"] is Array:
		players = (snapshot["players"] as Array).duplicate(true)
	if snapshot.has("active_player_id"):
		active_player_id = str(snapshot["active_player_id"])
	if snapshot.has("local_player_id"):
		local_player_id = str(snapshot["local_player_id"])
	if snapshot.has("turn_number"):
		turn_number = int(snapshot["turn_number"])
	if snapshot.has("strokes") and snapshot["strokes"] is Dictionary:
		strokes = (snapshot["strokes"] as Dictionary).duplicate(true)
	if snapshot.has("ball_transforms") and snapshot["ball_transforms"] is Dictionary:
		ball_transforms = (snapshot["ball_transforms"] as Dictionary).duplicate(true)
	if snapshot.has("match_status"):
		match_status = str(snapshot["match_status"])
	if snapshot.has("online_enabled"):
		online_enabled = bool(snapshot["online_enabled"])
	if snapshot.has("synchronized"):
		synchronized = bool(snapshot["synchronized"])
	if snapshot.has("connected"):
		connected = bool(snapshot["connected"])

func to_dict() -> Dictionary:
	return {
		"match_id": match_id,
		"join_code": join_code,
		"scene_path": scene_path,
		"players": players.duplicate(true),
		"active_player_id": active_player_id,
		"local_player_id": local_player_id,
		"turn_number": turn_number,
		"strokes": strokes.duplicate(true),
		"ball_transforms": ball_transforms.duplicate(true),
		"match_status": match_status,
		"online_enabled": online_enabled,
		"synchronized": synchronized,
		"connected": connected,
		"pending_local_shot": pending_local_shot
	}

func can_local_shoot() -> bool:
	return online_enabled and synchronized and connected and local_player_id != "" and local_player_id == active_player_id and not pending_local_shot
