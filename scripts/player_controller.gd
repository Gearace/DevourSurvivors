extends CharacterBody2D
## PlayerController — 玩家移动 + 吞噬判定 (四层机制版)
##
## 职责：
##   · 接收摇杆方向信号，更新移动速度
##   · 接收手势识别结果，触发技能
##   · 碰撞检测：一口吞 / 啃食进度 / 反噬 / 能量
##   · 管理玩家状态 (HP/体型/速度/能量)
##
## 依赖：
##   · GameManager (全局数据: 能量/等级/卡牌)
##   · GestureDetector (手势解析)
##   · EventBus (事件)
##   · DevourTable (数值表)

# ─── 公开属性 ─────────────────────────────────────────
@export var base_speed: float = 200.0       # 基础移动速度
@export var capture_radius: float = 40.0    # 吞噬判定半径 (随等级更新)
@export var body_radius: float = 20.0       # 身体渲染半径
@export var hp: int = 100                   # 生命值
@export var max_hp: int = 100               # 最大生命值

# ─── 啃食状态 (GDD 3.2.2 啃食进度) ─────────────────────
var _gnaw_target: Node2D = null             # 正在啃的敌人
var _gnaw_progress: float = 0.0             # 累计啃食秒数
var _gnaw_escape_timer: float = 1.5         # 下一次挣脱检查
var _gnaw_escape_chance: float = 0.12       # 每次检查挣脱概率
var _gnaw_escape_interval: float = 1.5      # 挣脱检查间隔
var _gnaw_escape_feedback: float = 0.0      # 挣脱反馈：把玩家推开
var _gnaw_energy_refund: float = 0.3        # 挣脱返还能量比例
var _gnaw_steadiness: float = 1.0          # 啃食稳固度倍率
# ─── 毒囊中毒状态 (GDD 5.8 elite_toxin) ──────────────────
var _poison_dps: float = 0.0
var _poison_timer: float = 0.0
var _poison_acc: float = 0.0
var _gnaw_steadiness_now: float = 1.0  # 当前啃食减速倍率 (堡垒=2.0)
var _gnaw_required: float = 1.0             # 该敌人需要啃多久

# ─── 内部状态 ─────────────────────────────────────────
var _gesture_detector: Object
var _current_direction: Vector2 = Vector2.ZERO
var _speed_multiplier: float = 1.0
var _invincible_timer: float = 0.0
var _body_color: Color = Color(0.3, 0.8, 0.4)
var _gm: Node
var _event_bus: Node
var _pool: Node2D
var _last_capture_check: float = 0.0
var _table: RefCounted

# ─── 信号 ─────────────────────────────────────────
signal player_captured_enemy(enemy_type: String, value: float)

func _ready() -> void:
	# 获取全局引用
	_gm = get_node_or_null("/root/GameManager")
	_event_bus = get_node_or_null("/root/EventBus")
	_pool = get_node_or_null("../ObjectPool")
	_table = preload("res://scripts/devour_table.gd").new()
	
	# 从 GameManager 同步体型/半径
	_sync_from_gm()
	
	# 初始化身体视觉
	_update_body_visuals()
	
	# 动态创建镜头，使其跟随玩家移动
	var camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(4.0, 4.0)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 720
	camera.limit_bottom = 1280
	add_child(camera)
	camera.make_current()
	
	print("[Player] 初始化完成 — HP:", hp, " 速度:", base_speed, " 半径:", body_radius)

## 从 GameManager 同步体型/能量 (升级后调用)
func _sync_from_gm() -> void:
	if _gm == null:
		return
	var stats: Dictionary = _gm.player_stats
	# v1.2: 体型 = 初始 20px + 变异卡数量×1px (GDD 2.0)，由 GameManager.mutation_card_count 驱动
	body_radius = _table.body_radius_for_mutation(_gm.mutation_card_count)
	capture_radius = body_radius + 10.0
	max_hp = int(stats.get("max_hp", 100))

func _process(delta: float) -> void:
	# 无敌计时器
	if _invincible_timer > 0:
		_invincible_timer -= delta

	# 中毒 DoT (GDD 5.8)
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_acc += delta
		if _poison_acc >= 1.0:
			_poison_acc -= 1.0
			take_damage(int(_poison_dps))
		if _poison_timer <= 0.0:
			_poison_dps = 0.0
	
	# 平滑移动
	velocity = _current_direction * base_speed * _speed_multiplier
	move_and_slide()
	
	# 边界限制 (固定 720x1280 场地，保留半半径的安全范围以免穿帮)
	global_position.x = clamp(global_position.x, body_radius, 720.0 - body_radius)
	global_position.y = clamp(global_position.y, body_radius, 1280.0 - body_radius)
	
	# 啃食进度条推进 (GDD 3.2.2)
	_update_gnaw(delta)
	
	# 定期执行吞噬判定 (每 0.1s 一次，避免每帧计算)
	_last_capture_check -= delta
	if _last_capture_check <= 0:
		_last_capture_check = 0.1
		_check_and_capture()

