extends Node
const Find = preload("res://utilscripts/find.gd")

@export var user_data_source_path: String = "res://config/userdat.json"
const user_data_path: String = "user://userdat.json"

var number_of_players: int = 1
var processed_scene: Node = null

func _ready() -> void:
	_load_number_of_players_from_user_data()
	_try_setup_for_current_scene()

func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene != processed_scene:
		processed_scene = current_scene
		_try_setup_for_current_scene()

func _load_number_of_players_from_user_data() -> void:
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
	var f := FileAccess.open(user_data_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(merged))
		f.close()
	var players := 1
	if typeof(merged) == TYPE_DICTIONARY and merged.has("options") and typeof(merged["options"]) == TYPE_DICTIONARY and merged["options"].has("players"):
		players = int(merged["options"]["players"])
	number_of_players = clamp(players, 1, 4)

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

func _try_setup_for_current_scene() -> void:
	if number_of_players <= 1:
		var any_ball_sp: RigidBody2D = Find.find_ball(self)
		if any_ball_sp and any_ball_sp.get_parent():
			var duplicates: Array = []
			for child in any_ball_sp.get_parent().get_children():
				if child is RigidBody2D and child.get_script() == any_ball_sp.get_script():
					duplicates.append(child)
			# single player setup
			for i in range(duplicates.size()):
				var b: RigidBody2D = duplicates[i]
				b.set_process_input(true)
				if b.is_in_group("ball"):
					b.remove_from_group("ball")
				if i > 0:
					b.queue_free()
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
	var to_spawn: int = min(number_of_players, 4) - existing_balls.size()
	if to_spawn <= 0:
		# still ensure textures are set below
		pass
	else:
		for i in to_spawn:
			var clone: RigidBody2D = any_ball.duplicate()
			clone.name = any_ball.name + "_P" + str(existing_balls.size() + 1)
			parent.add_child(clone)
			clone.global_position = any_ball.global_position + Vector2(50 * (existing_balls.size()), 0)
			existing_balls.append(clone)

	# Assign per-player textures up to 4 players
	for i in min(existing_balls.size(), 4):
		var b: RigidBody2D = existing_balls[i]
		var sprite: Sprite2D = null
		if b.has_node("Sprite2D"):
			sprite = b.get_node("Sprite2D")
		if sprite:
			var tex_path := "res://Ball/Ball" + str(i + 1) + ".png"
			var tex: Texture2D = load(tex_path)
			if tex:
				sprite.texture = tex
