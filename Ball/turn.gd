extends Node
const FindUtils = preload("res://utilscripts/find.gd")

@export var stop_linear_speed: float = 5.0
@export var stop_angular_speed: float = 1.0
@export var settle_duration: float = 0.35

@onready var ball: RigidBody2D = FindUtils.find_ball(self)
@onready var network_client: Node = get_node_or_null("/root/NetworkClient")

var is_turn_ready: bool = true
var is_waiting: bool = false
var below_threshold_time: float = 0.0
var player_balls: Array = []
var active_index: int = 0

func _ready() -> void:
	_collect_player_balls()
	if _is_online_mode():
		if network_client and network_client.has_signal("turn_started") and not network_client.turn_started.is_connected(_on_network_turn_started):
			network_client.turn_started.connect(_on_network_turn_started)
		if network_client and network_client.has_method("get_active_player_id"):
			_set_active_player_by_id(network_client.get_active_player_id())
		is_turn_ready = _is_local_turn()
	else:
		_set_active_player(active_index)

func can_start_shot() -> bool:
	if _is_online_mode():
		if not network_client or not network_client.has_method("can_local_player_shoot") or not network_client.can_local_player_shoot():
			return false
	return is_turn_ready and not is_waiting and _systems_ready_for_ball(ball)

func notify_shot_fired() -> void:
	is_turn_ready = false
	is_waiting = true
	below_threshold_time = 0.0

func _physics_process(delta: float) -> void:
	var prev_count := player_balls.size()
	_collect_player_balls()
	if player_balls.size() != prev_count:
		if player_balls.is_empty():
			return
		if is_waiting:
			is_waiting = false
			is_turn_ready = _is_local_turn() if _is_online_mode() else true
		if _is_online_mode() and network_client and network_client.has_method("get_active_player_id"):
			_set_active_player_by_id(network_client.get_active_player_id())
		else:
			active_index = active_index % player_balls.size()
			_set_active_player(active_index)
	if not is_waiting:
		return
	if not ball:
		ball = FindUtils.find_ball(self)
		if not ball:
			return
	if player_balls.find(ball) == -1:
		if _is_online_mode():
			is_waiting = false
			is_turn_ready = false
		else:
			_start_next_turn()
		return
	var lin: float = ball.linear_velocity.length()
	var ang: float = abs(ball.angular_velocity)
	var stopped: bool = (lin <= stop_linear_speed and ang <= stop_angular_speed) or ball.sleeping
	if stopped:
		below_threshold_time += delta
	else:
		below_threshold_time = 0.0
	if below_threshold_time >= settle_duration:
		if _is_online_mode():
			is_waiting = false
			is_turn_ready = false
			if network_client and network_client.has_method("notify_shot_settled"):
				network_client.notify_shot_settled()
		else:
			_start_next_turn()

func _start_next_turn() -> void:
	is_waiting = false
	is_turn_ready = true
	if player_balls.size() > 0:
		active_index = (active_index + 1) % player_balls.size()
		_set_active_player(active_index)

func _collect_player_balls() -> void:
	var reference_ball: RigidBody2D = FindUtils.find_ball(self)
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
			var allow_input := true
			if _is_online_mode() and network_client and network_client.has_method("get_local_player_id"):
				allow_input = str(b.get_meta("player_id", "")) == network_client.get_local_player_id()
			b.set_process_input(allow_input)
			if allow_input and not b.is_in_group("ball"):
				b.add_to_group("ball")
			elif not allow_input and b.is_in_group("ball"):
				b.remove_from_group("ball")
			ball = b
		else:
			b.set_process_input(false)
			if b.is_in_group("ball"):
				b.remove_from_group("ball")

func _set_active_player_by_id(player_id: String) -> void:
	if player_balls.is_empty():
		return
	var found_index := -1
	for i in player_balls.size():
		var b: RigidBody2D = player_balls[i]
		var ball_player_id := str(b.get_meta("player_id", ""))
		if ball_player_id == player_id:
			found_index = i
			break
	if found_index >= 0:
		_set_active_player(found_index)
	else:
		_set_active_player(0)

func _on_network_turn_started(player_id: String, _turn_number: int) -> void:
	_collect_player_balls()
	_set_active_player_by_id(player_id)
	is_waiting = false
	is_turn_ready = _is_local_turn()

func _is_online_mode() -> bool:
	return network_client and network_client.has_method("is_online_match") and network_client.is_online_match()

func _is_local_turn() -> bool:
	if not _is_online_mode():
		return true
	if not network_client or not network_client.has_method("get_local_player_id") or not network_client.has_method("get_active_player_id"):
		return false
	return network_client.get_local_player_id() == network_client.get_active_player_id()

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


