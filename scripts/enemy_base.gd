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

	# ─── 精英机制状态 (GDD 7.3 / 5.8) ──────────────────────
const SPLIT_WAVE_DMG := 8
const TOXIN_DPS := 3
const TOXIN_DURATION := 8.0
const MIRROR_CLONE_COUNT := 2
const FORTRESS_GNAW_SLOW := 2.0
const TEARER_COOLDOWN := 4.0
const POISON_RANGE := 60.0
var _elite_timer: float = 0.0

# ─── v1.2 多大关 Boss 3 阶段 (只狼阶段化 + 黑神话忍杀, §3.3) ───
# 满血: 固定技能×1 → 50%: 弱点暴露+技能×2 → 20%: 狂暴(速度+50%,技能×3)+忍杀窗口
var boss_phase: int = 1            # 1=满血 2=50% 3=20%狂暴
var boss_weakness_open: bool = false  # 50% 后弱点暴露 (啃食 +50%)
var boss_enraged: bool = false    # 20% 狂暴
var boss_kill_window: float = 0.0 # 忍杀窗口剩余秒数 (窗口内啃食 3 倍速)
const BOSS_KILL_WINDOW_SEC := 3.0
const BOSS_KILL_GNAW_MULT := 3.0
const BOSS_WEAKNESS_GNAW_MULT := 1.5
const BOSS_ENRAGE_SPEED_MULT := 1.5
var _boss_skill_timer: float = 0.0
var _boss_skill_cd: float = 4.0   # 技能 CD (随阶段缩短)
# P0/P1: Boss 阶段特效贴图 (弱点环/狂暴光环/忍杀金环/撕裂波, 素材已就位)
var _fx_weakpoint: Sprite2D = null
var _fx_enraged: Sprite2D = null
var _fx_kill_window: Sprite2D = null
var _fx_tear_wave: Sprite2D = null

var textures: Dictionary = {
	"basic": preload("res://assets/sprites/enemies/enemy_basic.png"),
	"swift": preload("res://assets/sprites/enemies/enemy_swift.png"),
	"heavy": preload("res://assets/sprites/enemies/enemy_heavy.png"),
	"split": preload("res://assets/sprites/enemies/enemy_split.png"),
	"decoy": preload("res://assets/sprites/enemies/enemy_decoy.png"),
	"boss": preload("res://assets/sprites/enemies/enemy_boss.png"),
	# v1.2 多大关: 精英 4 变体 (GDD 7.3) + 章节 Boss 3 形态 (GDD 7.5)
	"elite_tearer":   preload("res://assets/sprites/enemies/enemy_elite_tearer.png"),
	"elite_toxin":    preload("res://assets/sprites/enemies/enemy_elite_toxin.png"),
	"elite_mirror":   preload("res://assets/sprites/enemies/enemy_elite_mirror.png"),
	"elite_fortress": preload("res://assets/sprites/enemies/enemy_elite_fortress.png"),
	"boss_ch1":       preload("res://assets/sprites/enemies/enemy_boss_ch1.png"),
	"boss_v2_void":   preload("res://assets/sprites/enemies/enemy_boss_v2_void.png"),
	"boss_v3_abyss":  preload("res://assets/sprites/enemies/enemy_boss_v3_abyss.png"),
	# P1 风格新怪 (关卡设计 §3.0 风格差异表)
	"toxin_pod":    preload("res://assets/sprites/enemies/enemy_toxin_pod.png"),
	"split_body":   preload("res://assets/sprites/enemies/enemy_split_body.png"),
	"phase_slash":  preload("res://assets/sprites/enemies/enemy_phase_slash.png"),
	"feint":        preload("res://assets/sprites/enemies/enemy_feint.png")
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
	_update_gnaw_ring()
	if _fear_shake > 0.0:
		_fear_shake -= delta
		if _fear_shake <= 0.0: _fear_shake = 0.0
		var shake = 5.0 * min(_fear_shake, 1.0)
		position += Vector2(randf() - 0.5, randf() - 0.5) * shake
	global_position += _velocity * delta
	global_position.x = clamp(global_position.x, body_radius, 720.0 - body_radius)
	global_position.y = clamp(global_position.y, body_radius, 1280.0 - body_radius)
	_process_elite(delta)
	_process_boss(delta)

## 重置敌人到可用状态 (对象池用)
func reset(pos: Vector2, type_data: Dictionary = {}) -> void:
	active = true
	current_hp = type_data.get("hp", max_hp)

	_velocity = Vector2.ZERO
	_wander_angle = randf() * TAU
	_wander_timer = 0.0
	_fear_shake = 0.0
	_elite_timer = 0.0
	if enemy_type in ["elite_tearer", "elite_toxin", "elite_mirror", "elite_fortress"]:
		_apply_elite_default()
	if enemy_type == "elite_fortress":
		set_meta("gnaw_slow", FORTRESS_GNAW_SLOW)
	if _is_boss_type():
		_reset_boss_state()
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
	if enemy_type == "elite_mirror":
		_spawn_mirrors()

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
	# P1: Boss 阶段特效节点 (按需惰性创建)
	_ensure_boss_fx()

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

func _update_gnaw_ring() -> void:
	if _gnaw_ring == null or not is_instance_valid(_gnaw_ring):
		return
	var progress: float = get_meta("gnaw_progress", 0.0)
	if progress > 0.0:
		_gnaw_ring.visible = true
		_gnaw_ring.set_progress(progress)
	else:
		_gnaw_ring.visible = false

func clear_gnaw() -> void:
	set_meta("gnaw_progress", 0.0)
	if _gnaw_ring and is_instance_valid(_gnaw_ring):
		_gnaw_ring.visible = false

class GnawRing:
	extends Node2D

	var ring_radius: float = 21.0
	var thickness: float = 4.0
	var ring_color: Color = Color(1.0, 0.6, 0.1, 1.0)
	var bg_color: Color = Color(0.0, 0.0, 0.0, 0.35)
	var _progress: float = 0.0

	func set_progress(value: float) -> void:
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, bg_color, thickness, true)
		if _progress > 0.0:
			var end_angle = TAU * _progress - PI / 2.0
			draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, end_angle, 48, ring_color, thickness, true)

