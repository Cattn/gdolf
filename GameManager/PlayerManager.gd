extends Node
const Find = preload("res://utilscripts/find.gd")

@export var config_path: String = "res://config/gamemanager.json"

var number_of_players: int = 1
var processed_scene: Node = null

func _ready() -> void:
	_number_of_players_from_config()
	_try_setup_for_current_scene()

func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene != processed_scene:
		processed_scene = current_scene
		_try_setup_for_current_scene()

func _number_of_players_from_config() -> void:
	var players := 1
	if FileAccess.file_exists(config_path):
		var text := FileAccess.get_file_as_string(config_path)
		var data = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY and data.has("players"):
			players = int(data["players"])
	number_of_players = max(1, players)

func _try_setup_for_current_scene() -> void:
	if number_of_players <= 1:
		return
	var any_ball: RigidBody2D = Find.find_ball(self)
	if not any_ball:
		return
	var parent := any_ball.get_parent()
	if not parent:
		return
	var existing_balls: Array = []
	for child in parent.get_children():
		if child is RigidBody2D and child.get_script() == any_ball.get_script():
			existing_balls.append(child)
	var to_spawn := number_of_players - existing_balls.size()
	if to_spawn <= 0:
		return
	for i in to_spawn:
		var clone: RigidBody2D = any_ball.duplicate()
		clone.name = any_ball.name + "_P" + str(existing_balls.size() + 1)
		parent.add_child(clone)
		clone.global_position = any_ball.global_position + Vector2(50 * (existing_balls.size()), 0)
		existing_balls.append(clone)