## ─── 啃食进度推进 ─────────────────────────────────────────
func _update_gnaw(delta: float) -> void:
	if _gnaw_target == null or not is_instance_valid(_gnaw_target):
		_gnaw_target = null
		_gnaw_progress = 0.0
		return
	
	if not _gnaw_target.active:
		_gnaw_target = null
		_gnaw_progress = 0.0
		return
	
	# 必须保持贴身才继续啃 (敌人挣脱则重置)
	var dist = global_position.distance_to(_gnaw_target.global_position)
	if dist > capture_radius + 5.0:
		_reset_gnaw()
		return
	
	# 挣脱判定 (GDD 3.2.2 挣脱率)
	_gnaw_escape_timer -= delta
	if _gnaw_escape_timer <= 0.0:
		_gnaw_escape_timer = _gnaw_escape_interval
		if randf() < _gnaw_escape_chance:
			_escape_gnaw()
			return

	# 扣血反噬 (GDD 3.2.3)
	var type_id: String = _gnaw_target.enemy_type
	var gnaw_dps: float = _table.gnaw_damage_per_sec(type_id)
	if gnaw_dps > 0.0:
		take_damage(int(gnaw_dps * delta + 0.5))
	
	# 能量消耗 (GDD 3.2.4)
	var energy_cost: float = _table.energy_cost_per_sec(type_id) * delta
	if energy_cost > 0.0 and _gm:
		_gm.spend_energy(energy_cost)
		if _gm.get_energy() <= 0.0:
			# 能量耗尽 → 啃不动，重置
			_reset_gnaw()
			print("[Player] 能量耗尽，啃食中断")
	
	# 进度推进（堡垒啃食减速：_gnaw_steadiness_now 越大越慢）
	_gnaw_progress += _gnaw_steadiness * delta / maxf(_gnaw_steadiness_now, 1.0)

	_gnaw_target.set_meta("gnaw_progress", _gnaw_progress / maxf(_gnaw_required, 0.1))
	
	# 完成
	if _gnaw_progress >= _gnaw_required:
		_finish_gnaw()

func _reset_gnaw() -> void:
	if _gnaw_target and is_instance_valid(_gnaw_target):
		_gnaw_target.clear_gnaw()
	_gnaw_target = null
	_gnaw_progress = 0.0


func _start_gnaw(enemy: Node2D) -> void:
	_gnaw_target = enemy
	_gnaw_progress = 0.0
	_gnaw_required = _table.gnaw_seconds(enemy.enemy_type)
	if _gnaw_required <= 0.0:
		_gnaw_required = 0.1  # 安全下限
	# 堡垒啃食减速 (GDD 5.8 elite_fortress)：读 meta gnaw_slow 放慢进度
	var gnaw_slow: float = 1.0
	if enemy.has_meta("gnaw_slow"):
		gnaw_slow = enemy.get_meta("gnaw_slow")
	_gnaw_steadiness_now = gnaw_slow


func _finish_gnaw() -> void:
	var enemy := _gnaw_target
	_gnaw_target = null
	_gnaw_progress = 0.0
	if enemy == null or not is_instance_valid(enemy):
		return
	_execute_capture(enemy)

## ─── 吞噬判定 ────────────────────────────────────────────
func _check_and_capture() -> void:
	if _gm == null or not _gm.is_playing():
		return
	
	# 正在啃大怪时跳过普通判定
	if _gnaw_target != null:
		return
	
	var enemies = _pool.get_active_enemies() if _pool else []
	
	for enemy in enemies:
		if enemy == null or not enemy.active:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		
		var enemy_radius: float = 15.0
		if enemy.has_meta("body_radius"):
			enemy_radius = enemy.get_meta("body_radius")
		
		if dist <= capture_radius + enemy_radius:
			var type_id: String = enemy.enemy_type
			
			# 门槛: 能否一口吞 (GDD 3.2.1)
			if _table.is_one_bite(type_id) and body_radius >= enemy_radius * 0.8:
				_execute_capture(enemy)
				break
			
			# 需要啃食的大怪 (GDD 3.2.2)
			elif _table.gnaw_seconds(type_id) > 0.0:
				_start_gnaw(enemy)
				break
			
			# 吃不动且不能啃 → 反噬 (GDD 3.2.3)
			elif body_radius < enemy_radius:
				_handle_collision_backlash(enemy, type_id, enemy_radius)
				break