## P1: Boss 阶段特效 — 惰性创建 弱点环/狂暴光环/忍杀金环/撕裂波 4 个 Sprite
func _ensure_boss_fx() -> void:
	if _is_boss_type():
		if _fx_weakpoint == null:
			_fx_weakpoint = Sprite2D.new()
			_fx_weakpoint.name = "FXWeakpoint"
			_fx_weakpoint.texture = load("res://assets/sprites/skills/fx_boss_weakpoint.png")
			_fx_weakpoint.z_index = 6
			_fx_weakpoint.visible = false
			add_child(_fx_weakpoint)
		if _fx_enraged == null:
			_fx_enraged = Sprite2D.new()
			_fx_enraged.name = "FXEnraged"
			_fx_enraged.texture = load("res://assets/sprites/skills/fx_boss_enraged.png")
			_fx_enraged.z_index = 5
			_fx_enraged.modulate = Color(1, 1, 1, 0.55)
			_fx_enraged.visible = false
			add_child(_fx_enraged)
		if _fx_kill_window == null:
			_fx_kill_window = Sprite2D.new()
			_fx_kill_window.name = "FXKillWindow"
			_fx_kill_window.texture = load("res://assets/sprites/skills/fx_kill_window.png")
			_fx_kill_window.z_index = 7
			_fx_kill_window.visible = false
			add_child(_fx_kill_window)
	if enemy_type == "elite_tearer" and _fx_tear_wave == null:
		_fx_tear_wave = Sprite2D.new()
		_fx_tear_wave.name = "FXTearWave"
		_fx_tear_wave.texture = load("res://assets/sprites/skills/fx_tear_wave.png")
		_fx_tear_wave.z_index = 6
		_fx_tear_wave.visible = false
		add_child(_fx_tear_wave)

