extends Node

const Find = preload("res://utilscripts/find.gd")

@export var speed_boost_multiplier: float = 3.0
@export var min_speed_for_boost: float = 1.0

var loop_body: StaticBody2D

func _ready() -> void:
	loop_body = get_parent() as StaticBody2D

func _process(_delta: float) -> void:
	_check_and_boost_balls()

func _check_and_boost_balls() -> void:
	var all_balls: Array[RigidBody2D] = []
	var ball = Find.find_ball(self)
	if ball:
		var parent = ball.get_parent()
		if parent:
			for child in parent.get_children():
				if child is RigidBody2D and child.get_script() == ball.get_script():
					all_balls.append(child)
	
	for ball_node in all_balls:
		if _is_ball_touching_loop(ball_node):
			_apply_speed_boost(ball_node)

func _is_ball_touching_loop(ball_node: RigidBody2D) -> bool:
	if not loop_body or not ball_node:
		return false
	
	var contacts = ball_node.get_colliding_bodies()
	return loop_body in contacts

func _apply_speed_boost(ball_node: RigidBody2D) -> void:
	var current_velocity = ball_node.linear_velocity
	var speed = current_velocity.length()
	
	if speed > min_speed_for_boost:
		var boosted_velocity = current_velocity * speed_boost_multiplier
		ball_node.linear_velocity = boosted_velocity
