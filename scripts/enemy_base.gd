extends Area2D
## EnemyBase — 敌人基类
## 所有敌人类型的父节点，提供公共属性和方法

# ─── 公开属性 (可在编辑器中调整) ─────────────────────
@export var enemy_type: String = "basic"
@export var body_radius: float = 15.0
@export var max_hp: int = 1
@export var speed: float = 80.0
@export var color: Color = Color(0.3, 0.8, 0.3)
@export var capture_value: float = 1.0
@export var flee_radius: float = 200.0
@export var flee_speed_mult: float = 1.3
@export var wander_speed_mult: float = 0.3

# ─── 内部状态 ─────────────────────────────────────────
var current_hp: int = 1
var active: bool = true
var is_fleeing: bool = false
var player_ref: Node2D = null
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _fear_shake: float = 0.0

# ─── 信号 ─────────────────────────────────────────
signal enemy_died(enemy_type: String, position: Vector2)
signal enemy_captured(value: float)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0


	add_to_group("enemies")
	set_meta("enemy_type", enemy_type)
	set_meta("body_radius", body_radius)
	set_meta("max_hp", max_hp)
	current_hp = max_hp
	print("[Enemy(", enemy_type, ")] 初始化 — 速度:", speed, " 半径:", body_radius)

func _physics_process(delta: float) -> void:
	if not active:
		return
	# 恐惧抖动效果
	if _fear_shake > 0:
		_fear_shake -= delta
		position += Vector2(randf() - 0.5, randf() - 0.5) * _fear_shake * 5.0
	# 更新位置
	global_position += _velocity * delta

## 重置敌人到可用状态 (对象池用)
func reset(pos: Vector2, type_data: Dictionary = {}) -> void:
	active = true
	current_hp = type_data.get("hp", max_hp)

	_velocity = Vector2.ZERO
	_wander_angle = randf() * TAU
	_wander_timer = 0.0
	_fear_shake = 0.0
	is_fleeing = false
	if not type_data.is_empty():
		if type_data.has("speed"): speed = type_data["speed"]
		if type_data.has("body_radius"): body_radius = type_data["body_radius"]
		if type_data.has("color"): color = type_data["color"]


## 敌人死亡
func die() -> void:
	if not active:
		return
	active = false
	current_hp = 0
	enemy_died.emit(enemy_type, global_position)
	enemy_captured.emit(capture_value)
	_death_animation()

## 死亡动画
func _death_animation() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	var tween2 = create_tween()
	tween2.tween_callback(_death_cleanup)

## 死亡清理回调
func _death_cleanup() -> void:
	queue_free()

## 更新视觉
func _update_visuals() -> void:

	var body = get_node_or_null("Body")
	if body and body is ColorRect:
		body.color = color
		body.custom_minimum_size = Vector2(body_radius * 2, body_radius * 2)
	if not body:
		body = ColorRect.new()
		body.name = "Body"
		body.color = color
		body.custom_minimum_size = Vector2(body_radius * 2, body_radius * 2)
		body.position = Vector2(-body_radius, -body_radius)
		add_child(body)

## 设置玩家引用
func set_player_reference(player: Node2D) -> void:
	player_ref = player

## 触发恐惧效果
func trigger_fear(intensity: float) -> void:
	_fear_shake = intensity

## 获取与玩家距离
func distance_to_player() -> float:
	if player_ref == null:
		return flee_radius + 1
	return global_position.distance_to(player_ref.global_position)

## 获取归一化远离玩家的方向
func get_flee_direction() -> Vector2:
	if player_ref == null:
		return Vector2.RIGHT
	var dir := global_position - player_ref.global_position
	return dir.normalized()
