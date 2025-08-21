extends StaticBody2D

var _win_area: Area2D = null
var _triggered: bool = false
@onready var _sfx: AudioStreamPlayer2D = get_node_or_null("Sfx")

func _ready() -> void:
	var node := get_node_or_null("WinDetection")
	if node is Area2D:
		_win_area = node
		_win_area.monitoring = true
		_win_area.monitorable = true
		_win_area.collision_mask = -1
		_win_area.body_entered.connect(_on_body_entered)
		return
	var det: CollisionShape2D = node
	if det:
		det.set_deferred("disabled", true)
		_win_area = Area2D.new()
		add_child(_win_area)
		_win_area.position = det.position
		_win_area.monitoring = true
		_win_area.monitorable = true
		_win_area.collision_mask = -1
		var cs := CollisionShape2D.new()
		_win_area.add_child(cs)
		cs.shape = det.shape
		_win_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is RigidBody2D:
		_handle_win_for_body(body)

func _handle_win_for_body(body: RigidBody2D) -> void:
	if _triggered:
		return
	_triggered = true
	if _sfx:
		_sfx.play()
	if PlayerManager and PlayerManager.number_of_players > 1:
		var parent := body.get_parent()
		var ball_script: Script = body.get_script()
		if is_instance_valid(body):
			body.queue_free()
		var remaining := 0
		if parent:
			for child in parent.get_children():
				if child is RigidBody2D and child != body and child.get_script() == ball_script and not child.is_queued_for_deletion():
					remaining += 1
		if remaining <= 0:
			get_tree().change_scene_to_file("res://utilscripts/win_screen.tscn")
			return
		call_deferred("_reset_triggered")
		return
	get_tree().change_scene_to_file("res://utilscripts/win_screen.tscn")

func _reset_triggered() -> void:
	_triggered = false

func _physics_process(_delta: float) -> void:
	if _triggered:
		return
	if _win_area:
		var bodies := _win_area.get_overlapping_bodies()
		for b in bodies:
			if b is RigidBody2D:
				_handle_win_for_body(b)
				return