## P1: 每帧刷新 Boss 特效可见性 (弱点/狂暴/忍杀窗口)
func _update_boss_fx() -> void:
	if not _is_boss_type():
		return
	if _fx_weakpoint and boss_weakness_open:
		_fx_weakpoint.visible = true
		_fx_weakpoint.modulate = Color(1, 1, 1, 0.6 + 0.4 * abs(sin(Time.get_ticks_msec() * 0.006)))
	elif _fx_weakpoint:
		_fx_weakpoint.visible = false
	if _fx_enraged and boss_enraged:
		_fx_enraged.visible = true
	elif _fx_enraged:
		_fx_enraged.visible = false
	if _fx_kill_window:
		_fx_kill_window.visible = boss_kill_window > 0.0

## P1: 撕裂者撕裂波 — 扇形冲击动画 (向玩家方向, 0.5s 淡出)
func _animate_tear_wave() -> void:
	if _fx_tear_wave == null or not is_instance_valid(_fx_tear_wave):
		return
	if player_ref != null:
		_fx_tear_wave.rotation = global_position.angle_to(player_ref.global_position)
	_fx_tear_wave.position = Vector2(150, 0)
	_fx_tear_wave.modulate = Color(1, 1, 1, 1.0)
	_fx_tear_wave.visible = true
	var tween = create_tween()
	tween.tween_property(_fx_tear_wave, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _fx_tear_wave.visible = false)

## P1: 重置 Boss 特效可见性 (对象池复用)
func _reset_boss_fx() -> void:
	if _fx_weakpoint: _fx_weakpoint.visible = false
	if _fx_enraged: _fx_enraged.visible = false
	if _fx_kill_window: _fx_kill_window.visible = false
	if _fx_tear_wave: _fx_tear_wave.visible = false

## 按 elite 类型设置默认体型/血量/颜色
func _apply_elite_default() -> void:
	match enemy_type:
		"elite_tearer":
			body_radius = 45.0
			max_hp = 6
			color = Color(0.85, 0.2, 0.2)
		"elite_toxin":
			body_radius = 38.0
			max_hp = 4
			color = Color(0.4, 0.85, 0.3)
		"elite_mirror":
			body_radius = 30.0
			max_hp = 3
			color = Color(0.6, 0.6, 0.95)
		"elite_fortress":
			body_radius = 50.0
			max_hp = 10
			color = Color(0.7, 0.55, 0.3)

## 镜影：被吞噬时召唤 2 个诱饵分身 (GDD 7.3)
func _spawn_mirrors() -> void:
	var pool = get_node_or_null("/root/MainGame/ObjectPool")
	if pool == null:
		return
	for i in range(MIRROR_CLONE_COUNT):
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var clone_data := {
			"enemy_type": "decoy",
			"speed": 60.0,
			"body_radius": 18.0,
			"color": Color(0.9, 0.5, 0.7),
			"capture_value": 0.5,
		}
		pool.spawn(global_position + offset, clone_data)

## 精英专属行为分发 (GDD 7.3 / 5.8)
func _process_elite(delta: float) -> void:
	if not active:
		return
	match enemy_type:
		"elite_tearer":
			_update_tearer(delta)
		"elite_toxin":
			_update_toxin()

## 撕裂者：每 4s 向玩家发撕裂波（300px 直线）
func _update_tearer(delta: float) -> void:
	_elite_timer += delta
	if _elite_timer >= TEARER_COOLDOWN:
		_elite_timer = 0.0
		_fire_tear_wave()

func _fire_tear_wave() -> void:
	if player_ref == null:
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= 300.0:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(SPLIT_WAVE_DMG)
		_animate_tear_wave()
		var bus = get_node_or_null("/root/MainGame/EventBus")
		if bus and bus.has_signal("screen_shake"):
			bus.emit_signal("screen_shake", 0.2, 6.0)

## 毒囊：靠近玩家时施加中毒
func _update_toxin() -> void:
	if player_ref == null:
		return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < POISON_RANGE and player_ref.has_method("apply_poison"):
		player_ref.apply_poison(TOXIN_DPS, TOXIN_DURATION)

