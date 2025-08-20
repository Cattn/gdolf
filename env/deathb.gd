extends Node2D
const Find = preload("res://utilscripts/find.gd")

@export var margin: float = 0.0

@onready var ball: RigidBody2D = null
var spawn_positions := {}

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	var current := Find.find_ball(self)
	if current:
		var id := current.get_instance_id()
		if not spawn_positions.has(id):
			spawn_positions[id] = current.global_position
	ball = current
	if not ball:
		return
	var barrier_y := (get_parent() as Node2D).global_position.y if get_parent() and get_parent() is Node2D else global_position.y
	if ball.global_position.y > barrier_y + margin:
		_reset_ball()

func _reset_ball() -> void:
	var id := ball.get_instance_id()
	var spawn: Vector2 = spawn_positions.get(id, Vector2.ZERO)
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	if spawn_positions.has(id):
		ball.global_position = spawn
	ball.sleeping = false


