extends Node2D
const Find = preload("res://utilscripts/find.gd")

@export var margin: float = 0.0

@onready var ball: RigidBody2D = null
var spawn_positions := {}

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	var current := Find.find_ball(self)
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