## 撞到比自己大的怪 → 受伤 + 推开 (GDD 3.2.3)
func _handle_collision_backlash(enemy: Node2D, type_id: String, enemy_radius: float) -> void:
	# 无敌帧内不重复伤害
	if _invincible_timer > 0.0:
		return
	
	var dmg: float = _table.get_collision_damage(type_id, body_radius, enemy_radius)
	if dmg > 0.0:
		take_damage(int(dmg))
	
	# 推开
	var pushback: float = _table.get_collision_pushback(type_id)
	if pushback > 0.0:
		var dir = (global_position - enemy.global_position).normalized()
		global_position += dir * pushback
	
	# 撞到自己更大的怪也会打断啃食
	_reset_gnaw()

## 判断能否一口吞
func _can_capture(enemy_size: float) -> bool:
	return body_radius >= enemy_size * 0.8

## 执行吞噬
func _execute_capture(enemy) -> void:
	var enemy_type: String = enemy.enemy_type
	var enemy_size: float = 15.0
	if enemy.has_meta("body_radius"):
		enemy_size = enemy.get_meta("body_radius")
	
	var capture_value = _get_capture_value(enemy_type, enemy_size)
    
	# v1.2: 技能触发的吞噬, 按技能威力倍数 (含遗物) 放大收益
	if typeof(enemy) == TYPE_DICTIONARY and enemy.has("power_mult"):
		capture_value *= float(enemy.get("power_mult", 1.0))
	
	# 能量收益 (GDD 3.2.5)
	var energy_gain: float = _table.get_energy_gain(enemy_type)
	if _gm and energy_gain > 0.0:
		_gm.regenerate_energy(energy_gain)
	
	# 通知 GameManager
	if _gm:
		_gm.on_enemy_captured(enemy_type, capture_value)
	
	# 通知 EventBus
	if _event_bus:
		_event_bus.emit_signal("player_captured_enemy", enemy_type, capture_value)
	
	# 触发信号
	player_captured_enemy.emit(enemy_type, capture_value)
	
	# 升级后同步体型 (由 GameManager 阶梯式更新)
	_sync_from_gm()
	_update_body_visuals()
	
	# 从对象池回收敌人
	if _pool:
		_pool.despawn(enemy)
	
	
	# v1.1: 材质掉落 (怪物掉材质, 无经验系统)
	# heavy 30% / split 40% / 精英 100% (1~2) / Boss 100% (2~3)
	# 材质类型 5 种均等 (精英/Boss 50% 偏向自身属性)
	if _gm and _gm.has_method("drop_elemental_material"):
		_gm.drop_elemental_material(enemy_type)
	# 分裂怪吞下时分裂 (GDD 3.2)
	if enemy_type == "split" and _pool:
		for i in range(2):
			var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			var split_data: Dictionary = {
				"enemy_type": "basic",
				"speed": 80.0,
				"body_radius": 15.0,
				"color": Color(0.3, 0.8, 0.3),
			}
			_pool.spawn(global_position + offset, split_data)
	
	print("[Player] 吞噬了 ", enemy_type, " (+", round(capture_value), ")", 
		  " | 能量:", int(_gm.get_energy()) if _gm else "?")

## 获取吞噬收益值
func _get_capture_value(enemy_type: String, enemy_size: float) -> float:
	var values: Dictionary = {
		"basic": 1.0,
		"swift": 0.5,
		"heavy": 3.0,
		"split": 1.5,
		"decoy": 0.0,
		"boss": 10.0,
	}
	return values.get(enemy_type, 1.0)
## 中毒 DoT (GDD 5.8 elite_toxin)：每秒 _dps，持续 _duration 秒
func apply_poison(_dps: float, _duration: float) -> void:
	if _dps > _poison_dps or _poison_timer <= 0.0:
		_poison_dps = _dps
	_poison_timer = _duration

## 受到伤害
func take_damage(amount: int) -> void:
	if _invincible_timer > 0:
		return
	if amount <= 0:
		return
	
	hp -= amount
	_invincible_timer = 0.5  # 0.5s 无敌帧
	
	if _event_bus:
		_event_bus.emit_signal("player_hit", amount)
	
	if hp <= 0:
		hp = 0
		print("[Player] 玩家阵亡!")
		if _gm:
			_gm.player_died.emit()

## 摇杆/手势
func _on_joystick_moved(dir: Vector2) -> void:
	_current_direction = dir

func _on_joystick_released() -> void:
	_current_direction = Vector2.ZERO