## 掉落（GDD 7.3：精英必掉 遗物60% / 传说40%）
## ─── v1.2 多大关 Boss 3 阶段 (只狼阶段化 + 黑神话忍杀, §3.3) ───
## 满血: 固定技能×1 → 50%: 弱点暴露(啃食×1.5) → 20%: 狂暴(速度+50%,技能×3)+忍杀窗口(啃食×3)
## 判定: 通过 current_hp / max_hp 阈值, 写入 meta "gnaw_mult" 供 player_controller 读
func _process_boss(delta: float) -> void:
	if not active:
		return
	# 只对 Boss 生效 (类型名以 boss_ 开头 或 基础 boss)
	if not _is_boss_type():
		return
	var hp_ratio: float = float(current_hp) / float(max(1, max_hp))
	# 阶段判定 (20% 阈值后狂暴)
	if hp_ratio > 0.5:
		if boss_phase != 1:
			_enter_boss_phase(1)
	elif hp_ratio > 0.2:
		if boss_phase != 2:
			_enter_boss_phase(2)
	else:
		if boss_phase != 3:
			_enter_boss_phase(3)
	# 忍杀窗口倒计时
	if boss_kill_window > 0.0:
		boss_kill_window -= delta
	# 技能 CD (随阶段缩短, §3.3 技能×2/×3)
	_boss_skill_timer += delta
	var cd_target: float = _boss_skill_cd / _boss_skill_mult()
	if _boss_skill_timer >= cd_target:
		_boss_skill_timer = 0.0
		_boss_skill_cast()
	# 写入啃食倍率 meta (player_controller 每帧读, 弱点暴露 1.5× / 忍杀窗口 3×)
	var mult: float = 1.0
	if boss_weakness_open:
		mult = BOSS_WEAKNESS_GNAW_MULT
	if boss_kill_window > 0.0:
		mult = BOSS_KILL_GNAW_MULT
	set_meta("gnaw_mult", mult)
	# P1: 刷新 Boss 阶段特效可见性
	_update_boss_fx()

## 是否 Boss 类型 (v1.2 多大关 boss_swamp/gold/void/abyss + 基础 boss)
func _is_boss_type() -> bool:
	return enemy_type == "boss" or enemy_type.begins_with("boss_")

## 进入 Boss 阶段 (2=弱点暴露, 3=狂暴+开忍杀窗口)
func _enter_boss_phase(phase: int) -> void:
	boss_phase = phase
	if phase == 2:
		boss_weakness_open = true
		print("[Boss] 弱点暴露 — 啃食 ×", BOSS_WEAKNESS_GNAW_MULT)
	elif phase == 3:
		boss_enraged = true
		boss_kill_window = BOSS_KILL_WINDOW_SEC
		# 狂暴: 速度 +50%
		speed *= BOSS_ENRAGE_SPEED_MULT
		print("[Boss] 狂暴 — 速度+50%, 技能×3, 忍杀窗口 ", BOSS_KILL_WINDOW_SEC, "s")

## Boss 技能倍率 (1=×1, 2=×2, 3=×3)
func _boss_skill_mult() -> float:
	match boss_phase:
		1: return 1.0
		2: return 2.0
		3: return 3.0
		_: return 1.0

## Boss 技能释放 (简化: 向玩家发撕裂波, 阶段越高伤害越高)
func _boss_skill_cast() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= 300.0:
		var dmg: int = int(SPLIT_WAVE_DMG * _boss_skill_mult())
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(dmg)
		var bus = get_node_or_null("/root/MainGame/EventBus")
		if bus and bus.has_signal("screen_shake"):
			bus.emit_signal("screen_shake", 0.2, 6.0)

## 重置 Boss 阶段 (对象池复用时)
func _reset_boss_state() -> void:
	boss_phase = 1
	boss_weakness_open = false
	boss_enraged = false
	boss_kill_window = 0.0
	_boss_skill_timer = 0.0
	_boss_skill_cd = 4.0
	set_meta("gnaw_mult", 1.0)
	_reset_boss_fx()

func roll_elite_reward() -> Dictionary:
	if randf() < 0.6:
		return {"type": "relic"}
	return {"type": "legendary_card"}
