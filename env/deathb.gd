extends Node2D

@export var margin: float = 0.0

@onready var ball: RigidBody2D = _find_ball()
var spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if ball:
		spawn_position = ball.global_position

func _process(_delta: float) -> void:
	if not ball:
		return
	var barrier_y := (get_parent() as Node2D).global_position.y if get_parent() and get_parent() is Node2D else global_position.y
	if ball.global_position.y > barrier_y + margin:
		_reset_ball()

func _reset_ball() -> void:
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.global_position = spawn_position
	ball.sleeping = false

func _find_ball() -> RigidBody2D:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	for child in scene_root.get_children():
		if child is RigidBody2D:
			return child
	return null
