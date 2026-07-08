extends Node
## EnemyAI — 敌人行为控制器
## 挂载在每个敌人节点上，负责逃跑/游荡/边界处理

# ─── 配置参数 ─────────────────────────────────────────
const FLEE_ACCEL        := 300.0    # 逃跑加速度
const WANDER_ACCEL      := 100.0    # 游荡加速度
const MAX_WANDER_CHANGE := 2.0      # 游荡转向最大角度变化 (rad/s)
const BOUNDARY_MARGIN   := 50.0     # 边界安全距离
const PERLIN_SCALE      := 0.005    # Perlin Noise 扰动尺度

# ─── 内部状态 ─────────────────────────────────────────
var _velocity: Vector2 = Vector2.ZERO
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _perlin_seed: float = 0.0
var _state: int = 0  # 0=wander, 1=flee, 2=edge_slide

func _physics_process(delta: float) -> void:
    var enemy = owner as Node2D
    if enemy == null or not enemy.active:
        return
    
    var dist = enemy.distance_to_player()
    var base_speed = enemy.speed
    var dir = enemy.get_flee_direction()
    
    match _state:
        0:  # 游荡模式
            _handle_wander(delta, base_speed, enemy)
            if dist < enemy.flee_radius:
                _state = 1
                enemy.trigger_fear(0.5)
        
        1:  # 逃跑模式
            _handle_flee(delta, base_speed, dir, enemy)
            if dist > enemy.flee_radius * 1.5:
                _state = 0
                enemy.is_fleeing = false
                enemy.trigger_fear(0.0)
            else:
                enemy.is_fleeing = true
        
        2:  # 边缘滑动模式
            _handle_edge_slide(delta, base_speed, enemy)

## 游荡行为
func _handle_wander(delta: float, base_speed: float, enemy: Area2D) -> void:
    _wander_timer -= delta
    if _wander_timer <= 0:
        _wander_angle += randf_range(-MAX_WANDER_CHANGE, MAX_WANDER_CHANGE) * delta
        _wander_timer = randf_range(0.5, 2.0)
    
    var target_vel = Vector2.from_angle(_wander_angle) * base_speed * enemy.wander_speed_mult
    _velocity = _velocity.lerp(target_vel, 0.05)
    
    enemy.global_position += _velocity * delta

## 逃跑行为 (含 Perlin Noise 扰动)
func _handle_flee(delta: float, base_speed: float, dir: Vector2, enemy: Area2D) -> void:
    enemy.is_fleeing = true
    
    # Perlin Noise 随机扰动 — 让逃跑路线不那么死板
    _perlin_seed += delta * 2.0
    var noise_x = randf_range(-1.0, 1.0) * 0.5
    var noise_y = randf_range(-1.0, 1.0) * 0.5
    
    # 急转弯扰动 (近距离时更大)
    var dist = enemy.distance_to_player()
    var urgency = remap(dist, 0, enemy.flee_radius, 1.0, 0.0)
    noise_x += randf_range(-urgency, urgency)
    noise_y += randf_range(-urgency, urgency)
    
    var flee_dir = (dir + Vector2(noise_x, noise_y)).normalized()
    var target_speed = base_speed * enemy.flee_speed_mult
    
    # 近距离加速
    if dist < 80:
        target_speed *= 1.3
    
    var target_vel = flee_dir * target_speed
    _velocity = _velocity.lerp(target_vel, 0.08)
    
    enemy.global_position += _velocity * delta

## 边缘滑动行为
func _handle_edge_slide(delta: float, base_speed: float, enemy: Area2D) -> void:
    var screen_size = _get_screen_size()
    var pos = enemy.global_position
    
    # 检查是否在边界附近
    var near_boundary = (
        pos.x < BOUNDARY_MARGIN or 
        pos.x > screen_size.x - BOUNDARY_MARGIN or
        pos.y < BOUNDARY_MARGIN or
        pos.y > screen_size.y - BOUNDARY_MARGIN
    )
    
    if not near_boundary:
        _state = 1  # 回到逃跑模式
        return
    
    # 沿边缘滑动
    var boundary_force = Vector2.ZERO
    
    if pos.x < BOUNDARY_MARGIN:
        boundary_force.x = 1.0
    elif pos.x > screen_size.x - BOUNDARY_MARGIN:
        boundary_force.x = -1.0
    
    if pos.y < BOUNDARY_MARGIN:
        boundary_force.y = 1.0
    elif pos.y > screen_size.y - BOUNDARY_MARGIN:
        boundary_force.y = -1.0
    
    # 同时远离玩家
    var dir = enemy.get_flee_direction()
    boundary_force = boundary_force + dir * 0.5
    boundary_force = boundary_force.normalized()
    
    _velocity = boundary_force * base_speed * 0.8
    enemy.global_position += _velocity * delta

## 获取当前屏幕尺寸
func _get_screen_size() -> Vector2:
    var viewport = get_viewport()
    if viewport == null:
        return Vector2(720, 1280)
    return viewport.get_visible_rect().size

## 强制设置状态
func set_state(state: int) -> void:
    _state = state