func connect_joystick(joystick_node) -> void:
	joystick_node.moved.connect(_on_joystick_moved)
	joystick_node.released.connect(_on_joystick_released)

func handle_gesture(gesture_type: int, data: Dictionary) -> void:
	match gesture_type:
		1:  # MOVE
			pass
		2:  # SWIPE — 指向性技能
			if _gm and _gm.is_playing():
				print("[Player] 划屏技能! 方向:", data.get("direction", Vector2.ZERO))
				_cast_skill("swipe", data)
		3:  # DOUBLE_CLICK — 非指向性技能
			if _gm and _gm.is_playing():
				print("[Player] 双击技能!")
				_cast_skill("double_click", data)

func _cast_skill(skill_type: String, data: Dictionary) -> void:
	var direction = Vector2.ZERO
	if skill_type == "swipe":
		direction = data.get("direction", Vector2.RIGHT)
	if _event_bus:
		_event_bus.emit_signal("skill_cast", skill_type, direction)

## 受到伤害后 (供外部调用)
func on_player_hit(amount: int) -> void:
	take_damage(amount)

## 更新身体视觉
func _update_body_visuals() -> void:
	var scale: float = body_radius / 20.0
	scale = clamp(scale, 0.8, 3.0)
	scale_node(scale)
	
	var brightness: float = clamp(1.0 / scale, 0.3, 1.0)
	_body_color = Color(0.3 * brightness, 0.8 * brightness, 0.4 * brightness)
	
	var body = get_node_or_null("Body")
	if body and body is Sprite2D:
		if body.texture == null:
			body.texture = load("res://assets/sprites/player/player.png")
			if body.texture:
				var tex_size = body.texture.get_size()
				if tex_size.x > 0:
					var s = 40.0 / tex_size.x
					body.scale = Vector2(s, s)
		body.modulate = _body_color
	elif body and body is ColorRect:
		body.color = _body_color

func _sync_card_modifiers(stats: Dictionary) -> void:
	# 挣脱概率修正 (坚韧下颚/铁齿利牙卡)
	var esc_red: float = stats.get("escape_chance_reduction", 0.0)
	if esc_red > 0.0:
		_gnaw_escape_chance = _gnaw_escape_chance * (1.0 - clampf(esc_red, 0.0, 1.0))
		# 铁齿利牙 (escape_chance_reduction=1.0) 归零
		if esc_red >= 1.0:
			_gnaw_escape_chance = 0.0
	# 啃食速度修正 (啃食共鸣卡)
	var gnaw_bonus: float = stats.get("gnaw_speed_bonus", 0.0)
	if gnaw_bonus > 0.0:
		_gnaw_steadiness = _gnaw_steadiness * (1.0 + gnaw_bonus)

func scale_node(new_scale: float) -> void:
	scale = Vector2(new_scale, new_scale)

## 获取当前啃食进度 (供 UI 显示)
func get_gnaw_progress() -> float:
	if _gnaw_target == null:
		return 0.0
	return _gnaw_progress / maxf(_gnaw_required, 0.1)

## 获取啃食目标
func get_gnaw_target() -> Node2D:
	return _gnaw_target
func _escape_gnaw() -> void:
	var enemy := _gnaw_target
	if enemy == null or not is_instance_valid(enemy):
		_reset_gnaw()
		return
	# 挣脱反馈：把玩家推开
	if _gnaw_escape_feedback > 0.0:
		var dir = (global_position - enemy.global_position).normalized()
		global_position += dir * _gnaw_escape_feedback
		if _invincible_timer <= 0.0:
			_invincible_timer = 0.3
	# 敌人进入无敌 1s (GDD 3.2.2 挣脱后无敌)
	enemy.set_invincible(1.0)
	# 音效 + 屏幕抖动反馈
	_play_escape_feedback()
	# 返还部分能量
	if _gnaw_energy_refund > 0.0 and _gm:
		_gm.regenerate_energy(_gm.get_max_energy() * _gnaw_energy_refund * 0.1)
	_reset_gnaw()
	print("[Player] 敌人挣脱了啃食!")
## 挣脱时的视觉/音效反馈
func _play_escape_feedback() -> void:
	# 音效 (若无音频资源则静默)
	var audio = _get_audio_mgr()
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("escape")
	# 屏幕抖动 (通过 EventBus 通知 MainGame)
	if _event_bus and _event_bus.has_signal("screen_shake"):
		_event_bus.emit_signal("screen_shake", 0.25, 8.0)

func _get_audio_mgr() -> Object:
	return get_node_or_null("AudioMgr")
## 通用音效播放 (静默失败)
func _play_sfx_safe(name: String) -> void:
	var audio = _get_audio_mgr()
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(name)
