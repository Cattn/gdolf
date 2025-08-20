extends Node

@export var stop_linear_speed: float = 5.0
@export var stop_angular_speed: float = 1.0
@export var settle_duration: float = 0.35

@onready var ball: RigidBody2D = _find_ball()

var is_turn_ready: bool = true
var is_waiting: bool = false
var below_threshold_time: float = 0.0

func can_start_shot() -> bool:
	return is_turn_ready and not is_waiting

func notify_shot_fired() -> void:
	is_turn_ready = false
	is_waiting = true
	below_threshold_time = 0.0

func _physics_process(delta: float) -> void:
	if not is_waiting or not ball:
		return
	var lin: float = ball.linear_velocity.length()
	var ang: float = abs(ball.angular_velocity)
	var stopped: bool = (lin <= stop_linear_speed and ang <= stop_angular_speed) or ball.sleeping
	if stopped:
		below_threshold_time += delta
	else:
		below_threshold_time = 0.0
	if below_threshold_time >= settle_duration:
		_start_next_turn()

func _start_next_turn() -> void:
	is_waiting = false
	is_turn_ready = true

func _find_ball() -> RigidBody2D:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	for child in scene_root.get_children():
		if child is RigidBody2D:
			return child
	return null
