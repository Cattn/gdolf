extends Node
const Find = preload("res://utilscripts/find.gd")

@export var stop_linear_speed: float = 5.0
@export var stop_angular_speed: float = 1.0
@export var settle_duration: float = 0.35

@onready var ball: RigidBody2D = Find.find_ball(self)

var is_turn_ready: bool = true
var is_waiting: bool = false
var below_threshold_time: float = 0.0
var player_balls: Array = []
var active_index: int = 0

func _ready() -> void:
	_collect_player_balls()
	_set_active_player(active_index)

func can_start_shot() -> bool:
	return is_turn_ready and not is_waiting and _systems_ready_for_ball(ball)

func notify_shot_fired() -> void:
	is_turn_ready = false
	is_waiting = true
	below_threshold_time = 0.0

func _physics_process(delta: float) -> void:
	var prev_count := player_balls.size()
	_collect_player_balls()
	if player_balls.size() != prev_count:
		_set_active_player(active_index)
	if not is_waiting:
		return
	if not ball:
		ball = Find.find_ball(self)
		if not ball:
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
	if player_balls.size() > 0:
		active_index = (active_index + 1) % player_balls.size()
		_set_active_player(active_index)

func _collect_player_balls() -> void:
	var reference_ball: RigidBody2D = Find.find_ball(self)
	if not reference_ball:
		return
	var parent := reference_ball.get_parent()
	if not parent:
		return
	var list: Array = []
	for child in parent.get_children():
		if child is RigidBody2D and child.get_script() == reference_ball.get_script():
			list.append(child)
	player_balls = list

func _set_active_player(index: int) -> void:
	if player_balls.is_empty():
		return
	active_index = clamp(index, 0, player_balls.size() - 1)
	for i in player_balls.size():
		var b: RigidBody2D = player_balls[i]
		if i == active_index:
			b.set_process_input(true)
			if not b.is_in_group("ball"):
				b.add_to_group("ball")
			ball = b
		else:
			b.set_process_input(false)
			if b.is_in_group("ball"):
				b.remove_from_group("ball")

func _systems_ready_for_ball(b: RigidBody2D) -> bool:
	if not b:
		return false
	var root := get_tree().current_scene
	if not root:
		return true
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n != self and n.has_method("is_ready_for_ball"):
			if not n.is_ready_for_ball(b):
				return false
		for child in n.get_children():
			if child is Node:
				stack.append(child)
	return true


