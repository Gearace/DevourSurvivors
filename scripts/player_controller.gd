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
var _gnaw_mult_now: float = 1.0        # v1.2 多大关 Boss 啃食加速倍率 (弱点1.5×/忍杀3×, §3.3)
var _gnaw_required: float = 1.0             # 该敌人需要啃多久

# ─── 内部状态 ─────────────────────────────────────────
var _gesture_detector: Object
var _current_direction: Vector2 = Vector2.ZERO
var _speed_multiplier: float = 1.0
var _invincible_timer: float = 0.0
var _body_color: Color = Color(0.3, 0.8, 0.4)

# P1: 表情帧/反馈特效 (素材已就位: munch/hurt/lowhp/shadow + fx_capture_pop)
var _tx_base: Texture2D
var _tx_munch: Texture2D
var _tx_hurt: Texture2D
var _tx_lowhp: Texture2D
var _tx_shadow: Texture2D
var _pop_fx: Sprite2D
var _munch_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
const LOW_HP_THRESHOLD := 0.25   # 低血量比例 (25% 以下换低血量帧)
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
	
	# P1: 加载表情帧贴图 + 创建阴影/吞噬反馈节点
	_setup_expression_frames()
	
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
	# P1: 表情帧/低血量视觉刷新
	_update_expression_frames(delta)
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
	
	# 进度推进（堡垒啃食减速：_gnaw_steadiness_now 越大越慢; Boss 啃食加速：_gnaw_mult_now 越大越快, §3.3）
	_gnaw_progress += _gnaw_steadiness * delta * _gnaw_mult_now / maxf(_gnaw_steadiness_now, 1.0)

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
	# v1.2 多大关 Boss 阶段 (只狼阶段化 §3.3)：读 meta gnaw_mult 加快啃食 (弱点1.5×/忍杀3×)
	# gnaw_mult 越大越快 — 与 gnaw_slow 相反, 除以 steady 后还需再乘 mult
	var gnaw_mult: float = 1.0
	if enemy.has_meta("gnaw_mult"):
		gnaw_mult = enemy.get_meta("gnaw_mult")
	_gnaw_mult_now = gnaw_mult


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
	
	# P1: 吞噬瞬间反馈 (大嘴帧 + pop 粒子)
	_play_munch()
	_play_capture_pop()

	# v1.2 P1 警报机制 (合金装备 §3.5): 吞噬累加 streak (受伤才清零)
	_notify_alarm_capture()
	
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
		"boss_ch1": 10.0,
		"boss_v2_void": 10.0,
		"boss_v3_abyss": 10.0,
		"elite_tearer": 5.0,
		"elite_toxin": 5.0,
		"elite_mirror": 5.0,
		"elite_fortress": 5.0,
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
	
	# P1: 受伤闪白 + hurt 表情帧
	_play_hurt_flash()
	
	if _event_bus:
		_event_bus.emit_signal("player_hit", amount)
	
	# v1.2 P1 警报机制: 受伤 → 警报清零 + streak 清零 (合金装备 §3.5)
	_notify_alarm_damage()
	
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

## v1.2 P1 警报机制: 通知 RouteGenerator.alarm
func _notify_alarm_capture() -> void:
	var rg = get_node_or_null("/root/MainGame/RouteGenerator")
	if rg and rg.alarm != null and rg.alarm.has_method("on_capture"):
		rg.alarm.on_capture()

func _notify_alarm_damage() -> void:
	var rg = get_node_or_null("/root/MainGame/RouteGenerator")
	if rg and rg.alarm != null and rg.alarm.has_method("on_damage"):
		rg.alarm.on_damage()

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
## P1: 加载表情帧 + 阴影 + 吞噬反馈 (贴图缺失时静默跳过, 不影响游戏)
func _setup_expression_frames() -> void:
	_tx_base = load("res://assets/sprites/player/player.png")
	_tx_munch = load("res://assets/sprites/player/player_munch.png")
	_tx_hurt = load("res://assets/sprites/player/player_hurt.png")
	_tx_lowhp = load("res://assets/sprites/player/player_lowhp.png")
	_tx_shadow = load("res://assets/sprites/player/player_shadow.png")

	if _tx_shadow != null:
		var shadow := Sprite2D.new()
		shadow.name = "Shadow"
		shadow.texture = _tx_shadow
		shadow.z_index = -1
		shadow.position = Vector2(0, body_radius * 0.55)
		shadow.modulate = Color(1, 1, 1, 0.35)
		add_child(shadow)

	if _gm == null:
		_gm = get_node_or_null("/root/GameManager")

