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
# ─── 无敌状态 (挣脱后 1s，GDD 3.2.2) ───────────────────
var invincible: bool = false
var invincible_timer: float = 0.0
var _gnaw_ring: Node2D = null

var textures: Dictionary = {
	"basic": preload("res://assets/sprites/enemies/enemy_basic.png"),
	"swift": preload("res://assets/sprites/enemies/enemy_swift.png"),
	"heavy": preload("res://assets/sprites/enemies/enemy_heavy.png"),
	"split": preload("res://assets/sprites/enemies/enemy_split.png"),
	"decoy": preload("res://assets/sprites/enemies/enemy_decoy.png"),
	"boss": preload("res://assets/sprites/enemies/enemy_boss.png")
}

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
	_update_visuals()

func _physics_process(delta: float) -> void:
	# 刷新啃食进度环
	_update_gnaw_ring()
	# 恐惧抖动效果
	if _fear_shake > 0:
		_fear_shake -= delta
		position += Vector2(randf() - 0.5, randf() - 0.5) * _fear_shake * 5.0
	# 更新位置
	global_position += _velocity * delta
	# 边界限制 (固定 720x1280 场地)
	global_position.x = clamp(global_position.x, body_radius, 720.0 - body_radius)
	global_position.y = clamp(global_position.y, body_radius, 1280.0 - body_radius)

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
		if type_data.has("enemy_type"):
			enemy_type = type_data["enemy_type"]
			set_meta("enemy_type", enemy_type)
		if type_data.has("speed"): speed = type_data["speed"]
		if type_data.has("body_radius"): 
			body_radius = type_data["body_radius"]
			set_meta("body_radius", body_radius)
		if type_data.has("color"): color = type_data["color"]
		_update_visuals()


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
	if _gnaw_ring and is_instance_valid(_gnaw_ring):
		_gnaw_ring.visible = false
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
	if body and body is Sprite2D:
		if textures.has(enemy_type):
			body.texture = textures[enemy_type]
		if body.texture:
			var tex_size = body.texture.get_size()
			if tex_size.x > 0:
				var s = (body_radius * 2.0) / tex_size.x
				body.scale = Vector2(s, s)
		body.self_modulate = Color.WHITE
	elif body and body is ColorRect:
		body.color = color
		body.custom_minimum_size = Vector2(body_radius * 2, body_radius * 2)
		body.position = Vector2(-body_radius, -body_radius)
	if not body:
		body = ColorRect.new()
		body.name = "Body"
		body.color = color
		body.custom_minimum_size = Vector2(body_radius * 2, body_radius * 2)
		body.position = Vector2(-body_radius, -body_radius)
		add_child(body)
	_ensure_gnaw_ring()

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

## ─── 啃食进度环 (GDD 3.2.2) ───────────────────────────────
## 由 PlayerController 每帧写入 meta "gnaw_progress" (0.0~1.0)
## 敌人基类根据该 meta 刷新进度环

func _ensure_gnaw_ring() -> void:
	if _gnaw_ring and is_instance_valid(_gnaw_ring):
		return
	var ring := GnawRing.new()
	ring.name = "GnawRing"
	ring.ring_radius = body_radius + 6.0
	ring.z_index = 5
	ring.visible = false
	add_child(ring)
	_gnaw_ring = ring

## 每帧刷新进度环显示 (由 _physics_process 调用)
func _update_gnaw_ring() -> void:
	if _gnaw_ring == null or not is_instance_valid(_gnaw_ring):
		return
	var progress: float = get_meta("gnaw_progress", 0.0)
	if progress > 0.0:
		_gnaw_ring.visible = true
		_gnaw_ring.set_progress(progress)
	else:
		_gnaw_ring.visible = false

## 清除啃食进度
func clear_gnaw() -> void:
	set_meta("gnaw_progress", 0.0)
	if _gnaw_ring and is_instance_valid(_gnaw_ring):
		_gnaw_ring.visible = false


# ─── 嵌套类：啃食进度环渲染节点 ───────────────────────────
class GnawRing:
	extends Node2D
	## 啃食进度环 — 环形进度条替代血条 (GDD 3.2.2)
	## 挂载在敌人身上，由 set_progress() 驱动

	var ring_radius: float = 21.0
	var thickness: float = 4.0
	var ring_color: Color = Color(1.0, 0.6, 0.1, 1.0)
	var bg_color: Color = Color(0.0, 0.0, 0.0, 0.35)
	var _progress: float = 0.0

	func set_progress(value: float) -> void:
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		# 背景环
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, bg_color, thickness, true)
		# 进度环 (从顶部开始顺时针)
		if _progress > 0.0:
			var end_angle: float = TAU * _progress - PI / 2.0
			draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, end_angle, 48, ring_color, thickness, true)
