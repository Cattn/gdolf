extends Node2D
const FindUtils = preload("res://utilscripts/find.gd")

@export var margin: float = 0.0

@onready var ball: RigidBody2D = null
@onready var network_client: Node = get_node_or_null("/root/NetworkClient")
var spawn_positions := {}

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	var current := FindUtils.find_ball(self)
	var balls: Array = []
	if current:
		var parent := current.get_parent()
		if parent:
			for child in parent.get_children():
				if child is RigidBody2D and child.get_script() == current.get_script():
					balls.append(child)
	for b in balls:
		var id: int = b.get_instance_id()
		if not spawn_positions.has(id):
			spawn_positions[id] = b.global_position
	ball = current
	if balls.is_empty():
		return
	var barrier_y := (get_parent() as Node2D).global_position.y if get_parent() and get_parent() is Node2D else global_position.y
	for b in balls:
		if b.global_position.y > barrier_y + margin:
			_reset_ball_specific(b)

func _reset_ball() -> void:
	if ball:
		_reset_ball_specific(ball)

func _reset_ball_specific(b: RigidBody2D) -> void:
	if _is_online_mode() and network_client and network_client.has_method("report_out_of_bounds"):
		var player_id := str(b.get_meta("player_id", ""))
		network_client.report_out_of_bounds(player_id, b.global_position)
	var id: int = b.get_instance_id()
	var spawn: Vector2 = spawn_positions.get(id, Vector2.ZERO)
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	if spawn_positions.has(id):
		b.global_position = spawn
	b.sleeping = false

func is_ready_for_ball(b: RigidBody2D) -> bool:
	if not b:
		return false
	return spawn_positions.has(b.get_instance_id())

func _is_online_mode() -> bool:
	return network_client and network_client.has_method("is_online_match") and network_client.is_online_match()