## P1: 吞噬反馈 — 玩家位置播放 fx_capture_pop
func _play_capture_pop() -> void:
	var pop_tex = load("res://assets/sprites/particles/fx_capture_pop.png")
	if pop_tex == null:
		return
	if _pop_fx == null or not is_instance_valid(_pop_fx):
		_pop_fx = Sprite2D.new()
		_pop_fx.name = "CapturePop"
		_pop_fx.z_index = 10
		add_child(_pop_fx)
	_pop_fx.texture = pop_tex
	_pop_fx.global_position = global_position
	_pop_fx.modulate = Color(1, 1, 1, 1.0)
	_pop_fx.scale = Vector2.ONE
	_pop_fx.visible = true
	var tween := create_tween()
	tween.tween_property(_pop_fx, "scale", Vector2(1.6, 1.6), 0.25)
	tween.parallel().tween_property(_pop_fx, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if _pop_fx and is_instance_valid(_pop_fx):
			_pop_fx.visible = false
)

## P1: 吞噬瞬间表情 (0.3s 大嘴帧后回 base)
func _play_munch() -> void:
	if _tx_munch == null:
		return
	var body = get_node_or_null("Body")
	if body and body is Sprite2D:
		body.texture = _tx_munch
	_munch_timer = 0.5

## P1: 受伤闪白 + hurt 表情 (0.25s)
func _play_hurt_flash() -> void:
	if _tx_hurt != null:
		var body = get_node_or_null("Body")
		if body and body is Sprite2D:
			body.texture = _tx_hurt
	_hurt_flash_timer = 0.25
	modulate = Color(1.4, 1.0, 1.0, 1.0)

## P1: 每帧刷新表情/血量视觉状态
func _update_expression_frames(delta: float) -> void:
	var body = get_node_or_null("Body")
	if body == null or not (body is Sprite2D):
		return
	# munch / hurt 定时回 base
	_munch_timer -= delta
	_hurt_flash_timer -= delta
	if _hurt_flash_timer <= 0.0:
		modulate = Color.WHITE
	# 低血量持续帧 (优先级: munch > hurt > lowhp > base)
	var ratio: float = 1.0
	if _gm != null:
		var stats: Dictionary = _gm.player_stats
		var max_hp: int = int(stats.get("max_hp", 100))
		var cur_hp: int = int(stats.get("current_hp", max_hp))
		if max_hp > 0:
			ratio = float(cur_hp) / float(max_hp)
	if _munch_timer > 0.0:
		body.texture = _tx_munch
	elif _hurt_flash_timer > 0.0:
		body.texture = _tx_hurt
	elif ratio <= LOW_HP_THRESHOLD and _tx_lowhp != null:
		body.texture = _tx_lowhp
	elif _tx_base != null:
		body.texture = _tx_base
		# 低血量时身体边缘暗色提示
		body.modulate = Color(0.75, 0.75, 0.85, 1.0) if ratio <= LOW_HP_THRESHOLD else Color.WHITE

func _update_body_visuals() -> void:
	var scale: float = body_radius / 20.0
	scale = clamp(scale, 0.8, 3.0)
	scale_node(scale)
	
	var brightness: float = clamp(1.0 / scale, 0.3, 1.0)
	_body_color = Color(0.3 * brightness, 0.8 * brightness, 0.4 * brightness)
	
	var body = get_node_or_null("Body")
	if body and body is Sprite2D:
		if body.texture == null:
			body.texture = _tx_base if _tx_base != null else load("res://assets/sprites/player/player.png")
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
